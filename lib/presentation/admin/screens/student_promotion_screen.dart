import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../data/services/student_promotion_service.dart';
import '../../shared/widgets/searchable_dropdown.dart';
import '../../shared/widgets/year_selector_widget.dart';

class StudentPromotionScreen extends ConsumerStatefulWidget {
  const StudentPromotionScreen({super.key});

  @override
  ConsumerState<StudentPromotionScreen> createState() => _StudentPromotionScreenState();
}

class _StudentPromotionScreenState extends ConsumerState<StudentPromotionScreen> {
  final _promotionService = StudentPromotionService();
  
  String? _selectedClass;
  String? _selectedSection;
  String? _fromAcademicYear;
  String? _toAcademicYear;
  String? _toClass;
  String? _toSection;
  
  bool _isPromoting = false;
  Map<String, dynamic>? _lastResult;

  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  static const List<String> _classes = ['Pre-KG', 'LKG', 'UKG', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI', 'XII'];
  static const List<String> _sections = ['A', 'B', 'C', 'D', 'E'];

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;

    if (session?.schoolId == null) {
      return const Scaffold(
        backgroundColor: _bgDark,
        body: Center(child: Text('Access Denied', style: TextStyle(color: _textPrimary))),
      );
    }

    final schoolId = session!.schoolId!;

    return Scaffold(
      backgroundColor: _bgDark,
      body: Column(
        children: [
          _buildHeader(isDesktop),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isDesktop ? 24 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPromotionForm(schoolId, isDesktop),
                  if (_lastResult != null) ...[
                    const SizedBox(height: 24),
                    _buildResultCard(_lastResult!, isDesktop),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      decoration: const BoxDecoration(
        color: _cardDark,
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
            child: const Icon(Icons.school_rounded, color: _accentBlue, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Student Promotion',
                  style: TextStyle(
                    fontSize: isDesktop ? 20 : 17,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Promote students to next class and academic year',
                  style: TextStyle(color: _textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromotionForm(String schoolId, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Promotion Details',
            style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          // From Academic Year
          YearSelectorWidget(
            schoolId: schoolId,
            selectedYearCode: _fromAcademicYear,
            onYearChanged: (year) => setState(() => _fromAcademicYear = year),
            label: 'From Academic Year',
          ),
          const SizedBox(height: 16),
          
          // To Academic Year
          YearSelectorWidget(
            schoolId: schoolId,
            selectedYearCode: _toAcademicYear,
            onYearChanged: (year) => setState(() => _toAcademicYear = year),
            label: 'To Academic Year',
          ),
          const SizedBox(height: 16),
          
          // From Class
          _buildLabel('From Class'),
          SearchableDropdown<String>(
            value: _selectedClass,
            items: _classes,
            itemLabel: (item) => 'Class $item',
            onChanged: (value) => setState(() {
              _selectedClass = value;
              _toClass = value != null ? _promotionService.getNextClass(value) : null;
            }),
            hint: 'Select Class',
          ),
          const SizedBox(height: 16),
          
          // From Section
          _buildLabel('From Section'),
          SearchableDropdown<String>(
            value: _selectedSection,
            items: _sections,
            itemLabel: (item) => 'Section $item',
            onChanged: (value) => setState(() {
              _selectedSection = value;
              _toSection = value; // Default to same section
            }),
            hint: 'Select Section',
          ),
          const SizedBox(height: 24),
          
          const Divider(color: _borderColor),
          const SizedBox(height: 16),
          
          const Text(
            'Target Details (Optional)',
            style: TextStyle(color: _textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          
          // To Class (auto-filled but editable)
          _buildLabel('To Class (Auto-detected)'),
          SearchableDropdown<String>(
            value: _toClass,
            items: _classes,
            itemLabel: (item) => 'Class $item',
            onChanged: (value) => setState(() => _toClass = value),
            hint: 'Auto-detected',
          ),
          const SizedBox(height: 16),
          
          // To Section
          _buildLabel('To Section'),
          SearchableDropdown<String>(
            value: _toSection,
            items: _sections,
            itemLabel: (item) => 'Section $item',
            onChanged: (value) => setState(() => _toSection = value),
            hint: 'Same as from section',
          ),
          const SizedBox(height: 24),
          
          // Promote Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _canPromote() ? _performPromotion : null,
              icon: _isPromoting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_upward, size: 20),
              label: Text(_isPromoting ? 'Promoting...' : 'Promote Class', style: const TextStyle(fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(color: _textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  bool _canPromote() {
    return !_isPromoting &&
        _selectedClass != null &&
        _selectedSection != null &&
        _fromAcademicYear != null &&
        _toAcademicYear != null;
  }

  Future<void> _performPromotion() async {
    final session = ref.read(currentSessionProvider);
    if (session?.schoolId == null) return;

    setState(() {
      _isPromoting = true;
      _lastResult = null;
    });

    try {
      final result = await _promotionService.bulkPromoteClass(
        schoolId: session!.schoolId!,
        fromClass: _selectedClass!,
        fromSection: _selectedSection!,
        fromAcademicYear: _fromAcademicYear!,
        toAcademicYear: _toAcademicYear!,
        promotedBy: session.uid,
        toClass: _toClass,
        toSection: _toSection,
      );

      setState(() {
        _lastResult = result;
        _isPromoting = false;
      });

      if (mounted && result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text((result['message'] as String?) ?? 'Promotion completed'),
            backgroundColor: _accentBlue,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _lastResult = {'success': false, 'error': e.toString()};
        _isPromoting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildResultCard(Map<String, dynamic> result, bool isDesktop) {
    final success = result['success'] == true;
    final successCount = result['successCount'] as int? ?? 0;
    final graduatedCount = result['graduatedCount'] as int? ?? 0;
    final errorCount = result['errorCount'] as int? ?? 0;
    final totalStudents = result['totalStudents'] as int? ?? 0;
    final fromClass = result['fromClass'] as String? ?? '';
    final toClass = result['toClass'] as String? ?? '';
    final arrearsCreated = result['totalArrearsCreated'] as double? ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: success ? _accentBlue.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: success ? _accentBlue : Colors.red),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                success ? Icons.check_circle : Icons.error,
                color: success ? _accentBlue : Colors.red,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  success ? 'Promotion Completed' : 'Promotion Failed',
                  style: TextStyle(
                    color: success ? _accentBlue : Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (success) ...[
            const SizedBox(height: 16),
            _buildResultRow('Total Students', '$totalStudents'),
            _buildResultRow('Promoted', '$successCount ($fromClass → $toClass)'),
            if (graduatedCount > 0) _buildResultRow('Graduated', '$graduatedCount'),
            if (errorCount > 0) _buildResultRow('Errors', '$errorCount', isError: true),
            if (arrearsCreated > 0) _buildResultRow('Total Arrears Created', '₹${arrearsCreated.toStringAsFixed(2)}'),
          ] else ...[
            const SizedBox(height: 12),
            Text(
              result['error']?.toString() ?? 'Unknown error',
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: _textSecondary, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              color: isError ? Colors.orange : _textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
