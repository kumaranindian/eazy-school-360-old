import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:eazy_school_360/core/providers/auth_provider.dart';
import 'package:eazy_school_360/data/repositories/holiday_repository.dart';
import 'package:eazy_school_360/domain/entities/school_holiday.dart';
import 'package:eazy_school_360/presentation/widgets/holiday_calendar_widget.dart';

class HolidayManagementScreen extends ConsumerStatefulWidget {
  const HolidayManagementScreen({super.key});

  @override
  ConsumerState<HolidayManagementScreen> createState() => _HolidayManagementScreenState();
}

class _HolidayManagementScreenState extends ConsumerState<HolidayManagementScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  String _selectedAcademicYear = AcademicYearHelper.getCurrentAcademicYear();

  // Dark theme colors
  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentGreen = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    final isTablet = screenWidth > 600 && screenWidth <= 900;

    if (session == null || !session.isAdmin || session.schoolId == null) {
      return const Scaffold(body: Center(child: Text('Access Denied')));
    }

    return Container(
      color: _bgDark,
      child: Column(
        children: [
          _buildHeader(isDesktop),
          Container(
            color: _cardDark,
            child: TabBar(
              controller: _tabController,
              labelColor: _accentGreen,
              unselectedLabelColor: _textSecondary,
              indicatorColor: _accentGreen,
              indicatorWeight: 3,
              tabs: const [
                Tab(icon: Icon(Icons.calendar_month, size: 20), text: 'Holidays'),
                Tab(icon: Icon(Icons.settings, size: 20), text: 'Settings'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildHolidaysTab(session.schoolId!, isDesktop, isTablet),
                _buildSettingsTab(session.schoolId!, isDesktop),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      color: _bgDark,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Holiday Management',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: isDesktop ? 24 : 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Configure holidays and weekend settings for leave calculations',
                  style: TextStyle(color: _textSecondary, fontSize: isDesktop ? 14 : 12),
                ),
              ],
            ),
          ),
          _buildAcademicYearSelector(),
        ],
      ),
    );
  }

  Widget _buildAcademicYearSelector() {
    final years = _generateAcademicYears();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedAcademicYear,
          dropdownColor: _cardDark,
          style: const TextStyle(color: _textPrimary, fontSize: 14),
          icon: const Icon(Icons.arrow_drop_down, color: _textSecondary),
          items: years.map((year) {
            return DropdownMenuItem(value: year, child: Text('AY $year'));
          }).toList(),
          onChanged: (value) {
            if (value != null) setState(() => _selectedAcademicYear = value);
          },
        ),
      ),
    );
  }

  List<String> _generateAcademicYears() {
    final currentYear = DateTime.now().year;
    return [
      '${currentYear - 1}-${currentYear.toString().substring(2)}',
      '$currentYear-${(currentYear + 1).toString().substring(2)}',
      '${currentYear + 1}-${(currentYear + 2).toString().substring(2)}',
    ];
  }

  // ============ HOLIDAYS TAB ============

  Widget _buildHolidaysTab(String schoolId, bool isDesktop, bool isTablet) {
    final holidaysAsync = ref.watch(
      holidaysByAcademicYearProvider((schoolId: schoolId, academicYear: _selectedAcademicYear)),
    );
    final weekendAsync = ref.watch(weekendConfigStreamProvider(schoolId));
    final weekendDays = weekendAsync.valueOrNull?.weekendDays ?? [7];

    return Column(
      children: [
        _buildCalendarToolbar(schoolId, isDesktop),
        Expanded(
          child: holidaysAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: _accentGreen)),
            error: (error, stack) => _buildErrorState(error.toString()),
            data: (holidays) => HolidayCalendarWidget(
              holidays: holidays,
              weekendDays: weekendDays,
              isAdmin: true,
              onAddHoliday: () => _showAddHolidayDialog(schoolId),
              onEditHoliday: (h) => _showEditHolidayDialog(schoolId, h),
              onDeleteHoliday: (h) => _confirmDeleteHoliday(schoolId, h),
              onToggleHoliday: (h) => _toggleHolidayStatus(schoolId, h),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarToolbar(String schoolId, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: _bgDark,
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: () => _showAddHolidayDialog(schoolId),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Holiday'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _showBulkAddHolidayDialog(schoolId),
            icon: const Icon(Icons.date_range_rounded, size: 18),
            label: const Text('Bulk Add'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF3B82F6),
              side: const BorderSide(color: Color(0xFF3B82F6)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const Spacer(),
          _buildQuickStats(schoolId),
          const SizedBox(width: 8),
          _buildBulkActionsButton(schoolId),
        ],
      ),
    );
  }

  Widget _buildBulkActionsButton(String schoolId) {  // keep
    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _cardDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _borderColor),
        ),
        child: const Icon(Icons.more_vert, color: _textSecondary, size: 20),
      ),
      color: _cardDark,
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'generate_sundays',
          child: Row(
            children: [
              Icon(Icons.auto_awesome, color: _accentGreen, size: 18),
              SizedBox(width: 8),
              Text('Generate Sundays', style: TextStyle(color: _textPrimary)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'remove_sundays',
          child: Row(
            children: [
              Icon(Icons.delete_sweep, color: Colors.orange, size: 18),
              SizedBox(width: 8),
              Text('Remove Sundays', style: TextStyle(color: _textPrimary)),
            ],
          ),
        ),
      ],
      onSelected: (value) => _handleBulkAction(schoolId, value),
    );
  }

  Widget _buildQuickStats(String schoolId) {
    final holidaysAsync = ref.watch(
      holidaysByAcademicYearProvider((schoolId: schoolId, academicYear: _selectedAcademicYear)),
    );

    return holidaysAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (holidays) {
        final publicCount = holidays.where((h) => h.type == HolidayType.PUBLIC).length;
        final schoolCount = holidays.where((h) => h.type == HolidayType.SCHOOL).length;
        final optionalCount = holidays.where((h) => h.type == HolidayType.OPTIONAL).length;

        return Row(
          children: [
            _buildStatChip('Total', holidays.length.toString(), _accentGreen),
            const SizedBox(width: 6),
            _buildStatChip('Public', publicCount.toString(), const Color(0xFF3B82F6)),
            const SizedBox(width: 6),
            _buildStatChip('School', schoolCount.toString(), const Color(0xFF8B5CF6)),
            const SizedBox(width: 6),
            _buildStatChip('Optional', optionalCount.toString(), const Color(0xFFF59E0B)),
          ],
        );
      },
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11)),
        ],
      ),
    );
  }

  // removed: _filterHolidays, _buildHolidaysList, _buildHolidaysTable,
  // _buildHolidayCard, _buildTypeTag, _buildStatusTag, _getTypeColor,
  // _getTypeLabel, _buildEmptyState — all replaced by HolidayCalendarWidget

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text('Error: $error',
              style: const TextStyle(color: _textSecondary)),
        ],
      ),
    );
  }

  // ============ SETTINGS TAB ============

  Widget _buildSettingsTab(String schoolId, bool isDesktop) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWeekendConfigCard(schoolId),
          const SizedBox(height: 24),
          _buildBulkOperationsCard(schoolId),
        ],
      ),
    );
  }

  Widget _buildWeekendConfigCard(String schoolId) {
    final weekendConfigAsync = ref.watch(weekendConfigStreamProvider(schoolId));

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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _accentGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.weekend, color: _accentGreen, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekend Configuration',
                      style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Select which days are considered weekends (excluded from leave calculation)',
                      style: TextStyle(color: _textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          weekendConfigAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: _accentGreen)),
            error: (error, _) => Text('Error: $error', style: const TextStyle(color: Colors.red)),
            data: (config) => _buildWeekendDaySelector(schoolId, config?.weekendDays ?? [7]),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekendDaySelector(String schoolId, List<int> currentWeekendDays) {
    final days = [
      (1, 'Mon'),
      (2, 'Tue'),
      (3, 'Wed'),
      (4, 'Thu'),
      (5, 'Fri'),
      (6, 'Sat'),
      (7, 'Sun'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: days.map((day) {
        final isSelected = currentWeekendDays.contains(day.$1);
        return FilterChip(
          label: Text(day.$2),
          selected: isSelected,
          onSelected: (selected) => _updateWeekendDays(schoolId, currentWeekendDays, day.$1, selected),
          selectedColor: _accentGreen.withValues(alpha: 0.3),
          checkmarkColor: _accentGreen,
          backgroundColor: _bgDark,
          labelStyle: TextStyle(
            color: isSelected ? _accentGreen : _textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
          side: BorderSide(color: isSelected ? _accentGreen : _borderColor),
        );
      }).toList(),
    );
  }

  Widget _buildBulkOperationsCard(String schoolId) {
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome, color: Color(0xFF8B5CF6), size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bulk Operations',
                      style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Quickly generate or remove holidays for the academic year',
                      style: TextStyle(color: _textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: () => _handleBulkAction(schoolId, 'generate_sundays'),
                icon: const Icon(Icons.calendar_today, size: 18),
                label: const Text('Generate All Sundays'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accentGreen,
                  side: const BorderSide(color: _accentGreen),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _handleBulkAction(schoolId, 'remove_sundays'),
                icon: const Icon(Icons.delete_sweep, size: 18),
                label: const Text('Remove All Sundays'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============ ACTIONS ============

  Future<void> _showAddHolidayDialog(String schoolId) async {
    final result = await showDialog<CreateHolidayRequest>(
      context: context,
      builder: (context) => _HolidayFormDialog(
        academicYear: _selectedAcademicYear,
      ),
    );

    if (result != null) {
      try {
        final session = ref.read(currentSessionProvider);
        await ref.read(holidayRepositoryProvider).createHoliday(
              schoolId,
              result,
              session?.uid ?? 'unknown',
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Holiday added successfully'), backgroundColor: _accentGreen),
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

  Future<void> _showEditHolidayDialog(String schoolId, SchoolHoliday holiday) async {
    final result = await showDialog<UpdateHolidayRequest>(
      context: context,
      builder: (context) => _HolidayFormDialog(
        academicYear: _selectedAcademicYear,
        existingHoliday: holiday,
      ),
    );

    if (result != null && result.hasChanges) {
      try {
        await ref.read(holidayRepositoryProvider).updateHoliday(schoolId, holiday.id, result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Holiday updated successfully'), backgroundColor: _accentGreen),
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

  Future<void> _toggleHolidayStatus(String schoolId, SchoolHoliday holiday) async {
    try {
      await ref.read(holidayRepositoryProvider).toggleHolidayStatus(
            schoolId,
            holiday.id,
            !holiday.isActive,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(holiday.isActive ? 'Holiday deactivated' : 'Holiday activated'),
            backgroundColor: _accentGreen,
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

  Future<void> _confirmDeleteHoliday(String schoolId, SchoolHoliday holiday) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardDark,
        title: const Text('Delete Holiday', style: TextStyle(color: _textPrimary)),
        content: Text(
          'Are you sure you want to delete "${holiday.title}"?',
          style: const TextStyle(color: _textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(holidayRepositoryProvider).deleteHoliday(schoolId, holiday.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Holiday deleted'), backgroundColor: _accentGreen),
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

  Future<void> _updateWeekendDays(
    String schoolId,
    List<int> currentDays,
    int day,
    bool selected,
  ) async {
    final newDays = List<int>.from(currentDays);
    if (selected) {
      if (!newDays.contains(day)) newDays.add(day);
    } else {
      newDays.remove(day);
    }
    newDays.sort();

    try {
      final session = ref.read(currentSessionProvider);
      await ref.read(holidayRepositoryProvider).saveWeekendConfig(
            schoolId,
            newDays,
            session?.uid ?? 'unknown',
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showBulkAddHolidayDialog(String schoolId) async {
    final session = ref.read(currentSessionProvider);
    final result = await showDialog<_BulkHolidayRequest>(
      context: context,
      builder: (_) => _BulkHolidayFormDialog(academicYear: _selectedAcademicYear),
    );
    if (result == null) return;
    try {
      final count = await ref.read(holidayRepositoryProvider).createBulkHolidays(
        schoolId,
        result.startDate,
        result.endDate,
        result.title,
        result.description,
        result.type,
        _selectedAcademicYear,
        session?.uid ?? 'unknown',
        skipWeekdays: result.skipWeekdays,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added $count holidays successfully'), backgroundColor: _accentGreen),
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

  Future<void> _handleBulkAction(String schoolId, String action) async {
    final session = ref.read(currentSessionProvider);

    switch (action) {
      case 'generate_sundays':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: _cardDark,
            title: const Text('Generate Sundays', style: TextStyle(color: _textPrimary)),
            content: Text(
              'This will add all Sundays for academic year $_selectedAcademicYear as holidays. Continue?',
              style: const TextStyle(color: _textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: _accentGreen),
                child: const Text('Generate'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          try {
            final count = await ref.read(holidayRepositoryProvider).generateSundaysForYear(
                  schoolId,
                  _selectedAcademicYear,
                  session?.uid ?? 'unknown',
                );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Added $count Sundays'), backgroundColor: _accentGreen),
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
        break;

      case 'remove_sundays':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: _cardDark,
            title: const Text('Remove Sundays', style: TextStyle(color: _textPrimary)),
            content: Text(
              'This will remove all auto-generated Sunday holidays for $_selectedAcademicYear. Continue?',
              style: const TextStyle(color: _textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Remove'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          try {
            final count = await ref.read(holidayRepositoryProvider).removeSundaysForYear(
                  schoolId,
                  _selectedAcademicYear,
                );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Removed $count Sundays'), backgroundColor: _accentGreen),
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
        break;
    }
  }
}

// ============ HOLIDAY FORM DIALOG ============

class _HolidayFormDialog extends StatefulWidget {
  final String academicYear;
  final SchoolHoliday? existingHoliday;

  const _HolidayFormDialog({
    required this.academicYear,
    this.existingHoliday,
  });

  @override
  State<_HolidayFormDialog> createState() => _HolidayFormDialogState();
}

class _HolidayFormDialogState extends State<_HolidayFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late DateTime _selectedDate;
  late HolidayType _selectedType;

  static const Color _cardDark = Color(0xFF161B22);
  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _accentGreen = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existingHoliday?.title ?? '');
    _descriptionController = TextEditingController(text: widget.existingHoliday?.description ?? '');
    _selectedDate = widget.existingHoliday?.date ?? DateTime.now();
    _selectedType = widget.existingHoliday?.type ?? HolidayType.PUBLIC;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingHoliday != null;

    return Dialog(
      backgroundColor: _cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing ? 'Edit Holiday' : 'Add Holiday',
                style: const TextStyle(color: _textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              _buildDatePicker(),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _titleController,
                label: 'Title',
                hint: 'e.g., Republic Day',
                validator: (value) => value?.isEmpty == true ? 'Title is required' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _descriptionController,
                label: 'Description (Optional)',
                hint: 'e.g., National holiday',
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              _buildTypeSelector(),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentGreen,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: Text(isEditing ? 'Update' : 'Add'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _bgDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _borderColor),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: _accentGreen, size: 20),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Date', style: TextStyle(color: _textSecondary, fontSize: 11)),
                const SizedBox(height: 2),
                Text(
                  DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate),
                  style: const TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.arrow_drop_down, color: _textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _textSecondary, fontSize: 12)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: _textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _textSecondary, fontSize: 14),
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
              borderSide: const BorderSide(color: _accentGreen),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Holiday Type', style: TextStyle(color: _textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: HolidayType.values.map((type) {
            final isSelected = _selectedType == type;
            final color = _getTypeColor(type);
            return ChoiceChip(
              label: Text(_getTypeLabel(type)),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) setState(() => _selectedType = type);
              },
              selectedColor: color.withValues(alpha: 0.3),
              backgroundColor: _bgDark,
              labelStyle: TextStyle(
                color: isSelected ? color : _textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide(color: isSelected ? color : _borderColor),
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _getTypeColor(HolidayType type) {
    switch (type) {
      case HolidayType.PUBLIC:
        return const Color(0xFF3B82F6);
      case HolidayType.SCHOOL:
        return const Color(0xFF8B5CF6);
      case HolidayType.OPTIONAL:
        return const Color(0xFFF59E0B);
    }
  }

  String _getTypeLabel(HolidayType type) {
    switch (type) {
      case HolidayType.PUBLIC:
        return 'Public';
      case HolidayType.SCHOOL:
        return 'School';
      case HolidayType.OPTIONAL:
        return 'Optional';
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _accentGreen,
              surface: _cardDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (widget.existingHoliday != null) {
      Navigator.pop(
        context,
        UpdateHolidayRequest(
          date: _selectedDate != widget.existingHoliday!.date ? _selectedDate : null,
          title: _titleController.text != widget.existingHoliday!.title ? _titleController.text : null,
          description: _descriptionController.text != widget.existingHoliday!.description
              ? _descriptionController.text
              : null,
          type: _selectedType != widget.existingHoliday!.type ? _selectedType : null,
        ),
      );
    } else {
      Navigator.pop(
        context,
        CreateHolidayRequest(
          date: _selectedDate,
          title: _titleController.text,
          description: _descriptionController.text,
          type: _selectedType,
          academicYear: widget.academicYear,
        ),
      );
    }
  }
}

// ============ BULK HOLIDAY REQUEST MODEL ============

class _BulkHolidayRequest {
  final DateTime startDate;
  final DateTime endDate;
  final String title;
  final String description;
  final HolidayType type;
  final List<int> skipWeekdays;

  const _BulkHolidayRequest({
    required this.startDate,
    required this.endDate,
    required this.title,
    required this.description,
    required this.type,
    required this.skipWeekdays,
  });
}

// ============ BULK HOLIDAY FORM DIALOG ============

class _BulkHolidayFormDialog extends StatefulWidget {
  final String academicYear;
  const _BulkHolidayFormDialog({required this.academicYear});

  @override
  State<_BulkHolidayFormDialog> createState() => _BulkHolidayFormDialogState();
}

class _BulkHolidayFormDialogState extends State<_BulkHolidayFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 6));
  HolidayType _selectedType = HolidayType.SCHOOL;
  // Weekdays to skip (1=Mon..7=Sun). Default: skip Sunday (7)
  final Set<int> _skipWeekdays = {7};

  static const Color _cardDark    = Color(0xFF161B22);
  static const Color _bgDark      = Color(0xFF0D1117);
  static const Color _accentGreen = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  int get _dayCount {
    int count = 0;
    var d = _startDate;
    while (!d.isAfter(_endDate)) {
      if (!_skipWeekdays.contains(d.weekday)) count++;
      d = d.add(const Duration(days: 1));
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF1C2128),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: _borderColor)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.date_range_rounded, color: Color(0xFF3B82F6), size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bulk Add Holidays', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('Configure multiple days at once', style: TextStyle(color: _textSecondary, fontSize: 11)),
                  ],
                )),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: _textSecondary, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]),
            ),
            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date range row
                      Row(children: [
                        Expanded(child: _buildDateTile('Start Date', _startDate, (d) => setState(() {
                          _startDate = d;
                          if (_endDate.isBefore(_startDate)) _endDate = _startDate;
                        }))),
                        const SizedBox(width: 12),
                        Expanded(child: _buildDateTile('End Date', _endDate, (d) => setState(() => _endDate = d))),
                      ]),
                      const SizedBox(height: 12),
                      // Preview chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _accentGreen.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _accentGreen.withOpacity(0.2)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.info_outline, color: _accentGreen, size: 15),
                          const SizedBox(width: 8),
                          Text('$_dayCount day(s) will be added (excluding skipped weekdays)',
                              style: const TextStyle(color: _accentGreen, fontSize: 12)),
                        ]),
                      ),
                      const SizedBox(height: 16),
                      // Title
                      _buildTextField(
                        controller: _titleController,
                        label: 'Holiday Title',
                        hint: 'e.g., Summer Vacation',
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                      ),
                      const SizedBox(height: 12),
                      // Description
                      _buildTextField(
                        controller: _descriptionController,
                        label: 'Description (Optional)',
                        hint: 'e.g., School summer break',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      // Type selector
                      _buildTypeSelector(),
                      const SizedBox(height: 16),
                      // Skip weekdays
                      _buildSkipWeekdaysSelector(),
                      const SizedBox(height: 20),
                      // Actions
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _dayCount == 0 ? null : _submit,
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: Text('Add $_dayCount Holiday${_dayCount == 1 ? '' : 's'}'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accentGreen,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: _borderColor,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTile(String label, DateTime date, ValueChanged<DateTime> onPicked) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.dark(primary: _accentGreen, surface: _cardDark)),
            child: child!,
          ),
        );
        if (picked != null) onPicked(picked);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _bgDark, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderColor)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: _textSecondary, fontSize: 11)),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.calendar_today, color: _accentGreen, size: 14),
            const SizedBox(width: 6),
            Text(DateFormat('dd MMM yyyy').format(date), style: const TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
          ]),
        ]),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: _textSecondary, fontSize: 12)),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: _textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _textSecondary, fontSize: 13),
          filled: true, fillColor: _bgDark,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _borderColor)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _borderColor)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _accentGreen)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        validator: validator,
      ),
    ]);
  }

  Widget _buildTypeSelector() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Holiday Type', style: TextStyle(color: _textSecondary, fontSize: 12)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: HolidayType.values.map((type) {
        final isSelected = _selectedType == type;
        final color = _typeColor(type);
        return ChoiceChip(
          label: Text(_typeLabel(type)),
          selected: isSelected,
          onSelected: (s) { if (s) setState(() => _selectedType = type); },
          selectedColor: color.withOpacity(0.3),
          backgroundColor: _bgDark,
          labelStyle: TextStyle(color: isSelected ? color : _textSecondary, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal),
          side: BorderSide(color: isSelected ? color : _borderColor),
        );
      }).toList()),
    ]);
  }

  Widget _buildSkipWeekdaysSelector() {
    const days = [(1,'Mon'),(2,'Tue'),(3,'Wed'),(4,'Thu'),(5,'Fri'),(6,'Sat'),(7,'Sun')];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Skip Weekdays', style: TextStyle(color: _textSecondary, fontSize: 12)),
      const SizedBox(height: 4),
      const Text('Days to exclude from bulk creation', style: TextStyle(color: _textSecondary, fontSize: 11)),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: days.map((d) {
        final isSkipped = _skipWeekdays.contains(d.$1);
        return FilterChip(
          label: Text(d.$2, style: TextStyle(fontSize: 12, color: isSkipped ? Colors.orange : _textSecondary)),
          selected: isSkipped,
          onSelected: (s) => setState(() { if (s) _skipWeekdays.add(d.$1); else _skipWeekdays.remove(d.$1); }),
          selectedColor: Colors.orange.withOpacity(0.2),
          backgroundColor: _bgDark,
          checkmarkColor: Colors.orange,
          side: BorderSide(color: isSkipped ? Colors.orange : _borderColor),
        );
      }).toList()),
    ]);
  }

  Color _typeColor(HolidayType type) {
    switch (type) {
      case HolidayType.PUBLIC: return const Color(0xFF3B82F6);
      case HolidayType.SCHOOL: return const Color(0xFF8B5CF6);
      case HolidayType.OPTIONAL: return const Color(0xFFF59E0B);
    }
  }

  String _typeLabel(HolidayType type) {
    switch (type) {
      case HolidayType.PUBLIC: return 'Public';
      case HolidayType.SCHOOL: return 'School';
      case HolidayType.OPTIONAL: return 'Optional';
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_endDate.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date must be after start date'), backgroundColor: Colors.red),
      );
      return;
    }
    Navigator.pop(context, _BulkHolidayRequest(
      startDate: _startDate,
      endDate: _endDate,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      type: _selectedType,
      skipWeekdays: _skipWeekdays.toList(),
    ));
  }
}
