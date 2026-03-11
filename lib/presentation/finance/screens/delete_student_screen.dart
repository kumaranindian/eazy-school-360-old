import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';

const Color _bgDark = Color(0xFF0D1117);
const Color _cardDark = Color(0xFF161B22);
const Color _accentGreen = Color(0xFF4CAF50);
const Color _textPrimary = Color(0xFFE6EDF3);
const Color _textSecondary = Color(0xFF8B949E);
const Color _borderColor = Color(0xFF30363D);

class DeleteStudentScreen extends ConsumerStatefulWidget {
  const DeleteStudentScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<DeleteStudentScreen> createState() => _DeleteStudentScreenState();
}

class _DeleteStudentScreenState extends ConsumerState<DeleteStudentScreen> {
  String? _selectedClass;
  String? _selectedSection;
  String? _selectedStudentDocId;
  Map<String, dynamic>? _selectedStudent;
  List<String> _classes = [];
  List<String> _sections = [];
  List<Map<String, dynamic>> _students = [];
  bool _isDeleting = false;
  bool _hasPayments = false;

  String? get _schoolId => ref.read(currentSessionProvider)?.schoolId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadClasses());
  }

  Future<void> _loadClasses() async {
    if (_schoolId == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('schools').doc(_schoolId).collection('student_fee_details')
          .get();
      final classSet = <String>{};
      for (final doc in snap.docs) {
        final c = (doc.data()['stuClass'] ?? doc.data()['className'] ?? '').toString();
        if (c.isNotEmpty) classSet.add(c);
      }
      setState(() {
        _classes = classSet.toList()..sort();
      });
    } catch (_) {}
  }

  Future<void> _loadSections() async {
    if (_schoolId == null || _selectedClass == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('schools').doc(_schoolId).collection('student_fee_details')
        .where('stuClass', isEqualTo: _selectedClass)
        .get();
    final sectionSet = <String>{};
    for (final doc in snap.docs) {
      final s = (doc.data()['stuSection'] ?? doc.data()['section'] ?? '').toString();
      if (s.isNotEmpty) sectionSet.add(s);
    }
    setState(() {
      _sections = sectionSet.toList()..sort();
      _selectedSection = null;
      _selectedStudentDocId = null;
      _selectedStudent = null;
      _students = [];
    });
  }

  Future<void> _loadStudents() async {
    if (_schoolId == null || _selectedClass == null || _selectedSection == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('schools').doc(_schoolId).collection('student_fee_details')
        .where('stuClass', isEqualTo: _selectedClass)
        .where('stuSection', isEqualTo: _selectedSection)
        .orderBy('stuName')
        .get();
    setState(() {
      _students = snap.docs.map((d) {
        final data = d.data();
        data['docId'] = d.id;
        return data;
      }).toList();
      _selectedStudentDocId = null;
      _selectedStudent = null;
    });
  }

  Future<void> _checkPaymentHistory() async {
    if (_schoolId == null || _selectedStudent == null) return;
    final stuId = (_selectedStudent!['stuId'] ?? '').toString();
    final snap = await FirebaseFirestore.instance
        .collection('schools').doc(_schoolId).collection('bills')
        .where('billType', isEqualTo: 'Revenue')
        .where('stuId', isEqualTo: stuId)
        .where('isDeleted', isEqualTo: false)
        .limit(1)
        .get();
    setState(() => _hasPayments = snap.docs.isNotEmpty);
  }

  Future<void> _deleteStudent() async {
    if (_schoolId == null || _selectedStudentDocId == null) return;
    setState(() => _isDeleting = true);
    try {
      // Delete from student_fee_details
      await FirebaseFirestore.instance
          .collection('schools').doc(_schoolId).collection('student_fee_details')
          .doc(_selectedStudentDocId).delete();

      // Also delete from students collection if exists
      final stuId = (_selectedStudent?['stuId'] ?? '').toString();
      if (stuId.isNotEmpty) {
        final stuSnap = await FirebaseFirestore.instance
            .collection('schools').doc(_schoolId).collection('students')
            .where('studentId', isEqualTo: stuId)
            .limit(1)
            .get();
        for (final doc in stuSnap.docs) {
          await doc.reference.delete();
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student deleted successfully'), backgroundColor: _accentGreen),
        );
      }
      _clearSelection();
      _loadClasses();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isDeleting = false);
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedClass = null;
      _selectedSection = null;
      _selectedStudentDocId = null;
      _selectedStudent = null;
      _sections = [];
      _students = [];
      _hasPayments = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1024;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 28 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Delete Student', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 4),
          const Text('Remove student records from the system', style: TextStyle(color: _textSecondary)),
          const SizedBox(height: 24),
          _buildWarningBanner(),
          const SizedBox(height: 24),
          _buildSelectionCard(isDesktop),
          if (_selectedStudent != null) ...[
            const SizedBox(height: 24),
            _buildStudentDetails(isDesktop),
          ],
        ],
      ),
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 28),
        const SizedBox(width: 12),
        const Expanded(child: Text(
          'WARNING: This action cannot be undone. Only students without any payment history can be deleted.',
          style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w500),
        )),
      ]),
    );
  }

  Widget _buildSelectionCard(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: _borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _accentGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.search_rounded, color: _accentGreen, size: 20)),
            const SizedBox(width: 12),
            const Text('Select Student', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
          ]),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: isDesktop ? 250 : double.infinity,
                child: _buildDropdown('Select Class', _selectedClass, _classes, (v) {
                  setState(() => _selectedClass = v);
                  _loadSections();
                }),
              ),
              SizedBox(
                width: isDesktop ? 250 : double.infinity,
                child: _buildDropdown('Select Section', _selectedSection, _sections, (v) {
                  setState(() => _selectedSection = v);
                  _loadStudents();
                }),
              ),
              SizedBox(
                width: isDesktop ? 300 : double.infinity,
                child: _buildDropdown(
                  'Select Student',
                  _selectedStudentDocId,
                  _students.map((s) => s['docId'].toString()).toList(),
                  (v) {
                    setState(() {
                      _selectedStudentDocId = v;
                      _selectedStudent = _students.firstWhere((s) => s['docId'].toString() == v, orElse: () => {});
                    });
                    _checkPaymentHistory();
                  },
                  displayMapper: (docId) {
                    final s = _students.firstWhere((s) => s['docId'].toString() == docId, orElse: () => {});
                    return '${s['stuName'] ?? s['studentName'] ?? ''} - ${s['stuId'] ?? ''}';
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.clear_rounded, size: 16),
            label: const Text('Clear Selection'),
            style: OutlinedButton.styleFrom(foregroundColor: _textSecondary, side: const BorderSide(color: _borderColor)),
            onPressed: _clearSelection,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String hint, String? value, List<String> items, Function(String?) onChanged, {String Function(String)? displayMapper}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: _bgDark, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderColor)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: const TextStyle(color: _textSecondary, fontSize: 14)),
          isExpanded: true,
          dropdownColor: _cardDark,
          style: const TextStyle(color: _textPrimary, fontSize: 14),
          items: items.map((v) => DropdownMenuItem(value: v, child: Text(displayMapper != null ? displayMapper(v) : v, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildStudentDetails(bool isDesktop) {
    final s = _selectedStudent!;
    final stuName = (s['stuName'] ?? s['studentName'] ?? 'N/A').toString();
    final stuId = (s['stuId'] ?? 'N/A').toString();
    final stuClass = (s['stuClass'] ?? s['className'] ?? 'N/A').toString();
    final stuSection = (s['stuSection'] ?? s['section'] ?? 'N/A').toString();
    final totalFees = (s['stuTotalFees'] as num?)?.toDouble() ?? 0;
    final paidFees = (s['stuPaidTotalFees'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: _borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Student Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 16),
          Wrap(spacing: 24, runSpacing: 12, children: [
            _infoItem(Icons.person_rounded, 'Name', stuName),
            _infoItem(Icons.badge_rounded, 'ID', stuId),
            _infoItem(Icons.class_rounded, 'Class', stuClass),
            _infoItem(Icons.grid_view_rounded, 'Section', stuSection),
            _infoItem(Icons.currency_rupee_rounded, 'Total Fees', '₹${totalFees.toStringAsFixed(0)}'),
            _infoItem(Icons.check_circle_rounded, 'Paid Fees', '₹${paidFees.toStringAsFixed(0)}'),
          ]),
          const SizedBox(height: 24),
          if (_hasPayments) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3))),
              child: const Row(children: [
                Icon(Icons.info_rounded, color: Color(0xFFF59E0B)),
                SizedBox(width: 12),
                Expanded(child: Text('This student has payment history and cannot be deleted. Delete all associated bills first.', style: TextStyle(color: Color(0xFFF59E0B)))),
              ]),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isDeleting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.delete_forever_rounded),
                label: Text(_isDeleting ? 'Deleting...' : 'Delete Student Permanently'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isDeleting ? null : () => _showConfirmDialog(stuName),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoItem(IconData icon, String label, String value) {
    return SizedBox(
      width: 180,
      child: Row(children: [
        Icon(icon, size: 16, color: _accentGreen),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: _textSecondary)),
          Text(value, style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w500)),
        ]),
      ]),
    );
  }

  void _showConfirmDialog(String studentName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Deletion', style: TextStyle(color: _textPrimary)),
        content: Text('Are you sure you want to permanently delete "$studentName"? This cannot be undone.', style: const TextStyle(color: _textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            onPressed: () { Navigator.pop(ctx); _deleteStudent(); },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
