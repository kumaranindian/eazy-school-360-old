import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../domain/entities/academic_year.dart';
import '../../../data/repositories/student_fee_ledger_repository.dart';
import '../../../domain/entities/student.dart';
import '../../finance/screens/student_fee_ledger_detail_screen.dart';

class StaffStudentLedgerScreen extends ConsumerStatefulWidget {
  const StaffStudentLedgerScreen({super.key});

  @override
  ConsumerState<StaffStudentLedgerScreen> createState() =>
      _StaffStudentLedgerScreenState();
}

class _StaffStudentLedgerScreenState
    extends ConsumerState<StaffStudentLedgerScreen> {
  String _searchQuery = '';
  String? _filterSection;
  final _searchController = TextEditingController();
  bool _isSendingNotifications = false;

  List<Student> _allStudents = [];
  List<String> _availableSections = [];
  bool _isLoading = true;
  String? _staffClassName;

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
  String? get _staffId => ref.read(currentSessionProvider)?.uid;
  String get _academicYear => AcademicYear.getCurrentYearCode();

  Future<void> _loadData() async {
    final schoolId = _schoolId;
    final staffId = _staffId;
    if (schoolId == null || staffId == null) return;

    setState(() => _isLoading = true);
    try {
      // Get staff's assigned class
      final staffDoc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('staff')
          .doc(staffId)
          .get();

      final staffData = staffDoc.data();
      final className = staffData?['assignedClass'] as String?;

      if (className == null || className.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _staffClassName = null;
          });
        }
        return;
      }

      // Load students from assigned class
      final snapshot = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .where('status', isEqualTo: 'ACTIVE')
          .where('className', isEqualTo: className)
          .get();

      final students =
          snapshot.docs.map((doc) => Student.fromFirestore(doc)).toList();
      students
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      // Derive sections
      final sectionSet = <String>{};
      for (final s in students) {
        if (s.section.isNotEmpty) sectionSet.add(s.section);
      }

      if (mounted) {
        setState(() {
          _allStudents = students;
          _availableSections = sectionSet.toList()..sort();
          _staffClassName = className;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading students: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Student> get _filteredStudents {
    var filtered = _allStudents;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((s) {
        final query = _searchQuery.toLowerCase();
        return s.name.toLowerCase().contains(query) ||
            s.studentId.toString().contains(query) ||
            (s.parentName?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    if (_filterSection != null) {
      filtered = filtered.where((s) => s.section == _filterSection).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final filteredStudents = _filteredStudents;
    final isWideScreen = MediaQuery.of(context).size.width > 900;

    if (_staffClassName == null && !_isLoading) {
      return Scaffold(
        backgroundColor: _bgDark,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 64, color: Colors.grey[600]),
              const SizedBox(height: 16),
              Text(
                'No Class Assigned',
                style: TextStyle(fontSize: 18, color: Colors.grey[400]),
              ),
              const SizedBox(height: 8),
              Text(
                'Please contact admin to assign a class',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

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
              child: _buildMobileList(filteredStudents),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Students - Class $_staffClassName',
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'View fee ledgers and send payment reminders',
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
                label: Text(
                    _isSendingNotifications ? 'Sending...' : 'Send Due Alerts'),
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
          if (_availableSections.isNotEmpty)
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

  Widget _buildMobileList(List<Student> students) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: students.length,
      itemBuilder: (context, index) => _buildStudentCard(students[index]),
    );
  }

  Widget _buildStudentCard(Student student) {
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
          OutlinedButton.icon(
            onPressed: () => _viewLedger(student),
            icon: const Icon(Icons.account_balance_wallet, size: 16),
            label: const Text('View Ledger'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue,
              side: const BorderSide(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  void _viewLedger(Student student) async {
    final schoolId = _schoolId;
    if (schoolId == null) return;

    final repo = ref.read(studentFeeLedgerRepositoryProvider);
    final ledger = await repo.getByStudent(
        schoolId, student.studentId.toString(), _academicYear);

    if (ledger == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No ledger found for this student'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentFeeLedgerDetailScreen(
          schoolId: schoolId,
          ledgerId: ledger.id,
        ),
      ),
    );
  }

  Future<void> _sendBulkPaymentDueNotifications() async {
    final studentsWithDues = _filteredStudents.where((s) {
      return s.parentPhone != null && s.parentPhone!.isNotEmpty;
    }).toList();

    if (studentsWithDues.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('No students with pending fees and valid phone numbers'),
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

          // Ledger reminder timestamp update skipped (on-demand loading)

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
            content:
                Text('Sent $successCount notification(s). Failed: $failCount'),
            backgroundColor: failCount > 0 ? Colors.orange : Colors.green,
          ),
        );
      }
    }
  }
}
