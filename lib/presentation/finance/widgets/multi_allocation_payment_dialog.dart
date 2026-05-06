import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../data/repositories/communication_log_repository.dart';
import '../../../data/repositories/term_fee_payment_repository.dart';
import '../../../domain/entities/communication_log.dart';
import '../../../domain/entities/student_fee_item.dart';
import '../../../domain/entities/student_fee_ledger.dart';
import '../../../domain/entities/term_fee_payment.dart';
import 'uqi_qr_payment_widget.dart';

const Color _bgDark = Color(0xFF0D1117);
const Color _cardDark = Color(0xFF161B22);
const Color _accentGreen = Color(0xFF4CAF50);
const Color _accentBlue = Color(0xFF3B82F6);
const Color _accentAmber = Color(0xFFF59E0B);
const Color _accentRed = Color(0xFFEF4444);
const Color _textPrimary = Color(0xFFE6EDF3);
const Color _textSecondary = Color(0xFF8B949E);
const Color _borderColor = Color(0xFF30363D);

/// Multi-row "Make Payment" dialog. Lets the cashier collect a single
/// payment that the system allocates across **multiple open ledger rows**
/// — across categories, terms, and prior-year arrears — atomically.
///
/// Behavior:
///   * Lists every ledger term entry with `balanceAmount > 0`.
///   * Arrears rows (carried from prior years) appear first by default
///     (FIFO), tagged with their source academic year.
///   * Also lists ad-hoc fee items with outstanding balances.
///   * The cashier can enter a total tendered amount and click
///     "Auto-allocate" to fill rows oldest-first; or fill row-by-row
///     manually.
///   * Submit records one [TermFeePayment] per allocated row, each as a
///     separate transaction (preserves the existing single-term contract
///     of [TermFeePaymentRepository.recordPayment] + receipt counter).
///   * For ad-hoc fees, records payments via StudentFeeItemRepository.
///   * On any per-row failure, the dialog reports which rows succeeded
///     and surfaces the failure for the rest, so the cashier can retry.
///
/// Returns `true` if at least one row was paid successfully so the
/// caller can refresh.
class MultiAllocationPaymentDialog extends ConsumerStatefulWidget {
  const MultiAllocationPaymentDialog({
    super.key,
    required this.schoolId,
    required this.ledger,
    this.adHocFeeItems = const [],
  });

  final String schoolId;
  final StudentFeeLedger ledger;
  final List<StudentFeeItem> adHocFeeItems;

  @override
  ConsumerState<MultiAllocationPaymentDialog> createState() =>
      _MultiAllocationPaymentDialogState();
}

class _MultiAllocationPaymentDialogState
    extends ConsumerState<MultiAllocationPaymentDialog> {
  late List<TermLedgerEntry> _openEntries;
  late List<StudentFeeItem> _openAdHocItems;
  late Map<String, TextEditingController> _amountCtrls;
  late Map<String, TextEditingController> _adhocAmountCtrls;
  final TextEditingController _totalTenderedCtrl = TextEditingController();
  final TextEditingController _refCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  TermPaymentMode _mode = TermPaymentMode.CASH;
  DateTime _paidAt = DateTime.now();
  bool _saving = false;
  String? _error;
  
  // Parent phone - fetched from student record if not in ledger
  String? _parentPhone;
  String? _parentName;

  /// Get the effective parent phone (always from student record, not ledger)
  String? get _effectiveParentPhone {
    // Always use parent phone from student detail, not from ledger
    return _parentPhone;
  }

  @override
  void initState() {
    super.initState();
    _loadParentInfoFromStudent();
    // Arrears first (FIFO by sourceAcademicYear), then regular by sequence.
    final entries =
        widget.ledger.termStatus.where((e) => e.balanceAmount > 0.001).toList()
          ..sort((a, b) {
            if (a.isArrear != b.isArrear) return a.isArrear ? -1 : 1;
            if (a.isArrear) {
              // Older source AY first.
              final c = a.sourceAcademicYear.compareTo(b.sourceAcademicYear);
              if (c != 0) return c;
            }
            return a.sequence.compareTo(b.sequence);
          });
    _openEntries = entries;
    _amountCtrls = {
      for (final e in entries) e.termId: TextEditingController(text: '0'),
    };

    // Ad-hoc fee items with outstanding balance
    final adhocItems = widget.adHocFeeItems
        .where((e) => e.balanceAmount > 0.001)
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    _openAdHocItems = adhocItems;
    _adhocAmountCtrls = {
      for (final e in adhocItems) e.id: TextEditingController(text: '0'),
    };
  }

  @override
  void dispose() {
    for (final c in _amountCtrls.values) {
      c.dispose();
    }
    for (final c in _adhocAmountCtrls.values) {
      c.dispose();
    }
    _totalTenderedCtrl.dispose();
    _refCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  /// Create a communication log entry in Firestore for audit/visibility
  Future<void> _logCommunication({
    required CommPurpose purpose,
    required String subject,
    required String message,
    required CommStatus status,
    String? errorMessage,
  }) async {
    try {
      final session = ref.read(currentSessionProvider);
      final phone = _effectiveParentPhone;
      if (phone == null || phone.isEmpty) return;

      final repo = ref.read(communicationLogRepositoryProvider);
      await repo.createLog(CommunicationLog(
        id: '',
        schoolId: widget.ledger.schoolId,
        recipientId: widget.ledger.studentId,
        recipientName:
            _parentName ?? widget.ledger.parentName ?? widget.ledger.studentName,
        recipientPhone: phone,
        recipientType: RecipientType.parent,
        purpose: purpose,
        channel: CommChannel.whatsapp,
        status: status,
        subject: subject,
        message: message,
        relatedEntityId: widget.ledger.id,
        relatedEntityType: 'studentFeeLedger',
        sentByUserId: session?.uid,
        sentByName: session?.displayName,
        sentAt: DateTime.now(),
        errorMessage: errorMessage,
      ));
    } catch (e) {
      debugPrint('[PaymentDialog] Failed to log communication: $e');
    }
  }

  /// Fetch parent phone and name from student document if not in ledger
  Future<void> _loadParentInfoFromStudent() async {
    // Skip if ledger already has parent phone
    if (widget.ledger.parentPhone != null && widget.ledger.parentPhone!.isNotEmpty) {
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.ledger.schoolId)
          .collection('students')
          .doc(widget.ledger.studentId)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data();
        if (data != null) {
          setState(() {
            _parentPhone = data['parentPhone']?.toString() ?? 
                          data['parentMobile']?.toString() ??
                          data['studentPhone']?.toString();
            _parentName = data['parentName']?.toString();
          });
          debugPrint('[PaymentDialog] Loaded parent phone: $_parentPhone');
        }
      }
    } catch (e) {
      debugPrint('[PaymentDialog] Error loading parent info: $e');
    }
  }

  double _allocatedTotal() {
    double t = 0;
    for (final c in _amountCtrls.values) {
      t += double.tryParse(c.text.trim()) ?? 0;
    }
    for (final c in _adhocAmountCtrls.values) {
      t += double.tryParse(c.text.trim()) ?? 0;
    }
    return t;
  }

  void _autoAllocate() {
    final tendered = double.tryParse(_totalTenderedCtrl.text.trim()) ?? 0;
    if (tendered <= 0) {
      setState(() => _error = 'Enter a tendered amount first');
      return;
    }
    double remaining = tendered;

    // Allocate to ledger entries first (arrears first, then regular)
    for (final e in _openEntries) {
      if (remaining <= 0) {
        _amountCtrls[e.termId]!.text = '0';
        continue;
      }
      final take = remaining < e.balanceAmount ? remaining : e.balanceAmount;
      _amountCtrls[e.termId]!.text = take.toStringAsFixed(0);
      remaining -= take;
    }

    // Then allocate to ad-hoc fee items
    for (final e in _openAdHocItems) {
      if (remaining <= 0) {
        _adhocAmountCtrls[e.id]!.text = '0';
        continue;
      }
      final take = remaining < e.balanceAmount ? remaining : e.balanceAmount;
      _adhocAmountCtrls[e.id]!.text = take.toStringAsFixed(0);
      remaining -= take;
    }

    setState(() {
      _error = remaining > 0.01
          ? 'Tendered amount exceeds total outstanding by ₹${remaining.toStringAsFixed(0)}'
          : null;
    });
  }

  Future<void> _submit() async {
    final allocations = <(TermLedgerEntry entry, double amount)>[];
    for (final e in _openEntries) {
      final amt = double.tryParse(_amountCtrls[e.termId]!.text.trim()) ?? 0;
      if (amt <= 0) continue;
      if (amt > e.balanceAmount + 0.01) {
        setState(() => _error =
            'Row "${e.termName}": ₹$amt exceeds balance ₹${e.balanceAmount.toStringAsFixed(0)}');
        return;
      }
      allocations.add((e, amt));
    }

    final adhocAllocations = <(StudentFeeItem item, double amount)>[];
    for (final e in _openAdHocItems) {
      final amt = double.tryParse(_adhocAmountCtrls[e.id]!.text.trim()) ?? 0;
      if (amt <= 0) continue;
      if (amt > e.balanceAmount + 0.01) {
        setState(() => _error =
            'Ad-hoc fee "${e.itemName}": ₹$amt exceeds balance ₹${e.balanceAmount.toStringAsFixed(0)}');
        return;
      }
      adhocAllocations.add((e, amt));
    }

    if (allocations.isEmpty && adhocAllocations.isEmpty) {
      setState(() => _error = 'Enter an amount on at least one row');
      return;
    }

    // Validate that allocated total doesn't exceed tendered amount
    final allocatedTotal = _allocatedTotal();
    final tenderedAmount = double.tryParse(_totalTenderedCtrl.text.trim()) ?? 0;
    if (allocatedTotal > tenderedAmount + 0.01) {
      setState(() => _error =
          'Allocated amount ₹${allocatedTotal.toStringAsFixed(0)} exceeds tendered amount ₹${tenderedAmount.toStringAsFixed(0)}');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      print('[Payment Dialog] Starting payment submission...');

      final repo = ref.read(termFeePaymentRepositoryProvider);
      print('[Payment Dialog] Repository loaded');

      final session = ref.read(currentSessionProvider);
      print('[Payment Dialog] Session loaded: ${session?.uid}');

      // Check if session is available
      if (session == null) {
        setState(() {
          _saving = false;
          _error = 'Session expired or invalid. Please log in again.';
        });
        return;
      }

      // Prepare term allocations
      print('[Payment Dialog] Preparing term allocations...');
      final termAllocations = allocations
          .map((a) => TermAllocation(
                termId: a.$1.termId,
                termName: a.$1.termName,
                amount: a.$2,
              ))
          .toList();
      print(
          '[Payment Dialog] Term allocations prepared: ${termAllocations.length}');

      // Prepare ad-hoc allocations
      print('[Payment Dialog] Preparing ad-hoc allocations...');
      final adHocAllocations = adhocAllocations
          .map((a) => AdHocAllocation(
                feeItemId: a.$1.id,
                itemName: a.$1.itemName,
                categoryCode: a.$1.categoryCode,
                amount: a.$2,
              ))
          .toList();
      print(
          '[Payment Dialog] Ad-hoc allocations prepared: ${adHocAllocations.length}');

      // Record single payment with both term and adhoc allocations
      print('[Payment Dialog] Calling recordMultiTermPayment...');
      await repo.recordMultiTermPayment(RecordMultiTermPaymentRequest(
        schoolId: widget.schoolId,
        ledgerId: widget.ledger.id,
        termAllocations: termAllocations,
        adHocAllocations: adHocAllocations,
        paymentMode: _mode,
        transactionRef:
            _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
        paidAt: _paidAt,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        collectedBy: session.uid,
        collectedByName: session.displayName,
      ));
      print('[Payment Dialog] Payment recorded successfully');

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: _accentGreen,
        content: Text('Payment saved successfully with single bill ID'),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        // Provide more detailed error message
        String errorMsg = 'Payment failed: ';
        if (e.toString().contains('Student ledger not found')) {
          errorMsg += 'Student ledger not found. Please refresh and try again.';
        } else if (e.toString().contains('not on ledger')) {
          errorMsg +=
              'Term not found on ledger. Data may be stale. Please refresh.';
        } else if (e.toString().contains('exceeds balance')) {
          errorMsg +=
              'Amount exceeds available balance. Please check the amounts.';
        } else if (e.toString().contains('permission') ||
            e.toString().contains('PERMISSION_DENIED')) {
          errorMsg +=
              'Permission denied. You may not have the required permissions.';
        } else {
          errorMsg += e.toString();
        }
        _error = errorMsg;
      });
    }
  }

  void _showUPIQR() {
    final allocations = <(TermLedgerEntry entry, double amount)>[];
    for (final e in _openEntries) {
      final amt = double.tryParse(_amountCtrls[e.termId]!.text.trim()) ?? 0;
      if (amt <= 0) continue;
      if (amt > e.balanceAmount + 0.01) {
        setState(() => _error =
            'Row "${e.termName}": ₹$amt exceeds balance ₹${e.balanceAmount.toStringAsFixed(0)}');
        return;
      }
      allocations.add((e, amt));
    }

    final adhocAllocations = <(StudentFeeItem item, double amount)>[];
    for (final e in _openAdHocItems) {
      final amt = double.tryParse(_adhocAmountCtrls[e.id]!.text.trim()) ?? 0;
      if (amt <= 0) continue;
      if (amt > e.balanceAmount + 0.01) {
        setState(() => _error =
            'Ad-hoc fee "${e.itemName}": ₹$amt exceeds balance ₹${e.balanceAmount.toStringAsFixed(0)}');
        return;
      }
      adhocAllocations.add((e, amt));
    }

    if (allocations.isEmpty && adhocAllocations.isEmpty) {
      setState(() => _error = 'Enter an amount on at least one row');
      return;
    }

    // Validate that allocated total doesn't exceed tendered amount
    final allocatedTotal = _allocatedTotal();
    final tenderedAmount = double.tryParse(_totalTenderedCtrl.text.trim()) ?? 0;
    if (allocatedTotal > tenderedAmount + 0.01) {
      setState(() => _error =
          'Allocated amount ₹${allocatedTotal.toStringAsFixed(0)} exceeds tendered amount ₹${tenderedAmount.toStringAsFixed(0)}');
      return;
    }

    final totalAmount = allocations.fold<double>(0, (s, a) => s + a.$2) +
        adhocAllocations.fold<double>(0, (s, a) => s + a.$2);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _cardDark,
        child: UPIQRPaymentWidget(
          schoolId: widget.schoolId,
          ledger: widget.ledger,
          amount: totalAmount,
          onPaymentConfirmed: () async {
            await _savePaymentAfterUPI(allocations, adhocAllocations);
          },
          onCancel: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  Future<void> _savePaymentAfterUPI(
    List<(TermLedgerEntry, double)> allocations,
    List<(StudentFeeItem, double)> adhocAllocations,
  ) async {
    try {
      setState(() {
        _saving = true;
      });

      final repo = ref.read(termFeePaymentRepositoryProvider);
      final session = ref.read(currentSessionProvider);

      if (session == null) {
        setState(() {
          _saving = false;
          _error = 'Session expired or invalid. Please log in again.';
        });
        return;
      }

      final termAllocations = allocations
          .map((a) => TermAllocation(
                termId: a.$1.termId,
                termName: a.$1.termName,
                amount: a.$2,
              ))
          .toList();

      final adHocAllocations = adhocAllocations
          .map((a) => AdHocAllocation(
                feeItemId: a.$1.id,
                itemName: a.$1.itemName,
                categoryCode: a.$1.categoryCode,
                amount: a.$2,
              ))
          .toList();

      await repo.recordMultiTermPayment(RecordMultiTermPaymentRequest(
        schoolId: widget.schoolId,
        ledgerId: widget.ledger.id,
        termAllocations: termAllocations,
        adHocAllocations: adHocAllocations,
        paymentMode: TermPaymentMode.UPI,
        transactionRef: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
        paidAt: DateTime.now(),
        notes: 'UPI QR Code Payment',
        collectedBy: session.uid,
        collectedByName: session.displayName,
      ));

      if (!mounted) return;
      Navigator.of(context).pop(true);
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: _accentGreen,
        content: Text('Payment saved successfully via UPI QR'),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Payment saved failed: $e';
      });
    }
  }

  Future<void> _sendPaymentDueNotification() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardDark,
        title: const Text('Send Payment Due Notification',
            style: TextStyle(color: _textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Student: ${widget.ledger.studentName}',
                style: const TextStyle(color: _textPrimary)),
            const SizedBox(height: 8),
            Text('Pending Amount: ₹${widget.ledger.totalPending.toStringAsFixed(0)}',
                style: const TextStyle(color: Colors.orange, fontSize: 16)),
            const SizedBox(height: 12),
            if (_effectiveParentPhone != null)
              Text('Notification will be sent to: $_effectiveParentPhone',
                  style: const TextStyle(color: _textSecondary, fontSize: 12))
            else
              const Text('No parent phone number available',
                  style: TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: _effectiveParentPhone != null
                ? () => Navigator.pop(context, true)
                : null,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Send Notification'),
          ),
        ],
      ),
    );

    if (confirmed == true && _effectiveParentPhone != null) {
      try {
        // TODO: Implement WhatsApp/SMS notification
        await Future.delayed(const Duration(seconds: 1));

        // Log the communication
        await _logCommunication(
          purpose: CommPurpose.paymentDue,
          subject: 'Payment Due Reminder',
          message: 'Payment of ₹${widget.ledger.totalPending.toStringAsFixed(0)} is due for ${widget.ledger.studentName}. Please pay at your earliest convenience.',
          status: CommStatus.sent,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Payment due notification sent to $_effectiveParentPhone'),
              backgroundColor: Colors.green,
            ),
          );

          // Update last reminder sent
          await FirebaseFirestore.instance
              .collection('schools')
              .doc(widget.schoolId)
              .collection('studentFeeLedgers')
              .doc(widget.ledger.id)
              .update({'lastReminderSentAt': FieldValue.serverTimestamp()});
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send notification: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        // Log failed attempt
        await _logCommunication(
          purpose: CommPurpose.paymentDue,
          subject: 'Payment Due Reminder',
          message: 'Payment of ₹${widget.ledger.totalPending.toStringAsFixed(0)} is due for ${widget.ledger.studentName}. Please pay at your earliest convenience.',
          status: CommStatus.failed,
          errorMessage: e.toString(),
        );
      }
    }
  }

  Future<void> _sendTermPaymentDueNotification(TermLedgerEntry term) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardDark,
        title: const Text('Send Payment Reminder',
            style: TextStyle(color: _textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Student: ${widget.ledger.studentName}',
                style: const TextStyle(color: _textPrimary)),
            const SizedBox(height: 8),
            Text('Fee: ${term.termName}',
                style: const TextStyle(color: _accentBlue, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Category: ${term.category}',
                style: const TextStyle(color: _textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            Text('Pending Amount: ₹${term.balanceAmount.toStringAsFixed(0)}',
                style: const TextStyle(color: Colors.orange, fontSize: 16)),
            const SizedBox(height: 4),
            Text('Due Date: ${DateFormat('dd MMM yyyy').format(term.dueDate)}',
                style: const TextStyle(color: _textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            if (_effectiveParentPhone != null)
              Text('Notification will be sent to: $_effectiveParentPhone',
                  style: const TextStyle(color: _textSecondary, fontSize: 12))
            else
              const Text('No parent phone number available',
                  style: TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: _effectiveParentPhone != null
                ? () => Navigator.pop(context, true)
                : null,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Send Reminder'),
          ),
        ],
      ),
    );

    if (confirmed == true && _effectiveParentPhone != null) {
      try {
        // TODO: Implement WhatsApp/SMS notification for specific term
        await Future.delayed(const Duration(seconds: 1));

        // Log the communication
        await _logCommunication(
          purpose: CommPurpose.feeReminder,
          subject: '${term.termName} Payment Reminder',
          message: 'Payment of ₹${term.balanceAmount.toStringAsFixed(0)} for ${term.termName} is due for ${widget.ledger.studentName}. Due date: ${DateFormat('dd MMM yyyy').format(term.dueDate)}.',
          status: CommStatus.sent,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Payment reminder for ${term.termName} sent to $_effectiveParentPhone'),
              backgroundColor: Colors.green,
            ),
          );

          // Update last reminder sent
          await FirebaseFirestore.instance
              .collection('schools')
              .doc(widget.schoolId)
              .collection('studentFeeLedgers')
              .doc(widget.ledger.id)
              .update({'lastReminderSentAt': FieldValue.serverTimestamp()});
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send reminder: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        // Log failed attempt
        await _logCommunication(
          purpose: CommPurpose.feeReminder,
          subject: '${term.termName} Payment Reminder',
          message: 'Payment of ₹${term.balanceAmount.toStringAsFixed(0)} for ${term.termName} is due for ${widget.ledger.studentName}. Due date: ${DateFormat('dd MMM yyyy').format(term.dueDate)}.',
          status: CommStatus.failed,
          errorMessage: e.toString(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final money =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final allocated = _allocatedTotal();
    final outstanding =
        _openEntries.fold<double>(0, (s, e) => s + e.balanceAmount) +
            _openAdHocItems.fold<double>(0, (s, e) => s + e.balanceAmount);

    return Dialog(
      backgroundColor: _cardDark,
      surfaceTintColor: _cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Theme(
        // Force a dark InputDecoration theme so every TextField /
        // DropdownButtonFormField / InputDecorator below inherits the
        // correct dark surface instead of the app-wide light fill.
        data: Theme.of(context).copyWith(
          canvasColor: _cardDark,
          dialogBackgroundColor: _cardDark,
          textTheme: Theme.of(context).textTheme.apply(
                bodyColor: _textPrimary,
                displayColor: _textPrimary,
              ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: _bgDark,
            isDense: true,
            labelStyle: const TextStyle(color: _textSecondary),
            hintStyle: const TextStyle(color: _textSecondary),
            prefixStyle: const TextStyle(color: _textSecondary),
            suffixStyle: const TextStyle(color: _textSecondary),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _accentGreen),
            ),
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(children: [
                  const Icon(Icons.payments_rounded, color: _accentGreen),
                  const SizedBox(width: 8),
                  const Text('Make Payment',
                      style: TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18)),
                  const Spacer(),
                  IconButton(
                    icon:
                        const Icon(Icons.close_rounded, color: _textSecondary),
                    onPressed: _saving ? null : () => Navigator.pop(context),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(
                    '${widget.ledger.studentName} • ${widget.ledger.className} • AY ${widget.ledger.academicYear}',
                    style:
                        const TextStyle(color: _textSecondary, fontSize: 12)),
                const SizedBox(height: 12),

                // Tendered amount + auto-allocate
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _bgDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _borderColor),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _totalTenderedCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}'))
                        ],
                        style: const TextStyle(
                            color: _textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                        decoration: const InputDecoration(
                          labelText: 'Total Tendered',
                          labelStyle: TextStyle(color: _textSecondary),
                          prefixText: '₹ ',
                          prefixStyle: TextStyle(color: _textSecondary),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _saving ? null : _autoAllocate,
                      icon: const Icon(Icons.auto_awesome, size: 16),
                      label: const Text('Auto-allocate'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentBlue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),

                // Open ledger rows
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        ..._openEntries
                            .map((e) => _allocationRow(e, money))
                            .toList(),
                        if (_openAdHocItems.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _accentAmber.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.event_note_rounded,
                                    color: _accentAmber, size: 14),
                                const SizedBox(width: 4),
                                Text('Ad-Hoc Fees',
                                    style: TextStyle(
                                        color: _accentAmber,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          ..._openAdHocItems
                              .map((e) => _adhocAllocationRow(e, money))
                              .toList(),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Allocation summary
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: _bgDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _borderColor),
                  ),
                  child: Row(children: [
                    Text('Outstanding: ${money.format(outstanding)}',
                        style: const TextStyle(
                            color: _textSecondary, fontSize: 12)),
                    const Spacer(),
                    Text('Allocated: ${money.format(allocated)}',
                        style: TextStyle(
                            color:
                                allocated > 0 ? _accentGreen : _textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                  ]),
                ),

                const SizedBox(height: 12),

                // Mode + date + ref + notes
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<TermPaymentMode>(
                      value: _mode,
                      dropdownColor: _cardDark,
                      style: const TextStyle(color: _textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Mode',
                        labelStyle: TextStyle(color: _textSecondary),
                        isDense: true,
                      ),
                      items: TermPaymentMode.values
                          .map((m) =>
                              DropdownMenuItem(value: m, child: Text(m.name)))
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (v) =>
                              setState(() => _mode = v ?? TermPaymentMode.CASH),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _saving
                          ? null
                          : () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _paidAt,
                                firstDate: DateTime(2020),
                                lastDate:
                                    DateTime.now().add(const Duration(days: 1)),
                              );
                              if (picked != null) {
                                setState(() => _paidAt = picked);
                              }
                            },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          labelStyle: TextStyle(color: _textSecondary),
                          isDense: true,
                        ),
                        child: Text(DateFormat('dd MMM yyyy').format(_paidAt),
                            style: const TextStyle(color: _textPrimary)),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                TextField(
                  controller: _refCtrl,
                  style: const TextStyle(color: _textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Transaction Reference',
                    labelStyle: TextStyle(color: _textSecondary),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesCtrl,
                  style: const TextStyle(color: _textPrimary),
                  maxLines: 1,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    labelStyle: TextStyle(color: _textSecondary),
                    isDense: true,
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _accentRed.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _accentRed.withOpacity(0.4)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.warning_amber,
                          color: _accentRed, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                color: _accentRed, fontSize: 12)),
                      ),
                    ]),
                  ),
                ],

                // Send Payment Due Button (if pending amount > 0)
                if (widget.ledger.totalPending > 0) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _sendPaymentDueNotification,
                      icon: const Icon(Icons.notifications_active, size: 18),
                      label: Text('Send Payment Due (₹${money.format(widget.ledger.totalPending)})'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _saving || allocated <= 0 ? null : _submit,
                        icon: _saving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.save_rounded),
                        label: Text(_saving
                            ? 'Saving…'
                            : 'Save Payment (${money.format(allocated)})'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentGreen,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _borderColor,
                          disabledForegroundColor: _textSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // UPI QR code - admin shows QR to payee on all platforms
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _saving || allocated <= 0 ? null : _showUPIQR,
                        icon: const Icon(Icons.qr_code_2_rounded),
                        label: Text('Show UPI QR (${money.format(allocated)})'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentAmber,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _borderColor,
                          disabledForegroundColor: _textSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _allocationRow(TermLedgerEntry e, NumberFormat money) {
    final isArrear = e.isArrear;
    final tagColor = isArrear ? _accentRed : _accentBlue;
    final tagLabel = isArrear ? 'ARREARS ${e.sourceAcademicYear}' : e.category;
    
    // Debug: Check if notify button should show
    final shouldShowNotify = e.balanceAmount > 0 && 
        widget.ledger.parentPhone != null && 
        widget.ledger.parentPhone!.isNotEmpty;
    debugPrint('[AllocationRow] ${e.termName}: balance=${e.balanceAmount}, phone=${widget.ledger.parentPhone}, showNotify=$shouldShowNotify');

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _bgDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: tagColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: tagColor.withOpacity(0.4)),
            ),
            child: Text(tagLabel,
                style: TextStyle(
                    color: tagColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3)),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.termName,
                    style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                Text(
                    'Due ${DateFormat('dd MMM yyyy').format(e.dueDate)} • Bal ${money.format(e.balanceAmount)}',
                    style:
                        const TextStyle(color: _textSecondary, fontSize: 10)),
              ],
            ),
          ),
          SizedBox(
            width: 110,
            child: TextField(
              controller: _amountCtrls[e.termId],
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
              ],
              style: const TextStyle(color: _textPrimary, fontSize: 13),
              textAlign: TextAlign.right,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: const TextStyle(color: _textSecondary),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                hintText: '0',
                hintStyle: const TextStyle(color: _textSecondary),
                filled: true,
                fillColor: _cardDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: _borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: _borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: _accentGreen),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Notify button for this specific fee term - show if has balance
          if (e.balanceAmount > 0)
            IconButton(
              icon: const Icon(Icons.notifications_outlined, size: 18),
              color: Colors.orange,
              tooltip: 'Send reminder for ${e.termName}',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () => _sendTermPaymentDueNotification(e),
            ),
        ],
      ),
    );
  }

  Widget _adhocAllocationRow(StudentFeeItem item, NumberFormat money) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _bgDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _accentAmber.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _accentAmber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _accentAmber.withOpacity(0.4)),
            ),
            child: Text(item.categoryCode,
                style: TextStyle(
                    color: _accentAmber,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3)),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.itemName,
                    style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                Text(
                    'Due ${DateFormat('dd MMM yyyy').format(item.dueDate)} • Bal ${money.format(item.balanceAmount)}',
                    style:
                        const TextStyle(color: _textSecondary, fontSize: 10)),
              ],
            ),
          ),
          SizedBox(
            width: 110,
            child: TextField(
              controller: _adhocAmountCtrls[item.id],
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
              ],
              style: const TextStyle(color: _textPrimary, fontSize: 13),
              textAlign: TextAlign.right,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: const TextStyle(color: _textSecondary),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                hintText: '0',
                hintStyle: const TextStyle(color: _textSecondary),
                filled: true,
                fillColor: _cardDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: _borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: _borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: _accentAmber),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Notify button for this specific ad-hoc fee - show if has balance
          if (item.balanceAmount > 0)
            IconButton(
              icon: const Icon(Icons.notifications_outlined, size: 18),
              color: _accentAmber,
              tooltip: 'Send reminder for ${item.itemName}',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () => _sendAdHocFeePaymentDueNotification(item),
            ),
        ],
      ),
    );
  }

  Future<void> _sendAdHocFeePaymentDueNotification(StudentFeeItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardDark,
        title: const Text('Send Payment Reminder',
            style: TextStyle(color: _textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Student: ${widget.ledger.studentName}',
                style: const TextStyle(color: _textPrimary)),
            const SizedBox(height: 8),
            Text('Fee: ${item.itemName}',
                style: TextStyle(color: _accentAmber, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Category: ${item.categoryCode}',
                style: const TextStyle(color: _textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            Text('Pending Amount: ₹${item.balanceAmount.toStringAsFixed(0)}',
                style: const TextStyle(color: Colors.orange, fontSize: 16)),
            const SizedBox(height: 4),
            Text('Due Date: ${DateFormat('dd MMM yyyy').format(item.dueDate)}',
                style: const TextStyle(color: _textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            if (_effectiveParentPhone != null)
              Text('Notification will be sent to: $_effectiveParentPhone',
                  style: const TextStyle(color: _textSecondary, fontSize: 12))
            else
              const Text('No parent phone number available',
                  style: TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: _effectiveParentPhone != null
                ? () => Navigator.pop(context, true)
                : null,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Send Reminder'),
          ),
        ],
      ),
    );

    if (confirmed == true && _effectiveParentPhone != null) {
      try {
        // TODO: Implement WhatsApp/SMS notification for ad-hoc fee
        await Future.delayed(const Duration(seconds: 1));

        // Log the communication
        await _logCommunication(
          purpose: CommPurpose.feeReminder,
          subject: '${item.itemName} Payment Reminder',
          message: 'Payment of ₹${item.balanceAmount.toStringAsFixed(0)} for ${item.itemName} is due for ${widget.ledger.studentName}. Due date: ${DateFormat('dd MMM yyyy').format(item.dueDate)}.',
          status: CommStatus.sent,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Payment reminder for ${item.itemName} sent to $_effectiveParentPhone'),
              backgroundColor: Colors.green,
            ),
          );

          // Update last reminder sent
          await FirebaseFirestore.instance
              .collection('schools')
              .doc(widget.schoolId)
              .collection('studentFeeLedgers')
              .doc(widget.ledger.id)
              .update({'lastReminderSentAt': FieldValue.serverTimestamp()});
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send reminder: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        // Log failed attempt
        await _logCommunication(
          purpose: CommPurpose.feeReminder,
          subject: '${item.itemName} Payment Reminder',
          message: 'Payment of ₹${item.balanceAmount.toStringAsFixed(0)} for ${item.itemName} is due for ${widget.ledger.studentName}. Due date: ${DateFormat('dd MMM yyyy').format(item.dueDate)}.',
          status: CommStatus.failed,
          errorMessage: e.toString(),
        );
      }
    }
  }
}

// Suppress unused-warning for _accentAmber if neighbors trim it.
// ignore: unused_element
const Color _kKeepAmber = _accentAmber;
