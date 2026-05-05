import 'dart:typed_data';
import 'dart:html' as html;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/fee_refresh_provider.dart';
import '../../shared/widgets/searchable_dropdown.dart';
import '../../shared/pdf/pdf_branding.dart';

const Color _bgDark = Color(0xFF0D1117);
const Color _cardDark = Color(0xFF161B22);
const Color _accentGreen = Color(0xFF4CAF50);
const Color _textPrimary = Color(0xFFE6EDF3);
const Color _textSecondary = Color(0xFF8B949E);
const Color _borderColor = Color(0xFF30363D);

class BillManagementScreen extends ConsumerStatefulWidget {
  const BillManagementScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<BillManagementScreen> createState() =>
      _BillManagementScreenState();
}

class _BillManagementScreenState extends ConsumerState<BillManagementScreen> {
  DateTime _startDate = _startOfCurrentWeek();
  DateTime _endDate = _endOfCurrentWeek();
  String _filterType = 'Both';
  String _quickRange = 'week';
  List<Map<String, dynamic>> _revenueBills = [];
  List<Map<String, dynamic>> _expenseBills = [];
  bool _isLoading = false;
  String? _schoolId;
  final Set<String> _selectedRevenueBills = {};
  final Set<String> _selectedExpenseBills = {};

  @override
  void initState() {
    super.initState();
    loadPdfUnicodeFont(); // Load global Unicode font
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _schoolId = ref.read(currentSessionProvider)?.schoolId;
      if (_schoolId != null) _fetchBills();
    });
  }

  static DateTime _startOfCurrentWeek() {
    final now = DateTime.now();
    // DateTime.weekday: Monday = 1 ... Sunday = 7
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return DateTime(monday.year, monday.month, monday.day);
  }

  static DateTime _endOfCurrentWeek() {
    final monday = _startOfCurrentWeek();
    final sunday = monday.add(const Duration(days: 6));
    return DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59);
  }

  Future<void> _fetchBills() async {
    if (_schoolId == null) return;
    setState(() {
      _isLoading = true;
      _selectedRevenueBills.clear();
      _selectedExpenseBills.clear();
    });

    try {
      final revenueResults = <Map<String, dynamic>>[];
      final expenseResults = <Map<String, dynamic>>[];
      final rangeStart = Timestamp.fromDate(
          DateTime(_startDate.year, _startDate.month, _startDate.day));
      final rangeEnd = Timestamp.fromDate(DateTime(
          _endDate.year, _endDate.month, _endDate.day, 23, 59, 59, 999));

      // Fetch Revenue bills (term fee payments)
      if (_filterType == 'Both' || _filterType == 'Revenue') {
        final termPayments = await FirebaseFirestore.instance
            .collection('schools')
            .doc(_schoolId)
            .collection('termFeePayments')
            .where('paidAt', isGreaterThanOrEqualTo: rangeStart)
            .where('paidAt', isLessThanOrEqualTo: rangeEnd)
            .orderBy('paidAt', descending: true)
            .get();

        for (final doc in termPayments.docs) {
          final d = doc.data();
          d['docId'] = doc.id;
          d['billType'] = 'Revenue';
          revenueResults.add(d);
        }

        // Fetch ad-hoc fee items with payments
        try {
          final adhocItems = await FirebaseFirestore.instance
              .collection('schools')
              .doc(_schoolId)
              .collection('studentFeeItems')
              .where('isActive', isEqualTo: true)
              .where('paidAmount', isGreaterThan: 0)
              .get();

          for (final doc in adhocItems.docs) {
            final d = doc.data();
            final updatedAt = (d['updatedAt'] as Timestamp?) ??
                (d['assignedAt'] as Timestamp?);
            if (updatedAt != null &&
                updatedAt.compareTo(rangeStart) >= 0 &&
                updatedAt.compareTo(rangeEnd) <= 0) {
              revenueResults.add({
                'id': doc.id,
                'docId': doc.id,
                'receiptNumber': 'ADH-${d['categoryCode'] ?? 'ADH'}',
                'paidAt': updatedAt,
                'amount': d['paidAmount'],
                'termName': d['itemName'] ?? 'Ad-hoc Fee',
                'studentId': d['studentId'] ?? '',
                'studentName': d['studentName'] ?? 'N/A',
                'isDeleted': false,
                'isAdHoc': true,
                'billType': 'Revenue',
              });
            }
          }
        } catch (e) {
          print('Error fetching ad-hoc payments: $e');
        }
      }

      // Fetch Expense bills
      if (_filterType == 'Both' || _filterType == 'Expense') {
        final expenseBills = await FirebaseFirestore.instance
            .collection('schools')
            .doc(_schoolId)
            .collection('bills')
            .where('billType', isEqualTo: 'Expense')
            .where('billDate', isGreaterThanOrEqualTo: rangeStart)
            .where('billDate', isLessThanOrEqualTo: rangeEnd)
            .orderBy('billDate', descending: true)
            .get();

        for (final doc in expenseBills.docs) {
          final d = doc.data();
          d['docId'] = doc.id;
          if (d['isDeleted'] != true) {
            expenseResults.add(d);
          }
        }
      }

      setState(() {
        _revenueBills = revenueResults;
        _expenseBills = expenseResults;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ [BillManagement] Error fetching bills: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error fetching bills: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDesktop = screenSize.width > 1024;
    final isMobile = screenSize.width < 600;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop
          ? 28
          : isMobile
              ? 12
              : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isMobile),
          SizedBox(height: isMobile ? 12 : 20),
          _buildFilterBar(isDesktop, isMobile),
          SizedBox(height: isMobile ? 12 : 16),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: _accentGreen))
          else
            ..._buildBillsTables(isDesktop, isMobile),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    final totalRecords = _revenueBills.length + _expenseBills.length;
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Container(
          padding: EdgeInsets.all(isMobile ? 8 : 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.receipt_long_rounded,
              color: Colors.white, size: isMobile ? 24 : 28),
        ),
        SizedBox(width: isMobile ? 12 : 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bill Management',
                style: TextStyle(
                  fontSize: isMobile ? 18 : 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: isMobile ? 2 : 4),
              Text(
                'View and manage revenue & expense bills',
                style: TextStyle(
                  fontSize: isMobile ? 11 : 13,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 10 : 12,
            vertical: isMobile ? 4 : 6,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$totalRecords records',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: isMobile ? 11 : 13,
            ),
          ),
        ),
      ]),
    );
  }

  void _applyQuickRange(String key) {
    final now = DateTime.now();
    DateTime start = _startDate;
    DateTime end = _endDate;
    switch (key) {
      case 'today':
        start = DateTime(now.year, now.month, now.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'week':
        start = _startOfCurrentWeek();
        end = _endOfCurrentWeek();
        break;
      case 'month':
        start = DateTime(now.year, now.month, 1);
        final lastDay = DateTime(now.year, now.month + 1, 0);
        end = DateTime(lastDay.year, lastDay.month, lastDay.day, 23, 59, 59);
        break;
      case 'year':
        start = DateTime(now.year, 1, 1);
        end = DateTime(now.year, 12, 31, 23, 59, 59);
        break;
      case 'custom':
        // Keep current dates; just enable the pickers
        setState(() => _quickRange = 'custom');
        return;
    }
    setState(() {
      _quickRange = key;
      _startDate = start;
      _endDate = end;
    });
    _fetchBills();
  }

  Widget _buildFilterBar(bool isDesktop, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
          color: _cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor)),
      child: Wrap(
        spacing: isMobile ? 8 : 12,
        runSpacing: isMobile ? 8 : 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(Icons.filter_list_rounded,
              color: _accentGreen, size: isMobile ? 18 : 20),
          Text('Filter',
              style: TextStyle(
                  color: _textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 12 : 14)),
          _buildQuickChip('Today', 'today', isMobile),
          _buildQuickChip('This Week', 'week', isMobile),
          _buildQuickChip('This Month', 'month', isMobile),
          _buildQuickChip('This Year', 'year', isMobile),
          _buildQuickChip('Custom', 'custom', isMobile),
          _buildDateButton(
              'From', _startDate, (d) => setState(() => _startDate = d),
              enabled: _quickRange == 'custom', isMobile: isMobile),
          _buildDateButton('To', _endDate, (d) => setState(() => _endDate = d),
              enabled: _quickRange == 'custom', isMobile: isMobile),
          _buildTypeDropdown(isMobile),
          ElevatedButton.icon(
            icon: Icon(Icons.search_rounded, size: isMobile ? 16 : 18),
            label: Text('Apply Filter',
                style: TextStyle(fontSize: isMobile ? 12 : 14)),
            style: ElevatedButton.styleFrom(
                backgroundColor: _accentGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            onPressed: _fetchBills,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String label, String key, bool isMobile) {
    final selected = _quickRange == key;
    return InkWell(
      onTap: () => _applyQuickRange(key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 10 : 12, vertical: isMobile ? 6 : 8),
        decoration: BoxDecoration(
          color: selected ? _accentGreen.withValues(alpha: 0.15) : _bgDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _accentGreen : _borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? _accentGreen : _textSecondary,
            fontSize: isMobile ? 10 : 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildDateButton(
      String label, DateTime date, Function(DateTime) onPicked,
      {bool enabled = true, bool isMobile = false}) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: InkWell(
        onTap: enabled
            ? () async {
                final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    builder: (ctx, child) => Theme(
                        data: ThemeData.dark().copyWith(
                            colorScheme: const ColorScheme.dark(
                                primary: _accentGreen, surface: _cardDark)),
                        child: child!));
                if (picked != null) {
                  onPicked(picked);
                }
              }
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
              color: _bgDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _borderColor)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
                enabled
                    ? Icons.calendar_today_rounded
                    : Icons.lock_outline_rounded,
                size: 14,
                color: enabled ? _accentGreen : _textSecondary),
            const SizedBox(width: 8),
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style:
                          const TextStyle(fontSize: 10, color: _textSecondary)),
                  Text(DateFormat('yyyy-MM-dd').format(date),
                      style:
                          const TextStyle(color: _textPrimary, fontSize: 13)),
                ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildTypeDropdown(bool isMobile) {
    return SizedBox(
      width: isMobile ? 120 : 140,
      child: SearchableDropdown<String>(
        value: _filterType,
        items: const ['Both', 'Revenue', 'Expense'],
        itemLabel: (v) => v,
        hint: 'Type',
        onChanged: (v) {
          if (v != null) setState(() => _filterType = v);
        },
      ),
    );
  }

  Widget _buildActionBar(String billType, bool isMobile, int billCount,
      Set<String> selectedBills) {
    final hasSelection = selectedBills.isNotEmpty;

    return Wrap(
      spacing: isMobile ? 6 : 8,
      runSpacing: isMobile ? 6 : 8,
      alignment: WrapAlignment.end,
      children: [
        if (hasSelection) ...[
          ElevatedButton.icon(
            icon: Icon(Icons.print_rounded, size: isMobile ? 14 : 16),
            label: Text('Print Selected (${selectedBills.length})',
                style: TextStyle(fontSize: isMobile ? 11 : 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: EdgeInsets.symmetric(
                  vertical: isMobile ? 8 : 10, horizontal: isMobile ? 10 : 14),
            ),
            onPressed: () => _printSelectedBills(billType, selectedBills),
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.delete_rounded, size: isMobile ? 14 : 16),
            label: Text('Delete Selected (${selectedBills.length})',
                style: TextStyle(fontSize: isMobile ? 11 : 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: EdgeInsets.symmetric(
                  vertical: isMobile ? 8 : 10, horizontal: isMobile ? 10 : 14),
            ),
            onPressed: () => _deleteSelectedBills(billType, selectedBills),
          ),
        ],
        ElevatedButton.icon(
          icon: Icon(Icons.print_rounded, size: isMobile ? 14 : 16),
          label:
              Text('Print All', style: TextStyle(fontSize: isMobile ? 11 : 13)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: EdgeInsets.symmetric(
                vertical: isMobile ? 8 : 10, horizontal: isMobile ? 10 : 14),
          ),
          onPressed: billCount == 0 ? null : () => _printAllBills(billType),
        ),
        ElevatedButton.icon(
          icon: Icon(Icons.download_rounded, size: isMobile ? 14 : 16),
          label: Text('Export CSV',
              style: TextStyle(fontSize: isMobile ? 11 : 13)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: EdgeInsets.symmetric(
                vertical: isMobile ? 8 : 10, horizontal: isMobile ? 10 : 14),
          ),
          onPressed: billCount == 0 ? null : () => _exportCsv(billType),
        ),
      ],
    );
  }

  List<Widget> _buildBillsTables(bool isDesktop, bool isMobile) {
    final tables = <Widget>[];

    // Revenue Bills Table
    if (_filterType == 'Both' || _filterType == 'Revenue') {
      tables.add(
          _buildSectionHeader('Revenue Bills', _revenueBills.length, isMobile));
      tables.add(const SizedBox(height: 12));
      tables.add(_buildActionBar(
          'Revenue', isMobile, _revenueBills.length, _selectedRevenueBills));
      tables.add(const SizedBox(height: 12));
      tables.add(_buildSingleTable('Revenue', _revenueBills,
          _selectedRevenueBills, isDesktop, isMobile));
      tables.add(const SizedBox(height: 24));
    }

    // Expense Bills Table
    if (_filterType == 'Both' || _filterType == 'Expense') {
      tables.add(
          _buildSectionHeader('Expense Bills', _expenseBills.length, isMobile));
      tables.add(const SizedBox(height: 12));
      tables.add(_buildActionBar(
          'Expense', isMobile, _expenseBills.length, _selectedExpenseBills));
      tables.add(const SizedBox(height: 12));
      tables.add(_buildSingleTable('Expense', _expenseBills,
          _selectedExpenseBills, isDesktop, isMobile));
    }

    return tables;
  }

  Widget _buildSectionHeader(String title, int count, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 16, vertical: isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Icon(
            title.contains('Revenue') ? Icons.trending_up : Icons.trending_down,
            color: title.contains('Revenue')
                ? const Color(0xFF10B981)
                : const Color(0xFFEF4444),
            size: isMobile ? 18 : 20,
          ),
          SizedBox(width: isMobile ? 8 : 12),
          Text(
            title,
            style: TextStyle(
              color: _textPrimary,
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 8 : 10, vertical: isMobile ? 3 : 4),
            decoration: BoxDecoration(
              color: _accentGreen.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count bills',
              style: TextStyle(
                color: _accentGreen,
                fontSize: isMobile ? 11 : 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleTable(String billType, List<Map<String, dynamic>> bills,
      Set<String> selectedBills, bool isDesktop, bool isMobile) {
    if (bills.isEmpty) {
      return Container(
        padding: EdgeInsets.all(isMobile ? 24 : 40),
        decoration: BoxDecoration(
            color: _cardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor)),
        child: Center(
            child: Text('No $billType bills found.',
                style: TextStyle(
                    color: _textSecondary, fontSize: isMobile ? 13 : 15))),
      );
    }

    final isRevenue = billType == 'Revenue';

    if (isMobile) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: bills.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (ctx, index) {
          final b = bills[index];
          final docId = b['docId']?.toString() ?? '';
          final isSelected = selectedBills.contains(docId);
          final isDeleted = b['isDeleted'] == true;

          DateTime? dateField;
          double amount = 0;
          String identifier = '';
          String description = '';
          String name = '';

          if (isRevenue) {
            amount = (b['amount'] as num?)?.toDouble() ?? 0;
            dateField = (b['paidAt'] is Timestamp)
                ? (b['paidAt'] as Timestamp).toDate()
                : (b['paidAt'] as DateTime?);
            identifier = (b['receiptNumber'] ?? b['id'] ?? '').toString();
            name = (b['studentName'] ?? '').toString();

            final isAdHoc = b['isAdHoc'] == true;
            if (isAdHoc) {
              description = (b['termName'] ?? 'Ad-hoc Fee').toString();
            } else {
              final components = b['components'] as List?;
              if (components != null && components.isNotEmpty) {
                description = components.map((c) {
                  final comp = c as Map<String, dynamic>;
                  final cName = (comp['termName'] as String?) ??
                      (comp['itemName'] as String?) ??
                      'Fee';
                  final amt = (comp['amount'] as num?)?.toDouble() ?? 0;
                  return '$cName (Rs.${amt.toStringAsFixed(0)})';
                }).join(', ');
              } else {
                description = (b['termName'] ?? 'Fee Payment').toString();
              }
            }
          } else {
            amount = (b['expenseAmount'] as num?)?.toDouble() ??
                (b['amount'] as num?)?.toDouble() ??
                0;
            dateField = (b['billDate'] is Timestamp)
                ? (b['billDate'] as Timestamp).toDate()
                : (b['billDate'] as DateTime?);
            identifier = 'EXP-${b['billId'] ?? ''}';
            name = (b['expensePOC'] ?? b['pointOfContact'] ?? '').toString();
            description = (b['expenseType'] ??
                    b['categoryName'] ??
                    b['description'] ??
                    '')
                .toString();
          }

          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? _accentGreen.withOpacity(0.1)
                  : (isDeleted
                      ? const Color(0xFFEF4444).withOpacity(0.06)
                      : _cardDark),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: isSelected ? _accentGreen : _borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: isSelected,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            selectedBills.add(docId);
                          } else {
                            selectedBills.remove(docId);
                          }
                        });
                      },
                      activeColor: _accentGreen,
                    ),
                    Expanded(
                      child: Text(
                        identifier,
                        style: TextStyle(
                          color: isDeleted
                              ? _textSecondary.withOpacity(0.5)
                              : _textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          decoration:
                              isDeleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    Text(
                      'Rs.${amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: isDeleted
                            ? _textSecondary.withOpacity(0.5)
                            : (isRevenue
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444)),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        decoration:
                            isDeleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  name.isEmpty ? 'N/A' : name,
                  style: TextStyle(
                    color: isDeleted
                        ? _textSecondary.withOpacity(0.5)
                        : _textPrimary,
                    fontSize: 13,
                    decoration: isDeleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: isDeleted
                        ? _textSecondary.withOpacity(0.4)
                        : _textSecondary,
                    fontSize: 11,
                    decoration: isDeleted ? TextDecoration.lineThrough : null,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  dateField != null
                      ? DateFormat('dd/MM/yyyy').format(dateField)
                      : '',
                  style: TextStyle(
                    color: _textSecondary.withOpacity(0.7),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 8),
                if (!isDeleted)
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.print_rounded,
                            color: Color(0xFF3B82F6), size: 16),
                        tooltip: 'Print',
                        onPressed: () => _printSingleBill(b, billType),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.delete_rounded,
                            color: Color(0xFFEF4444), size: 16),
                        tooltip: 'Delete',
                        onPressed: () => _confirmDeleteBill(b, billType),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      );
    }

    return Container(
      decoration: BoxDecoration(
          color: _cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(_bgDark),
          dataRowColor: WidgetStateProperty.all(_cardDark),
          dividerThickness: 0.5,
          columns: [
            DataColumn(
              label: Checkbox(
                value: bills.isNotEmpty && selectedBills.length == bills.length,
                tristate: true,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      selectedBills.addAll(
                          bills.map((b) => b['docId']?.toString() ?? ''));
                    } else {
                      selectedBills.clear();
                    }
                  });
                },
                activeColor: _accentGreen,
              ),
            ),
            DataColumn(
                label: Text(isRevenue ? 'Receipt#' : 'Bill#',
                    style: const TextStyle(
                        color: _accentGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 12))),
            const DataColumn(
                label: Text('Date',
                    style: TextStyle(
                        color: _accentGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 12))),
            DataColumn(
                label: Text(isRevenue ? 'Student Name' : 'POC',
                    style: const TextStyle(
                        color: _accentGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 12))),
            const DataColumn(
                label: Text('Amount',
                    style: TextStyle(
                        color: _accentGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 12))),
            const DataColumn(
                label: Text('Actions',
                    style: TextStyle(
                        color: _accentGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 12))),
            const DataColumn(
                label: Text('Description',
                    style: TextStyle(
                        color: _accentGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 12))),
          ],
          rows: bills.map((b) {
            final docId = b['docId']?.toString() ?? '';
            final isSelected = selectedBills.contains(docId);
            final isDeleted = b['isDeleted'] == true;

            DateTime? dateField;
            double amount = 0;
            String identifier = '';
            String description = '';
            String name = '';

            if (isRevenue) {
              amount = (b['amount'] as num?)?.toDouble() ?? 0;
              dateField = (b['paidAt'] is Timestamp)
                  ? (b['paidAt'] as Timestamp).toDate()
                  : (b['paidAt'] as DateTime?);
              identifier = (b['receiptNumber'] ?? b['id'] ?? '').toString();
              name = (b['studentName'] ?? '').toString();

              final isAdHoc = b['isAdHoc'] == true;
              if (isAdHoc) {
                description = (b['termName'] ?? 'Ad-hoc Fee').toString();
              } else {
                final components = b['components'] as List?;
                if (components != null && components.isNotEmpty) {
                  description = components.map((c) {
                    final comp = c as Map<String, dynamic>;
                    final cName = (comp['termName'] as String?) ??
                        (comp['itemName'] as String?) ??
                        'Fee';
                    final amt = (comp['amount'] as num?)?.toDouble() ?? 0;
                    return '$cName (Rs.${amt.toStringAsFixed(0)})';
                  }).join(', ');
                } else {
                  description = (b['termName'] ?? 'Fee Payment').toString();
                }
              }
            } else {
              amount = (b['expenseAmount'] as num?)?.toDouble() ??
                  (b['amount'] as num?)?.toDouble() ??
                  0;
              dateField = (b['billDate'] is Timestamp)
                  ? (b['billDate'] as Timestamp).toDate()
                  : (b['billDate'] as DateTime?);
              identifier = 'EXP-${b['billId'] ?? ''}';
              name = (b['expensePOC'] ?? b['pointOfContact'] ?? '').toString();
              description = (b['expenseType'] ??
                      b['categoryName'] ??
                      b['description'] ??
                      '')
                  .toString();
            }

            final rowTextStyle = TextStyle(
              color: isDeleted ? _textSecondary.withOpacity(0.5) : _textPrimary,
              fontSize: 12,
              decoration: isDeleted ? TextDecoration.lineThrough : null,
            );

            return DataRow(
              color: isSelected
                  ? WidgetStateProperty.all(_accentGreen.withOpacity(0.1))
                  : (isDeleted
                      ? WidgetStateProperty.all(
                          const Color(0xFFEF4444).withOpacity(0.06))
                      : null),
              cells: [
                DataCell(Checkbox(
                  value: isSelected,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        selectedBills.add(docId);
                      } else {
                        selectedBills.remove(docId);
                      }
                    });
                  },
                  activeColor: _accentGreen,
                )),
                DataCell(Text(identifier, style: rowTextStyle)),
                DataCell(Text(
                    dateField != null
                        ? DateFormat('dd/MM/yyyy').format(dateField)
                        : '',
                    style: rowTextStyle)),
                DataCell(
                    Text(name.isEmpty ? 'N/A' : name, style: rowTextStyle)),
                DataCell(Text('Rs.${amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: isDeleted
                          ? _textSecondary.withOpacity(0.5)
                          : (isRevenue
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444)),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      decoration: isDeleted ? TextDecoration.lineThrough : null,
                    ))),
                DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                  if (!isDeleted)
                    IconButton(
                        icon: const Icon(Icons.print_rounded,
                            color: Color(0xFF3B82F6), size: 18),
                        tooltip: 'Print',
                        onPressed: () => _printSingleBill(b, billType)),
                  if (!isDeleted)
                    IconButton(
                        icon: const Icon(Icons.delete_rounded,
                            color: Color(0xFFEF4444), size: 18),
                        tooltip: 'Delete',
                        onPressed: () => _confirmDeleteBill(b, billType)),
                ])),
                DataCell(
                  SizedBox(
                    width: 200,
                    child: Text(
                      description,
                      style: TextStyle(
                        color: isDeleted
                            ? _textSecondary.withOpacity(0.4)
                            : _textSecondary,
                        fontSize: 12,
                        decoration:
                            isDeleted ? TextDecoration.lineThrough : null,
                      ),
                      softWrap: true,
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // ============ PRINT SINGLE BILL ============
  Future<void> _printSingleBill(
      Map<String, dynamic> bill, String billType) async {
    if (_schoolId == null) return;
    PdfBranding.clearCache(); // Force refresh school data
    final branding = await PdfBranding.forSchool(_schoolId!);
    final pdf = pw.Document();
    final isRevenue = (bill['billType'] ?? '') == 'Revenue';
    final amount = isRevenue
        ? (bill['revenueAmount'] as num?)?.toDouble() ?? 
          (bill['amount'] as num?)?.toDouble() ?? 
          (bill['paidAmount'] as num?)?.toDouble() ?? 0
        : (bill['expenseAmount'] as num?)?.toDouble() ?? 
          (bill['amount'] as num?)?.toDouble() ?? 0;
    final date = (bill['billDate'] as Timestamp?)?.toDate() ?? DateTime.now();
    final ay = (bill['academicYear'] ?? '').toString();
    final origAy = (bill['originatingAcademicYear'] ?? '').toString();
    final origClass = (bill['originatingClass'] ?? '').toString();
    final schoolName =
        branding.schoolName.isNotEmpty ? branding.schoolName : 'School';
    final schoolAddr = branding.schoolAddress;
    final schoolPhone = branding.schoolPhone;
    final schoolEmail = branding.schoolEmail;
    final schoolWebsite = branding.schoolWebsite;

    // Build one receipt copy as a list of widgets
    pw.Widget buildReceiptCopy(String copyLabel) {
      final bold = pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10);
      const normal = pw.TextStyle(fontSize: 9);
      const small = pw.TextStyle(fontSize: 8);
      
      // Extract description using the same logic as the list display
      String description = '';
      if (isRevenue) {
        final isAdHoc = bill['isAdHoc'] == true;
        if (isAdHoc) {
          description = (bill['termName'] ?? 'Ad-hoc Fee').toString();
        } else {
          final components = bill['components'] as List?;
          if (components != null && components.isNotEmpty) {
            description = components.map((c) {
              final comp = c as Map<String, dynamic>;
              final cName = (comp['termName'] as String?) ??
                  (comp['itemName'] as String?) ??
                  'Fee';
              final amt = (comp['amount'] as num?)?.toDouble() ?? 0;
              return '$cName (Rs.${amt.toStringAsFixed(0)})';
            }).join(', ');
          } else {
            description = (bill['termName'] ?? 'Fee Payment').toString();
          }
        }
      } else {
        description = (bill['expenseType'] ??
                bill['categoryName'] ??
                bill['description'] ??
                '')
            .toString();
      }
      // Replace any remaining rupee symbols with Rs. to avoid font issues
      description = description.replaceAll('₹', 'Rs.');
      return pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // School name + copy label
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                      child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                        pw.Text(schoolName,
                            style: pw.TextStyle(
                                fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.Text(schoolAddr, style: small),
                        pw.Text('Ph: $schoolPhone', style: small),
                        if (schoolEmail.isNotEmpty)
                          pw.Text('Email: $schoolEmail', style: small),
                        if (schoolWebsite.isNotEmpty)
                          pw.Text('Web: $schoolWebsite', style: small),
                      ])),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration:
                        pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
                    child: pw.Text(copyLabel,
                        style: pw.TextStyle(
                            fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ),
                ]),
            pw.Divider(thickness: 0.5, height: 8),
            // Title
            pw.Center(
                child: pw.Text(
              isRevenue ? 'FEE RECEIPT' : 'EXPENSE VOUCHER',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            )),
            pw.SizedBox(height: 4),
            // Bill info row
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Bill No: ${bill['billId'] ?? ''}', style: bold),
                  pw.Text('Date: ${DateFormat('dd/MM/yyyy').format(date)}',
                      style: bold),
                ]),
            pw.SizedBox(height: 4),
            if (isRevenue) ...[
              pw.Row(children: [
                pw.Text('Student: ', style: bold),
                pw.Text(
                    '${bill['stuName'] ?? bill['studentName'] ?? 'N/A'} (ID: ${bill['stuId'] ?? bill['studentId'] ?? 'N/A'})',
                    style: normal),
              ]),
              pw.Row(children: [
                pw.Text('Class: ', style: bold),
                pw.Text(
                    '${bill['stuClass'] ?? bill['className'] ?? ''} - ${bill['stuSection'] ?? bill['section'] ?? ''}',
                    style: normal),
                pw.SizedBox(width: 20),
                pw.Text('AY: ', style: bold),
                pw.Text(ay, style: normal),
              ]),
              if (origAy.isNotEmpty && origAy != ay)
                pw.Text('Arrears from: Class $origClass ($origAy)',
                    style: small),
            ],
            if (!isRevenue) ...[
              pw.Row(children: [
                pw.Text('POC: ', style: bold),
                pw.Text('${bill['expensePOC'] ?? bill['pointOfContact'] ?? ''}', style: normal),
              ]),
            ],
            pw.Row(children: [
              pw.Text(isRevenue ? 'Fee Type: ' : 'Expense Type: ', style: bold),
              pw.Text(
                  isRevenue
                      ? (bill['revenueType'] ?? bill['termName'] ?? 'Fee Payment').toString()
                      : (bill['expenseType'] ?? bill['categoryName'] ?? bill['description'] ?? 'Expense').toString(),
                  style: normal),
            ]),
            pw.SizedBox(height: 2),
            if (description.isNotEmpty) ...[
              pw.Text(isRevenue ? 'Fee Details:' : 'Expense Details:', style: bold),
              pw.SizedBox(height: 2),
              pw.Container(
                width: double.infinity,
                child: pw.Text(description, style: small, maxLines: 3),
              ),
            ],
            pw.SizedBox(height: 6),
            // Amount box
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
              child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('AMOUNT:',
                        style: pw.TextStyle(
                            fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Rs. ${amount.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                            fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  ]),
            ),
            if ((bill['remarks'] ?? '').toString().isNotEmpty) ...[
              pw.SizedBox(height: 3),
              pw.Text('Remarks: ${bill['remarks']}', style: small),
            ],
            pw.SizedBox(height: 6),
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Cashier: ${bill['billCashierName'] ?? bill['cashierName'] ?? bill['createdBy'] ?? ''}',
                      style: small),
                  pw.Text('Signature: _______________', style: small),
                ]),
          ],
        ),
      );
    }

    // Two copies on one A5 page
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) => pw.Column(
        children: [
          buildReceiptCopy('SCHOOL COPY'),
          pw.SizedBox(height: 6),
          pw.Center(
              child: pw.Text(
            '- - - - - - - - - - - - - - - - - -  Cut Here  - - - - - - - - - - - - - - - - - -',
            style: const pw.TextStyle(fontSize: 7),
          )),
          pw.SizedBox(height: 6),
          buildReceiptCopy('PARENT COPY'),
        ],
      ),
    ));

    final pdfBytes = await pdf.save();
    _downloadFile(
        pdfBytes, 'Bill_${bill['billId']}_Receipt.pdf', 'application/pdf');
  }

  // ============ PRINT SELECTED BILLS ============
  Future<void> _printSelectedBills(
      String billType, Set<String> selectedIds) async {
    if (_schoolId == null || selectedIds.isEmpty) return;

    final billsList = billType == 'Revenue' ? _revenueBills : _expenseBills;
    final selectedBills = billsList
        .where((b) => selectedIds.contains(b['docId']?.toString() ?? ''))
        .toList();

    if (selectedBills.isEmpty) return;

    final branding = await PdfBranding.forSchool(_schoolId!);
    final pdf = pw.Document();

    for (final bill in selectedBills) {
      await _addBillToPdf(pdf, bill, billType, branding);
    }

    final pdfBytes = await pdf.save();
    _downloadFile(
        pdfBytes,
        '${billType}_Bills_Selected_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
        'application/pdf');
  }

  Future<void> _addBillToPdf(pw.Document pdf, Map<String, dynamic> bill,
      String billType, PdfBrandingContext branding) async {
    PdfBranding.clearCache(); // Force refresh school data
    branding = await PdfBranding.forSchool(_schoolId!);
    final isRevenue = billType == 'Revenue';
    final schoolName =
        branding.schoolName.isNotEmpty ? branding.schoolName : 'School';
    final schoolAddr = branding.schoolAddress;
    final schoolPhone = branding.schoolPhone;
    final schoolEmail = branding.schoolEmail;
    final schoolWebsite = branding.schoolWebsite;

    double amount = 0;
    DateTime? date;
    String identifier = '';
    String name = '';
    String description = '';

    if (isRevenue) {
      amount = (bill['revenueAmount'] as num?)?.toDouble() ?? 
               (bill['amount'] as num?)?.toDouble() ?? 
               (bill['paidAmount'] as num?)?.toDouble() ?? 0;
      date = (bill['paidAt'] is Timestamp)
          ? (bill['paidAt'] as Timestamp).toDate()
          : DateTime.now();
      identifier = (bill['receiptNumber'] ?? bill['id'] ?? '').toString();
      name = (bill['studentName'] ?? '').toString();
      final isAdHoc = bill['isAdHoc'] == true;
      if (isAdHoc) {
        description = (bill['termName'] ?? 'Ad-hoc Fee').toString();
      } else {
        final components = bill['components'] as List?;
        if (components != null && components.isNotEmpty) {
          description = components.map((c) {
            final comp = c as Map<String, dynamic>;
            final cName = (comp['termName'] as String?) ??
                (comp['itemName'] as String?) ??
                'Fee';
            return cName;
          }).join(', ');
        } else {
          description = (bill['termName'] ?? 'Fee Payment').toString();
        }
      }
    } else {
      amount = (bill['expenseAmount'] as num?)?.toDouble() ??
          (bill['amount'] as num?)?.toDouble() ??
          0;
      date = (bill['billDate'] is Timestamp)
          ? (bill['billDate'] as Timestamp).toDate()
          : DateTime.now();
      identifier = 'EXP-${bill['billId'] ?? ''}';
      name = (bill['expensePOC'] ?? bill['pointOfContact'] ?? '').toString();
      description =
          (bill['expenseType'] ?? bill['categoryName'] ?? '').toString();
    }

    pw.Widget buildReceiptCopy(String copyLabel) {
      final bold = pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10);
      const normal = pw.TextStyle(fontSize: 9);
      const small = pw.TextStyle(fontSize: 8);
      return pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                      child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                        pw.Text(schoolName,
                            style: pw.TextStyle(
                                fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.Text(schoolAddr, style: small),
                        pw.Text('Ph: $schoolPhone', style: small),
                        if (schoolEmail.isNotEmpty)
                          pw.Text('Email: $schoolEmail', style: small),
                        if (schoolWebsite.isNotEmpty)
                          pw.Text('Web: $schoolWebsite', style: small),
                      ])),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration:
                        pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
                    child: pw.Text(copyLabel,
                        style: pw.TextStyle(
                            fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ),
                ]),
            pw.Divider(thickness: 0.5, height: 8),
            pw.Center(
                child: pw.Text(
              isRevenue ? 'FEE RECEIPT' : 'EXPENSE VOUCHER',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            )),
            pw.SizedBox(height: 4),
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('$billType #: $identifier', style: bold),
                  pw.Text('Date: ${DateFormat('dd/MM/yyyy').format(date!)}',
                      style: bold),
                ]),
            pw.SizedBox(height: 4),
            pw.Row(children: [
              pw.Text(isRevenue ? 'Student: ' : 'POC: ', style: bold),
              pw.Text(name, style: normal),
            ]),
            pw.Row(children: [
              pw.Text('Description: ', style: bold),
              pw.Expanded(child: pw.Text(description, style: normal)),
            ]),
            pw.SizedBox(height: 6),
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
              child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('AMOUNT:',
                        style: pw.TextStyle(
                            fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Rs. ${amount.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                            fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  ]),
            ),
            if ((bill['remarks'] ?? '').toString().isNotEmpty) ...[
              pw.SizedBox(height: 3),
              pw.Text('Remarks: ${bill['remarks']}', style: small),
            ],
            pw.SizedBox(height: 6),
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                      'Cashier: ${bill['billCashierName'] ?? bill['cashierName'] ?? bill['createdBy'] ?? ''}',
                      style: small),
                  pw.Text('Signature: _______________', style: small),
                ]),
          ],
        ),
      );
    }

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) => pw.Column(
        children: [
          buildReceiptCopy('SCHOOL COPY'),
          pw.SizedBox(height: 6),
          pw.Center(
              child: pw.Text(
            '- - - - - - - - - - - - - - - - - -  Cut Here  - - - - - - - - - - - - - - - - - -',
            style: const pw.TextStyle(fontSize: 7),
          )),
          pw.SizedBox(height: 6),
          buildReceiptCopy('PARENT/OFFICE COPY'),
        ],
      ),
    ));
  }

  // ============ PRINT ALL BILLS ============
  Future<void> _printAllBills(String billType) async {
    if (_schoolId == null) return;
    final branding = await PdfBranding.forSchool(_schoolId!);
    final schoolName =
        branding.schoolName.isNotEmpty ? branding.schoolName : 'School';
    final schoolAddr = branding.schoolAddress;
    final schoolPhone = branding.schoolPhone;
    final schoolEmail = branding.schoolEmail;
    final schoolWebsite = branding.schoolWebsite;
    final pdf = pw.Document();

    // Filter out deleted bills for the print report (only for expense bills)
    final billsList = billType == 'Revenue' ? _revenueBills : _expenseBills;
    final activeBills = billType == 'Revenue' 
        ? billsList 
        : billsList.where((b) => b['isDeleted'] != true).toList();

    if (activeBills.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No active bills to print'),
              backgroundColor: Colors.orange),
        );
      }
      return;
    }

    final isRevenue = billType == 'Revenue';
    final small = pw.TextStyle(fontSize: 7);

    // Calculate total amount
    final totalAmount = activeBills.fold<double>(0, (sum, b) {
      if (isRevenue) {
        return sum + ((b['amount'] as num?)?.toDouble() ?? 0);
      } else {
        return sum + ((b['expenseAmount'] as num?)?.toDouble() ?? (b['amount'] as num?)?.toDouble() ?? 0);
      }
    });

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      header: (ctx) => pw.Column(
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 8),
            decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(width: 0.5))),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(schoolName,
                    style: pw.TextStyle(
                        fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Row(children: [
                  pw.Text(schoolAddr, style: small),
                  pw.SizedBox(width: 10),
                  pw.Text('Ph: $schoolPhone', style: small),
                ]),
                pw.Row(children: [
                  if (schoolEmail.isNotEmpty)
                    pw.Text('Email: $schoolEmail', style: small),
                  if (schoolEmail.isNotEmpty && schoolWebsite.isNotEmpty)
                    pw.SizedBox(width: 10),
                  if (schoolWebsite.isNotEmpty)
                    pw.Text('Web: $schoolWebsite', style: small),
                ]),
                pw.SizedBox(height: 4),
                pw.Text(
                    '$billType Bills Report: ${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}',
                    style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          ),
        ],
      ),
      footer: (ctx) => pw.Container(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8)),
      ),
      build: (ctx) => [
        pw.TableHelper.fromTextArray(
          headerStyle:
              pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          headers: isRevenue
              ? ['Receipt#', 'Date', 'Student Name', 'Description', 'Amount']
              : ['Bill#', 'Date', 'POC', 'Expense Type', 'Amount'],
          data: [
            ...activeBills.map((b) {
            if (isRevenue) {
              final amt = (b['amount'] as num?)?.toDouble() ?? 0;
              final date = (b['paidAt'] is Timestamp)
                  ? (b['paidAt'] as Timestamp).toDate()
                  : null;
              final identifier =
                  (b['receiptNumber'] ?? b['id'] ?? '').toString();
              final name = (b['studentName'] ?? '').toString();
              String desc = '';
              final isAdHoc = b['isAdHoc'] == true;
              if (isAdHoc) {
                desc = (b['termName'] ?? 'Ad-hoc Fee').toString();
              } else {
                final components = b['components'] as List?;
                if (components != null && components.isNotEmpty) {
                  desc = components.map((c) {
                    final comp = c as Map<String, dynamic>;
                    return (comp['termName'] as String?) ??
                        (comp['itemName'] as String?) ??
                        'Fee';
                  }).join(', ');
                } else {
                  desc = (b['termName'] ?? 'Fee').toString();
                }
              }
              return [
                identifier,
                date != null ? DateFormat('dd/MM/yyyy').format(date) : '',
                name,
                desc,
                'Rs.${amt.toStringAsFixed(2)}',
              ];
            } else {
              final amt = (b['expenseAmount'] as num?)?.toDouble() ??
                  (b['amount'] as num?)?.toDouble() ??
                  0;
              final date = (b['billDate'] is Timestamp)
                  ? (b['billDate'] as Timestamp).toDate()
                  : null;
              final identifier = 'EXP-${b['billId'] ?? ''}';
              final poc =
                  (b['expensePOC'] ?? b['pointOfContact'] ?? '').toString();
              final expType =
                  (b['expenseType'] ?? b['categoryName'] ?? '').toString();
              return [
                identifier,
                date != null ? DateFormat('dd/MM/yyyy').format(date) : '',
                poc,
                expType,
                'Rs.${amt.toStringAsFixed(2)}',
              ];
            }
          }).toList(),
            [
              '',
              '',
              '',
              'TOTAL',
              'Rs.${totalAmount.toStringAsFixed(2)}',
            ],
          ],
        ),
      ],
    ));

    final pdfBytes = await pdf.save();
    _downloadFile(
        pdfBytes,
        '${billType}_Bills_All_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
        'application/pdf');
  }

  // ============ DELETE SELECTED BILLS ============
  Future<void> _deleteSelectedBills(
      String billType, Set<String> selectedIds) async {
    if (selectedIds.isEmpty) return;

    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Selected Bills',
            style: TextStyle(color: _textPrimary)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
              'Are you sure you want to delete ${selectedIds.length} selected bills?',
              style: const TextStyle(color: _textSecondary)),
          const SizedBox(height: 16),
          TextField(
            controller: reasonController,
            style: const TextStyle(color: _textPrimary),
            decoration: InputDecoration(
              hintText: 'Reason for deletion',
              hintStyle: const TextStyle(color: _textSecondary),
              filled: true,
              fillColor: _bgDark,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _borderColor)),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: _textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final billsList = billType == 'Revenue' ? _revenueBills : _expenseBills;
    final selectedBills = billsList
        .where((b) => selectedIds.contains(b['docId']?.toString() ?? ''))
        .toList();

    for (final bill in selectedBills) {
      await _deleteBill(bill, reasonController.text, billType);
    }

    if (billType == 'Revenue') {
      _selectedRevenueBills.clear();
    } else {
      _selectedExpenseBills.clear();
    }
  }

  // ============ EXPORT CSV ============
  void _exportCsv(String billType) {
    final billsList = billType == 'Revenue' ? _revenueBills : _expenseBills;
    final isRevenue = billType == 'Revenue';

    final rows = <List<String>>[
      isRevenue
          ? [
              'Receipt#',
              'Date',
              'Student Name',
              'Description',
              'Amount',
              'Remarks'
            ]
          : [
              'Bill#',
              'Date',
              'POC',
              'Expense Type',
              'Description',
              'Amount',
              'Remarks'
            ],
    ];

    for (final b in billsList) {
      if (isRevenue) {
        final amt = (b['amount'] as num?)?.toDouble() ?? 0;
        final date = (b['paidAt'] is Timestamp)
            ? (b['paidAt'] as Timestamp).toDate()
            : null;
        final identifier = (b['receiptNumber'] ?? b['id'] ?? '').toString();
        final name = (b['studentName'] ?? '').toString();
        String desc = '';
        final isAdHoc = b['isAdHoc'] == true;
        if (isAdHoc) {
          desc = (b['termName'] ?? 'Ad-hoc Fee').toString();
        } else {
          final components = b['components'] as List?;
          if (components != null && components.isNotEmpty) {
            desc = components.map((c) {
              final comp = c as Map<String, dynamic>;
              return (comp['termName'] as String?) ??
                  (comp['itemName'] as String?) ??
                  'Fee';
            }).join(', ');
          } else {
            desc = (b['termName'] ?? 'Fee').toString();
          }
        }
        rows.add([
          identifier,
          date != null ? DateFormat('dd/MM/yyyy').format(date) : '',
          name,
          desc,
          amt.toStringAsFixed(2),
          (b['remarks'] ?? '').toString(),
        ]);
      } else {
        final amt = (b['expenseAmount'] as num?)?.toDouble() ??
            (b['amount'] as num?)?.toDouble() ??
            0;
        final date = (b['billDate'] is Timestamp)
            ? (b['billDate'] as Timestamp).toDate()
            : null;
        final identifier = 'EXP-${b['billId'] ?? ''}';
        final poc = (b['expensePOC'] ?? b['pointOfContact'] ?? '').toString();
        final expType =
            (b['expenseType'] ?? b['categoryName'] ?? '').toString();
        final desc = (b['description'] ?? b['expenseDesc'] ?? '').toString();
        rows.add([
          identifier,
          date != null ? DateFormat('dd/MM/yyyy').format(date) : '',
          poc,
          expType,
          desc,
          amt.toStringAsFixed(2),
          (b['remarks'] ?? '').toString(),
        ]);
      }
    }

    final csvData = const ListToCsvConverter().convert(rows);
    final bytes = Uint8List.fromList(csvData.codeUnits);
    _downloadFile(
        bytes,
        '${billType}_Bills_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
        'text/csv');
  }

  // ============ DELETE BILL ============
  void _confirmDeleteBill(Map<String, dynamic> bill, String billType) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Bill', style: TextStyle(color: _textPrimary)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Are you sure you want to delete this $billType bill?',
              style: const TextStyle(color: _textSecondary)),
          const SizedBox(height: 16),
          TextField(
            controller: reasonController,
            style: const TextStyle(color: _textPrimary),
            decoration: InputDecoration(
              hintText: 'Reason for deletion',
              hintStyle: const TextStyle(color: _textSecondary),
              filled: true,
              fillColor: _bgDark,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _borderColor)),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: _textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteBill(bill, reasonController.text, billType);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBill(
      Map<String, dynamic> bill, String reason, String billType) async {
    if (_schoolId == null) return;
    try {
      final isRevenue = billType == 'Revenue';
      final docId = bill['docId']?.toString() ?? '';

      if (docId.isEmpty) return;

      // Soft-delete the bill
      if (isRevenue) {
        // For revenue bills, delete from termFeePayments or studentFeeItems
        final isAdHoc = bill['isAdHoc'] == true;
        if (isAdHoc) {
          await FirebaseFirestore.instance
              .collection('schools')
              .doc(_schoolId)
              .collection('studentFeeItems')
              .doc(docId)
              .update({
            'isActive': false,
            'deletionReason': reason,
            'deletedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          await FirebaseFirestore.instance
              .collection('schools')
              .doc(_schoolId)
              .collection('termFeePayments')
              .doc(docId)
              .update({
            'isDeleted': true,
            'deletionReason': reason,
            'deletedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        // For expense bills
        await FirebaseFirestore.instance
            .collection('schools')
            .doc(_schoolId)
            .collection('bills')
            .doc(docId)
            .update({
          'isDeleted': true,
          'isBillDeleted': true,
          'deletionReason': reason,
          'deletedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Revert fee amount for revenue bills
      if (isRevenue) {
        final studentId = (bill['studentId'] ?? '').toString();
        final amount = (bill['amount'] as num?)?.toDouble() ?? 0.0;
        final academicYear = (bill['academicYear'] ?? '').toString();

        print('[Delete Bill] isRevenue: true, studentId: $studentId, amount: $amount, academicYear: $academicYear');

        if (studentId.isNotEmpty && amount > 0) {
          try {
            final isAdHoc = bill['isAdHoc'] == true;
            print('[Delete Bill] isAdHoc: $isAdHoc');
            
            // Update student_fee_details collection for arrears
            if (academicYear.isNotEmpty) {
              print('[Delete Bill] Updating student_fee_details collection');
              final studentDetailsQuery = await FirebaseFirestore.instance
                  .collection('schools')
                  .doc(_schoolId)
                  .collection('student_fee_details')
                  .where('stuId', isEqualTo: int.tryParse(studentId) ?? 0)
                  .where('academicYear', isEqualTo: academicYear)
                  .limit(1)
                  .get();

              if (studentDetailsQuery.docs.isNotEmpty) {
                final studentDetailsDoc = studentDetailsQuery.docs.first;
                final studentDetailsData = studentDetailsDoc.data();
                print('[Delete Bill] Found student_fee_details record');

                // Get current paid amounts
                final currentPaidTuition = (studentDetailsData['stuPaidTutionFees'] as num?)?.toDouble() ?? 0;
                final currentPaidExam = (studentDetailsData['stuPaidExamFees'] as num?)?.toDouble() ?? 0;
                final currentPaidVan = (studentDetailsData['studPaidVanFees'] as num?)?.toDouble() ?? 0;
                final currentPaidAdmission = (studentDetailsData['stuPaidAdmissionFees'] as num?)?.toDouble() ?? 0;

                // Check bill components to determine which fee types were paid
                final components = bill['components'] as List?;
                Map<String, double> feeTypeAmounts = {
                  'tuition': 0.0,
                  'exam': 0.0,
                  'van': 0.0,
                  'admission': 0.0,
                };

                if (components != null && components.isNotEmpty) {
                  for (final comp in components) {
                    final compData = comp as Map<String, dynamic>;
                    final compAmount = (compData['amount'] as num?)?.toDouble() ?? 0;
                    final compName = (compData['termName'] ?? compData['itemName'] ?? '').toString().toLowerCase();
                    
                    if (compName.contains('tution') || compName.contains('tuition')) {
                      feeTypeAmounts['tuition'] = feeTypeAmounts['tuition']! + compAmount;
                    } else if (compName.contains('exam')) {
                      feeTypeAmounts['exam'] = feeTypeAmounts['exam']! + compAmount;
                    } else if (compName.contains('van')) {
                      feeTypeAmounts['van'] = feeTypeAmounts['van']! + compAmount;
                    } else if (compName.contains('admission')) {
                      feeTypeAmounts['admission'] = feeTypeAmounts['admission']! + compAmount;
                    } else {
                      // Default to tuition if unknown
                      feeTypeAmounts['tuition'] = feeTypeAmounts['tuition']! + compAmount;
                    }
                  }
                } else {
                  // If no components, default to tuition
                  feeTypeAmounts['tuition'] = amount;
                }

                // Build update map with only the fee types that were actually paid
                Map<String, dynamic> updates = {};
                if (feeTypeAmounts['tuition']! > 0) {
                  updates['stuPaidTutionFees'] = currentPaidTuition - feeTypeAmounts['tuition']!;
                }
                if (feeTypeAmounts['exam']! > 0) {
                  updates['stuPaidExamFees'] = currentPaidExam - feeTypeAmounts['exam']!;
                }
                if (feeTypeAmounts['van']! > 0) {
                  updates['studPaidVanFees'] = currentPaidVan - feeTypeAmounts['van']!;
                }
                if (feeTypeAmounts['admission']! > 0) {
                  updates['stuPaidAdmissionFees'] = currentPaidAdmission - feeTypeAmounts['admission']!;
                }
                updates['updatedAt'] = FieldValue.serverTimestamp();

                await studentDetailsDoc.reference.update(updates);
                print('[Delete Bill] student_fee_details updated with amounts: $feeTypeAmounts');
              } else {
                print('[Delete Bill] No student_fee_details record found');
              }
            }
            
            if (isAdHoc) {
              // For ad-hoc payments, find ledger by studentId and category
              final category = (bill['category'] ?? '').toString();
              print('[Delete Bill] category: $category');
              if (category.isNotEmpty) {
                final ledgerQuery = await FirebaseFirestore.instance
                    .collection('schools')
                    .doc(_schoolId)
                    .collection('studentFeeLedgers')
                    .where('studentId', isEqualTo: studentId)
                    .where('category', isEqualTo: category)
                    .limit(1)
                    .get();

                print('[Delete Bill] Found ${ledgerQuery.docs.length} ledgers for ad-hoc payment');

                if (ledgerQuery.docs.isNotEmpty) {
                  final ledgerDoc = ledgerQuery.docs.first;
                  final ledgerData = ledgerDoc.data();
                  final currentPaid =
                      (ledgerData['totalPaid'] as num?)?.toDouble() ?? 0;
                  final currentBalance =
                      (ledgerData['totalBalance'] as num?)?.toDouble() ?? 0;

                  print('[Delete Bill] currentPaid: $currentPaid, currentBalance: $currentBalance');
                  print('[Delete Bill] Updating to: paid=${currentPaid - amount}, balance=${currentBalance + amount}');

                  await ledgerDoc.reference.update({
                    'totalPaid': currentPaid - amount,
                    'totalBalance': currentBalance + amount,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                  print('[Delete Bill] Ledger updated successfully');
                } else {
                  print('[Delete Bill] No ledger found for ad-hoc payment');
                }
              } else {
                print('[Delete Bill] Category is empty for ad-hoc payment');
              }
            } else {
              // For regular term payments, find ledger by ledgerId
              final ledgerId = (bill['ledgerId'] ?? '').toString();
              print('[Delete Bill] ledgerId: $ledgerId');
              
              if (ledgerId.isNotEmpty) {
                final ledgerDoc = await FirebaseFirestore.instance
                    .collection('schools')
                    .doc(_schoolId)
                    .collection('studentFeeLedgers')
                    .doc(ledgerId)
                    .get();

                print('[Delete Bill] Ledger exists: ${ledgerDoc.exists}');

                if (ledgerDoc.exists) {
                  final ledgerData = ledgerDoc.data()!;
                  final currentPaid =
                      (ledgerData['totalPaid'] as num?)?.toDouble() ?? 0;
                  final currentBalance =
                      (ledgerData['totalBalance'] as num?)?.toDouble() ?? 0;

                  print('[Delete Bill] currentPaid: $currentPaid, currentBalance: $currentBalance');
                  print('[Delete Bill] Updating to: paid=${currentPaid - amount}, balance=${currentBalance + amount}');

                  await ledgerDoc.reference.update({
                    'totalPaid': currentPaid - amount,
                    'totalBalance': currentBalance + amount,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                  print('[Delete Bill] Ledger updated successfully');
                } else {
                  print('[Delete Bill] Ledger not found with ledgerId: $ledgerId');
                }
              } else {
                print('[Delete Bill] ledgerId is empty, trying to find by components');
                // Try to find ledger by components if ledgerId is missing
                final components = bill['components'] as List?;
                if (components != null && components.isNotEmpty) {
                  print('[Delete Bill] Found ${components.length} components');
                  for (final comp in components) {
                    final compData = comp as Map<String, dynamic>;
                    final compLedgerId = (compData['ledgerId'] ?? '').toString();
                    if (compLedgerId.isNotEmpty) {
                      final compAmount = (compData['amount'] as num?)?.toDouble() ?? 0;
                      print('[Delete Bill] Updating component ledger: $compLedgerId, amount: $compAmount');
                      
                      final compLedgerDoc = await FirebaseFirestore.instance
                          .collection('schools')
                          .doc(_schoolId)
                          .collection('studentFeeLedgers')
                          .doc(compLedgerId)
                          .get();

                      if (compLedgerDoc.exists) {
                        final compLedgerData = compLedgerDoc.data()!;
                        final compCurrentPaid =
                            (compLedgerData['totalPaid'] as num?)?.toDouble() ?? 0;
                        final compCurrentBalance =
                            (compLedgerData['totalBalance'] as num?)?.toDouble() ?? 0;

                        await compLedgerDoc.reference.update({
                          'totalPaid': compCurrentPaid - compAmount,
                          'totalBalance': compCurrentBalance + compAmount,
                          'updatedAt': FieldValue.serverTimestamp(),
                        });
                        print('[Delete Bill] Component ledger updated successfully');
                      }
                    }
                  }
                }
              }
            }
          } catch (e) {
            print('[Delete Bill] Error reverting ledger: $e');
          }
        }
      }

      _fetchBills();
      // Trigger fee data refresh across screens
      triggerFeeRefresh(ref);
      
      if (mounted) {
        final amount = isRevenue
            ? (bill['amount'] as num?)?.toDouble() ?? 0
            : (bill['expenseAmount'] as num?)?.toDouble() ??
                (bill['amount'] as num?)?.toDouble() ??
                0;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isRevenue
              ? 'Bill deleted & Rs.${amount.toStringAsFixed(0)} reverted to student balance'
              : 'Expense bill deleted'),
          backgroundColor: _accentGreen,
        ));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  void _downloadFile(Uint8List bytes, String fileName, String mimeType) {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}
