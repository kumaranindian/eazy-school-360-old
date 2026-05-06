import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eazy_school_360/core/providers/auth_provider.dart';
import 'package:eazy_school_360/data/repositories/holiday_repository.dart';
import 'package:eazy_school_360/domain/entities/school_holiday.dart';
import 'package:eazy_school_360/presentation/widgets/holiday_calendar_widget.dart';

class HolidayCalendarScreen extends ConsumerStatefulWidget {
  const HolidayCalendarScreen({super.key});

  @override
  ConsumerState<HolidayCalendarScreen> createState() => _HolidayCalendarScreenState();
}

class _HolidayCalendarScreenState extends ConsumerState<HolidayCalendarScreen> {
  String _selectedAcademicYear = AcademicYearHelper.getCurrentAcademicYear();

  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentGreen = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  List<String> _generateAcademicYears() {
    final y = DateTime.now().year;
    return [
      '${y - 1}-$y',
      '$y-${y + 1}',
      '${y + 1}-${y + 2}',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider);
    final isDesktop = MediaQuery.of(context).size.width > 900;

    if (session == null || session.schoolId == null) {
      return const Scaffold(
          backgroundColor: _bgDark,
          body: Center(child: Text('Access Denied', style: TextStyle(color: _textPrimary))));
    }

    final schoolId = session.schoolId!;
    final holidaysAsync = ref.watch(
      holidaysByAcademicYearProvider(
          (schoolId: schoolId, academicYear: _selectedAcademicYear)),
    );
    final weekendAsync = ref.watch(weekendConfigStreamProvider(schoolId));
    final weekendDays = weekendAsync.valueOrNull?.weekendDays ?? [7];

    return Container(
      color: _bgDark,
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────
          Container(
            padding: EdgeInsets.all(isDesktop ? 24 : 16),
            color: _bgDark,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Holiday Calendar',
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: isDesktop ? 24 : 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'View all holidays and non-working days',
                        style: TextStyle(
                            color: _textSecondary,
                            fontSize: isDesktop ? 14 : 12),
                      ),
                    ],
                  ),
                ),
                // Academic year selector
                Container(
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
                      items: _generateAcademicYears()
                          .map((y) => DropdownMenuItem(
                              value: y, child: Text('AY $y')))
                          .toList(),
                      onChanged: (v) {
                        if (v != null)
                          setState(() => _selectedAcademicYear = v);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Calendar body ────────────────────────────────────────
          Expanded(
            child: holidaysAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator(color: _accentGreen)),
              error: (e, _) => Center(
                  child: Text('Error: $e',
                      style: const TextStyle(color: Colors.red))),
              data: (holidays) => HolidayCalendarWidget(
                holidays: holidays,
                weekendDays: weekendDays,
                isAdmin: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

}
