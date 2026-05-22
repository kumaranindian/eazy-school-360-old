import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../domain/entities/academic_year.dart';
import '../../../data/repositories/student_fee_ledger_repository.dart';
import '../../../data/repositories/fee_structure_v2_repository.dart';
import '../../../domain/entities/student.dart';
import '../../../domain/entities/student_fee_ledger.dart';
import '../../../domain/entities/fee_structure_v2.dart';

// Color constants
const Color _bgDark = Color(0xFF0D1117);
const Color _cardDark = Color(0xFF161B22);
const Color _accentBlue = Color(0xFF4CAF50);
const Color _accentGreen = Color(0xFF10B981);
const Color _accentAmber = Color(0xFFF59E0B);
const Color _accentRed = Color(0xFFEF4444);
const Color _textPrimary = Color(0xFFE6EDF3);
const Color _textSecondary = Color(0xFF8B949E);
const Color _borderColor = Color(0xFF30363D);

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
  bool _isSendingSingleNotification = false;
  int _notificationProgress = 0;
  int _notificationTotal = 0;
  int _dueDaysThreshold = 7; // Configurable days for due notification

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
  String get _academicYear => AcademicYear.getCurrentYearCode();

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
        });
      }
      
      // Load ledgers for all students
      await _loadLedgersForStudents(students, schoolId);
      
      if (mounted) {
        setState(() => _isLoading = false);
        _updateSections();
      }
    } catch (e) {
      debugPrint('Error loading students: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLedgersForStudents(List<Student> students, String schoolId) async {
    try {
      // Optimized: Load all ledgers for the academic year in a single query
      // instead of individual queries per student (reduces cost from N queries to 1)
      final snapshot = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('studentFeeLedgers')
          .where('academicYear', isEqualTo: _academicYear)
          .get();
      
      debugPrint('[StudentDirectory] Loaded ${snapshot.docs.length} ledgers in single query');
      
      // Build a map of studentId -> ledger for quick lookup
      final ledgersByStudentId = <String, StudentFeeLedger>{};
      for (final doc in snapshot.docs) {
        final ledger = StudentFeeLedger.fromFirestore(doc);
        // Store by both string and numeric studentId for compatibility
        ledgersByStudentId[ledger.studentId] = ledger;
      }
      
      // Map ledgers to student IDs (student.id is the Firestore document ID)
      final cache = <String, StudentFeeLedger?>{};
      for (final student in students) {
        // Try to find ledger by studentId (could be string or number)
        final ledger = ledgersByStudentId[student.studentId.toString()] ??
                       ledgersByStudentId[student.studentId.toString()];
        cache[student.id] = ledger;
      }
      
      if (mounted) {
        setState(() => _ledgerCache = cache);
      }
    } catch (e) {
      debugPrint('[StudentDirectory] Error loading ledgers: $e');
      if (mounted) {
        setState(() => _ledgerCache = {});
      }
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
                child: Center(
                    child: CircularProgressIndicator(color: _accentBlue)))
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
              const SizedBox(width: 12),
              // Due days threshold selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _bgDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Due within:',
                      style: TextStyle(color: _textSecondary, fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: _dueDaysThreshold,
                      dropdownColor: _cardDark,
                      underline: Container(),
                      style: const TextStyle(color: _textPrimary, fontSize: 13),
                      items: [1, 3, 7, 14, 30, 60, 90].map((days) {
                        return DropdownMenuItem<int>(
                          value: days,
                          child: Text('$days days'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _dueDaysThreshold = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () async {
                  try {
                    final testCallable = FirebaseFunctions.instanceFor(region: 'us-central1')
                        .httpsCallable('sendFeeDueNotification');
                    
                    final result = await testCallable.call({
                      'schoolId': _schoolId,
                      'phoneNumber': '+918508196981',
                      'studentName': 'Test Student',
                      'pendingAmount': '1000',
                      'dueDate': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
                      'dueTerms': 'Test Term',
                      'schoolName': 'Test School',
                      'className': 'Test Class',
                    });
                    
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Test result: ${result.data}'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Test error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.bug_report, color: _textSecondary),
                tooltip: 'Test WhatsApp Config',
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () => _bulkCreateLedgers(),
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.library_add, size: 18),
                label: Text(_isLoading ? 'Creating...' : 'Bulk Create Ledgers'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentBlue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
              const SizedBox(width: 12),
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
          if (_isSendingNotifications)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _notificationTotal > 0 ? _notificationProgress / _notificationTotal : 0,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sending notifications: $_notificationProgress / $_notificationTotal',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
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
                  child: Text('All Status',
                      style: TextStyle(color: _textPrimary))),
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
                if (ledger != null) ...[
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
                      onPressed: () =>
                          _sendPaymentDueNotification(student, ledger),
                      tooltip: 'Send Payment Due',
                    ),
                ] else
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline,
                        size: 18, color: _accentBlue),
                    onPressed: () => _createLedgerForStudent(student),
                    tooltip: 'Create Ledger',
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
              if (ledger != null) ...[
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
                      onPressed: () =>
                          _sendPaymentDueNotification(student, ledger),
                      icon: const Icon(Icons.notifications, size: 16),
                      label: const Text('Send Due'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ] else
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _createLedgerForStudent(student),
                    icon: const Icon(Icons.add_circle_outline, size: 16),
                    label: const Text('Create Ledger'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentBlue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
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
    final schoolId = _schoolId;
    if (schoolId == null) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: _accentBlue),
      ),
    );

    // Fetch ledger on demand instead of using a pre-loaded cache
    final repo = ref.read(studentFeeLedgerRepositoryProvider);
    final ledger = await repo.getByStudent(
        schoolId, student.studentId.toString(), _academicYear);

    if (!mounted) return;
    
    // Close loading dialog
    Navigator.pop(context);

    if (ledger == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No ledger found for this student'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show ledger in popup dialog
    showDialog(
      context: context,
      builder: (context) => _LedgerViewDialog(
        student: student,
        ledger: ledger,
        schoolId: schoolId,
        academicYear: _academicYear,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color valueColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(label,
              style: const TextStyle(color: _textSecondary, fontSize: 13)),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(color: valueColor, fontSize: 13)),
        ),
      ],
    );
  }

  Future<void> _sendPaymentDueNotification(
      Student student, StudentFeeLedger ledger) async {
    final now = DateTime.now();
    final dueTerms = <Map<String, dynamic>>[];
    
    // First, add all arrears (always include if balance > 0)
    final arrearsTerms = ledger.termStatus.where((t) => t.isArrear && t.balanceAmount > 0).toList();
    for (final term in arrearsTerms) {
      dueTerms.add({
        'termName': term.termName,
        'amount': term.balanceAmount,
        'dueDate': term.dueDate,
        'daysUntilDue': 0, // Arrears are always overdue
        'isOverdue': true,
        'isArrear': true,
      });
    }
    
    // Then, add regular terms that are due within threshold
    for (final term in ledger.termStatus) {
      if (!term.isArrear && term.balanceAmount > 0) {
        final dueDate = term.dueDate;
        final daysUntilDue = dueDate.difference(now).inDays;
        
        // Consider as due if within configured days or already overdue
        if (daysUntilDue <= _dueDaysThreshold) {
          dueTerms.add({
            'termName': term.termName,
            'amount': term.balanceAmount,
            'dueDate': dueDate,
            'daysUntilDue': daysUntilDue,
            'isOverdue': daysUntilDue < 0,
            'isArrear': false,
          });
        }
      }
    }
    
    // Sort by due date (earliest first)
    dueTerms.sort((a, b) => (a['dueDate'] as DateTime).compareTo(b['dueDate'] as DateTime));
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardDark,
        title: const Text('Send Payment Due Notification',
            style: TextStyle(color: _textPrimary)),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Student Info
                _buildInfoRow('Student:', student.name, _textPrimary),
                const SizedBox(height: 4),
                _buildInfoRow('Class:', '${student.className} ${student.section}', _textSecondary),
                const SizedBox(height: 4),
                if (student.parentName != null)
                  _buildInfoRow('Parent:', student.parentName!, _textSecondary),
                const SizedBox(height: 4),
                if (student.parentPhone != null)
                  _buildInfoRow('Phone:', student.parentPhone!, _textSecondary),
                const SizedBox(height: 12),
                
                // Calculate total due amount from dueTerms
                Builder(builder: (context) {
                  final totalDue = dueTerms.fold<double>(0, (sum, term) => sum + (term['amount'] as double));
                  final hasArrears = dueTerms.any((t) => t['isArrear'] == true);
                  final dueColor = hasArrears ? _accentRed : Colors.orange;
                  
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: dueColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: dueColor.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        if (hasArrears)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _accentRed.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: _accentRed.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warning_amber, color: _accentRed, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'ARREARS - Priority Payment Required',
                                  style: TextStyle(
                                    color: _accentRed,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              hasArrears ? 'Arrears Amount:' : 'Amount Due:',
                              style: const TextStyle(color: _textPrimary, fontSize: 14),
                            ),
                            Text(
                              '₹${totalDue.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: dueColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 12),
                
                // Fee Breakdown
                if (dueTerms.isNotEmpty) ...[
                  Builder(builder: (context) {
                    final hasArrears = dueTerms.any((t) => t['isArrear'] == true);
                    return Text(
                      hasArrears ? 'Arrears Details:' : 'Due Fees:',
                      style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.bold),
                    );
                  }),
                  const SizedBox(height: 8),
                  ...dueTerms.map((term) {
                    final isArrear = term['isArrear'] as bool;
                    final isOverdue = term['isOverdue'] as bool;
                    final termColor = isArrear ? _accentRed : (isOverdue ? Colors.red : Colors.blue);
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: termColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: termColor.withValues(alpha: 0.3)),
                      ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(term['termName'] as String,
                                style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w500)),
                            Text('₹${(term['amount'] as double).toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: (term['isOverdue'] as bool) ? Colors.red : Colors.blue,
                                  fontWeight: FontWeight.bold,
                                )),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: _textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${(term['dueDate'] as DateTime).day}/${(term['dueDate'] as DateTime).month}/${(term['dueDate'] as DateTime).year}',
                              style: const TextStyle(color: _textSecondary, fontSize: 12),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              (term['isOverdue'] as bool)
                                  ? 'OVERDUE by ${-(term['daysUntilDue'] as int)} days'
                                  : 'Due in ${term['daysUntilDue'] as int} days',
                              style: TextStyle(
                                color: (term['isOverdue'] as bool) ? Colors.red : Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                  }),
                ] else
                  Text('No fees due in the next $_dueDaysThreshold days',
                      style: const TextStyle(color: _textSecondary)),
                
                const SizedBox(height: 12),
                if (student.parentPhone == null)
                  const Text('No parent phone number available',
                      style: TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSendingSingleNotification
                ? null
                : () => Navigator.pop(context, false),
            child:
                const Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: (student.parentPhone != null && dueTerms.isNotEmpty && !_isSendingSingleNotification)
                ? () async {
                    setState(() => _isSendingSingleNotification = true);
                    try {
                      debugPrint('[DueNotification] ===== SENDING NOTIFICATION =====');
                      debugPrint('[DueNotification] Student: ${student.name}');
                      debugPrint('[DueNotification] Phone: ${student.parentPhone}');
                      
                      // Calculate actual due amount from dueTerms (arrears + terms within threshold)
                      final dueAmount = dueTerms.fold<double>(0, (sum, term) => sum + (term['amount'] as double));
                      final dueTermNames = dueTerms.map((t) => t['termName'] as String).toList();
                      
                      debugPrint('[DueNotification] Due amount: ₹$dueAmount');
                      debugPrint('[DueNotification] Due terms: ${dueTermNames.join(", ")}');
                      
                      // Call the Cloud Function to send WhatsApp fee due notification
                      final callable = FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('sendFeeDueNotification');
                      debugPrint('[DueNotification] Cloud Function callable created');
                      
                      // Calculate earliest due date from dueTerms
                      String earliestDueDate = DateTime.now().add(const Duration(days: 7)).toIso8601String();
                      if (dueTerms.isNotEmpty) {
                        final sortedTerms = List<Map<String, dynamic>>.from(dueTerms);
                        sortedTerms.sort((a, b) => (a['dueDate'] as DateTime).compareTo(b['dueDate'] as DateTime));
                        earliestDueDate = (sortedTerms.first['dueDate'] as DateTime).toIso8601String();
                      }
                      debugPrint('[DueNotification] Earliest due date: $earliestDueDate');
                      
                      final params = {
                        'schoolId': _schoolId,
                        'phoneNumber': student.parentPhone,
                        'studentName': student.name,
                        'pendingAmount': dueAmount.toStringAsFixed(0),
                        'dueDate': earliestDueDate,
                        'dueTerms': dueTermNames.join(', '),
                        'schoolName': 'School',
                        'className': student.className,
                      };
                      debugPrint('[DueNotification] Calling function with params: $params');
                      
                      final result = await callable.call(params);
                      debugPrint('[DueNotification] Function call completed');
                      debugPrint('[DueNotification] Result data: ${result.data}');

                      if (mounted) {
                        final success = result.data['success'] as bool? ?? false;
                        debugPrint('[DueNotification] Success: $success');
                        
                        setState(() => _isSendingSingleNotification = false);
                        Navigator.pop(context, false);
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                success 
                                    ? 'Fee due reminder sent to ${student.parentPhone!}'
                                    : 'Failed to send notification: ${result.data['error'] ?? "Unknown error"}'),
                            backgroundColor: success ? Colors.green : Colors.orange,
                            duration: const Duration(seconds: 3),
                          ),
                        );

                        // Update last reminder sent only if successful
                        if (success) {
                          debugPrint('[DueNotification] Updating lastReminderSentAt...');
                          await FirebaseFirestore.instance
                              .collection('schools')
                              .doc(_schoolId)
                              .collection('studentFeeLedgers')
                              .doc(ledger.id)
                              .update({'lastReminderSentAt': FieldValue.serverTimestamp()});
                          debugPrint('[DueNotification] lastReminderSentAt updated');
                        }
                      }
                      debugPrint('[DueNotification] ===== NOTIFICATION COMPLETE =====');
                    } catch (e, stackTrace) {
                      debugPrint('[DueNotification] ===== ERROR =====');
                      debugPrint('[DueNotification] Error: $e');
                      debugPrint('[DueNotification] Stack trace: $stackTrace');
                      
                      setState(() => _isSendingSingleNotification = false);
                      Navigator.pop(context, false);
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to send notification: $e'),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                    }
                  }
                : null,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: _isSendingSingleNotification
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Send Notification'),
          ),
        ],
      ),
    );
  }

  Future<void> _createLedgerForStudent(Student student) async {
    final schoolId = _schoolId;
    if (schoolId == null) return;

    // Fetch available fee structures for the current academic year
    final structureRepo = ref.read(feeStructureV2RepositoryProvider);
    final allStructures = await structureRepo.listAll(schoolId);
    
    // Auto-select structure based on class and academic year
    final matchingStructures = allStructures.where((s) => 
      s.academicYear == _academicYear && 
      s.isActive &&
      s.applicableToClassIds.contains(student.className)
    ).toList();

    if (!mounted) return;

    FeeStructureV2? selectedStructure;

    if (matchingStructures.isEmpty) {
      // No matching structure found, show all active structures for manual selection
      final activeStructures = allStructures
          .where((s) => s.academicYear == _academicYear && s.isActive)
          .toList();
      
      if (activeStructures.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No active fee structures found for current academic year'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      selectedStructure = await showDialog<FeeStructureV2>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: _cardDark,
          title: const Text('Select Fee Structure', style: TextStyle(color: _textPrimary)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No fee structure found for class ${student.className}',
                  style: const TextStyle(color: Colors.orange, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  'Student: ${student.name}',
                  style: const TextStyle(color: _textSecondary, fontSize: 13),
                ),
                Text(
                  'Class: ${student.className}-${student.section}',
                  style: const TextStyle(color: _textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                const Text('Select a fee structure:', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                ...activeStructures.map((structure) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    tileColor: _bgDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: _borderColor),
                    ),
                    title: Text(structure.name, style: const TextStyle(color: _textPrimary, fontSize: 14)),
                    subtitle: Text(
                      '₹${structure.totalAmount.toStringAsFixed(2)} • ${structure.termCount} terms',
                      style: const TextStyle(color: _textSecondary, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, color: _accentBlue, size: 16),
                    onTap: () => Navigator.pop(context, structure),
                  ),
                )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    } else if (matchingStructures.length == 1) {
      // Exactly one matching structure - show confirmation dialog
      selectedStructure = matchingStructures.first;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: _cardDark,
          title: const Text('Confirm Fee Structure', style: TextStyle(color: _textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Creating ledger for:',
                style: const TextStyle(color: _textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 8),
              _buildInfoRow('Student', student.name, _textPrimary),
              _buildInfoRow('Class', '${student.className}-${student.section}', _textPrimary),
              _buildInfoRow('Academic Year', _academicYear, _textPrimary),
              const SizedBox(height: 16),
              const Text(
                'Fee Structure:',
                style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _accentBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _accentBlue.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedStructure!.name,
                      style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total Amount: ₹${selectedStructure.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(color: _textSecondary, fontSize: 13),
                    ),
                    Text(
                      'Terms: ${selectedStructure.termCount}',
                      style: const TextStyle(color: _textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Do you want to create this ledger?',
                style: TextStyle(color: _textSecondary, fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: _accentBlue),
              child: const Text('Create Ledger'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    } else {
      // Multiple matching structures - let user choose
      selectedStructure = await showDialog<FeeStructureV2>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: _cardDark,
          title: const Text('Select Fee Structure', style: TextStyle(color: _textPrimary)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Multiple fee structures found for class ${student.className}',
                  style: const TextStyle(color: _textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  'Student: ${student.name}',
                  style: const TextStyle(color: _textSecondary, fontSize: 13),
                ),
                Text(
                  'Class: ${student.className}-${student.section}',
                  style: const TextStyle(color: _textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                const Text('Select a fee structure:', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                ...matchingStructures.map((structure) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    tileColor: _bgDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: _borderColor),
                    ),
                    title: Text(structure.name, style: const TextStyle(color: _textPrimary, fontSize: 14)),
                    subtitle: Text(
                      '₹${structure.totalAmount.toStringAsFixed(2)} • ${structure.termCount} terms',
                      style: const TextStyle(color: _textSecondary, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, color: _accentBlue, size: 16),
                    onTap: () => Navigator.pop(context, structure),
                  ),
                )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    }

    if (selectedStructure == null || !mounted) return;

    // Create ledger using repository
    setState(() => _isLoading = true);
    
    try {
      final ledgerRepo = ref.read(studentFeeLedgerRepositoryProvider);
      final result = await ledgerRepo.assignToStudent(
        schoolId: schoolId,
        studentId: student.studentId.toString(), // Use student number, not Firestore doc ID
        studentName: student.name,
        className: student.className,
        section: student.section,
        structureId: selectedStructure.id,
        parentName: student.parentName,
        parentPhone: student.parentPhone,
        onConflict: ConflictAction.SKIP,
      );

      if (!mounted) return;

      if (result.outcome == AssignmentOutcome.NEW) {
        // Fetch the newly created ledger directly (same as Assign & Load)
        // Use student.studentId (the student number) not student.id (Firestore doc ID)
        final newLedger = await ledgerRepo.getByStudent(
          schoolId,
          student.studentId.toString(),
          _academicYear,
        );
        
        if (!mounted) return;
        
        // Update cache with the new ledger using student.id (Firestore doc ID) as key
        setState(() {
          if (newLedger != null) {
            _ledgerCache[student.id] = newLedger;
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ledger created successfully for ${student.name}'),
            backgroundColor: Colors.green,
          ),
        );
      } else{
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create ledger: ${result.outcome.name}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating ledger: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _bulkCreateLedgers() async {
    final schoolId = _schoolId;
    if (schoolId == null) return;

    // Find all students without ledgers
    final studentsWithoutLedgers = _filteredStudents
        .where((student) => _ledgerCache[student.id] == null)
        .toList();

    if (studentsWithoutLedgers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All students already have ledgers'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    // Group students by class
    final Map<String, List<Student>> studentsByClass = {};
    for (final student in studentsWithoutLedgers) {
      studentsByClass.putIfAbsent(student.className, () => []).add(student);
    }

    // Fetch all fee structures
    final structureRepo = ref.read(feeStructureV2RepositoryProvider);
    final allStructures = await structureRepo.listAll(schoolId);
    final activeStructures = allStructures
        .where((s) => s.academicYear == _academicYear && s.isActive)
        .toList();

    if (activeStructures.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active fee structures found for current academic year'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Build preview showing which structure will be assigned to each class
    final Map<String, FeeStructureV2?> classToStructure = {};
    final List<String> classesWithoutStructure = [];
    
    for (final className in studentsByClass.keys) {
      final matchingStructures = activeStructures
          .where((s) => s.applicableToClassIds.contains(className))
          .toList();
      
      if (matchingStructures.isEmpty) {
        classesWithoutStructure.add(className);
        classToStructure[className] = null;
      } else if (matchingStructures.length == 1) {
        classToStructure[className] = matchingStructures.first;
      } else {
        // Multiple structures - will need manual selection
        classToStructure[className] = null;
      }
    }

    if (!mounted) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardDark,
        title: const Text('Bulk Create Ledgers', style: TextStyle(color: _textPrimary)),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Creating ledgers for ${studentsWithoutLedgers.length} students',
                  style: const TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Fee Structure Assignment:',
                  style: TextStyle(color: _textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 12),
                ...studentsByClass.entries.map((entry) {
                  final className = entry.key;
                  final students = entry.value;
                  final structure = classToStructure[className];
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: structure != null 
                          ? _accentBlue.withValues(alpha: 0.1)
                          : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: structure != null 
                            ? _accentBlue.withValues(alpha: 0.3)
                            : Colors.orange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              structure != null ? Icons.check_circle : Icons.warning,
                              color: structure != null ? _accentBlue : Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Class $className',
                                style: const TextStyle(
                                  color: _textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Text(
                              '${students.length} students',
                              style: const TextStyle(color: _textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (structure != null) ...[
                          Text(
                            structure.name,
                            style: const TextStyle(color: _textPrimary, fontSize: 13),
                          ),
                          Text(
                            '₹${structure.totalAmount.toStringAsFixed(2)} • ${structure.termCount} terms',
                            style: const TextStyle(color: _textSecondary, fontSize: 12),
                          ),
                        ] else
                          const Text(
                            'No matching fee structure found',
                            style: TextStyle(color: Colors.orange, fontSize: 12),
                          ),
                      ],
                    ),
                  );
                }),
                if (classesWithoutStructure.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Students in classes without matching structures will be skipped: ${classesWithoutStructure.join(", ")}',
                            style: const TextStyle(color: Colors.orange, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: _accentBlue),
            child: const Text('Create Ledgers'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _BulkCreateProgressDialog(
        totalStudents: studentsWithoutLedgers.length,
      ),
    );

    // Create ledgers
    int successCount = 0;
    int skipCount = 0;
    int failCount = 0;
    int processedCount = 0;

    try {
      final ledgerRepo = ref.read(studentFeeLedgerRepositoryProvider);
      
      for (final entry in studentsByClass.entries) {
        final className = entry.key;
        final students = entry.value;
        final structure = classToStructure[className];
        
        if (structure == null) {
          skipCount += students.length;
          processedCount += students.length;
          
          // Update progress
          if (mounted) {
            _updateBulkProgress(
              context,
              processedCount,
              studentsWithoutLedgers.length,
              successCount,
              skipCount,
              failCount,
              'Skipping Class $className (no structure)',
            );
          }
          continue;
        }

        for (final student in students) {
          try {
            // Update progress before processing
            if (mounted) {
              _updateBulkProgress(
                context,
                processedCount,
                studentsWithoutLedgers.length,
                successCount,
                skipCount,
                failCount,
                'Creating ledger for ${student.name} (${student.className})',
              );
            }

            final result = await ledgerRepo.assignToStudent(
              schoolId: schoolId,
              studentId: student.studentId.toString(), // Use student number, not Firestore doc ID
              studentName: student.name,
              className: student.className,
              section: student.section,
              structureId: structure.id,
              parentName: student.parentName,
              parentPhone: student.parentPhone,
              onConflict: ConflictAction.SKIP,
            );

            if (result.outcome == AssignmentOutcome.NEW) {
              successCount++;
            } else {
              skipCount++;
            }
          } catch (e) {
            failCount++;
            debugPrint('[BulkCreateLedgers] Failed for ${student.name}: $e');
          }
          
          processedCount++;
          
          // Update progress after processing
          if (mounted) {
            _updateBulkProgress(
              context,
              processedCount,
              studentsWithoutLedgers.length,
              successCount,
              skipCount,
              failCount,
              processedCount < studentsWithoutLedgers.length
                  ? 'Processing...'
                  : 'Complete!',
            );
          }
        }
      }

      if (!mounted) return;

      // Close progress dialog
      Navigator.of(context).pop();

      // Reload data to show new ledgers
      await _loadData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bulk creation complete: $successCount created, $skipCount skipped, $failCount failed',
          ),
          backgroundColor: failCount > 0 ? Colors.orange : Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      // Close progress dialog
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during bulk creation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendBulkPaymentDueNotifications() async {
    final now = DateTime.now();
    final studentsWithDues = <Map<String, dynamic>>[];
    
    for (final student in _filteredStudents) {
      final ledger = _ledgerCache[student.id];
      if (ledger != null &&
          ledger.totalPending > 0 &&
          student.parentPhone != null &&
          student.parentPhone!.isNotEmpty) {
        
        final dueTerms = <String>[];
        double dueAmount = 0;
        
        // First, add all arrears (always include if balance > 0)
        final arrearsTerms = ledger.termStatus.where((t) => t.isArrear && t.balanceAmount > 0).toList();
        for (final term in arrearsTerms) {
          dueTerms.add(term.termName);
          dueAmount += term.balanceAmount;
        }
        
        // Then, add regular terms that are due within threshold
        for (final term in ledger.termStatus) {
          if (!term.isArrear && term.balanceAmount > 0) {
            final daysUntilDue = term.dueDate.difference(now).inDays;
            if (daysUntilDue <= _dueDaysThreshold) {
              dueTerms.add(term.termName);
              dueAmount += term.balanceAmount;
            }
          }
        }
        
        // Only add student if they have at least one term due
        if (dueTerms.isNotEmpty) {
          studentsWithDues.add({
            'student': student,
            'ledger': ledger,
            'dueTerms': dueTerms,
            'dueAmount': dueAmount,
            'hasArrears': arrearsTerms.isNotEmpty,
          });
        }
      }
    }

    if (studentsWithDues.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No students with due fees in the next $_dueDaysThreshold days'),
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
        content: SizedBox(
          width: 600,
          height: 400,
          child: Column(
            children: [
              Text(
                  'This will send payment due notifications to ${studentsWithDues.length} parent(s).',
                  style: const TextStyle(color: _textPrimary)),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: studentsWithDues.length,
                  itemBuilder: (context, index) {
                    final item = studentsWithDues[index];
                    final student = item['student'] as Student;
                    final dueTerms = item['dueTerms'] as List<String>;
                    final dueAmount = item['dueAmount'] as double;
                    final hasArrears = item['hasArrears'] as bool;
                    
                    return Card(
                      color: _cardDark,
                      child: ListTile(
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(student.name,
                                  style: const TextStyle(color: _textPrimary)),
                            ),
                            if (hasArrears)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _accentRed.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: _accentRed.withValues(alpha: 0.3)),
                                ),
                                child: const Text(
                                  'ARREARS',
                                  style: TextStyle(
                                    color: _accentRed,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${student.className} ${student.section}',
                                style: const TextStyle(color: _textSecondary, fontSize: 12)),
                            Text('Parent: ${student.parentPhone}',
                                style: const TextStyle(color: _textSecondary, fontSize: 12)),
                            if (dueTerms.isNotEmpty)
                              Text('Due: ${dueTerms.join(', ')}',
                                  style: TextStyle(
                                    color: hasArrears ? _accentRed : Colors.orange,
                                    fontSize: 12,
                                  )),
                          ],
                        ),
                        trailing: Text('₹${dueAmount.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: hasArrears ? _accentRed : Colors.orange,
                              fontWeight: FontWeight.bold,
                            )),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
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
      debugPrint('[BulkDueNotification] ===== STARTING BULK SEND =====');
      debugPrint('[BulkDueNotification] Total students: ${studentsWithDues.length}');
      
      setState(() {
        _isSendingNotifications = true;
        _notificationProgress = 0;
        _notificationTotal = studentsWithDues.length;
      });

      int successCount = 0;
      int failCount = 0;
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('sendFeeDueNotification');

      for (int i = 0; i < studentsWithDues.length; i++) {
        final item = studentsWithDues[i];
        setState(() => _notificationProgress = i + 1);
        
        try {
          final student = item['student'] as Student;
          final ledger = item['ledger'] as StudentFeeLedger;
          final dueAmount = item['dueAmount'] as double;
          final dueTerms = item['dueTerms'] as List<String>;
          
          debugPrint('[BulkDueNotification] [$i/${studentsWithDues.length}] Sending to ${student.name} (${student.parentPhone})');
          debugPrint('[BulkDueNotification] Due amount: ₹$dueAmount for terms: ${dueTerms.join(", ")}');
          
          // Calculate earliest due date from terms
          String earliestDueDate = DateTime.now().toIso8601String();
          final pendingTerms = ledger.termStatus.where((t) => t.balanceAmount > 0).toList();
          if (pendingTerms.isNotEmpty) {
            pendingTerms.sort((a, b) => a.dueDate.compareTo(b.dueDate));
            earliestDueDate = pendingTerms.first.dueDate.toIso8601String();
          }
          
          final params = {
            'schoolId': _schoolId,
            'phoneNumber': student.parentPhone,
            'studentName': student.name,
            'pendingAmount': dueAmount.toStringAsFixed(0),
            'dueDate': earliestDueDate,
            'dueTerms': dueTerms.join(', '),
            'schoolName': 'School',
            'className': student.className,
          };
          
          debugPrint('[BulkDueNotification] Calling function with params: $params');
          final result = await callable.call(params);
          debugPrint('[BulkDueNotification] Result: ${result.data}');

          final success = result.data['success'] as bool? ?? false;
          if (success) {
            successCount++;
            debugPrint('[BulkDueNotification] ✓ Success for ${student.name}');
            // Update last reminder sent
            await FirebaseFirestore.instance
                .collection('schools')
                .doc(_schoolId)
                .collection('studentFeeLedgers')
                .doc(ledger.id)
                .update({'lastReminderSentAt': FieldValue.serverTimestamp()});
          } else {
            failCount++;
            debugPrint('[BulkDueNotification] ✗ Failed for ${student.name}: ${result.data['error']}');
          }
        } catch (e, stackTrace) {
          failCount++;
          debugPrint('[BulkDueNotification] ✗ Exception for student: $e');
          debugPrint('[BulkDueNotification] Error type: ${e.runtimeType}');
          if (e is FirebaseFunctionsException) {
            debugPrint('[BulkDueNotification] Firebase error code: ${e.code}');
            debugPrint('[BulkDueNotification] Firebase error message: ${e.message}');
            debugPrint('[BulkDueNotification] Firebase error details: ${e.details}');
          }
          debugPrint('[BulkDueNotification] Stack trace: $stackTrace');
        }
      }
      
      debugPrint('[BulkDueNotification] ===== BULK SEND COMPLETE =====');
      debugPrint('[BulkDueNotification] Success: $successCount, Failed: $failCount');

      setState(() => _isSendingNotifications = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Bulk send complete: $successCount sent, $failCount failed'),
            backgroundColor: failCount > 0 ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _updateBulkProgress(
    BuildContext context,
    int processed,
    int total,
    int success,
    int skipped,
    int failed,
    String currentAction,
  ) {
    // Find the dialog in the widget tree and update its state
    final state = context.findAncestorStateOfType<_BulkCreateProgressDialogState>();
    state?.updateProgress(processed, total, success, skipped, failed, currentAction);
  }
}

// Progress dialog for bulk ledger creation
class _BulkCreateProgressDialog extends StatefulWidget {
  final int totalStudents;

  const _BulkCreateProgressDialog({
    required this.totalStudents,
  });

  @override
  State<_BulkCreateProgressDialog> createState() => _BulkCreateProgressDialogState();
}

class _BulkCreateProgressDialogState extends State<_BulkCreateProgressDialog> {
  int _processed = 0;
  int _success = 0;
  int _skipped = 0;
  int _failed = 0;
  String _currentAction = 'Starting...';

  void updateProgress(int processed, int total, int success, int skipped, int failed, String currentAction) {
    if (mounted) {
      setState(() {
        _processed = processed;
        _success = success;
        _skipped = skipped;
        _failed = failed;
        _currentAction = currentAction;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.totalStudents > 0 ? _processed / widget.totalStudents : 0.0;
    final percentage = (progress * 100).toStringAsFixed(0);

    return WillPopScope(
      onWillPop: () async => false, // Prevent dismissing
      child: Dialog(
        backgroundColor: _cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _accentBlue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.library_add, color: _accentBlue, size: 24),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Creating Ledgers',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Progress bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$_processed / ${widget.totalStudents}',
                        style: const TextStyle(
                          color: _textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$percentage%',
                        style: const TextStyle(
                          color: _accentBlue,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: _borderColor,
                      valueColor: const AlwaysStoppedAnimation<Color>(_accentBlue),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Current action
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _bgDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _borderColor),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(_accentBlue),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _currentAction,
                        style: const TextStyle(
                          color: _textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Status counters
              Row(
                children: [
                  Expanded(
                    child: _statusCard(
                      'Created',
                      _success.toString(),
                      _accentGreen,
                      Icons.check_circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statusCard(
                      'Skipped',
                      _skipped.toString(),
                      _accentAmber,
                      Icons.info,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statusCard(
                      'Failed',
                      _failed.toString(),
                      _accentRed,
                      Icons.error,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// Ledger view dialog
class _LedgerViewDialog extends StatelessWidget {
  final Student student;
  final StudentFeeLedger ledger;
  final String schoolId;
  final String academicYear;

  const _LedgerViewDialog({
    required this.student,
    required this.ledger,
    required this.schoolId,
    required this.academicYear,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;

    // Group entries by term
    final regularEntries = ledger.termStatus.where((e) => !e.isArrear).toList();
    final arrearsEntries = ledger.termStatus.where((e) => e.isArrear).toList();

    return Dialog(
      backgroundColor: _cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: isDesktop ? 900 : width * 0.95,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: _bgDark,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                border: Border(bottom: BorderSide(color: _borderColor)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _accentBlue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance_wallet, color: _accentBlue, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.name,
                          style: const TextStyle(
                            color: _textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${student.studentId} • Class: ${student.className}-${student.section} • AY: $academicYear',
                          style: const TextStyle(color: _textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: _textSecondary),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary cards
                    Row(
                      children: [
                        Expanded(
                          child: _summaryCard(
                            'Total Assigned',
                            '₹${ledger.totalAssigned.toStringAsFixed(2)}',
                            _accentAmber,
                            Icons.assignment,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _summaryCard(
                            'Total Paid',
                            '₹${ledger.totalPaid.toStringAsFixed(2)}',
                            _accentGreen,
                            Icons.check_circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _summaryCard(
                            'Balance',
                            '₹${ledger.totalPending.toStringAsFixed(2)}',
                            _accentRed,
                            Icons.pending,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Regular terms
                    if (regularEntries.isNotEmpty) ...[
                      _sectionHeader('Fee Terms', Icons.calendar_today),
                      const SizedBox(height: 12),
                      ...regularEntries.map((entry) => _termCard(entry)),
                    ],

                    // Arrears
                    if (arrearsEntries.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _sectionHeader('Arrears', Icons.warning_amber),
                      const SizedBox(height: 12),
                      ...arrearsEntries.map((entry) => _termCard(entry)),
                    ],
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: _bgDark,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border(top: BorderSide(color: _borderColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: _accentBlue, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _termCard(TermLedgerEntry entry) {
    final isPaid = entry.status == 'PAID';
    final isPartial = entry.paidAmount > 0 && entry.paidAmount < entry.amount;
    
    Color statusColor = _accentRed;
    String statusText = 'Pending';
    IconData statusIcon = Icons.pending;
    
    if (isPaid) {
      statusColor = _accentGreen;
      statusText = 'Paid';
      statusIcon = Icons.check_circle;
    } else if (isPartial) {
      statusColor = _accentAmber;
      statusText = 'Partial';
      statusIcon = Icons.info;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.termName,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _detailRow('Amount', '₹${entry.amount.toStringAsFixed(2)}'),
              ),
              Expanded(
                child: _detailRow('Paid', '₹${entry.paidAmount.toStringAsFixed(2)}'),
              ),
              Expanded(
                child: _detailRow('Balance', '₹${entry.balanceAmount.toStringAsFixed(2)}'),
              ),
            ],
          ),
          if (entry.lateFeeApplied > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.warning_amber, color: _accentAmber, size: 14),
                const SizedBox(width: 4),
                Text(
                  'Late Fee: ₹${entry.lateFeeApplied.toStringAsFixed(2)}',
                  style: const TextStyle(color: _accentAmber, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _textSecondary,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
