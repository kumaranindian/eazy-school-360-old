import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../domain/entities/staff_profile.dart';
import '../../../domain/entities/app_user.dart';

class ClassTeacherAssignmentScreen extends ConsumerStatefulWidget {
  const ClassTeacherAssignmentScreen({super.key});

  @override
  ConsumerState<ClassTeacherAssignmentScreen> createState() => _ClassTeacherAssignmentScreenState();
}

class _ClassTeacherAssignmentScreenState extends ConsumerState<ClassTeacherAssignmentScreen> {
  List<StaffProfile> _allStaff = [];
  List<_ClassSectionEntry> _classSections = [];
  bool _isLoading = true;
  bool _isSaving = false;

  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  static const List<String> _classOrder = [
    'Pre-KG', 'LKG', 'UKG', 'I', 'II', 'III', 'IV', 'V',
    'VI', 'VII', 'VIII', 'IX', 'X', 'XI', 'XII',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  String? get _schoolId => ref.read(currentSessionProvider)?.schoolId;

  Future<void> _loadData() async {
    final schoolId = _schoolId;
    if (schoolId == null) return;
    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseFirestore.instance;

      // Load all active teaching staff
      final staffSnap = await firestore
          .collection('schools').doc(schoolId).collection('staff')
          .where('status', isEqualTo: 'ACTIVE')
          .get();
      final staff = staffSnap.docs.map((d) => StaffProfile.fromFirestore(d)).toList();

      // Load all students to derive class/section combos
      final studentSnap = await firestore
          .collection('schools').doc(schoolId).collection('students')
          .get();

      final csSet = <String>{};
      for (final doc in studentSnap.docs) {
        final data = doc.data();
        final cls = data['className'] as String? ?? '';
        final sec = data['section'] as String? ?? '';
        if (cls.isNotEmpty && sec.isNotEmpty) csSet.add('$cls|$sec');
      }

      // Build entries sorted by class order then section
      final entries = csSet.map((cs) {
        final parts = cs.split('|');
        return _ClassSectionEntry(className: parts[0], section: parts[1]);
      }).toList();

      entries.sort((a, b) {
        final ia = _classOrder.indexOf(a.className);
        final ib = _classOrder.indexOf(b.className);
        final ca = ia != -1 ? ia : 100;
        final cb = ib != -1 ? ib : 100;
        if (ca != cb) return ca.compareTo(cb);
        return a.section.compareTo(b.section);
      });

      // Populate current assignments - disabled as class assignment fields removed
      for (final entry in entries) {
        entry.assignedStaffId = null;
      }

      if (mounted) {
        setState(() {
          _allStaff = staff;
          _classSections = entries;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading class teacher data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAssignment(_ClassSectionEntry entry, String? newStaffId) async {
    // Class teacher assignment disabled - fields removed from StaffProfile
    // This functionality is no longer available
    setState(() => _isSaving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Class teacher assignment is no longer available'),
          backgroundColor: Colors.orange,
        ),
      );
    }
    return;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _accentBlue));
    }

    return Column(
      children: [
        // Header
        Container(
          padding: EdgeInsets.fromLTRB(isDesktop ? 24 : 16, isDesktop ? 20 : 16, isDesktop ? 24 : 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Class Teacher Assignments',
                      style: TextStyle(fontSize: isDesktop ? 20 : 17, fontWeight: FontWeight.bold, color: _textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_classSections.length} class-sections • ${_classSections.where((e) => e.assignedStaffId != null).length} assigned',
                      style: const TextStyle(color: _textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _isLoading ? null : _loadData,
                icon: const Icon(Icons.refresh_rounded, color: _textSecondary),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: _classSections.isEmpty
              ? const Center(child: Text('No class/section data found. Add students first.', style: TextStyle(color: _textSecondary)))
              : isDesktop
                  ? _buildDesktopTable()
                  : _buildMobileList(),
        ),
      ],
    );
  }

  Widget _buildDesktopTable() {
    final teachingStaff = _allStaff.where((s) => s.staffType == StaffType.TEACHING && s.isActive).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor)),
      child: Column(
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _borderColor))),
            child: const Row(
              children: [
                SizedBox(width: 120, child: Text('CLASS', style: TextStyle(fontWeight: FontWeight.w600, color: _textSecondary, fontSize: 11))),
                SizedBox(width: 80, child: Text('SECTION', style: TextStyle(fontWeight: FontWeight.w600, color: _textSecondary, fontSize: 11))),
                Expanded(child: Text('ASSIGNED TEACHER', style: TextStyle(fontWeight: FontWeight.w600, color: _textSecondary, fontSize: 11))),
                SizedBox(width: 100, child: Text('STATUS', style: TextStyle(fontWeight: FontWeight.w600, color: _textSecondary, fontSize: 11))),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _classSections.length,
              itemBuilder: (context, index) {
                final entry = _classSections[index];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _borderColor, width: 0.5))),
                  child: Row(
                    children: [
                      SizedBox(width: 120, child: Text(entry.className, style: const TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w600))),
                      SizedBox(width: 80, child: Text(entry.section, style: const TextStyle(color: _textPrimary, fontSize: 14))),
                      Expanded(
                        child: _isSaving
                            ? const Text('Saving...', style: TextStyle(color: _textSecondary, fontSize: 13))
                            : DropdownButtonHideUnderline(
                                child: DropdownButton<String?>(
                                  value: entry.assignedStaffId,
                                  hint: const Text('Select teacher...', style: TextStyle(color: _textSecondary, fontSize: 13)),
                                  dropdownColor: _cardDark,
                                  isExpanded: true,
                                  style: const TextStyle(color: _textPrimary, fontSize: 13),
                                  items: [
                                    const DropdownMenuItem<String?>(value: null, child: Text('-- None --', style: TextStyle(color: Colors.orange, fontSize: 13))),
                                    ...teachingStaff.map((s) => DropdownMenuItem(
                                      value: s.id,
                                      child: Text('${s.name} (${s.employeeId})', style: const TextStyle(color: _textPrimary, fontSize: 13)),
                                    )),
                                  ],
                                  onChanged: (val) => _saveAssignment(entry, val),
                                ),
                              ),
                      ),
                      SizedBox(
                        width: 100,
                        child: entry.assignedStaffId != null
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: _accentBlue.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle, size: 14, color: _accentBlue),
                                    SizedBox(width: 4),
                                    Text('Assigned', style: TextStyle(color: _accentBlue, fontSize: 11, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange),
                                    SizedBox(width: 4),
                                    Text('Vacant', style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileList() {
    final teachingStaff = _allStaff.where((s) => s.staffType == StaffType.TEACHING && s.isActive).toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _classSections.length,
      itemBuilder: (context, index) {
        final entry = _classSections[index];
        final hasAssignment = entry.assignedStaffId != null;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: _accentBlue.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                    child: Text('${entry.className} - ${entry.section}',
                        style: const TextStyle(color: _accentBlue, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  const Spacer(),
                  if (hasAssignment)
                    const Icon(Icons.check_circle, size: 18, color: _accentBlue)
                  else
                    const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Class Teacher', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String?>(
                value: entry.assignedStaffId,
                hint: const Text('Select teacher...', style: TextStyle(color: _textSecondary, fontSize: 13)),
                dropdownColor: _cardDark,
                isExpanded: true,
                style: const TextStyle(color: _textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: _bgDark,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _borderColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _borderColor)),
                ),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('-- None --', style: TextStyle(color: Colors.orange, fontSize: 13))),
                  ...teachingStaff.map((s) => DropdownMenuItem(
                    value: s.id,
                    child: Text('${s.name} (${s.employeeId})', style: const TextStyle(color: _textPrimary, fontSize: 13)),
                  )),
                ],
                onChanged: _isSaving ? null : (val) => _saveAssignment(entry, val),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ClassSectionEntry {
  final String className;
  final String section;
  String? assignedStaffId;

  _ClassSectionEntry({required this.className, required this.section});
}
