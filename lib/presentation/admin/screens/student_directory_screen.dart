import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../domain/entities/student.dart';
import '../../../domain/entities/app_user.dart';
import '../../../firebase_options.dart';

class StudentDirectoryScreen extends ConsumerStatefulWidget {
  const StudentDirectoryScreen({super.key});

  @override
  ConsumerState<StudentDirectoryScreen> createState() => _StudentDirectoryScreenState();
}

class _StudentDirectoryScreenState extends ConsumerState<StudentDirectoryScreen> {
  String _searchQuery = '';
  String? _filterClass;
  String? _filterSection;
  String? _filterLoginStatus;
  final _searchController = TextEditingController();
  bool _isBulkCreating = false;

  // All students loaded from Firestore (including inactive)
  List<Student> _allStudents = [];
  List<String> _availableClasses = [];
  List<String> _availableSections = [];
  bool _isLoading = true;
  // Track which student IDs are toggling
  final Set<String> _togglingStudentIds = {};

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
          .collection('schools').doc(schoolId).collection('students')
          .get();

      debugPrint('[StudentDirectory] Found ${snapshot.docs.length} student docs');

      final students = snapshot.docs.map((doc) => Student.fromFirestore(doc)).toList();
      // Sort locally by name
      students.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      // Derive unique classes
      final classSet = <String>{};
      for (final s in students) {
        if (s.className.isNotEmpty) classSet.add(s.className);
      }
      final sorted = classSet.toList();
      // Sort with Pre-KG/LKG/UKG first, then roman numerals
      const order = ['Pre-KG', 'LKG', 'UKG', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI', 'XII'];
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
      if (_filterSection != null && !sorted.contains(_filterSection)) _filterSection = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;
    final isTablet = screenWidth > 600 && screenWidth <= 1024;

    if (session == null || session.schoolId == null) {
      return const Center(child: Text('Access Denied', style: TextStyle(color: _textPrimary)));
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
                  : _buildContent(context, _allStudents, filteredStudents, isDesktop, isTablet, session.schoolId!, session.uid),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, bool isDesktop, String schoolId) {
    return Container(
      padding: EdgeInsets.fromLTRB(isDesktop ? 24 : 16, isDesktop ? 20 : 16, isDesktop ? 24 : 16, 12),
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
                  decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(10), border: Border.all(color: _borderColor)),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: _textPrimary, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Search by name, ID, phone, email...',
                      hintStyle: TextStyle(color: _textSecondary, fontSize: 14),
                      prefixIcon: Icon(Icons.search, color: _textSecondary, size: 20),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
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
                _buildFilterChip('Section', _filterSection, _availableSections, (v) {
                  setState(() => _filterSection = v);
                }),
              // Login status filter
              _buildFilterChip('Login Status', _filterLoginStatus, ['with_login', 'without_login'],
                  (v) => setState(() => _filterLoginStatus = v),
                  labelMap: {'with_login': 'Has Login', 'without_login': 'No Login'}),
              // Clear all filters
              if (_filterClass != null || _filterSection != null || _filterLoginStatus != null || _searchQuery.isNotEmpty)
                ActionChip(
                  label: const Text('Clear Filters', style: TextStyle(color: Colors.red, fontSize: 12)),
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
                style: ElevatedButton.styleFrom(backgroundColor: _accentBlue, foregroundColor: Colors.white),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _isBulkCreating ? null : () => _bulkCreateLogins(context, schoolId),
                icon: _isBulkCreating
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _accentBlue))
                    : const Icon(Icons.group_add_rounded, size: 18),
                label: Text(_isBulkCreating ? 'Creating...' : 'Create All Parent Logins'),
                style: OutlinedButton.styleFrom(foregroundColor: _accentBlue, side: const BorderSide(color: _accentBlue)),
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

  Widget _buildFilterChip(String label, String? currentValue, List<String> options, void Function(String?) onChanged, {Map<String, String>? labelMap}) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(10), border: Border.all(color: _borderColor)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: currentValue,
          hint: Text('All $label', style: const TextStyle(color: _textSecondary, fontSize: 14)),
          dropdownColor: _cardDark,
          icon: const Icon(Icons.keyboard_arrow_down, color: _textSecondary),
          items: [
            DropdownMenuItem(value: null, child: Text('All $label', style: const TextStyle(color: _textPrimary))),
            ...options.map((o) => DropdownMenuItem(
                value: o,
                child: Text(labelMap?[o] ?? (label == 'Class' ? 'Class $o' : o), style: const TextStyle(color: _textPrimary)))),
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
          (student.phoneNumber?.toLowerCase().contains(_searchQuery) ?? false) ||
          (student.parentEmail?.toLowerCase().contains(_searchQuery) ?? false) ||
          (student.parentName?.toLowerCase().contains(_searchQuery) ?? false) ||
          (student.parentPhone?.toLowerCase().contains(_searchQuery) ?? false);
      final matchesClass = _filterClass == null || student.className == _filterClass;
      final matchesSection = _filterSection == null || student.section == _filterSection;
      final matchesLogin = _filterLoginStatus == null ||
          (_filterLoginStatus == 'with_login' && student.parentUserId != null && student.parentUserId!.isNotEmpty) ||
          (_filterLoginStatus == 'without_login' && (student.parentUserId == null || student.parentUserId!.isEmpty));
      return matchesSearch && matchesClass && matchesSection && matchesLogin;
    }).toList();
  }

  Widget _buildContent(BuildContext context, List<Student> allStudents, List<Student> filteredStudents, bool isDesktop, bool isTablet, String schoolId, String adminUid) {
    if (allStudents.isEmpty) return _buildEmptyState();
    if (filteredStudents.isEmpty) return _buildNoResultsState();

    final withLogin = allStudents.where((s) => s.parentUserId != null && s.parentUserId!.isNotEmpty).length;
    final withoutLogin = allStudents.length - withLogin;

    return Column(
      children: [
        // Summary bar
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16),
          child: Row(
            children: [
              Text('${filteredStudents.length} student${filteredStudents.length != 1 ? 's' : ''}',
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
              : _buildMobileList(filteredStudents, schoolId, adminUid, isTablet),
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
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildDesktopTable(List<Student> students, String schoolId, String adminUid) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor)),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _borderColor))),
              child: const Row(
                children: [
                  SizedBox(width: 50, child: Text('ID', style: TextStyle(fontWeight: FontWeight.w600, color: _textSecondary, fontSize: 11))),
                  Expanded(flex: 2, child: Text('STUDENT', style: TextStyle(fontWeight: FontWeight.w600, color: _textSecondary, fontSize: 11))),
                  SizedBox(width: 70, child: Text('CLASS', style: TextStyle(fontWeight: FontWeight.w600, color: _textSecondary, fontSize: 11))),
                  Expanded(flex: 2, child: Text('PARENT INFO', style: TextStyle(fontWeight: FontWeight.w600, color: _textSecondary, fontSize: 11))),
                  SizedBox(width: 130, child: Text('PARENT LOGIN', style: TextStyle(fontWeight: FontWeight.w600, color: _textSecondary, fontSize: 11))),
                  SizedBox(width: 60, child: Text('EDIT', style: TextStyle(fontWeight: FontWeight.w600, color: _textSecondary, fontSize: 11))),
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
    final hasLogin = student.parentUserId != null && student.parentUserId!.isNotEmpty;
    final hasParentEmail = student.parentEmail != null && student.parentEmail!.isNotEmpty;
    final hasParentPhone = student.parentPhone != null && student.parentPhone!.isNotEmpty;
    final isToggling = _togglingStudentIds.contains(student.id);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _borderColor, width: 0.5))),
      child: Row(
        children: [
          SizedBox(width: 50, child: Text('${student.studentId}', style: const TextStyle(color: _textPrimary, fontSize: 13))),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: _accentBlue.withValues(alpha: 0.2),
                  radius: 16,
                  child: Text(student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
                      style: const TextStyle(color: _accentBlue, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student.name, style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w500, fontSize: 13), overflow: TextOverflow.ellipsis),
                      if (student.phoneNumber != null)
                        Text(student.phoneNumber!, style: const TextStyle(color: _textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 70, child: Text('${student.className}-${student.section}', style: const TextStyle(color: _textPrimary, fontSize: 13))),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (student.parentName != null)
                  Text(student.parentName!, style: const TextStyle(color: _textPrimary, fontSize: 12)),
                if (hasParentEmail)
                  Text(student.parentEmail!, style: const TextStyle(color: _textSecondary, fontSize: 11)),
                if (hasParentPhone)
                  Text(student.parentPhone!, style: const TextStyle(color: _textSecondary, fontSize: 11)),
                if (!hasParentEmail && !hasParentPhone)
                  const Text('No contact info', style: TextStyle(color: Colors.orange, fontSize: 11)),
              ],
            ),
          ),
          // Toggle switch for parent login
          SizedBox(
            width: 130,
            child: isToggling
                ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _accentBlue)))
                : Row(
                    children: [
                      SizedBox(
                        height: 28,
                        child: Switch(
                          value: hasLogin,
                          activeColor: _accentBlue,
                          inactiveThumbColor: _textSecondary,
                          inactiveTrackColor: _borderColor,
                          onChanged: (value) => _toggleParentLogin(context, student, schoolId, adminUid, value),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hasLogin ? 'Active' : 'Off',
                        style: TextStyle(color: hasLogin ? _accentBlue : _textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
          ),
          // Edit button
          SizedBox(
            width: 60,
            child: IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18, color: _textSecondary),
              onPressed: () => _showEditStudentDialog(context, student, schoolId),
              tooltip: 'Edit',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileList(List<Student> students, String schoolId, String adminUid, bool isTablet) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: students.length,
      itemBuilder: (context, index) => _buildStudentCard(students[index], schoolId, adminUid),
    );
  }

  Widget _buildStudentCard(Student student, String schoolId, String adminUid) {
    final hasLogin = student.parentUserId != null && student.parentUserId!.isNotEmpty;
    final hasParentEmail = student.parentEmail != null && student.parentEmail!.isNotEmpty;
    final hasParentPhone = student.parentPhone != null && student.parentPhone!.isNotEmpty;
    final isToggling = _togglingStudentIds.contains(student.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: _accentBlue.withValues(alpha: 0.2),
                radius: 22,
                child: Text(student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
                    style: const TextStyle(color: _accentBlue, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student.name, style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('ID: ${student.studentId} • Class ${student.className}-${student.section}',
                        style: const TextStyle(color: _textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              // Toggle for parent login
              if (isToggling)
                const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: _accentBlue))
              else
                Switch(
                  value: hasLogin,
                  activeColor: _accentBlue,
                  inactiveThumbColor: _textSecondary,
                  inactiveTrackColor: _borderColor,
                  onChanged: (value) => _toggleParentLogin(context, student, schoolId, adminUid, value),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Parent info
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _bgDark, borderRadius: BorderRadius.circular(8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('Parent Info', style: TextStyle(color: _textSecondary, fontSize: 10, fontWeight: FontWeight.w600))),
                    Text(hasLogin ? 'Login Active' : 'Login Off',
                        style: TextStyle(color: hasLogin ? _accentBlue : Colors.orange, fontSize: 10, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                if (student.parentName != null)
                  Text(student.parentName!, style: const TextStyle(color: _textPrimary, fontSize: 12)),
                if (hasParentEmail)
                  Text('Email: ${student.parentEmail}', style: const TextStyle(color: _textSecondary, fontSize: 11)),
                if (hasParentPhone)
                  Text('Phone: ${student.parentPhone}', style: const TextStyle(color: _textSecondary, fontSize: 11)),
                if (!hasParentEmail && !hasParentPhone)
                  const Text('No contact info - tap Edit to add', style: TextStyle(color: Colors.orange, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _showEditStudentDialog(context, student, schoolId),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Edit Student'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _textSecondary,
              side: const BorderSide(color: _borderColor),
              minimumSize: const Size(double.infinity, 38),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Dialogs ──────────────────────────────────────────────────────

  void _showAddStudentDialog(BuildContext context, String schoolId) {
    _showStudentFormDialog(context, schoolId, null);
  }

  void _showEditStudentDialog(BuildContext context, Student student, String schoolId) {
    _showStudentFormDialog(context, schoolId, student);
  }

  void _showStudentFormDialog(BuildContext context, String schoolId, Student? existingStudent) {
    final isEditing = existingStudent != null;
    final nameController = TextEditingController(text: existingStudent?.name ?? '');
    final phoneController = TextEditingController(text: existingStudent?.phoneNumber ?? '');
    final parentNameController = TextEditingController(text: existingStudent?.parentName ?? '');
    final parentPhoneController = TextEditingController(text: existingStudent?.parentPhone ?? '');
    final parentEmailController = TextEditingController(text: existingStudent?.parentEmail ?? '');
    String selectedClass = existingStudent?.className ?? 'I';
    String selectedSection = existingStudent?.section ?? 'A';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: _cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isEditing ? 'Edit Student' : 'Add New Student', style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _formField('Student Name *', nameController, Icons.person_outline),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _formDropdown('Class *', selectedClass, ['Pre-KG', 'LKG', 'UKG', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI', 'XII'], (v) => setDialogState(() => selectedClass = v!))),
                      const SizedBox(width: 12),
                      Expanded(child: _formDropdown('Section *', selectedSection, ['A', 'B', 'C', 'D'], (v) => setDialogState(() => selectedSection = v!))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _formField('Student Phone', phoneController, Icons.phone_outlined),
                  const Divider(height: 28, color: _borderColor),
                  const Align(alignment: Alignment.centerLeft, child: Text('Parent / Guardian Details', style: TextStyle(color: _accentBlue, fontWeight: FontWeight.w600, fontSize: 13))),
                  const SizedBox(height: 12),
                  _formField('Parent Name', parentNameController, Icons.family_restroom_outlined),
                  const SizedBox(height: 12),
                  _formField('Parent Mobile *', parentPhoneController, Icons.phone_android_outlined),
                  const SizedBox(height: 12),
                  _formField('Parent Email *', parentEmailController, Icons.email_outlined),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue),
                        SizedBox(width: 8),
                        Expanded(child: Text('Parent email is used as login ID. Default password = mobile number.', style: TextStyle(color: Colors.blue, fontSize: 11))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _textSecondary))),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Student name is required'), backgroundColor: Colors.red));
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
                      phoneNumber: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                      parentName: parentNameController.text.trim().isEmpty ? null : parentNameController.text.trim(),
                      parentPhone: parentPhoneController.text.trim().isEmpty ? null : parentPhoneController.text.trim(),
                      parentEmail: parentEmailController.text.trim().isEmpty ? null : parentEmailController.text.trim(),
                      updatedAt: now,
                    );
                    await repo.updateStudent(schoolId, existingStudent.id, updated);
                  } else {
                    final nextId = await repo.getNextStudentId(schoolId);
                    final newStudent = Student(
                      id: '',
                      schoolId: schoolId,
                      studentId: nextId,
                      name: nameController.text.trim(),
                      className: selectedClass,
                      section: selectedSection,
                      phoneNumber: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                      parentName: parentNameController.text.trim().isEmpty ? null : parentNameController.text.trim(),
                      parentPhone: parentPhoneController.text.trim().isEmpty ? null : parentPhoneController.text.trim(),
                      parentEmail: parentEmailController.text.trim().isEmpty ? null : parentEmailController.text.trim(),
                      status: StudentStatus.ACTIVE,
                      createdAt: now,
                      updatedAt: now,
                    );
                    await repo.createStudent(schoolId, newStudent);
                  }
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEditing ? 'Student updated' : 'Student added'), backgroundColor: _accentBlue));
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _accentBlue),
              child: Text(isEditing ? 'Update' : 'Add Student', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Toggle Parent Login (Activate / Deactivate) ─────────────────

  Future<void> _toggleParentLogin(BuildContext context, Student student, String schoolId, String adminUid, bool activate) async {
    if (activate) {
      await _activateParentLogin(context, student, schoolId, adminUid);
    } else {
      await _deactivateParentLogin(context, student, schoolId);
    }
  }

  Future<void> _activateParentLogin(BuildContext context, Student student, String schoolId, String adminUid) async {
    String? loginEmail = student.parentEmail ?? student.email;
    String? loginPassword = student.parentPhone ?? student.phoneNumber;

    if (loginEmail == null || loginEmail.isEmpty) {
      final result = await _showEnterParentInfoDialog(context, student);
      if (result == null) return;
      loginEmail = result['email']!;
      loginPassword = result['phone']!;

      final repo = ref.read(studentRepositoryProvider);
      await repo.updateStudent(schoolId, student.id, student.copyWith(
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

      await firestore.collection('users').doc(userId).set(userData.toFirestore());

      // Update student record with parentUserId
      final repo = ref.read(studentRepositoryProvider);
      await repo.updateStudent(schoolId, student.id, student.copyWith(
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
        await _queueWhatsAppLoginNotification(schoolId, student.name, loginEmail, loginPassword, parentPhone);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Parent login activated for ${student.name}'), backgroundColor: Colors.green),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }

    if (mounted) setState(() => _togglingStudentIds.remove(student.id));
  }

  Future<void> _deactivateParentLogin(BuildContext context, Student student, String schoolId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Deactivate Parent Login', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Disable login for ${student.name}\'s parent?', style: const TextStyle(color: _textPrimary)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber),
                  SizedBox(width: 8),
                  Expanded(child: Text('The parent will not be able to log in until reactivated.', style: TextStyle(color: Colors.amber, fontSize: 11))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: _textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Deactivate', style: TextStyle(color: Colors.white)),
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
      await repo.updateStudent(schoolId, student.id, student.copyWith(
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
          SnackBar(content: Text('Parent login deactivated for ${student.name}'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }

    if (mounted) setState(() => _togglingStudentIds.remove(student.id));
  }

  // ─── WhatsApp Login Notification ───────────────────────────────────

  Future<void> _queueWhatsAppLoginNotification(String schoolId, String studentName, String email, String password, String parentPhone) async {
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
        'message': 'Dear Parent, your Eazy School 360 login has been activated.\n\nLogin Email: $email\nPassword: $password\n\nPlease change your password after first login.\n\n- Eazy School 360',
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
    if (cleaned.length == 10 && !cleaned.startsWith('0')) cleaned = '91$cleaned';
    if (cleaned.startsWith('0')) cleaned = '91${cleaned.substring(1)}';
    if (cleaned.length < 10) return null;
    return cleaned;
  }

  // ─── Bulk Create Logins ───────────────────────────────────────────

  Future<void> _bulkCreateLogins(BuildContext context, String schoolId) async {
    final session = ref.read(currentSessionProvider);
    if (session == null) return;

    final eligibleStudents = _allStudents.where((s) =>
        (s.parentUserId == null || s.parentUserId!.isEmpty) &&
        (s.parentEmail != null && s.parentEmail!.isNotEmpty) &&
        (s.parentPhone != null && s.parentPhone!.isNotEmpty)).toList();

    if (eligibleStudents.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No eligible students found. Students must have parent email and phone to create logins.'),
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
        title: const Text('Bulk Create Parent Logins', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Found ${eligibleStudents.length} students with parent email & phone but no login.',
                style: const TextStyle(color: _textPrimary)),
            const SizedBox(height: 12),
            const Text('Login credentials:\n• Email = Parent Email\n• Password = Parent Mobile Number',
                style: TextStyle(color: _textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber),
                  SizedBox(width: 8),
                  Expanded(child: Text('This will create Firebase Auth users for all eligible students. This cannot be undone easily.',
                      style: TextStyle(color: Colors.amber, fontSize: 11))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: _textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _accentBlue),
            child: Text('Create ${eligibleStudents.length} Logins', style: const TextStyle(color: Colors.white)),
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

          final userCredential = await secondaryAuth.createUserWithEmailAndPassword(
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

          await firestore.collection('users').doc(userId).set(userData.toFirestore());
          await repo.updateStudent(schoolId, student.id, student.copyWith(parentUserId: userId, updatedAt: DateTime.now()));

          await secondaryAuth.signOut();

          // Update local state
          final idx = _allStudents.indexWhere((s) => s.id == student.id);
          if (idx != -1) {
            _allStudents[idx] = _allStudents[idx].copyWith(parentUserId: userId);
          }

          // Queue WhatsApp notification
          final parentPhone = student.parentPhone ?? student.phoneNumber;
          if (parentPhone != null && parentPhone.isNotEmpty) {
            await _queueWhatsAppLoginNotification(schoolId, student.name, loginEmail, loginPassword, parentPhone);
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

  Future<Map<String, String>?> _showEnterParentInfoDialog(BuildContext context, Student student) async {
    final emailController = TextEditingController();
    final phoneController = TextEditingController(text: student.parentPhone ?? student.phoneNumber ?? '');

    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Parent Info Required', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${student.name} does not have parent email on record.\nPlease enter parent details to create login.',
                  style: const TextStyle(color: _textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              _formField('Parent Email *', emailController, Icons.email_outlined),
              const SizedBox(height: 12),
              _formField('Parent Mobile (= password) *', phoneController, Icons.phone_android_outlined),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _textSecondary))),
          ElevatedButton(
            onPressed: () {
              final email = emailController.text.trim();
              final phone = phoneController.text.trim();
              if (email.isEmpty || !email.contains('@')) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Valid email is required'), backgroundColor: Colors.red));
                return;
              }
              if (phone.isEmpty || phone.length < 6) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Mobile number (min 6 digits) is required as password'), backgroundColor: Colors.red));
                return;
              }
              Navigator.pop(ctx, {'email': email, 'phone': phone});
            },
            style: ElevatedButton.styleFrom(backgroundColor: _accentBlue),
            child: const Text('Continue', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }


  // ─── Helpers ──────────────────────────────────────────────────────

  Widget _formField(String label, TextEditingController controller, IconData icon) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: _textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textSecondary),
        prefixIcon: Icon(icon, color: _textSecondary, size: 20),
        filled: true,
        fillColor: _bgDark,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _accentBlue)),
      ),
    );
  }

  Widget _formDropdown(String label, String value, List<String> items, void Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: _cardDark,
      style: const TextStyle(color: _textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textSecondary),
        filled: true,
        fillColor: _bgDark,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _accentBlue)),
      ),
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
    );
  }


  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: _accentBlue.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.people_outline, size: 48, color: _accentBlue),
          ),
          const SizedBox(height: 20),
          const Text('No Students Yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 8),
          const Text('Add your first student to get started', style: TextStyle(color: _textSecondary)),
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
          Text('No students found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
          SizedBox(height: 8),
          Text('Try adjusting your search or filters', style: TextStyle(color: _textSecondary)),
        ],
      ),
    );
  }

}
