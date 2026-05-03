import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../data/repositories/fee_repository.dart';
import '../../../data/repositories/student_fee_ledger_repository.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../domain/entities/academic_year.dart';
import '../../../domain/entities/student.dart';
import '../../shared/widgets/searchable_dropdown.dart';

class StudentManagementScreen extends ConsumerStatefulWidget {
  const StudentManagementScreen({super.key});

  @override
  ConsumerState<StudentManagementScreen> createState() =>
      _StudentManagementScreenState();
}

class _StudentManagementScreenState
    extends ConsumerState<StudentManagementScreen> {
  String _searchQuery = '';
  String? _filterClass;
  final _searchController = TextEditingController();

  // Dark theme colors
  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String? get _schoolId => ref.read(currentSessionProvider)?.schoolId;

  /// After a student is created, look up the active FeeStructureV2 for
  /// their class+AY and seed a [StudentFeeLedger] from it so the Fee
  /// Management screen works out of the box. Non-fatal: any failure is
  /// returned as a human-readable message for the snackbar instead of
  /// propagating — the student record itself is already committed.
  Future<String?> _autoAssignLedger({
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
        return 'Student added but no fee structure found for $className / $academicYear — assign one from Fee Management.';
      }
      final ledgerRepo = ref.read(studentFeeLedgerRepositoryProvider);
      await ledgerRepo.assignToStudent(
        schoolId: schoolId,
        studentId: studentId,
        studentName: studentName,
        className: className,
        section: section,
        structureId: structure.id,
        parentName: parentName,
        parentPhone: parentPhone,
        onConflict: ConflictAction.SKIP,
      );
      return 'Fee ledger seeded from "${structure.name}".';
    } catch (e) {
      return 'Student added; fee ledger auto-assign failed: $e';
    }
  }

  Future<String> _getCurrentAcademicYear(String schoolId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('academicYears')
          .where('isCurrent', isEqualTo: true)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data()['yearCode'] as String;
      }
    } catch (e) {
      debugPrint('[StudentManagement] Error getting current academic year: $e');
    }
    return AcademicYear.getCurrentYearCode();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;
    final isTablet = screenWidth > 600 && screenWidth <= 1024;

    if (session == null || session.schoolId == null) {
      return const Scaffold(
          backgroundColor: _bgDark,
          body: Center(
              child: Text('Access Denied',
                  style: TextStyle(color: _textPrimary))));
    }

    final studentsAsync = ref.watch(schoolStudentsProvider(session.schoolId!));

    return Scaffold(
      backgroundColor: _bgDark,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddStudentDialog(context, session.schoolId!),
        backgroundColor: _accentBlue,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('Add Student',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          _buildHeader(context, isDesktop),
          Expanded(
            child: studentsAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: _accentBlue)),
              error: (error, stack) => _buildErrorState(error),
              data: (students) {
                final filteredStudents = _filterStudents(students);
                return _buildContent(
                    context, students, filteredStudents, isDesktop, isTablet);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDesktop) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          isDesktop ? 24 : 16, isDesktop ? 20 : 16, isDesktop ? 24 : 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                      color: _cardDark,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _borderColor)),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: _textPrimary, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Search students by name, ID, or phone...',
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
              const SizedBox(width: 12),
              SizedBox(
                width: 180,
                child: SearchableDropdown<String>(
                  value: _filterClass,
                  hint: 'All Classes',
                  items: const [
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
                  ],
                  itemLabel: (c) => 'Class $c',
                  onChanged: (value) => setState(() => _filterClass = value),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Student> _filterStudents(List<Student> students) {
    return students.where((student) {
      final matchesSearch = _searchQuery.isEmpty ||
          student.name.toLowerCase().contains(_searchQuery) ||
          student.studentId.toString().contains(_searchQuery) ||
          (student.phoneNumber?.contains(_searchQuery) ?? false);
      final matchesClass =
          _filterClass == null || student.className == _filterClass;
      return matchesSearch && matchesClass;
    }).toList();
  }

  Widget _buildContent(BuildContext context, List<Student> allStudents,
      List<Student> filteredStudents, bool isDesktop, bool isTablet) {
    if (allStudents.isEmpty) {
      return _buildEmptyState();
    }

    if (filteredStudents.isEmpty) {
      return _buildNoResultsState();
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16),
          child: Row(
            children: [
              Text(
                  '${filteredStudents.length} student${filteredStudents.length != 1 ? 's' : ''}',
                  style: const TextStyle(color: _textSecondary, fontSize: 13)),
              const Spacer(),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: isDesktop
              ? _buildDesktopTable(filteredStudents)
              : _buildMobileList(filteredStudents, isTablet),
        ),
      ],
    );
  }

  Widget _buildDesktopTable(List<Student> students) {
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
                      width: 60,
                      child: Text('ID',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _textSecondary,
                              fontSize: 12))),
                  Expanded(
                      flex: 2,
                      child: Text('NAME',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _textSecondary,
                              fontSize: 12))),
                  SizedBox(
                      width: 80,
                      child: Text('CLASS',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _textSecondary,
                              fontSize: 12))),
                  SizedBox(
                      width: 80,
                      child: Text('SECTION',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _textSecondary,
                              fontSize: 12))),
                  Expanded(
                      child: Text('PHONE',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _textSecondary,
                              fontSize: 12))),
                  Expanded(
                      child: Text('PARENT',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _textSecondary,
                              fontSize: 12))),
                  SizedBox(
                      width: 100,
                      child: Text('ACTIONS',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _textSecondary,
                              fontSize: 12))),
                ],
              ),
            ),
            // Rows
            ...students.map((student) => _buildTableRow(student)),
          ],
        ),
      ),
    );
  }

  Widget _buildTableRow(Student student) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _borderColor, width: 0.5))),
      child: Row(
        children: [
          SizedBox(
              width: 60,
              child: Text('${student.studentId}',
                  style: const TextStyle(color: _textPrimary, fontSize: 13))),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: _accentBlue.withOpacity(0.2),
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
                    child: Text(student.name,
                        style: const TextStyle(
                            color: _textPrimary,
                            fontWeight: FontWeight.w500,
                            fontSize: 13),
                        overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          SizedBox(
              width: 80,
              child: Text(student.className,
                  style: const TextStyle(color: _textPrimary, fontSize: 13))),
          SizedBox(
              width: 80,
              child: Text(student.section,
                  style: const TextStyle(color: _textPrimary, fontSize: 13))),
          Expanded(
              child: Text(student.phoneNumber ?? '-',
                  style: const TextStyle(color: _textSecondary, fontSize: 13))),
          Expanded(
              child: Text(student.parentName ?? '-',
                  style: const TextStyle(color: _textSecondary, fontSize: 13))),
          SizedBox(
            width: 100,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      size: 18, color: _textSecondary),
                  onPressed: () => _showEditStudentDialog(context, student),
                  tooltip: 'Edit',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.payment_outlined,
                      size: 18, color: _accentBlue),
                  onPressed: () {}, // Navigate to fee payment
                  tooltip: 'Collect Fee',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileList(List<Student> students, bool isTablet) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: students.length,
      itemBuilder: (context, index) =>
          _buildStudentCard(students[index], isTablet),
    );
  }

  Widget _buildStudentCard(Student student, bool isTablet) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: _cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor)),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _accentBlue.withOpacity(0.2),
            radius: 22,
            child: Text(
                student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
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
                    'ID: ${student.studentId} • Class ${student.className} - ${student.section}',
                    style:
                        const TextStyle(color: _textSecondary, fontSize: 12)),
                if (student.phoneNumber != null) ...[
                  const SizedBox(height: 2),
                  Text(student.phoneNumber!,
                      style:
                          const TextStyle(color: _textSecondary, fontSize: 12)),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: _textSecondary, size: 20),
            color: _cardDark,
            onSelected: (value) {
              if (value == 'edit') _showEditStudentDialog(context, student);
              if (value == 'fee') {} // Navigate to fee payment
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_outlined, size: 18, color: _textSecondary),
                    SizedBox(width: 8),
                    Text('Edit', style: TextStyle(color: _textPrimary))
                  ])),
              const PopupMenuItem(
                  value: 'fee',
                  child: Row(children: [
                    Icon(Icons.payment_outlined, size: 18, color: _accentBlue),
                    SizedBox(width: 8),
                    Text('Collect Fee', style: TextStyle(color: _textPrimary))
                  ])),
            ],
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
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: _accentBlue.withOpacity(0.1), shape: BoxShape.circle),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 48, color: _textSecondary),
          const SizedBox(height: 16),
          const Text('No students found',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary)),
          const SizedBox(height: 8),
          const Text('Try adjusting your search or filters',
              style: TextStyle(color: _textSecondary)),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
          const SizedBox(height: 16),
          const Text('Error Loading Students',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary)),
          const SizedBox(height: 8),
          Text(error.toString(), style: const TextStyle(color: _textSecondary)),
        ],
      ),
    );
  }

  void _showAddStudentDialog(BuildContext context, String schoolId) {
    _showStudentFormDialog(context, schoolId, null);
  }

  void _showEditStudentDialog(BuildContext context, Student student) {
    _showStudentFormDialog(context, student.schoolId, student);
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
    String selectedClass = existingStudent?.className ?? 'I';
    String selectedSection = existingStudent?.section ?? 'A';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _cardDark,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isEditing ? 'Edit Student' : 'Add New Student',
              style: const TextStyle(
                  color: _textPrimary, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTextField(
                      'Student Name *', nameController, Icons.person_outline),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdownField(
                            'Class *',
                            selectedClass,
                            [
                              'LKG',
                              'UKG',
                              'KG',
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
                            ],
                            (v) => setDialogState(() => selectedClass = v!)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDropdownField(
                            'Section *',
                            selectedSection,
                            ['A', 'B', 'C', 'D'],
                            (v) => setDialogState(() => selectedSection = v!)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                      'Phone Number', phoneController, Icons.phone_outlined),
                  const SizedBox(height: 12),
                  _buildTextField('Parent Name', parentNameController,
                      Icons.family_restroom_outlined),
                  const SizedBox(height: 12),
                  _buildTextField('Parent Phone', parentPhoneController,
                      Icons.phone_outlined),
                  const SizedBox(height: 12),
                  _buildTextField('Parent Email', parentEmailController,
                      Icons.email_outlined),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Cancel', style: TextStyle(color: _textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Student name is required'),
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
                    final currentYearCode =
                        await _getCurrentAcademicYear(schoolId);
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
                      status: StudentStatus.ACTIVE,
                      academicYearCode: currentYearCode,
                      createdAt: now,
                      updatedAt: now,
                    );
                    await repo.createStudent(schoolId, newStudent);

                    // Auto-seed the student's fee ledger from the active
                    // FeeStructureV2 for their class+AY. Non-fatal: student
                    // stays created even if no structure matches (admin can
                    // assign later from the Fee Management empty state).
                    final ledgerMsg = await _autoAssignLedger(
                      schoolId: schoolId,
                      studentId: nextId.toString(),
                      studentName: newStudent.name,
                      className: newStudent.className,
                      section: newStudent.section,
                      academicYear: newStudent.academicYearCode,
                      parentName: newStudent.parentName,
                      parentPhone: newStudent.parentPhone,
                    );
                    if (mounted && ledgerMsg != null) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ledgerMsg),
                        backgroundColor: _accentBlue,
                      ));
                    }
                  }

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            isEditing ? 'Student updated' : 'Student added'),
                        backgroundColor: _accentBlue));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
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
        ),
      ),
    );
  }

  Widget _buildTextField(
      String label, TextEditingController controller, IconData icon) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: _textPrimary),
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

  Widget _buildDropdownField(String label, String value, List<String> items,
      void Function(String?) onChanged) {
    return SearchableDropdown<String>(
      value: items.contains(value) ? value : null,
      hint: label,
      items: items,
      itemLabel: (i) => i,
      onChanged: onChanged,
    );
  }
}
