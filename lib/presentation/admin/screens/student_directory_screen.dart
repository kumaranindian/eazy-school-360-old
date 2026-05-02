import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../data/repositories/concession_category_repository.dart';
import '../../../data/repositories/fee_repository.dart';
import '../../../data/repositories/student_fee_ledger_repository.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../domain/entities/academic_year.dart';
import '../../../domain/entities/app_user.dart';
import '../../../domain/entities/concession_category.dart';
import '../../../domain/entities/student.dart';
import '../../../firebase_options.dart';

class StudentDirectoryScreen extends ConsumerStatefulWidget {
  const StudentDirectoryScreen({super.key});

  @override
  ConsumerState<StudentDirectoryScreen> createState() =>
      _StudentDirectoryScreenState();
}

class _StudentDirectoryScreenState
    extends ConsumerState<StudentDirectoryScreen> {
  String _searchQuery = '';
  String? _filterClass;
  String? _filterSection;
  String? _filterLoginStatus;
  String? _filterAcademicYear;
  final _searchController = TextEditingController();
  bool _isBulkCreating = false;

  // All students loaded from Firestore (including inactive)
  List<Student> _allStudents = [];
  List<String> _availableClasses = [];
  List<String> _availableSections = [];
  bool _isLoading = true;
  // Track which student IDs are toggling
  final Set<String> _togglingStudentIds = {};

  // Cache for fee summaries to avoid repeated queries
  final Map<String, Map<String, dynamic>?> _feeSummaryCache = {};

  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAllStudents());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String? get _schoolId => ref.read(currentSessionProvider)?.schoolId;
  Future<void> _loadAllStudents() async {
    final schoolId = _schoolId;
    if (schoolId == null) {
      debugPrint('[StudentDirectory] No schoolId available');
      return;
    }
    setState(() => _isLoading = true);
    try {
      debugPrint('[StudentDirectory] Loading students for school: $schoolId');
      final snapshot = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .get();

      debugPrint(
          '[StudentDirectory] Found ${snapshot.docs.length} student docs');

      final students =
          snapshot.docs.map((doc) => Student.fromFirestore(doc)).toList();
      // Sort locally by name
      students
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      // Derive unique classes
      final classSet = <String>{};
      for (final s in students) {
        if (s.className.isNotEmpty) classSet.add(s.className);
      }
      final sorted = classSet.toList();
      // Sort with Pre-KG/LKG/UKG first, then roman numerals
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
      }
    } catch (e) {
      debugPrint('Error loading students: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateSections() {
    if (_filterClass == null) {
      setState(() {
        _availableSections = [];
        _filterSection = null;
      });
      return;
    }
    final sectionSet = <String>{};
    for (final s in _allStudents) {
      if (s.className == _filterClass && s.section.isNotEmpty) {
        sectionSet.add(s.section);
      }
    }
    final sorted = sectionSet.toList()..sort();
    setState(() {
      _availableSections = sorted;
      if (_filterSection != null && !sorted.contains(_filterSection))
        _filterSection = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;
    final isTablet = screenWidth > 600 && screenWidth <= 1024;

    if (session == null || session.schoolId == null) {
      return const Center(
          child: Text('Access Denied', style: TextStyle(color: _textPrimary)));
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _accentBlue));
    }

    final filteredStudents = _filterStudents(_allStudents);

    return Column(
      children: [
        _buildHeader(context, isDesktop, session.schoolId!),
        Expanded(
          child: _allStudents.isEmpty
              ? _buildEmptyState()
              : filteredStudents.isEmpty
                  ? _buildNoResultsState()
                  : _buildContent(context, _allStudents, filteredStudents,
                      isDesktop, isTablet, session.schoolId!, session.uid),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, bool isDesktop, String schoolId) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          isDesktop ? 24 : 16, isDesktop ? 20 : 16, isDesktop ? 24 : 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search + Filters row
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: isDesktop ? 350 : double.infinity,
                height: 44,
                child: Container(
                  decoration: BoxDecoration(
                      color: _cardDark,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _borderColor)),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: _textPrimary, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Search by name, ID, phone, email...',
                      hintStyle: TextStyle(color: _textSecondary, fontSize: 14),
                      prefixIcon:
                          Icon(Icons.search, color: _textSecondary, size: 20),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (value) =>
                        setState(() => _searchQuery = value.toLowerCase()),
                  ),
                ),
              ),
              // Class filter (cascading)
              _buildFilterChip('Class', _filterClass, _availableClasses, (v) {
                setState(() => _filterClass = v);
                _updateSections();
              }),
              // Section filter (depends on class)
              if (_filterClass != null && _availableSections.isNotEmpty)
                _buildFilterChip('Section', _filterSection, _availableSections,
                    (v) {
                  setState(() => _filterSection = v);
                }),
              // Login status filter
              _buildFilterChip(
                  'Login Status',
                  _filterLoginStatus,
                  ['with_login', 'without_login'],
                  (v) => setState(() => _filterLoginStatus = v),
                  labelMap: {
                    'with_login': 'Has Login',
                    'without_login': 'No Login'
                  }),
              // Clear all filters
              if (_filterClass != null ||
                  _filterSection != null ||
                  _filterLoginStatus != null ||
                  _searchQuery.isNotEmpty)
                ActionChip(
                  label: const Text('Clear Filters',
                      style: TextStyle(color: Colors.red, fontSize: 12)),
                  backgroundColor: Colors.red.withValues(alpha: 0.1),
                  side: const BorderSide(color: Colors.red, width: 0.5),
                  onPressed: () {
                    setState(() {
                      _filterClass = null;
                      _filterSection = null;
                      _filterLoginStatus = null;
                      _searchQuery = '';
                      _searchController.clear();
                      _availableSections = [];
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Action bar
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _showAddStudentDialog(context, schoolId),
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text('Add Student'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _accentBlue,
                    foregroundColor: Colors.white),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _isBulkCreating
                    ? null
                    : () => _bulkCreateLogins(context, schoolId),
                icon: _isBulkCreating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _accentBlue))
                    : const Icon(Icons.group_add_rounded, size: 18),
                label: Text(_isBulkCreating
                    ? 'Creating...'
                    : 'Create All Parent Logins'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: _accentBlue,
                    side: const BorderSide(color: _accentBlue)),
              ),
              const Spacer(),
              // Refresh
              IconButton(
                onPressed: _isLoading ? null : _loadAllStudents,
                icon: const Icon(Icons.refresh_rounded, color: _textSecondary),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? currentValue,
      List<String> options, void Function(String?) onChanged,
      {Map<String, String>? labelMap}) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          color: _cardDark,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _borderColor)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: currentValue,
          hint: Text('All $label',
              style: const TextStyle(color: _textSecondary, fontSize: 14)),
          dropdownColor: _cardDark,
          icon: const Icon(Icons.keyboard_arrow_down, color: _textSecondary),
          items: [
            DropdownMenuItem(
                value: null,
                child: Text('All $label',
                    style: const TextStyle(color: _textPrimary))),
            ...options.map((o) => DropdownMenuItem(
                value: o,
                child: Text(labelMap?[o] ?? (label == 'Class' ? 'Class $o' : o),
                    style: const TextStyle(color: _textPrimary)))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  List<Student> _filterStudents(List<Student> students) {
    return students.where((student) {
      final matchesSearch = _searchQuery.isEmpty ||
          student.name.toLowerCase().contains(_searchQuery) ||
          student.studentId.toString().contains(_searchQuery) ||
          (student.phoneNumber?.toLowerCase().contains(_searchQuery) ??
              false) ||
          (student.parentEmail?.toLowerCase().contains(_searchQuery) ??
              false) ||
          (student.parentName?.toLowerCase().contains(_searchQuery) ?? false) ||
          (student.parentPhone?.toLowerCase().contains(_searchQuery) ?? false);
      final matchesClass =
          _filterClass == null || student.className == _filterClass;
      final matchesSection =
          _filterSection == null || student.section == _filterSection;
      final matchesLogin = _filterLoginStatus == null ||
          (_filterLoginStatus == 'with_login' &&
              student.parentUserId != null &&
              student.parentUserId!.isNotEmpty) ||
          (_filterLoginStatus == 'without_login' &&
              (student.parentUserId == null || student.parentUserId!.isEmpty));
      return matchesSearch && matchesClass && matchesSection && matchesLogin;
    }).toList();
  }

  Widget _buildContent(
      BuildContext context,
      List<Student> allStudents,
      List<Student> filteredStudents,
      bool isDesktop,
      bool isTablet,
      String schoolId,
      String adminUid) {
    if (allStudents.isEmpty) return _buildEmptyState();
    if (filteredStudents.isEmpty) return _buildNoResultsState();

    final withLogin = allStudents
        .where((s) => s.parentUserId != null && s.parentUserId!.isNotEmpty)
        .length;
    final withoutLogin = allStudents.length - withLogin;

    return Column(
      children: [
        // Summary bar
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16),
          child: Row(
            children: [
              Text(
                  '${filteredStudents.length} student${filteredStudents.length != 1 ? 's' : ''}',
                  style: const TextStyle(color: _textSecondary, fontSize: 13)),
              const SizedBox(width: 16),
              _buildBadge('$withLogin with login', Colors.green),
              const SizedBox(width: 8),
              _buildBadge('$withoutLogin without login', Colors.orange),
              const Spacer(),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: isDesktop
              ? _buildDesktopTable(filteredStudents, schoolId, adminUid)
              : _buildMobileList(
                  filteredStudents, schoolId, adminUid, isTablet),
        ),
      ],
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildDesktopTable(
      List<Student> students, String schoolId, String adminUid) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
            color: _cardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor)),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: _borderColor))),
              child: const Row(
                children: [
                  SizedBox(
                      width: 50,
                      child: Text('ID',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _textSecondary,
                              fontSize: 11))),
                  Expanded(
                      flex: 2,
                      child: Text('STUDENT',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _textSecondary,
                              fontSize: 11))),
                  SizedBox(
                      width: 70,
                      child: Text('CLASS',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _textSecondary,
                              fontSize: 11))),
                  Expanded(
                      flex: 2,
                      child: Text('PARENT INFO',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _textSecondary,
                              fontSize: 11))),
                  SizedBox(
                      width: 130,
                      child: Text('PARENT LOGIN',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _textSecondary,
                              fontSize: 11))),
                  SizedBox(
                      width: 60,
                      child: Text('EDIT',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _textSecondary,
                              fontSize: 11))),
                ],
              ),
            ),
            ...students.map((s) => _buildTableRow(s, schoolId, adminUid)),
          ],
        ),
      ),
    );
  }

  Widget _buildTableRow(Student student, String schoolId, String adminUid) {
    final hasLogin =
        student.parentUserId != null && student.parentUserId!.isNotEmpty;
    final hasParentEmail =
        student.parentEmail != null && student.parentEmail!.isNotEmpty;
    final hasParentPhone =
        student.parentPhone != null && student.parentPhone!.isNotEmpty;
    final isToggling = _togglingStudentIds.contains(student.id);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                      if (student.phoneNumber != null)
                        Text(student.phoneNumber!,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (student.parentName != null)
                  Text(student.parentName!,
                      style:
                          const TextStyle(color: _textPrimary, fontSize: 12)),
                if (hasParentEmail)
                  Text(student.parentEmail!,
                      style:
                          const TextStyle(color: _textSecondary, fontSize: 11)),
                if (hasParentPhone)
                  Text(student.parentPhone!,
                      style:
                          const TextStyle(color: _textSecondary, fontSize: 11)),
                if (!hasParentEmail && !hasParentPhone)
                  const Text('No contact info',
                      style: TextStyle(color: Colors.orange, fontSize: 11)),
              ],
            ),
          ),
          // Toggle switch for parent login
          SizedBox(
            width: 130,
            child: isToggling
                ? const Center(
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _accentBlue)))
                : Row(
                    children: [
                      SizedBox(
                        height: 28,
                        child: Switch(
                          value: hasLogin,
                          activeColor: _accentBlue,
                          inactiveThumbColor: _textSecondary,
                          inactiveTrackColor: _borderColor,
                          onChanged: (value) => _toggleParentLogin(
                              context, student, schoolId, adminUid, value),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hasLogin ? 'Active' : 'Off',
                        style: TextStyle(
                            color: hasLogin ? _accentBlue : _textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
          ),
          // Edit button
          SizedBox(
            width: 60,
            child: IconButton(
              icon: const Icon(Icons.edit_outlined,
                  size: 18, color: _textSecondary),
              onPressed: () =>
                  _showEditStudentDialog(context, student, schoolId),
              tooltip: 'Edit',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileList(
      List<Student> students, String schoolId, String adminUid, bool isTablet) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: students.length,
      itemBuilder: (context, index) =>
          _buildStudentCard(students[index], schoolId, adminUid),
    );
  }

  Widget _buildStudentCard(Student student, String schoolId, String adminUid) {
    final hasLogin =
        student.parentUserId != null && student.parentUserId!.isNotEmpty;
    final hasParentEmail =
        student.parentEmail != null && student.parentEmail!.isNotEmpty;
    final hasParentPhone =
        student.parentPhone != null && student.parentPhone!.isNotEmpty;
    final isToggling = _togglingStudentIds.contains(student.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: _cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: _accentBlue.withValues(alpha: 0.2),
                radius: 22,
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
                            fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                        'ID: ${student.studentId} • Class ${student.className}-${student.section}',
                        style: const TextStyle(
                            color: _textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              // Toggle for parent login
              if (isToggling)
                const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _accentBlue))
              else
                Switch(
                  value: hasLogin,
                  activeColor: _accentBlue,
                  inactiveThumbColor: _textSecondary,
                  inactiveTrackColor: _borderColor,
                  onChanged: (value) => _toggleParentLogin(
                      context, student, schoolId, adminUid, value),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Fee info
          FutureBuilder<Map<String, dynamic>?>(
            future:
                _loadStudentFeeSummary(student.studentId.toString(), schoolId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox.shrink();
              }
              final feeData = snapshot.data;
              if (feeData == null) {
                // Show "No fee data" message instead of hiding
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3))),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('No fee data available',
                            style: TextStyle(
                                color: Colors.orange,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                );
              }
              final totalBalance =
                  (feeData['stuBalTotalFees'] as num?)?.toDouble() ?? 0;
              final hasPending = totalBalance > 0;

              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: hasPending
                        ? Colors.red.withValues(alpha: 0.1)
                        : Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: hasPending
                            ? Colors.red.withValues(alpha: 0.3)
                            : Colors.green.withValues(alpha: 0.3))),
                child: Row(
                  children: [
                    Icon(
                        hasPending
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline,
                        color: hasPending ? Colors.red : Colors.green,
                        size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(hasPending ? 'Pending Fees' : 'Fees Cleared',
                              style: TextStyle(
                                  color: hasPending ? Colors.red : Colors.green,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('Balance: ₹${totalBalance.toStringAsFixed(0)}',
                              style: TextStyle(
                                  color: _textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          // Parent info
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: _bgDark, borderRadius: BorderRadius.circular(8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                        child: Text('Parent Info',
                            style: TextStyle(
                                color: _textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600))),
                    Text(hasLogin ? 'Login Active' : 'Login Off',
                        style: TextStyle(
                            color: hasLogin ? _accentBlue : Colors.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                if (student.parentName != null)
                  Text(student.parentName!,
                      style:
                          const TextStyle(color: _textPrimary, fontSize: 12)),
                if (hasParentEmail)
                  Text('Email: ${student.parentEmail}',
                      style:
                          const TextStyle(color: _textSecondary, fontSize: 11)),
                if (hasParentPhone)
                  Text('Phone: ${student.parentPhone}',
                      style:
                          const TextStyle(color: _textSecondary, fontSize: 11)),
                if (!hasParentEmail && !hasParentPhone)
                  const Text('No contact info - tap Edit to add',
                      style: TextStyle(color: Colors.orange, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Action buttons row
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _showEditStudentDialog(context, student, schoolId),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit Student'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _textSecondary,
                    side: const BorderSide(color: _borderColor),
                    minimumSize: const Size(double.infinity, 38),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _viewStudentBills(context, student, schoolId),
                  icon: const Icon(Icons.receipt_long_outlined, size: 16),
                  label: const Text('View Bills'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green),
                    minimumSize: const Size(double.infinity, 38),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _viewStudentFeeDetails(context, student, schoolId),
                  icon: const Icon(Icons.account_balance_wallet_outlined,
                      size: 16),
                  label: const Text('Fee Details'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                    minimumSize: const Size(double.infinity, 38),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Dialogs ──────────────────────────────────────────────────────

  void _showAddStudentDialog(BuildContext context, String schoolId) {
    _showStudentFormDialog(context, schoolId, null);
  }

  void _showEditStudentDialog(
      BuildContext context, Student student, String schoolId) {
    _showStudentFormDialog(context, schoolId, student);
  }

  void _showStudentFormDialog(
      BuildContext context, String schoolId, Student? existingStudent) {
    final isEditing = existingStudent != null;
    final nameController =
        TextEditingController(text: existingStudent?.name ?? '');
    final phoneController =
        TextEditingController(text: existingStudent?.phoneNumber ?? '');
    final parentNameController =
        TextEditingController(text: existingStudent?.parentName ?? '');
    final parentPhoneController =
        TextEditingController(text: existingStudent?.parentPhone ?? '');
    final parentEmailController =
        TextEditingController(text: existingStudent?.parentEmail ?? '');
    final concessionCtrl = TextEditingController(text: '0');
    final concessionReasonCtrl = TextEditingController();
    final arrearTuitionCtrl = TextEditingController(text: '0');
    final arrearExamCtrl = TextEditingController(text: '0');
    final arrearVanCtrl = TextEditingController(text: '0');
    String selectedClass = existingStudent?.className ?? 'I';
    String selectedSection = existingStudent?.section ?? 'A';
    String vanAvailed = existingStudent?.isVanAvailed == true ? 'Yes' : 'No';
    bool feeLoading = isEditing;
    Map<String, dynamic>? feeData;
    String? feeDocId;
    // Fee structure loading
    Map<String, dynamic>? feeStructure;
    bool feeStructureLoading = false;
    late TextEditingController vanFeeCtrl;
    vanFeeCtrl = TextEditingController(text: '0'); // Initialize immediately

    // Concession category
    List<ConcessionCategory> concessionCategories = [];
    String? selectedConcessionCategory;
    bool concessionCategoriesLoading = false;

    // Academic year selection
    String selectedAcademicYear =
        existingStudent?.academicYearCode ?? AcademicYear.getCurrentYearCode();

    // Helper function to get academic year options
    List<String> _academicYearOptions() {
      final current = DateTime.now();
      final base = current.month >= 5 ? current.year : current.year - 1;
      return List.generate(7, (i) {
        final year = base + i - 3; // 3 years before to 3 years after
        return '$year-${(year + 1) % 100}';
      });
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Helper function to load fee structure (V2 only)
          Future<void> _loadFeeStructure(String className, String schoolId,
              StateSetter setDialogState) async {
            if (className.isEmpty) {
              setDialogState(() {
                feeStructure = null;
                feeStructureLoading = false;
              });
              return;
            }

            setDialogState(() => feeStructureLoading = true);
            try {
              print(
                  '🔍 Loading V2 fee structure for class: $className, schoolId: $schoolId');

              final ay = selectedAcademicYear;
              final snap = await FirebaseFirestore.instance
                  .collection('schools')
                  .doc(schoolId)
                  .collection('fee_structures_v2')
                  .where('isActive', isEqualTo: true)
                  .where('applicableClassIds', arrayContains: className)
                  .where('academicYear', isEqualTo: ay)
                  .limit(1)
                  .get();

              print('📊 Found ${snap.docs.length} V2 fee structure documents');

              if (snap.docs.isNotEmpty) {
                final data = snap.docs.first.data();
                print('✅ V2 Fee structure found');

                // Calculate total tuition from V2 terms
                final terms = data['terms'] as List? ?? [];
                double totalTuition = 0;
                for (final term in terms) {
                  if (term is Map) {
                    final termMap = Map<String, dynamic>.from(term);
                    final amount =
                        (termMap['totalAmount'] as num?)?.toDouble() ?? 0;
                    totalTuition += amount;
                  }
                }

                setDialogState(() {
                  feeStructure = {
                    'tuitionFee': totalTuition,
                    'examFee': 0,
                    'vanFee': 0,
                    'totalFee': totalTuition,
                    'isV2': true,
                    'structureName': data['name'] ?? 'V2 Structure',
                  };
                  vanFeeCtrl.text = '0';
                  feeStructureLoading = false;
                });
              } else {
                print(
                    '❌ No V2 fee structure found for class: $className, AY: $ay');
                setDialogState(() {
                  feeStructure = null;
                  vanFeeCtrl.text = '0';
                  feeStructureLoading = false;
                });
              }
            } catch (e) {
              print('🚨 Error loading fee structure: $e');
              setDialogState(() {
                feeStructure = null;
                vanFeeCtrl.text = '0';
                feeStructureLoading = false;
              });
            }
          }

          // Helper function to display fee info row
          Widget _feeInfoRow(String label, dynamic value) {
            final amt = (value as num?)?.toDouble() ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label,
                      style:
                          const TextStyle(color: _textSecondary, fontSize: 12)),
                  Text('₹${amt.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: amt > 0 ? _textPrimary : _textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      )),
                ],
              ),
            );
          }

          return AlertDialog(
            backgroundColor: _cardDark,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(isEditing ? 'Edit Student' : 'Add New Student',
                style: const TextStyle(
                    color: _textPrimary, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _formField(
                        'Student Name *', nameController, Icons.person_outline),
                    const SizedBox(height: 12),
                    // Academic Year Selection
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_today_outlined,
                                  color: Colors.blue, size: 16),
                              const SizedBox(width: 6),
                              const Text('Academic Year',
                                  style: TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _academicYearOptions().map((yr) {
                              final isSelected = selectedAcademicYear == yr;
                              final isCurrent =
                                  yr == AcademicYear.getCurrentYearCode();
                              return ChoiceChip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(yr,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: isSelected
                                                ? Colors.white
                                                : _textPrimary)),
                                    if (isCurrent) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.blue,
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        child: Text('Current',
                                            style: TextStyle(
                                                fontSize: 8,
                                                color: isSelected
                                                    ? Colors.blue
                                                    : Colors.white)),
                                      ),
                                    ],
                                  ],
                                ),
                                selected: isSelected,
                                onSelected: isEditing
                                    ? null
                                    : (_) => setDialogState(
                                        () => selectedAcademicYear = yr),
                                backgroundColor: _bgDark,
                                selectedColor: Colors.blue,
                                side: BorderSide(
                                    color: isSelected
                                        ? Colors.blue
                                        : _borderColor),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: _formDropdown('Class *', selectedClass, [
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
                        ], (v) {
                          setDialogState(() {
                            selectedClass = v!;
                            feeStructure = null;
                            feeStructureLoading = true;
                          });
                          if (v!.isNotEmpty) {
                            _loadFeeStructure(v, schoolId, setDialogState);
                          }
                        })),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _formDropdown(
                                'Section *',
                                selectedSection,
                                ['A', 'B', 'C', 'D'],
                                (v) => setDialogState(
                                    () => selectedSection = v!))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _formField(
                        'Student Phone', phoneController, Icons.phone_outlined),
                    const Divider(height: 28, color: _borderColor),
                    const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Parent / Guardian Details',
                            style: TextStyle(
                                color: _accentBlue,
                                fontWeight: FontWeight.w600,
                                fontSize: 13))),
                    const SizedBox(height: 12),
                    _formField('Parent Name', parentNameController,
                        Icons.family_restroom_outlined),
                    const SizedBox(height: 12),
                    _formField('Parent Mobile *', parentPhoneController,
                        Icons.phone_android_outlined),
                    const SizedBox(height: 12),
                    _formField('Parent Email *', parentEmailController,
                        Icons.email_outlined),
                    const SizedBox(height: 8),

                    // Transport Option
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.directions_bus_outlined,
                                  color: Colors.purple, size: 16),
                              const SizedBox(width: 6),
                              const Text('Transport Facility',
                                  style: TextStyle(
                                      color: Colors.purple,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _formDropdown('Transport Required',
                                    vanAvailed, ['No', 'Yes'], (value) {
                                  setDialogState(() {
                                    vanAvailed = value!;
                                  });
                                }),
                              ),
                            ],
                          ),
                          if (vanAvailed == 'Yes') ...[
                            const SizedBox(height: 8),
                            _formField('Van Fee Amount', vanFeeCtrl,
                                Icons.directions_bus_outlined,
                                onChanged: (value) {
                              print('🚌 Van fee changed to: $value');
                              setDialogState(() {});
                            }),
                            if (feeStructure != null) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    color:
                                        Colors.purple.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: Colors.purple
                                            .withValues(alpha: 0.2))),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline,
                                        color: Colors.purple, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Default van fee: ₹${((feeStructure!['vanFee'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}. You can modify as needed.',
                                        style: TextStyle(
                                            color: Colors.purple, fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Fee Structure Display
                    if (selectedClass.isNotEmpty) ...[
                      const Divider(height: 28, color: _borderColor),
                      const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Fee Structure',
                              style: TextStyle(
                                  color: _accentBlue,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13))),
                      const SizedBox(height: 12),
                      if (feeStructureLoading)
                        const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                                child: CircularProgressIndicator(
                                    color: _accentBlue, strokeWidth: 2)))
                      else if (feeStructure != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: _bgDark,
                              borderRadius: BorderRadius.circular(8)),
                          child: Column(
                            children: [
                              if (feeStructure!['isV2'] == true) ...[
                                _feeInfoRow(
                                    'Structure',
                                    feeStructure!['structureName'] ??
                                        'V2 Structure'),
                                _feeInfoRow('Tuition Fee (V2)',
                                    feeStructure!['tuitionFee']),
                                _feeInfoRow(
                                    'Exam Fee', feeStructure!['examFee']),
                                _feeInfoRow(
                                    'Total Fee', feeStructure!['totalFee']),
                              ] else ...[
                                _feeInfoRow(
                                    'Tuition Fee', feeStructure!['tuitionFee']),
                                _feeInfoRow(
                                    'Exam Fee', feeStructure!['examFee']),
                                if (feeStructure!['vanFee'] != null)
                                  _feeInfoRow(
                                      'Van Fee', feeStructure!['vanFee']),
                                _feeInfoRow(
                                    'Total Fee',
                                    ((feeStructure!['tuitionFee'] as num?)
                                                ?.toDouble() ??
                                            0) +
                                        ((feeStructure!['examFee'] as num?)
                                                ?.toDouble() ??
                                            0) +
                                        ((feeStructure!['vanFee'] as num?)
                                                ?.toDouble() ??
                                            0)),
                              ],
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8)),
                          child: const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: Colors.red, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                  child: Text(
                                      'No fee structure found for this class',
                                      style: TextStyle(
                                          color: Colors.red, fontSize: 12))),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),

                      // Concession and Arrears Section
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Fee Adjustments',
                                style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                            const SizedBox(height: 12),

                            // Concession Category Section
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Concession Category',
                                    style: TextStyle(
                                        color: _textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500)),
                                // Load button
                                TextButton.icon(
                                  onPressed: concessionCategoriesLoading
                                      ? null
                                      : () async {
                                          setDialogState(() =>
                                              concessionCategoriesLoading =
                                                  true);
                                          try {
                                            final repo = ref.read(
                                                concessionCategoryRepositoryProvider);
                                            final cats =
                                                await repo.getAll(schoolId);
                                            setDialogState(() {
                                              concessionCategories = cats;
                                              concessionCategoriesLoading =
                                                  false;
                                            });
                                          } catch (e) {
                                            setDialogState(() =>
                                                concessionCategoriesLoading =
                                                    false);
                                            ScaffoldMessenger.of(ctx)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      'Error loading categories: $e'),
                                                  backgroundColor: Colors.red),
                                            );
                                          }
                                        },
                                  icon: concessionCategoriesLoading
                                      ? const SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.orange))
                                      : const Icon(Icons.refresh, size: 14),
                                  label: const Text('Load',
                                      style: TextStyle(fontSize: 11)),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.orange,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                // Add new button
                                TextButton.icon(
                                  onPressed: () =>
                                      _showAddConcessionCategoryDialog(
                                          ctx, schoolId, setDialogState,
                                          (newCat) {
                                    setDialogState(() {
                                      concessionCategories.add(newCat);
                                      selectedConcessionCategory = newCat.code;
                                    });
                                  }),
                                  icon: const Icon(Icons.add, size: 14),
                                  label: const Text('Add New',
                                      style: TextStyle(fontSize: 11)),
                                  style: TextButton.styleFrom(
                                    foregroundColor: _accentBlue,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Concession Category Dropdown
                            if (concessionCategories.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _bgDark,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _borderColor),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline,
                                        color: _textSecondary, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Click "Load" to load concession categories or "Add New" to create one',
                                        style: TextStyle(
                                            color: _textSecondary,
                                            fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              DropdownButtonFormField<String>(
                                value: selectedConcessionCategory,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: _bgDark,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        const BorderSide(color: _borderColor),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        const BorderSide(color: _borderColor),
                                  ),
                                ),
                                dropdownColor: _cardDark,
                                style: const TextStyle(
                                    color: _textPrimary, fontSize: 13),
                                hint: const Text('Select category',
                                    style: TextStyle(
                                        color: _textSecondary, fontSize: 13)),
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text('None',
                                        style:
                                            TextStyle(color: _textSecondary)),
                                  ),
                                  ...concessionCategories.map((cat) =>
                                      DropdownMenuItem(
                                        value: cat.code,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (cat.isDefault)
                                              Container(
                                                margin: const EdgeInsets.only(
                                                    right: 6),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 4,
                                                        vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange
                                                      .withValues(alpha: 0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(3),
                                                ),
                                                child: const Text('DEFAULT',
                                                    style: TextStyle(
                                                        fontSize: 8,
                                                        color: Colors.orange,
                                                        fontWeight:
                                                            FontWeight.bold)),
                                              ),
                                            Flexible(
                                                child: Text(cat.name,
                                                    overflow:
                                                        TextOverflow.ellipsis)),
                                          ],
                                        ),
                                      )),
                                ],
                                onChanged: (v) {
                                  setDialogState(() {
                                    selectedConcessionCategory = v;
                                    // Auto-fill reason based on category
                                    if (v != null) {
                                      final cat = concessionCategories
                                          .firstWhere((c) => c.code == v,
                                              orElse: () => ConcessionCategory(
                                                  id: '', code: '', name: ''));
                                      concessionReasonCtrl.text = cat.name;
                                    } else {
                                      concessionReasonCtrl.text = '';
                                    }
                                  });
                                },
                              ),

                            const SizedBox(height: 8),

                            // Concession Amount and Reason
                            Row(
                              children: [
                                Expanded(
                                    child: _formField('Concession Amount',
                                        concessionCtrl, Icons.discount_outlined,
                                        onChanged: (value) =>
                                            setDialogState(() {}))),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: _formField(
                                        'Concession Reason',
                                        concessionReasonCtrl,
                                        Icons.note_outlined,
                                        onChanged: (value) =>
                                            setDialogState(() {}))),
                              ],
                            ),

                            const SizedBox(height: 12),
                            const Divider(color: _borderColor, height: 1),
                            const SizedBox(height: 12),

                            // Arrears Section
                            const Text('Arrears',
                                style: TextStyle(
                                    color: _textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                    child: _formField(
                                        'Arrear Tuition',
                                        arrearTuitionCtrl,
                                        Icons.money_off_outlined,
                                        onChanged: (value) =>
                                            setDialogState(() {}))),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: _formField(
                                        'Arrear Exam',
                                        arrearExamCtrl,
                                        Icons.money_off_outlined,
                                        onChanged: (value) =>
                                            setDialogState(() {}))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                    child: _formField('Arrear Van',
                                        arrearVanCtrl, Icons.money_off_outlined,
                                        onChanged: (value) =>
                                            setDialogState(() {}))),
                                const SizedBox(width: 12),
                                const Expanded(
                                    child:
                                        SizedBox()), // Placeholder for alignment
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Fee Summary with Arrears (only show if fee structure exists)
                            if (feeStructure != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                    color: _bgDark,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: _accentBlue.withValues(
                                            alpha: 0.3))),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.calculate_outlined,
                                            color: _accentBlue, size: 16),
                                        const SizedBox(width: 6),
                                        const Text(
                                            'Fee Summary (Live Calculation)',
                                            style: TextStyle(
                                                color: _accentBlue,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    _buildTransportAwareFeeSummary(
                                        feeStructure!,
                                        vanAvailed,
                                        concessionCtrl,
                                        arrearTuitionCtrl,
                                        arrearExamCtrl,
                                        arrearVanCtrl,
                                        vanFeeCtrl),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 16, color: Colors.blue),
                          SizedBox(width: 8),
                          Expanded(
                              child: Text(
                                  'Parent email is used as login ID. Default password = mobile number.',
                                  style: TextStyle(
                                      color: Colors.blue, fontSize: 11))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel',
                      style: TextStyle(color: _textSecondary))),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                        content: Text('Student name is required'),
                        backgroundColor: Colors.red));
                    return;
                  }

                  // Validate concession and arrears are valid numbers
                  final concession = concessionCtrl.text.trim();
                  final arrearTuition = arrearTuitionCtrl.text.trim();
                  final arrearExam = arrearExamCtrl.text.trim();
                  final arrearVan = arrearVanCtrl.text.trim();

                  if (concession.isNotEmpty &&
                      double.tryParse(concession) == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                        content: Text('Concession must be a valid number'),
                        backgroundColor: Colors.red));
                    return;
                  }
                  if (arrearTuition.isNotEmpty &&
                      double.tryParse(arrearTuition) == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                        content: Text('Arrear Tuition must be a valid number'),
                        backgroundColor: Colors.red));
                    return;
                  }
                  if (arrearExam.isNotEmpty &&
                      double.tryParse(arrearExam) == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                        content: Text('Arrear Exam must be a valid number'),
                        backgroundColor: Colors.red));
                    return;
                  }
                  if (arrearVan.isNotEmpty &&
                      double.tryParse(arrearVan) == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                        content: Text('Arrear Van must be a valid number'),
                        backgroundColor: Colors.red));
                    return;
                  }

                  // Validate fee structure exists when adding new student
                  if (!isEditing && feeStructure == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                        content:
                            Text('Fee structure not found for selected class'),
                        backgroundColor: Colors.red));
                    return;
                  }

                  try {
                    final repo = ref.read(studentRepositoryProvider);
                    final now = DateTime.now();
                    if (isEditing) {
                      final updated = existingStudent.copyWith(
                        name: nameController.text.trim(),
                        className: selectedClass,
                        section: selectedSection,
                        phoneNumber: phoneController.text.trim().isEmpty
                            ? null
                            : phoneController.text.trim(),
                        parentName: parentNameController.text.trim().isEmpty
                            ? null
                            : parentNameController.text.trim(),
                        parentPhone: parentPhoneController.text.trim().isEmpty
                            ? null
                            : parentPhoneController.text.trim(),
                        parentEmail: parentEmailController.text.trim().isEmpty
                            ? null
                            : parentEmailController.text.trim(),
                        updatedAt: now,
                      );
                      await repo.updateStudent(
                          schoolId, existingStudent.id, updated);
                    } else {
                      final nextId = await repo.getNextStudentId(schoolId);
                      final newStudent = Student(
                        id: '',
                        schoolId: schoolId,
                        studentId: nextId,
                        name: nameController.text.trim(),
                        className: selectedClass,
                        section: selectedSection,
                        phoneNumber: phoneController.text.trim().isEmpty
                            ? null
                            : phoneController.text.trim(),
                        parentName: parentNameController.text.trim().isEmpty
                            ? null
                            : parentNameController.text.trim(),
                        parentPhone: parentPhoneController.text.trim().isEmpty
                            ? null
                            : parentPhoneController.text.trim(),
                        parentEmail: parentEmailController.text.trim().isEmpty
                            ? null
                            : parentEmailController.text.trim(),
                        isVanAvailed: vanAvailed == 'Yes',
                        status: StudentStatus.ACTIVE,
                        academicYearCode:
                            selectedAcademicYear, // Use selected academic year
                        createdAt: now,
                        updatedAt: now,
                      );
                      await repo.createStudent(schoolId, newStudent);

                      // Create student fee details with concession and arrears
                      if (feeStructure != null) {
                        await _createStudentFeeDetails(
                            schoolId,
                            nextId.toString(),
                            feeStructure!,
                            concessionCtrl.text,
                            arrearTuitionCtrl.text,
                            arrearExamCtrl.text,
                            arrearVanCtrl.text,
                            nameController.text.trim(),
                            selectedSection,
                            selectedAcademicYear,
                            vanAvailed,
                            vanFeeCtrl.text);
                      }

                      // Also seed the V2 StudentFeeLedger from the active
                      // FeeStructureV2 for this class+AY so the new Fee
                      // Management screen renders immediately without a
                      // manual assign step. Non-fatal on any failure.
                      await _autoAssignLedgerV2(
                        schoolId: schoolId,
                        studentId: nextId.toString(),
                        studentName: nameController.text.trim(),
                        className: selectedClass,
                        section: selectedSection,
                        academicYear: selectedAcademicYear,
                        parentName: parentNameController.text.trim(),
                        parentPhone: parentPhoneController.text.trim(),
                      );
                    }
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                              isEditing ? 'Student updated' : 'Student added'),
                          backgroundColor: _accentBlue));
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red));
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: _accentBlue),
                child: Text(isEditing ? 'Update' : 'Add Student',
                    style: const TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── Toggle Parent Login (Activate / Deactivate) ─────────────────

  Future<void> _toggleParentLogin(BuildContext context, Student student,
      String schoolId, String adminUid, bool activate) async {
    if (activate) {
      await _activateParentLogin(context, student, schoolId, adminUid);
    } else {
      await _deactivateParentLogin(context, student, schoolId);
    }
  }

  Future<Map<String, dynamic>?> _loadStudentFeeSummary(
      String studentId, String schoolId) async {
    // Check cache first
    if (_feeSummaryCache.containsKey(studentId)) {
      return _feeSummaryCache[studentId];
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('student_fee_details')
          .where('stuId', isEqualTo: studentId)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();

        // Apply V2 override if applicable
        final className = data['stuClass']?.toString() ?? '';
        final ay = data['academicYear']?.toString() ?? '2024-25';

        if (className.isNotEmpty) {
          try {
            final v2Snap = await FirebaseFirestore.instance
                .collection('schools')
                .doc(schoolId)
                .collection('fee_structures_v2')
                .where('isActive', isEqualTo: true)
                .where('applicableClassIds', arrayContains: className)
                .where('academicYear', isEqualTo: ay)
                .limit(1)
                .get();

            if (v2Snap.docs.isNotEmpty) {
              final v2Data = v2Snap.docs.first.data();
              final v2Tuition = _calculateV2Tuition(v2Data);

              final exam = (data['stuTotalExamFees'] as num?)?.toDouble() ?? 0;
              final van = (data['stuTotalVanFees'] as num?)?.toDouble() ?? 0;
              final admission =
                  (data['stuTotalAdmissionFees'] as num?)?.toDouble() ?? 0;
              final concession =
                  (data['stuConcessionFees'] as num?)?.toDouble() ?? 0;
              final paidTuition =
                  (data['stuPaidTutionFees'] as num?)?.toDouble() ?? 0;
              final paidExam =
                  (data['stuPaidExamFees'] as num?)?.toDouble() ?? 0;
              final paidVan =
                  (data['studPaidVanFees'] as num?)?.toDouble() ?? 0;
              final paidAdmission =
                  (data['stuPaidAdmissionFees'] as num?)?.toDouble() ?? 0;
              final arrearTuition =
                  (data['arrearTuitionFees'] as num?)?.toDouble() ?? 0;
              final arrearExam =
                  (data['arrearExamFees'] as num?)?.toDouble() ?? 0;
              final arrearVan =
                  (data['arrearVanFees'] as num?)?.toDouble() ?? 0;
              final arrearAdmission =
                  (data['arrearAdmissionFees'] as num?)?.toDouble() ?? 0;

              final newTotal = v2Tuition + exam + van + admission;
              final newBalTuition =
                  v2Tuition + arrearTuition - concession - paidTuition;
              final newBalExam = exam + arrearExam - paidExam;
              final newBalVan = van + arrearVan - paidVan;
              final newBalAdmission =
                  admission + arrearAdmission - paidAdmission;
              final newBalTotal =
                  newBalTuition + newBalExam + newBalVan + newBalAdmission;

              data['stuTotalTutionFees'] = v2Tuition;
              data['stuTotalFees'] = newTotal;
              data['stuBalTutionFees'] = newBalTuition;
              data['stuBalExamFees'] = newBalExam;
              data['stuBalVanFees'] = newBalVan;
              data['stuBalAdmissionFees'] = newBalAdmission;
              data['stuBalTotalFees'] = newBalTotal;
            }
          } catch (e) {
            print('Error applying V2 override: $e');
          }
        }

        _feeSummaryCache[studentId] = data;
        return data;
      }
      _feeSummaryCache[studentId] = null;
      return null;
    } catch (e) {
      print('Error loading fee summary for student $studentId: $e');
      _feeSummaryCache[studentId] = null;
      return null;
    }
  }

  /// Calculate total tuition from V2 fee structure
  double _calculateV2Tuition(Map<String, dynamic> v2Data) {
    final terms = v2Data['terms'] as List? ?? [];
    double total = 0;
    for (final term in terms) {
      if (term is Map) {
        final termMap = Map<String, dynamic>.from(term);
        final amount = (termMap['totalAmount'] as num?)?.toDouble() ?? 0;
        total += amount;
      }
    }
    return total;
  }

  Future<void> _activateParentLogin(BuildContext context, Student student,
      String schoolId, String adminUid) async {
    String? loginEmail = student.parentEmail ?? student.email;
    String? loginPassword = student.parentPhone ?? student.phoneNumber;

    if (loginEmail == null || loginEmail.isEmpty) {
      final result = await _showEnterParentInfoDialog(context, student);
      if (result == null) return;
      loginEmail = result['email']!;
      loginPassword = result['phone']!;

      final repo = ref.read(studentRepositoryProvider);
      await repo.updateStudent(
          schoolId,
          student.id,
          student.copyWith(
            parentEmail: loginEmail,
            parentPhone: loginPassword,
            updatedAt: DateTime.now(),
          ));
    }

    if (loginPassword == null || loginPassword.isEmpty) {
      loginPassword = 'parent123';
    }

    if (!context.mounted) return;

    setState(() => _togglingStudentIds.add(student.id));

    try {
      // Use secondary auth to avoid logging out admin
      FirebaseApp secondaryApp;
      try {
        secondaryApp = Firebase.app('parent-helper');
      } on FirebaseException {
        secondaryApp = await Firebase.initializeApp(
          name: 'parent-helper',
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      final userCredential = await secondaryAuth.createUserWithEmailAndPassword(
        email: loginEmail,
        password: loginPassword,
      );

      final userId = userCredential.user!.uid;

      final firestore = FirebaseFirestore.instance;
      final userData = AppUser(
        uid: userId,
        email: loginEmail,
        displayName: student.parentName ?? student.name,
        role: UserRole.PARENT,
        schoolId: schoolId,
        status: UserStatus.ACTIVE,
        onboardingStatus: OnboardingStatus.ACTIVE,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: adminUid,
        profile: UserProfile(phoneNumber: loginPassword),
        permissions: UserPermissions.forRole(UserRole.PARENT),
      );

      await firestore
          .collection('users')
          .doc(userId)
          .set(userData.toFirestore());

      // Update student record with parentUserId
      final repo = ref.read(studentRepositoryProvider);
      await repo.updateStudent(
          schoolId,
          student.id,
          student.copyWith(
            parentUserId: userId,
            parentEmail: loginEmail,
            updatedAt: DateTime.now(),
          ));

      await secondaryAuth.signOut();

      // Update local state
      final idx = _allStudents.indexWhere((s) => s.id == student.id);
      if (idx != -1) {
        _allStudents[idx] = _allStudents[idx].copyWith(
          parentUserId: userId,
          parentEmail: loginEmail,
          parentPhone: loginPassword,
        );
      }

      // Queue WhatsApp notification
      final parentPhone = student.parentPhone ?? student.phoneNumber;
      if (parentPhone != null && parentPhone.isNotEmpty) {
        await _queueWhatsAppLoginNotification(
            schoolId, student.name, loginEmail, loginPassword, parentPhone);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Parent login activated for ${student.name}'),
              backgroundColor: Colors.green),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (context.mounted) {
        String msg = 'Failed to create login';
        if (e.code == 'email-already-in-use') {
          msg = 'Email $loginEmail is already registered.';
        } else if (e.code == 'weak-password') {
          msg = 'Password is too weak (min 6 characters).';
        } else if (e.code == 'invalid-email') {
          msg = 'Invalid email: $loginEmail';
        }
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }

    if (mounted) setState(() => _togglingStudentIds.remove(student.id));
  }

  Future<void> _deactivateParentLogin(
      BuildContext context, Student student, String schoolId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Deactivate Parent Login',
            style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Disable login for ${student.name}\'s parent?',
                style: const TextStyle(color: _textPrimary)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: Colors.amber),
                  SizedBox(width: 8),
                  Expanded(
                      child: Text(
                          'The parent will not be able to log in until reactivated.',
                          style: TextStyle(color: Colors.amber, fontSize: 11))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: _textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child:
                const Text('Deactivate', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    setState(() => _togglingStudentIds.add(student.id));

    try {
      final firestore = FirebaseFirestore.instance;
      final parentUserId = student.parentUserId;

      // Disable the user document in Firestore
      if (parentUserId != null && parentUserId.isNotEmpty) {
        await firestore.collection('users').doc(parentUserId).update({
          'status': 'DISABLED',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Clear parentUserId from student record
      final repo = ref.read(studentRepositoryProvider);
      await repo.updateStudent(
          schoolId,
          student.id,
          student.copyWith(
            parentUserId: '',
            updatedAt: DateTime.now(),
          ));

      // Update local state
      final idx = _allStudents.indexWhere((s) => s.id == student.id);
      if (idx != -1) {
        _allStudents[idx] = _allStudents[idx].copyWith(parentUserId: '');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Parent login deactivated for ${student.name}'),
              backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }

    if (mounted) setState(() => _togglingStudentIds.remove(student.id));
  }

  // ─── WhatsApp Login Notification ───────────────────────────────────

  Future<void> _queueWhatsAppLoginNotification(
      String schoolId,
      String studentName,
      String email,
      String password,
      String parentPhone) async {
    try {
      final formattedPhone = _formatPhoneForWhatsApp(parentPhone);
      if (formattedPhone == null) return;

      await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('whatsappQueue')
          .add({
        'to': formattedPhone,
        'studentName': studentName,
        'message':
            'Dear Parent, your Eazy School 360 login has been activated.\n\nLogin Email: $email\nPassword: $password\n\nPlease change your password after first login.\n\n- Eazy School 360',
        'createdAt': FieldValue.serverTimestamp(),
        'processed': false,
        'type': 'parent_login_activated',
      });
    } catch (e) {
      debugPrint('WhatsApp queue error: $e');
    }
  }

  String? _formatPhoneForWhatsApp(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.startsWith('+')) cleaned = cleaned.substring(1);
    if (cleaned.length == 10 && !cleaned.startsWith('0'))
      cleaned = '91$cleaned';
    if (cleaned.startsWith('0')) cleaned = '91${cleaned.substring(1)}';
    if (cleaned.length < 10) return null;
    return cleaned;
  }

  // ─── Add Concession Category Dialog ─────────────────────────────────

  void _showAddConcessionCategoryDialog(
    BuildContext context,
    String schoolId,
    StateSetter parentSetState,
    Function(ConcessionCategory) onCreated,
  ) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    bool isCreating = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: _cardDark,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Concession Category',
              style:
                  TextStyle(color: _textPrimary, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _formField(
                    'Category Name *', nameController, Icons.category_outlined),
                const SizedBox(height: 12),
                _formField('Description', descriptionController,
                    Icons.description_outlined),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This category will be available for all students in this school.',
                          style: TextStyle(color: Colors.blue, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('Cancel', style: TextStyle(color: _textSecondary)),
            ),
            ElevatedButton(
              onPressed: isCreating
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                              content: Text('Category name is required'),
                              backgroundColor: Colors.red),
                        );
                        return;
                      }

                      setDialogState(() => isCreating = true);
                      try {
                        final repo =
                            ref.read(concessionCategoryRepositoryProvider);
                        final code = name
                            .toUpperCase()
                            .replaceAll(RegExp(r'[^A-Z0-9]'), '_');
                        final newCategory = ConcessionCategory(
                          id: '',
                          code: code,
                          name: name,
                          description: descriptionController.text.trim(),
                          isDefault: false,
                          isActive: true,
                          sortOrder: 100,
                        );
                        await repo.create(schoolId, newCategory);

                        // Fetch the created category to get the ID
                        final cats = await repo.getAll(schoolId);
                        final created = cats.firstWhere((c) => c.code == code,
                            orElse: () => newCategory);

                        Navigator.pop(ctx);
                        onCreated(created);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text('Category "$name" created successfully'),
                              backgroundColor: _accentBlue),
                        );
                      } catch (e) {
                        setDialogState(() => isCreating = false);
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                              content: Text('Error creating category: $e'),
                              backgroundColor: Colors.red),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentBlue,
                foregroundColor: Colors.white,
              ),
              child: isCreating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Bulk Create Logins ───────────────────────────────────────────

  Future<void> _bulkCreateLogins(BuildContext context, String schoolId) async {
    final session = ref.read(currentSessionProvider);
    if (session == null) return;

    final eligibleStudents = _allStudents
        .where((s) =>
            (s.parentUserId == null || s.parentUserId!.isEmpty) &&
            (s.parentEmail != null && s.parentEmail!.isNotEmpty) &&
            (s.parentPhone != null && s.parentPhone!.isNotEmpty))
        .toList();

    if (eligibleStudents.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'No eligible students found. Students must have parent email and phone to create logins.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Bulk Create Parent Logins',
            style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Found ${eligibleStudents.length} students with parent email & phone but no login.',
                style: const TextStyle(color: _textPrimary)),
            const SizedBox(height: 12),
            const Text(
                'Login credentials:\n• Email = Parent Email\n• Password = Parent Mobile Number',
                style: TextStyle(color: _textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: Colors.amber),
                  SizedBox(width: 8),
                  Expanded(
                      child: Text(
                          'This will create Firebase Auth users for all eligible students. This cannot be undone easily.',
                          style: TextStyle(color: Colors.amber, fontSize: 11))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: _textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _accentBlue),
            child: Text('Create ${eligibleStudents.length} Logins',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    setState(() => _isBulkCreating = true);

    int created = 0;
    int failed = 0;

    try {
      FirebaseApp secondaryApp;
      try {
        secondaryApp = Firebase.app('parent-helper');
      } on FirebaseException {
        secondaryApp = await Firebase.initializeApp(
          name: 'parent-helper',
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final firestore = FirebaseFirestore.instance;
      final repo = ref.read(studentRepositoryProvider);

      for (final student in eligibleStudents) {
        try {
          final loginEmail = student.parentEmail ?? '';
          final loginPassword = student.parentPhone ?? '';

          final userCredential =
              await secondaryAuth.createUserWithEmailAndPassword(
            email: loginEmail,
            password: loginPassword,
          );
          final userId = userCredential.user!.uid;

          final userData = AppUser(
            uid: userId,
            email: loginEmail,
            displayName: student.parentName ?? student.name,
            role: UserRole.PARENT,
            schoolId: schoolId,
            status: UserStatus.ACTIVE,
            onboardingStatus: OnboardingStatus.ACTIVE,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            createdBy: session.uid,
            profile: UserProfile(phoneNumber: loginPassword),
            permissions: UserPermissions.forRole(UserRole.PARENT),
          );

          await firestore
              .collection('users')
              .doc(userId)
              .set(userData.toFirestore());
          await repo.updateStudent(
              schoolId,
              student.id,
              student.copyWith(
                  parentUserId: userId, updatedAt: DateTime.now()));

          await secondaryAuth.signOut();

          // Update local state
          final idx = _allStudents.indexWhere((s) => s.id == student.id);
          if (idx != -1) {
            _allStudents[idx] =
                _allStudents[idx].copyWith(parentUserId: userId);
          }

          // Queue WhatsApp notification
          final parentPhone = student.parentPhone ?? student.phoneNumber;
          if (parentPhone != null && parentPhone.isNotEmpty) {
            await _queueWhatsAppLoginNotification(
                schoolId, student.name, loginEmail, loginPassword, parentPhone);
          }

          created++;
        } catch (_) {
          failed++;
        }
      }
    } catch (e) {
      failed = eligibleStudents.length - created;
    }

    if (mounted) {
      setState(() => _isBulkCreating = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Done! $created logins created, $failed failed.'),
        backgroundColor: failed == 0 ? Colors.green : Colors.orange,
      ));
    }
  }

  // ─── Enter Parent Info Dialog ─────────────────────────────────────

  Future<Map<String, String>?> _showEnterParentInfoDialog(
      BuildContext context, Student student) async {
    final emailController = TextEditingController();
    final phoneController = TextEditingController(
        text: student.parentPhone ?? student.phoneNumber ?? '');

    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Parent Info Required',
            style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  '${student.name} does not have parent email on record.\nPlease enter parent details to create login.',
                  style: const TextStyle(color: _textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              _formField(
                  'Parent Email *', emailController, Icons.email_outlined),
              const SizedBox(height: 12),
              _formField('Parent Mobile (= password) *', phoneController,
                  Icons.phone_android_outlined),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: _textSecondary))),
          ElevatedButton(
            onPressed: () {
              final email = emailController.text.trim();
              final phone = phoneController.text.trim();
              if (email.isEmpty || !email.contains('@')) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('Valid email is required'),
                    backgroundColor: Colors.red));
                return;
              }
              if (phone.isEmpty || phone.length < 6) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text(
                        'Mobile number (min 6 digits) is required as password'),
                    backgroundColor: Colors.red));
                return;
              }
              Navigator.pop(ctx, {'email': email, 'phone': phone});
            },
            style: ElevatedButton.styleFrom(backgroundColor: _accentBlue),
            child:
                const Text('Continue', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────

  Widget _formField(
      String label, TextEditingController controller, IconData icon,
      {Function(String)? onChanged}) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: _textPrimary),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textSecondary),
        prefixIcon: Icon(icon, color: _textSecondary, size: 20),
        filled: true,
        fillColor: _bgDark,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _borderColor)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _borderColor)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _accentBlue)),
      ),
    );
  }

  Widget _formDropdown(String label, String value, List<String> items,
      void Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: _cardDark,
      style: const TextStyle(color: _textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textSecondary),
        filled: true,
        fillColor: _bgDark,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _borderColor)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _borderColor)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _accentBlue)),
      ),
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
    );
  }

  /// Seed a [StudentFeeLedger] from the active [FeeStructureV2] that
  /// matches the student's class + academic year. Runs after the legacy
  /// `student_fee_details` seed so both data models stay in sync during
  /// the migration window. Non-fatal: any failure is logged and swallowed
  /// so the student creation itself is never rolled back.
  Future<void> _autoAssignLedgerV2({
    required String schoolId,
    required String studentId,
    required String studentName,
    required String className,
    required String section,
    required String academicYear,
    String? parentName,
    String? parentPhone,
  }) async {
    try {
      final feeRepo = ref.read(feeRepositoryProvider);
      final structure = await feeRepo.getFeeStructureV2ByClass(
          schoolId, className, academicYear);
      if (structure == null) {
        print(
            '⚠️ No FeeStructureV2 found for $className / $academicYear — skipping ledger seed.');
        return;
      }
      final ledgerRepo = ref.read(studentFeeLedgerRepositoryProvider);
      await ledgerRepo.assignToStudent(
        schoolId: schoolId,
        studentId: studentId,
        studentName: studentName,
        className: className,
        section: section,
        structureId: structure.id,
        parentName: (parentName ?? '').isEmpty ? null : parentName,
        parentPhone: (parentPhone ?? '').isEmpty ? null : parentPhone,
        onConflict: ConflictAction.SKIP,
      );
      print(
          '✅ Seeded StudentFeeLedger from "${structure.name}" for $studentName');
    } catch (e) {
      print('⚠️ _autoAssignLedgerV2 failed: $e');
    }
  }

  Future<void> _createStudentFeeDetails(
      String schoolId,
      String studentId,
      Map<String, dynamic> feeStructure,
      String concession,
      String arrearTuition,
      String arrearExam,
      String arrearVan,
      String studentName,
      String studentSection,
      String academicYear,
      String vanAvailed,
      String vanFeeText) async {
    try {
      final tuitionFee = (feeStructure['tuitionFee'] as num?)?.toDouble() ?? 0;
      final examFee = (feeStructure['examFee'] as num?)?.toDouble() ?? 0;
      final vanFee = vanAvailed == 'Yes' ? double.tryParse(vanFeeText) ?? 0 : 0;
      final concessionAmount = double.tryParse(concession) ?? 0;
      final arrearTuitionAmount = double.tryParse(arrearTuition) ?? 0;
      final arrearExamAmount = double.tryParse(arrearExam) ?? 0;
      final arrearVanAmount =
          vanAvailed == 'Yes' ? double.tryParse(arrearVan) ?? 0 : 0;

      final totalFee = tuitionFee + examFee + vanFee;
      final totalPaid = 0.0;
      final totalConcession = concessionAmount;
      final totalArrears =
          arrearTuitionAmount + arrearExamAmount + arrearVanAmount;

      // Calculate balances for each fee type
      final balTuition =
          (tuitionFee + arrearTuitionAmount) - totalConcession - totalPaid;
      final balExam = (examFee + arrearExamAmount) - totalPaid;
      final balVan = (vanFee + arrearVanAmount) - totalPaid;
      final balTotal = totalFee + totalArrears - totalConcession - totalPaid;

      final feeData = {
        'stuId': studentId,
        'stuName': studentName, // Use actual student name
        'stuClass': feeStructure['className'] ?? '',
        'stuSection': studentSection, // Use actual student section
        'stuConcessionFees': totalConcession,
        'arrearTuitionFees': arrearTuitionAmount,
        'arrearExamFees': arrearExamAmount,
        'arrearVanFees': arrearVanAmount,
        'isStuAvailVan': vanAvailed == 'Yes' ? 'y' : 'n',
        'stuTotalVanFees': vanFee,
        'stuTotalTutionFees': tuitionFee,
        'stuTotalExamFees': examFee,
        'stuTotalAdmissionFees': 0.0,
        'stuTotalFees': totalFee,
        'stuPaidTutionFees': 0.0,
        'stuPaidExamFees': 0.0,
        'studPaidVanFees': 0.0,
        'stuPaidAdmissionFees': 0.0,
        'stuPaidTotalFees': totalPaid,
        'stuBalTutionFees': balTuition,
        'stuBalExamFees': balExam,
        'stuBalVanFees': balVan,
        'stuBalAdmissionFees': 0.0,
        'stuBalTotalFees': balTotal,
        'academicYear': academicYear,
        'fiscalYear': FiscalYear.getCurrentYearCode(),
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
      };

      await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('student_fee_details')
          .add(feeData);
    } catch (e) {
      print('Error creating student fee details: $e');
      // Continue without failing the student creation
    }
  }

  Future<String> _getCurrentAcademicYear(String schoolId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('academicYears')
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.id;
      }
      // Fallback to current academic year
      final now = DateTime.now();
      final currentYear = now.year;
      final startYear = now.month >= 6 ? currentYear : currentYear - 1;
      return '$startYear-${startYear + 1}';
    } catch (e) {
      // Fallback to current academic year
      final now = DateTime.now();
      final currentYear = now.year;
      final startYear = now.month >= 6 ? currentYear : currentYear - 1;
      return '$startYear-${startYear + 1}';
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: _accentBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle),
            child:
                const Icon(Icons.people_outline, size: 48, color: _accentBlue),
          ),
          const SizedBox(height: 20),
          const Text('No Students Yet',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary)),
          const SizedBox(height: 8),
          const Text('Add your first student to get started',
              style: TextStyle(color: _textSecondary)),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 48, color: _textSecondary),
          SizedBox(height: 16),
          Text('No students found',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary)),
          SizedBox(height: 8),
          Text('Try adjusting your search or filters',
              style: TextStyle(color: _textSecondary)),
        ],
      ),
    );
  }

  void _viewStudentBills(
      BuildContext context, Student student, String schoolId) {
    // Navigate to bills view for this student
    // This would typically navigate to a bills screen showing payment history, receipts, etc.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('Viewing bills for ${student.name} (${student.studentId})'),
        backgroundColor: Colors.green,
      ),
    );
    // TODO: Navigate to bills screen
    // Navigator.push(context, MaterialPageRoute(builder: (context) => StudentBillsScreen(studentId: student.studentId, schoolId: schoolId)));
  }

  void _viewStudentFeeDetails(
      BuildContext context, Student student, String schoolId) {
    showDialog(
      context: context,
      builder: (context) =>
          _StudentFeeDetailsDialog(student: student, schoolId: schoolId),
    );
  }

  Widget _buildFeeInfoRow(String label, dynamic value) {
    final amt = (value as num?)?.toDouble() ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: _textPrimary, fontSize: 11)),
          Text('₹${amt.toStringAsFixed(0)}',
              style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildTransportAwareFeeSummary(
      Map<String, dynamic> feeStructure,
      String vanAvailed,
      TextEditingController concessionCtrl,
      TextEditingController arrearTuitionCtrl,
      TextEditingController arrearExamCtrl,
      TextEditingController arrearVanCtrl,
      TextEditingController vanFeeCtrl) {
    // Calculate base fees based on transport selection
    final tuitionFee = (feeStructure['tuitionFee'] as num?)?.toDouble() ?? 0;
    final examFee = (feeStructure['examFee'] as num?)?.toDouble() ?? 0;
    final vanFee =
        vanAvailed == 'Yes' ? double.tryParse(vanFeeCtrl.text) ?? 0 : 0;
    print(
        '💰 Fee calculation - VanAvailed: $vanAvailed, VanFeeCtrl: "${vanFeeCtrl.text}", Calculated VanFee: $vanFee');
    final baseFees = tuitionFee + examFee + vanFee;

    // Calculate arrears based on transport selection
    final tuitionArrears = double.tryParse(arrearTuitionCtrl.text) ?? 0;
    final examArrears = double.tryParse(arrearExamCtrl.text) ?? 0;
    final vanArrears =
        vanAvailed == 'Yes' ? (double.tryParse(arrearVanCtrl.text) ?? 0) : 0;
    final totalArrears = tuitionArrears + examArrears + vanArrears;
    final concession = double.tryParse(concessionCtrl.text) ?? 0;

    return Column(
      children: [
        // Individual fee components
        _buildFeeInfoRow('Tuition Fee', tuitionFee),
        _buildFeeInfoRow('Exam Fee', examFee),
        if (vanAvailed == 'Yes') _buildFeeInfoRow('Van Fee', vanFee),

        // Base fees total
        const Divider(color: _borderColor, height: 4),
        _buildFeeInfoRow('Base Fees Total', baseFees),

        // Arrears section
        if (totalArrears > 0) ...[
          const SizedBox(height: 4),
          _buildFeeInfoRow('Tuition Arrears', tuitionArrears),
          _buildFeeInfoRow('Exam Arrears', examArrears),
          if (vanAvailed == 'Yes') _buildFeeInfoRow('Van Arrears', vanArrears),
          _buildFeeInfoRow('Total Arrears', totalArrears),
        ],

        // Concession
        if (concession > 0) _buildFeeInfoRow('Concession', concession),

        // Final total
        const Divider(color: _borderColor, height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: _accentBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4)),
          child: _buildFeeInfoRow(
              'Total Payable', baseFees + totalArrears - concession),
        ),
      ],
    );
  }
}

// Comprehensive Student Fee Details Dialog
class _StudentFeeDetailsDialog extends StatefulWidget {
  final Student student;
  final String schoolId;

  const _StudentFeeDetailsDialog(
      {required this.student, required this.schoolId});

  @override
  State<_StudentFeeDetailsDialog> createState() =>
      _StudentFeeDetailsDialogState();
}

class _StudentFeeDetailsDialogState extends State<_StudentFeeDetailsDialog> {
  Map<String, dynamic>? _studentFeeData;
  String? _studentFeeDocId;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _tuitionSource;

  // Controllers for editable fields
  final TextEditingController _arrearTuitionController =
      TextEditingController();
  final TextEditingController _arrearExamController = TextEditingController();
  final TextEditingController _arrearVanController = TextEditingController();
  final TextEditingController _arrearAdmissionController =
      TextEditingController();
  final TextEditingController _concessionController = TextEditingController();

  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _accentGreen = Color(0xFF10B981);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  @override
  void dispose() {
    _arrearTuitionController.dispose();
    _arrearExamController.dispose();
    _arrearVanController.dispose();
    _arrearAdmissionController.dispose();
    _concessionController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadStudentFeeData();
  }

  Future<void> _loadStudentFeeData() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .collection('student_fee_details')
          .where('stuId', isEqualTo: widget.student.studentId)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        setState(() {
          _studentFeeData = data;
          _studentFeeDocId = snap.docs.first.id;
          _isLoading = false;
        });
        // Populate controllers with existing values
        _arrearTuitionController.text =
            ((data['arrearTuitionFees'] as num?)?.toDouble() ?? 0).toString();
        _arrearExamController.text =
            ((data['arrearExamFees'] as num?)?.toDouble() ?? 0).toString();
        _arrearVanController.text =
            ((data['arrearVanFees'] as num?)?.toDouble() ?? 0).toString();
        _arrearAdmissionController.text =
            ((data['arrearAdmissionFees'] as num?)?.toDouble() ?? 0).toString();
        _concessionController.text =
            ((data['stuConcessionFees'] as num?)?.toDouble() ?? 0).toString();

        // Apply V2 fee structure override
        await _applyV2Override();
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading student fee data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Looks up the active FeeStructureV2 for the student's class
  /// and overrides the tuition figure with the sum of all V2 term amounts
  Future<void> _applyV2Override() async {
    if (widget.schoolId == null || _studentFeeData == null) return;

    final className = widget.student.className;
    if (className.isEmpty) return;

    final ay =
        (_studentFeeData!['academicYear']?.toString().isNotEmpty ?? false)
            ? _studentFeeData!['academicYear'].toString()
            : '2024-25';

    try {
      final repo = FirebaseFirestore.instance;
      final v2Snap = await repo
          .collection('schools')
          .doc(widget.schoolId)
          .collection('fee_structures_v2')
          .where('isActive', isEqualTo: true)
          .where('applicableClassIds', arrayContains: className)
          .where('academicYear', isEqualTo: ay)
          .limit(1)
          .get();

      if (v2Snap.docs.isEmpty) return;

      final v2Data = v2Snap.docs.first.data();
      final v2Tuition = _calculateV2Tuition(v2Data);

      final s = _studentFeeData!;
      final exam = (s['stuTotalExamFees'] as num?)?.toDouble() ?? 0;
      final van = (s['stuTotalVanFees'] as num?)?.toDouble() ?? 0;
      final admission = (s['stuTotalAdmissionFees'] as num?)?.toDouble() ?? 0;
      final concession = (s['stuConcessionFees'] as num?)?.toDouble() ?? 0;
      final paidTuition = (s['stuPaidTutionFees'] as num?)?.toDouble() ?? 0;
      final paidExam = (s['stuPaidExamFees'] as num?)?.toDouble() ?? 0;
      final paidVan = (s['studPaidVanFees'] as num?)?.toDouble() ?? 0;
      final paidAdmission =
          (s['stuPaidAdmissionFees'] as num?)?.toDouble() ?? 0;
      final arrearTuition = (s['arrearTuitionFees'] as num?)?.toDouble() ?? 0;
      final arrearExam = (s['arrearExamFees'] as num?)?.toDouble() ?? 0;
      final arrearVan = (s['arrearVanFees'] as num?)?.toDouble() ?? 0;
      final arrearAdmission =
          (s['arrearAdmissionFees'] as num?)?.toDouble() ?? 0;

      final newTotal = v2Tuition + exam + van + admission;
      final newBalTuition =
          v2Tuition + arrearTuition - concession - paidTuition;
      final newBalExam = exam + arrearExam - paidExam;
      final newBalVan = van + arrearVan - paidVan;
      final newBalAdmission = admission + arrearAdmission - paidAdmission;
      final newBalTotal =
          newBalTuition + newBalExam + newBalVan + newBalAdmission;

      setState(() {
        _studentFeeData = {
          ..._studentFeeData!,
          'stuTotalTutionFees': v2Tuition,
          'stuTotalFees': newTotal,
          'stuBalTutionFees': newBalTuition,
          'stuBalExamFees': newBalExam,
          'stuBalVanFees': newBalVan,
          'stuBalAdmissionFees': newBalAdmission,
          'stuBalTotalFees': newBalTotal,
        };
        _tuitionSource = 'v2';
      });
    } catch (e) {
      print('Error applying V2 override: $e');
    }
  }

  /// Calculate total tuition from V2 fee structure
  double _calculateV2Tuition(Map<String, dynamic> v2Data) {
    final terms = v2Data['terms'] as List? ?? [];
    double total = 0;
    for (final term in terms) {
      if (term is Map) {
        final termMap = Map<String, dynamic>.from(term);
        final amount = (termMap['totalAmount'] as num?)?.toDouble() ?? 0;
        total += amount;
      }
    }
    return total;
  }

  // Apply concession deduction logic: term fees first, then others one by one
  Map<String, double> _applyConcessionDeduction(
    double concession,
    double tuitionBalance,
    double examBalance,
    double vanBalance,
    double admissionBalance,
  ) {
    double remainingConcession = concession;
    double newTuitionBalance = tuitionBalance;
    double newExamBalance = examBalance;
    double newVanBalance = vanBalance;
    double newAdmissionBalance = admissionBalance;

    // Apply to tuition (term fee) first
    if (remainingConcession > 0 && newTuitionBalance > 0) {
      final deduction = remainingConcession.clamp(0, newTuitionBalance);
      newTuitionBalance -= deduction;
      remainingConcession -= deduction;
    }

    // Apply to exam fees
    if (remainingConcession > 0 && newExamBalance > 0) {
      final deduction = remainingConcession.clamp(0, newExamBalance);
      newExamBalance -= deduction;
      remainingConcession -= deduction;
    }

    // Apply to van fees
    if (remainingConcession > 0 && newVanBalance > 0) {
      final deduction = remainingConcession.clamp(0, newVanBalance);
      newVanBalance -= deduction;
      remainingConcession -= deduction;
    }

    // Apply to admission fees
    if (remainingConcession > 0 && newAdmissionBalance > 0) {
      final deduction = remainingConcession.clamp(0, newAdmissionBalance);
      newAdmissionBalance -= deduction;
      remainingConcession -= deduction;
    }

    return {
      'tuitionBalance': newTuitionBalance,
      'examBalance': newExamBalance,
      'vanBalance': newVanBalance,
      'admissionBalance': newAdmissionBalance,
      'remainingConcession': remainingConcession,
    };
  }

  Future<void> _saveFeeChanges() async {
    if (_studentFeeData == null) return;

    setState(() => _isSaving = true);
    try {
      final arrearTuition = double.tryParse(_arrearTuitionController.text) ?? 0;
      final arrearExam = double.tryParse(_arrearExamController.text) ?? 0;
      final arrearVan = double.tryParse(_arrearVanController.text) ?? 0;
      final arrearAdmission =
          double.tryParse(_arrearAdmissionController.text) ?? 0;
      final concession = double.tryParse(_concessionController.text) ?? 0;

      // Get current balance values
      final tuitionBalance =
          ((_studentFeeData!['stuBalTutionFees'] as num?)?.toDouble() ?? 0);
      final examBalance =
          ((_studentFeeData!['stuBalExamFees'] as num?)?.toDouble() ?? 0);
      final vanBalance =
          ((_studentFeeData!['stuBalVanFees'] as num?)?.toDouble() ?? 0);
      final admissionBalance =
          ((_studentFeeData!['stuBalAdmissionFees'] as num?)?.toDouble() ?? 0);

      // Apply concession deduction logic
      final deductionResult = _applyConcessionDeduction(
        concession,
        tuitionBalance,
        examBalance,
        vanBalance,
        admissionBalance,
      );

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .collection('student_fee_details')
          .doc(_studentFeeDocId)
          .update({
        'arrearTuitionFees': arrearTuition,
        'arrearExamFees': arrearExam,
        'arrearVanFees': arrearVan,
        'arrearAdmissionFees': arrearAdmission,
        'stuConcessionFees': concession,
        'stuBalTutionFees': deductionResult['tuitionBalance'],
        'stuBalExamFees': deductionResult['examBalance'],
        'stuBalVanFees': deductionResult['vanBalance'],
        'stuBalAdmissionFees': deductionResult['admissionBalance'],
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Reload data
      await _loadStudentFeeData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Fee details updated successfully'),
              backgroundColor: _accentGreen),
        );
      }
    } catch (e) {
      print('Error saving fee changes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error saving fee changes: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildFeeBreakdownCard(
      String title, Color accent, Map<String, dynamic> data, String type) {
    double tuition = 0, exam = 0, van = 0, admission = 0, total = 0;
    double tuitionArr = 0, examArr = 0, vanArr = 0, admissionArr = 0;

    switch (type) {
      case 'Total':
        tuition = (data['stuTotalTutionFees'] as num?)?.toDouble() ?? 0;
        exam = (data['stuTotalExamFees'] as num?)?.toDouble() ?? 0;
        van = (data['stuTotalVanFees'] as num?)?.toDouble() ?? 0;
        admission = (data['stuTotalAdmissionFees'] as num?)?.toDouble() ?? 0;
        tuitionArr = (data['arrearTuitionFees'] as num?)?.toDouble() ?? 0;
        examArr = (data['arrearExamFees'] as num?)?.toDouble() ?? 0;
        vanArr = (data['arrearVanFees'] as num?)?.toDouble() ?? 0;
        admissionArr = (data['arrearAdmissionFees'] as num?)?.toDouble() ?? 0;
        break;
      case 'Paid':
        tuition = (data['stuPaidTutionFees'] as num?)?.toDouble() ?? 0;
        exam = (data['stuPaidExamFees'] as num?)?.toDouble() ?? 0;
        van = (data['studPaidVanFees'] as num?)?.toDouble() ?? 0;
        admission = (data['stuPaidAdmissionFees'] as num?)?.toDouble() ?? 0;
        tuitionArr = (data['stuPaidArrearTutionFees'] as num?)?.toDouble() ?? 0;
        examArr = (data['stuPaidArrearExamFees'] as num?)?.toDouble() ?? 0;
        vanArr = (data['stuPaidArrearVanFees'] as num?)?.toDouble() ?? 0;
        admissionArr =
            (data['stuPaidArrearAdmissionFees'] as num?)?.toDouble() ?? 0;
        break;
      case 'Balance':
        tuition = (data['stuBalTutionFees'] as num?)?.toDouble() ?? 0;
        exam = (data['stuBalExamFees'] as num?)?.toDouble() ?? 0;
        van = (data['stuBalVanFees'] as num?)?.toDouble() ?? 0;
        admission = (data['stuBalAdmissionFees'] as num?)?.toDouble() ?? 0;
        tuitionArr =
            (data['balanceArrearTuitionFees'] as num?)?.toDouble() ?? 0;
        examArr = (data['balanceArrearExamFees'] as num?)?.toDouble() ?? 0;
        vanArr = (data['balanceArrearVanFees'] as num?)?.toDouble() ?? 0;
        admissionArr =
            (data['balanceArrearAdmissionFees'] as num?)?.toDouble() ?? 0;
        break;
    }
    total = tuition + exam + van + admission;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bgDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
              color: accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6)),
          child: Center(
              child: Text(title,
                  style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13))),
        ),
        const SizedBox(height: 10),
        _feeRow('', 'Regular', 'Arrears', accent, isHeader: true),
        _feeRow('Tuition Fees', '₹${tuition.toStringAsFixed(0)}',
            '₹${tuitionArr.toStringAsFixed(0)}', accent),
        _feeRow('Exam Fees', '₹${exam.toStringAsFixed(0)}',
            '₹${examArr.toStringAsFixed(0)}', accent),
        _feeRow('Van Fees', '₹${van.toStringAsFixed(0)}',
            '₹${vanArr.toStringAsFixed(0)}', accent),
        _feeRow('Admission Fees', '₹${admission.toStringAsFixed(0)}',
            '₹${admissionArr.toStringAsFixed(0)}', accent),
        Divider(color: _borderColor, height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('TOTAL',
              style: TextStyle(
                  color: _textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
          Text('₹${total.toStringAsFixed(0)}',
              style: TextStyle(
                  color: accent, fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
      ]),
    );
  }

  Widget _feeRow(String label, String regular, String arrears, Color accent,
      {bool isHeader = false}) {
    final style = isHeader
        ? TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 11)
        : const TextStyle(color: _textPrimary, fontSize: 12);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: isHeader
          ? null
          : BoxDecoration(
              color: accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: accent.withOpacity(0.15)),
            ),
      child: Row(children: [
        if (!isHeader) Icon(Icons.circle, size: 5, color: accent),
        if (!isHeader) const SizedBox(width: 6),
        Expanded(
            flex: 3,
            child: Text(label,
                style: TextStyle(
                    color: isHeader ? _textSecondary : _textPrimary,
                    fontSize: 12,
                    fontWeight:
                        isHeader ? FontWeight.normal : FontWeight.w500))),
        Expanded(
            flex: 2,
            child: Text(regular, style: style, textAlign: TextAlign.right)),
        const SizedBox(width: 8),
        Expanded(
            flex: 2,
            child: Text(arrears, style: style, textAlign: TextAlign.right)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _accentBlue.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_balance_wallet_rounded,
                          color: _accentBlue, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Fee Details',
                                style: TextStyle(
                                    color: _accentBlue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18)),
                            Text(widget.student.name,
                                style: const TextStyle(
                                    color: _textPrimary, fontSize: 14)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: _textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _infoChip(
                          'Student ID', widget.student.studentId.toString()),
                      const SizedBox(width: 8),
                      _infoChip('Class',
                          '${widget.student.className}-${widget.student.section}'),
                      if (_studentFeeData != null) ...[
                        const SizedBox(width: 8),
                        _infoChip(
                            'Academic Year',
                            (_studentFeeData!['academicYear'] ?? 'N/A')
                                .toString()),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(20),
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: _accentBlue))
                    : _studentFeeData == null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.info_outline,
                                    color: _textSecondary, size: 48),
                                const SizedBox(height: 16),
                                const Text('No fee data found',
                                    style: TextStyle(
                                        color: _textSecondary, fontSize: 16)),
                                const SizedBox(height: 8),
                                const Text(
                                    'This student may not have fee details recorded yet.',
                                    style: TextStyle(
                                        color: _textSecondary, fontSize: 12)),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Fee Management Cards
                                Row(
                                  children: [
                                    Expanded(
                                        child: _buildFeeBreakdownCard(
                                            'TOTAL FEES',
                                            const Color(0xFFF59E0B),
                                            _studentFeeData!,
                                            'Total')),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: _buildFeeBreakdownCard(
                                            'PAID FEES',
                                            const Color(0xFF10B981),
                                            _studentFeeData!,
                                            'Paid')),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                        child: _buildFeeBreakdownCard(
                                            'BALANCE FEES',
                                            const Color(0xFFEF4444),
                                            _studentFeeData!,
                                            'Balance')),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: _bgDark,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color:
                                                  _accentBlue.withOpacity(0.3)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              width: double.infinity,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 8),
                                              decoration: BoxDecoration(
                                                  color: _accentBlue
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(6)),
                                              child: Center(
                                                  child: Text('CONCESSION',
                                                      style: TextStyle(
                                                          color: _accentBlue,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 13))),
                                            ),
                                            const SizedBox(height: 10),
                                            TextField(
                                              controller: _concessionController,
                                              keyboardType:
                                                  TextInputType.number,
                                              style: const TextStyle(
                                                  color: _accentBlue,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16),
                                              decoration: InputDecoration(
                                                prefixText: '₹',
                                                prefixStyle: const TextStyle(
                                                    color: _accentBlue,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  borderSide: BorderSide(
                                                      color: _borderColor),
                                                ),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  borderSide: BorderSide(
                                                      color: _borderColor),
                                                ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  borderSide: BorderSide(
                                                      color: _accentBlue),
                                                ),
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 8),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                                'Applied to term fees first, then others',
                                                style: TextStyle(
                                                    color: _textSecondary,
                                                    fontSize: 10)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                // Arrears Section
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: _bgDark,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: _borderColor),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('Arrears',
                                          style: TextStyle(
                                              color: _textPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12)),
                                      const SizedBox(height: 10),
                                      _arrearInputField('Tuition Arrears',
                                          _arrearTuitionController),
                                      const SizedBox(height: 8),
                                      _arrearInputField('Exam Arrears',
                                          _arrearExamController),
                                      const SizedBox(height: 8),
                                      _arrearInputField(
                                          'Van Arrears', _arrearVanController),
                                      const SizedBox(height: 8),
                                      _arrearInputField('Admission Arrears',
                                          _arrearAdmissionController),
                                    ],
                                  ),
                                ),

                                // Additional Info
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _bgDark,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: _borderColor),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('Additional Information',
                                          style: TextStyle(
                                              color: _textPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12)),
                                      const SizedBox(height: 8),
                                      _infoRow(
                                          'Van Facility',
                                          _studentFeeData!['isStuAvailVan'] ==
                                                  'y'
                                              ? 'Available'
                                              : 'Not Available'),
                                      _infoRow(
                                          'Fiscal Year',
                                          (_studentFeeData!['fiscalYear'] ??
                                                  'N/A')
                                              .toString()),
                                      _infoRow(
                                          'Last Updated',
                                          _formatDate(
                                              _studentFeeData!['updatedAt'])),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
              ),
            ),
            // Action Buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _cardDark,
                border: Border(top: BorderSide(color: _borderColor)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _textSecondary,
                        side: BorderSide(color: _borderColor),
                        minimumSize: const Size(double.infinity, 44),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveFeeChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentBlue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 44),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _bgDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Text('$label: $value',
          style: const TextStyle(color: _textSecondary, fontSize: 11)),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: _textSecondary, fontSize: 11)),
          Text(value,
              style: const TextStyle(color: _textPrimary, fontSize: 11)),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    if (date is Timestamp) {
      return DateTime.fromMillisecondsSinceEpoch(date.millisecondsSinceEpoch)
          .toString()
          .split(' ')[0];
    }
    return date.toString();
  }

  Widget _arrearInputField(String label, TextEditingController controller) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(label,
              style: const TextStyle(color: _textPrimary, fontSize: 11)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: _textPrimary, fontSize: 12),
            decoration: InputDecoration(
              prefixText: '₹',
              prefixStyle: const TextStyle(color: _textPrimary, fontSize: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: _borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: _borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: _accentBlue),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
          ),
        ),
      ],
    );
  }
}
