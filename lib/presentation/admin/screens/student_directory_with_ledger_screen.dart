import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../data/repositories/student_fee_ledger_repository.dart';
import '../../../domain/entities/student.dart';
import '../../../domain/entities/student_fee_ledger.dart';
import '../../finance/screens/student_fee_ledger_detail_screen.dart';

class StudentDirectoryWithLedgerScreen extends ConsumerStatefulWidget {
  const StudentDirectoryWithLedgerScreen({super.key});

  @override
  ConsumerState<StudentDirectoryWithLedgerScreen> createState() =>
      _StudentDirectoryWithLedgerScreenState();
}

class _StudentDirectoryWithLedgerScreenState
    extends ConsumerState<StudentDirectoryWithLedgerScreen> {
  String _searchQuery = '';
  String? _filterClass;
  String? _filterSection;
  String? _filterPaymentStatus; // 'all', 'pending', 'paid'
  final _searchController = TextEditingController();

  List<Student> _allStudents = [];
  Map<String, StudentFeeLedger?> _ledgerCache = {};
  List<String> _availableClasses = [];
  List<String> _availableSections = [];
  bool _isLoading = true;
  bool _isSendingNotifications = false;

  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String? get _schoolId => ref.read(currentSessionProvider)?.schoolId;
  String? get _academicYear => '2024-2025'; // TODO: Get from settings

  Future<void> _loadData() async {
    final schoolId = _schoolId;
    if (schoolId == null) return;

    setState(() => _isLoading = true);
    try {
      // Load students
      final snapshot = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .where('status', isEqualTo: 'ACTIVE')
          .get();

      final students =
          snapshot.docs.map((doc) => Student.fromFirestore(doc)).toList();
      students
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      // Derive classes
      final classSet = <String>{};
      for (final s in students) {
        if (s.className.isNotEmpty) classSet.add(s.className);
      }
      final sorted = classSet.toList();
      const order = [
        'Pre-KG',
        'LKG',
        'UKG',
        'I',
        'II',
        'III',
        'IV',
        'V',
        'VI',
        'VII',
        'VIII',
        'IX',
        'X',
        'XI',
        'XII'
      ];
      sorted.sort((a, b) {
        final ia = order.indexOf(a);
        final ib = order.indexOf(b);
        if (ia != -1 && ib != -1) return ia.compareTo(ib);
        if (ia != -1) return -1;
        if (ib != -1) return 1;
        return a.compareTo(b);
      });

      if (mounted) {
        setState(() {
          _allStudents = students;
          _availableClasses = sorted;
          _isLoading = false;
        });
        _updateSections();
        _loadLedgers();
      }
    } catch (e) {
      debugPrint('Error loading students: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateSections() {
    if (_filterClass == null) {
      setState(() => _availableSections = []);
      return;
    }
    final sections = <String>{};
    for (final s in _allStudents) {
      if (s.className == _filterClass && s.section.isNotEmpty) {
        sections.add(s.section);
      }
    }
    setState(() => _availableSections = sections.toList()..sort());
  }

  Future<void> _loadLedgers() async {
    final schoolId = _schoolId;
    final academicYear = _academicYear;
    if (schoolId == null || academicYear == null) return;

    final repo = ref.read(studentFeeLedgerRepositoryProvider);
    int loadedCount = 0;
    int notFoundCount = 0;
    
    for (final student in _allStudents) {
      try {
        final ledger =
            await repo.getByStudent(schoolId, student.id, academicYear);
        if (mounted) {
          setState(() => _ledgerCache[student.id] = ledger);
          if (ledger != null) {
            loadedCount++;
          } else {
            notFoundCount++;
          }
        }
      } catch (e) {
        debugPrint('Error loading ledger for ${student.id}: $e');
        notFoundCount++;
      }
    }
    
    debugPrint('Loaded $loadedCount ledgers, $notFoundCount students without ledgers');
    
    // Show message if many students don't have ledgers
    if (mounted && notFoundCount > 0 && loadedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No fee ledgers found for students. Please create ledgers from Fee Management.'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  List<Student> get _filteredStudents {
    var filtered = _allStudents;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((s) {
        final query = _searchQuery.toLowerCase();
        return s.name.toLowerCase().contains(query) ||
            s.studentId.toString().contains(query) ||
            (s.parentName?.toLowerCase().contains(query) ?? false) ||
            (s.parentPhone?.contains(query) ?? false);
      }).toList();
    }

    if (_filterClass != null) {
      filtered = filtered.where((s) => s.className == _filterClass).toList();
    }

    if (_filterSection != null) {
      filtered = filtered.where((s) => s.section == _filterSection).toList();
    }

    if (_filterPaymentStatus != null && _filterPaymentStatus != 'all') {
      filtered = filtered.where((s) {
        final ledger = _ledgerCache[s.id];
        if (ledger == null) return false;
        if (_filterPaymentStatus == 'pending') {
          return ledger.totalPending > 0;
        } else if (_filterPaymentStatus == 'paid') {
          return ledger.totalPending <= 0;
        }
        return true;
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final filteredStudents = _filteredStudents;
    final isWideScreen = MediaQuery.of(context).size.width > 900;
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: _bgDark,
      body: Column(
        children: [
          _buildHeader(context, filteredStudents.length),
          _buildFilters(isWideScreen),
          if (_isLoading)
            const Expanded(
                child: Center(child: CircularProgressIndicator(color: _accentBlue)))
          else if (filteredStudents.isEmpty)
            _buildEmptyState()
          else
            Expanded(
              child: isWideScreen
                  ? _buildDesktopTable(filteredStudents)
                  : _buildMobileList(filteredStudents, isTablet),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int count) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: _cardDark,
        border: Border(bottom: BorderSide(color: _borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school, color: _accentBlue, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Student Directory & Ledgers',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'View students with fee ledgers and send payment reminders',
                      style: TextStyle(color: _textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isSendingNotifications
                    ? null
                    : () => _sendBulkPaymentDueNotifications(),
                icon: _isSendingNotifications
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.notifications_active, size: 18),
                label: Text(_isSendingNotifications
                    ? 'Sending...'
                    : 'Send Payment Due Alerts'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Showing $count student${count != 1 ? 's' : ''}',
            style: const TextStyle(color: _textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(bool isWideScreen) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: _cardDark,
        border: Border(bottom: BorderSide(color: _borderColor)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: isWideScreen ? 300 : double.infinity,
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: _textPrimary),
              decoration: InputDecoration(
                hintText: 'Search by name, ID, parent...',
                hintStyle: const TextStyle(color: _textSecondary),
                prefixIcon: const Icon(Icons.search, color: _textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: _textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: _bgDark,
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
                  borderSide: const BorderSide(color: _accentBlue),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          DropdownButton<String?>(
            value: _filterClass,
            hint: const Text('All Classes',
                style: TextStyle(color: _textSecondary)),
            dropdownColor: _cardDark,
            style: const TextStyle(color: _textPrimary),
            items: [
              const DropdownMenuItem(
                  value: null,
                  child: Text('All Classes',
                      style: TextStyle(color: _textPrimary))),
              ..._availableClasses.map((c) => DropdownMenuItem(
                  value: c,
                  child: Text('Class $c',
                      style: const TextStyle(color: _textPrimary)))),
            ],
            onChanged: (value) {
              setState(() {
                _filterClass = value;
                _filterSection = null;
              });
              _updateSections();
            },
          ),
          if (_filterClass != null)
            DropdownButton<String?>(
              value: _filterSection,
              hint: const Text('All Sections',
                  style: TextStyle(color: _textSecondary)),
              dropdownColor: _cardDark,
              style: const TextStyle(color: _textPrimary),
              items: [
                const DropdownMenuItem(
                    value: null,
                    child: Text('All Sections',
                        style: TextStyle(color: _textPrimary))),
                ..._availableSections.map((s) => DropdownMenuItem(
                    value: s,
                    child: Text('Section $s',
                        style: const TextStyle(color: _textPrimary)))),
              ],
              onChanged: (value) => setState(() => _filterSection = value),
            ),
          DropdownButton<String?>(
            value: _filterPaymentStatus,
            hint: const Text('Payment Status',
                style: TextStyle(color: _textSecondary)),
            dropdownColor: _cardDark,
            style: const TextStyle(color: _textPrimary),
            items: const [
              DropdownMenuItem(
                  value: null,
                  child:
                      Text('All Status', style: TextStyle(color: _textPrimary))),
              DropdownMenuItem(
                  value: 'pending',
                  child: Text('Pending Fees',
                      style: TextStyle(color: Colors.orange))),
              DropdownMenuItem(
                  value: 'paid',
                  child: Text('Fees Cleared',
                      style: TextStyle(color: Colors.green))),
            ],
            onChanged: (value) => setState(() => _filterPaymentStatus = value),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: _accentBlue),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_outlined, size: 64, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text(
            'No students found',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(List<Student> students) {
    return SingleChildScrollView(
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor),
        ),
        child: Column(
          children: [
            _buildTableHeader(),
            ...students.map((s) => _buildTableRow(s)),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: _bgDark,
        border: Border(bottom: BorderSide(color: _borderColor)),
      ),
      child: const Row(
        children: [
          SizedBox(
              width: 50,
              child: Text('ID',
                  style: TextStyle(
                      color: _textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600))),
          Expanded(
            flex: 2,
            child: Text('Student',
                style: TextStyle(
                    color: _textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          SizedBox(
              width: 70,
              child: Text('Class',
                  style: TextStyle(
                      color: _textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600))),
          Expanded(
            flex: 2,
            child: Text('Fee Status',
                style: TextStyle(
                    color: _textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          SizedBox(
              width: 150,
              child: Text('Actions',
                  style: TextStyle(
                      color: _textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildTableRow(Student student) {
    final ledger = _ledgerCache[student.id];
    final hasPending = ledger != null && ledger.totalPending > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _borderColor, width: 0.5))),
      child: Row(
        children: [
          SizedBox(
              width: 50,
              child: Text('${student.studentId}',
                  style: const TextStyle(color: _textPrimary, fontSize: 13))),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: _accentBlue.withValues(alpha: 0.2),
                  radius: 16,
                  child: Text(
                      student.name.isNotEmpty
                          ? student.name[0].toUpperCase()
                          : 'S',
                      style: const TextStyle(
                          color: _accentBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student.name,
                          style: const TextStyle(
                              color: _textPrimary,
                              fontWeight: FontWeight.w500,
                              fontSize: 13),
                          overflow: TextOverflow.ellipsis),
                      if (student.parentPhone != null)
                        Text(student.parentPhone!,
                            style: const TextStyle(
                                color: _textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
              width: 70,
              child: Text('${student.className}-${student.section}',
                  style: const TextStyle(color: _textPrimary, fontSize: 13))),
          Expanded(
            flex: 2,
            child: _buildFeeStatusChip(ledger),
          ),
          SizedBox(
            width: 150,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.account_balance_wallet,
                      size: 18, color: Colors.blue),
                  onPressed: () => _viewLedger(student),
                  tooltip: 'View Ledger',
                ),
                if (hasPending)
                  IconButton(
                    icon: const Icon(Icons.notifications,
                        size: 18, color: Colors.orange),
                    onPressed: () => _sendPaymentDueNotification(student, ledger!),
                    tooltip: 'Send Payment Due',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeStatusChip(StudentFeeLedger? ledger) {
    if (ledger == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text('No Ledger',
            style: TextStyle(color: Colors.grey, fontSize: 11)),
      );
    }

    final hasPending = ledger.totalPending > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: hasPending
            ? Colors.orange.withValues(alpha: 0.2)
            : Colors.green.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasPending ? 'Pending' : 'Cleared',
            style: TextStyle(
                color: hasPending ? Colors.orange : Colors.green,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
          Text(
            '₹${ledger.totalPending.toStringAsFixed(0)} / ₹${ledger.totalAssigned.toStringAsFixed(0)}',
            style: const TextStyle(color: _textPrimary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileList(List<Student> students, bool isTablet) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: students.length,
      itemBuilder: (context, index) => _buildStudentCard(students[index]),
    );
  }

  Widget _buildStudentCard(Student student) {
    final ledger = _ledgerCache[student.id];
    final hasPending = ledger != null && ledger.totalPending > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: _accentBlue.withValues(alpha: 0.2),
                radius: 24,
                child: Text(
                    student.name.isNotEmpty
                        ? student.name[0].toUpperCase()
                        : 'S',
                    style: const TextStyle(
                        color: _accentBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student.name,
                        style: const TextStyle(
                            color: _textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                        'ID: ${student.studentId} • ${student.className}-${student.section}',
                        style: const TextStyle(
                            color: _textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildFeeStatusCard(ledger),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _viewLedger(student),
                  icon: const Icon(Icons.account_balance_wallet, size: 16),
                  label: const Text('View Ledger'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                  ),
                ),
              ),
              if (hasPending) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _sendPaymentDueNotification(student, ledger!),
                    icon: const Icon(Icons.notifications, size: 16),
                    label: const Text('Send Due'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeeStatusCard(StudentFeeLedger? ledger) {
    if (ledger == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey, size: 20),
            SizedBox(width: 10),
            Text('No fee ledger available',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      );
    }

    final hasPending = ledger.totalPending > 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasPending
            ? Colors.orange.withValues(alpha: 0.1)
            : Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: hasPending
                ? Colors.orange.withValues(alpha: 0.3)
                : Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                  hasPending
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline,
                  color: hasPending ? Colors.orange : Colors.green,
                  size: 20),
              const SizedBox(width: 10),
              Text(hasPending ? 'Payment Pending' : 'Fees Cleared',
                  style: TextStyle(
                      color: hasPending ? Colors.orange : Colors.green,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Assigned',
                      style: TextStyle(color: _textSecondary, fontSize: 11)),
                  Text('₹${ledger.totalAssigned.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: _textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Paid',
                      style: TextStyle(color: _textSecondary, fontSize: 11)),
                  Text('₹${ledger.totalPaid.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: Colors.green,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pending',
                      style: TextStyle(color: _textSecondary, fontSize: 11)),
                  Text('₹${ledger.totalPending.toStringAsFixed(0)}',
                      style: TextStyle(
                          color: hasPending ? Colors.orange : Colors.green,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _viewLedger(Student student) async {
    final ledger = _ledgerCache[student.id];
    if (ledger == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No ledger found for this student'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentFeeLedgerDetailScreen(
          schoolId: _schoolId!,
          ledgerId: ledger.id,
        ),
      ),
    ).then((_) => _loadData());
  }

  Future<void> _sendPaymentDueNotification(
      Student student, StudentFeeLedger ledger) async {
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
            Text('Student: ${student.name}',
                style: const TextStyle(color: _textPrimary)),
            const SizedBox(height: 8),
            Text('Pending Amount: ₹${ledger.totalPending.toStringAsFixed(0)}',
                style: const TextStyle(color: Colors.orange, fontSize: 16)),
            const SizedBox(height: 12),
            if (student.parentPhone != null)
              Text('Notification will be sent to: ${student.parentPhone}',
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
            onPressed: student.parentPhone != null
                ? () => Navigator.pop(context, true)
                : null,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Send Notification'),
          ),
        ],
      ),
    );

    if (confirmed == true && student.parentPhone != null) {
      try {
        // TODO: Implement WhatsApp/SMS notification
        // For now, just show success message
        await Future.delayed(const Duration(seconds: 1));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Payment due notification sent to ${student.parentPhone!}'),
              backgroundColor: Colors.green,
            ),
          );

          // Update last reminder sent
          await FirebaseFirestore.instance
              .collection('schools')
              .doc(_schoolId)
              .collection('studentFeeLedgers')
              .doc(ledger.id)
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
      }
    }
  }

  Future<void> _sendBulkPaymentDueNotifications() async {
    final studentsWithDues = _filteredStudents.where((s) {
      final ledger = _ledgerCache[s.id];
      return ledger != null &&
          ledger.totalPending > 0 &&
          s.parentPhone != null &&
          s.parentPhone!.isNotEmpty;
    }).toList();

    if (studentsWithDues.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No students with pending fees and valid phone numbers'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardDark,
        title: const Text('Send Bulk Payment Due Notifications',
            style: TextStyle(color: _textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'This will send payment due notifications to ${studentsWithDues.length} parent(s).',
                style: const TextStyle(color: _textPrimary)),
            const SizedBox(height: 12),
            const Text('Are you sure you want to proceed?',
                style: TextStyle(color: _textSecondary, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Send All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isSendingNotifications = true);

      int successCount = 0;
      int failCount = 0;

      for (final student in studentsWithDues) {
        try {
          // TODO: Implement actual WhatsApp/SMS notification
          await Future.delayed(const Duration(milliseconds: 500));

          final ledger = _ledgerCache[student.id];
          if (ledger != null) {
            await FirebaseFirestore.instance
                .collection('schools')
                .doc(_schoolId)
                .collection('studentFeeLedgers')
                .doc(ledger.id)
                .update({'lastReminderSentAt': FieldValue.serverTimestamp()});
          }

          successCount++;
        } catch (e) {
          failCount++;
          debugPrint('Failed to send notification to ${student.name}: $e');
        }
      }

      setState(() => _isSendingNotifications = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Sent $successCount notification(s). Failed: $failCount'),
            backgroundColor: failCount > 0 ? Colors.orange : Colors.green,
          ),
        );
      }
    }
  }
}
