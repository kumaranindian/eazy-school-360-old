import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../data/repositories/academic_year_repository.dart';
import '../../../data/services/academic_year_migration_service.dart';
import '../../../domain/entities/academic_year.dart';

class AcademicYearManagementScreen extends ConsumerStatefulWidget {
  const AcademicYearManagementScreen({super.key});

  @override
  ConsumerState<AcademicYearManagementScreen> createState() => _AcademicYearManagementScreenState();
}

class _AcademicYearManagementScreenState extends ConsumerState<AcademicYearManagementScreen> {
  bool _isInitializing = false;
  bool _isMigrating = false;
  Map<String, dynamic>? _migrationResult;

  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

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
    final academicYearsAsync = ref.watch(schoolAcademicYearsProvider(schoolId));
    final fiscalYearsAsync = ref.watch(schoolFiscalYearsProvider(schoolId));

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
                  _buildQuickActions(schoolId, isDesktop),
                  const SizedBox(height: 24),
                  _buildAcademicYearsSection(academicYearsAsync, schoolId, isDesktop),
                  const SizedBox(height: 24),
                  _buildFiscalYearsSection(fiscalYearsAsync, schoolId, isDesktop),
                  if (_migrationResult != null) ...[
                    const SizedBox(height: 24),
                    _buildMigrationResult(_migrationResult!, isDesktop),
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
            child: const Icon(Icons.calendar_today, color: _accentBlue, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Academic Year Management',
                  style: TextStyle(
                    fontSize: isDesktop ? 20 : 17,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Manage academic and fiscal years for your school',
                  style: TextStyle(color: _textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(String schoolId, bool isDesktop) {
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
            'Quick Actions',
            style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildActionButton(
                'Initialize Years',
                Icons.add_circle_outline,
                _isInitializing ? null : () => _initializeYears(schoolId),
                _isInitializing,
              ),
              _buildActionButton(
                'Run Migration',
                Icons.sync,
                _isMigrating ? null : () => _runMigration(schoolId),
                _isMigrating,
              ),
              _buildActionButton(
                'Verify Migration',
                Icons.check_circle_outline,
                () => _verifyMigration(schoolId),
                false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback? onPressed, bool isLoading) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
          : Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: ElevatedButton.styleFrom(
        backgroundColor: _accentBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildAcademicYearsSection(AsyncValue<List<AcademicYear>> yearsAsync, String schoolId, bool isDesktop) {
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
            'Academic Years (May - April)',
            style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          yearsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: _accentBlue)),
            error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
            data: (years) {
              if (years.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No academic years found. Click "Initialize Years" to create them.',
                      style: TextStyle(color: _textSecondary, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return Column(
                children: years.map((year) => _buildYearCard(year, schoolId, true)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFiscalYearsSection(AsyncValue<List<FiscalYear>> yearsAsync, String schoolId, bool isDesktop) {
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
            'Fiscal Years (April - March)',
            style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          yearsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: _accentBlue)),
            error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
            data: (years) {
              if (years.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No fiscal years found. Click "Initialize Years" to create them.',
                      style: TextStyle(color: _textSecondary, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return Column(
                children: years.map((year) => _buildYearCard(year, schoolId, false)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildYearCard(dynamic year, String schoolId, bool isAcademic) {
    final yearCode = isAcademic ? (year as AcademicYear).yearCode : (year as FiscalYear).yearCode;
    final startDate = isAcademic ? (year as AcademicYear).startDate : (year as FiscalYear).startDate;
    final endDate = isAcademic ? (year as AcademicYear).endDate : (year as FiscalYear).endDate;
    final isCurrent = isAcademic ? (year as AcademicYear).isCurrent : (year as FiscalYear).isCurrent;
    final id = isAcademic ? (year as AcademicYear).id : (year as FiscalYear).id;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCurrent ? _accentBlue.withValues(alpha: 0.1) : _bgDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isCurrent ? _accentBlue : _borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      yearCode,
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _accentBlue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'CURRENT',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatDate(startDate)} - ${_formatDate(endDate)}',
                  style: const TextStyle(color: _textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          if (!isCurrent)
            TextButton(
              onPressed: () => _setCurrentYear(schoolId, id, isAcademic),
              child: const Text('Set Current', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _buildMigrationResult(Map<String, dynamic> result, bool isDesktop) {
    final success = result['success'] == true;
    
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
              Text(
                success ? 'Operation Successful' : 'Operation Failed',
                style: TextStyle(
                  color: success ? _accentBlue : Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            (result['message'] as String?) ?? result.toString(),
            style: const TextStyle(color: _textPrimary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Future<void> _initializeYears(String schoolId) async {
    setState(() => _isInitializing = true);

    try {
      final migrationService = AcademicYearMigrationService();
      final result = await migrationService.initializeYearsForSchool(schoolId);

      setState(() {
        _migrationResult = result;
        _isInitializing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text((result['message'] as String?) ?? 'Years initialized'),
            backgroundColor: result['success'] == true ? _accentBlue : Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _migrationResult = {'success': false, 'error': e.toString()};
        _isInitializing = false;
      });
    }
  }

  Future<void> _runMigration(String schoolId) async {
    setState(() => _isMigrating = true);

    try {
      final migrationService = AcademicYearMigrationService();
      final result = await migrationService.runCompleteMigration(schoolId);

      setState(() {
        _migrationResult = result;
        _isMigrating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text((result['message'] as String?) ?? 'Migration completed'),
            backgroundColor: result['success'] == true ? _accentBlue : Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _migrationResult = {'success': false, 'error': e.toString()};
        _isMigrating = false;
      });
    }
  }

  Future<void> _verifyMigration(String schoolId) async {
    try {
      final migrationService = AcademicYearMigrationService();
      final result = await migrationService.verifyMigration(schoolId);

      setState(() => _migrationResult = result);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['migrationComplete'] == true
                  ? 'Migration verified successfully'
                  : 'Migration incomplete. ${result['studentsWithoutYear']} students need year assignment.',
            ),
            backgroundColor: result['migrationComplete'] == true ? _accentBlue : Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() => _migrationResult = {'success': false, 'error': e.toString()});
    }
  }

  Future<void> _setCurrentYear(String schoolId, String yearId, bool isAcademic) async {
    try {
      final repo = ref.read(academicYearRepositoryProvider);
      
      if (isAcademic) {
        await repo.setCurrentAcademicYear(schoolId, yearId);
      } else {
        await repo.setCurrentFiscalYear(schoolId, yearId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Current ${isAcademic ? "academic" : "fiscal"} year updated'),
            backgroundColor: _accentBlue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
