import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:eazy_school_360/domain/entities/school_holiday.dart';

/// Shared calendar widget used by both Admin and Staff holiday screens.
/// Shows a monthly grid with holidays highlighted and a side/bottom panel
/// listing the holidays for the focused month.
class HolidayCalendarWidget extends StatefulWidget {
  final List<SchoolHoliday> holidays;
  final List<int> weekendDays; // e.g. [7] for Sunday, [6,7] for Sat+Sun
  final bool isAdmin;
  final void Function(SchoolHoliday)? onEditHoliday;
  final void Function(SchoolHoliday)? onDeleteHoliday;
  final void Function(SchoolHoliday)? onToggleHoliday;
  final VoidCallback? onAddHoliday;

  const HolidayCalendarWidget({
    super.key,
    required this.holidays,
    this.weekendDays = const [7],
    this.isAdmin = false,
    this.onEditHoliday,
    this.onDeleteHoliday,
    this.onToggleHoliday,
    this.onAddHoliday,
  });

  @override
  State<HolidayCalendarWidget> createState() => _HolidayCalendarWidgetState();
}

class _HolidayCalendarWidgetState extends State<HolidayCalendarWidget> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;

  // Dark theme
  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentGreen = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  // ── helpers ──────────────────────────────────────────────────────────────

  Map<DateTime, List<SchoolHoliday>> get _holidayMap {
    final map = <DateTime, List<SchoolHoliday>>{};
    for (final h in widget.holidays) {
      if (!h.isActive) continue;
      final key = DateTime(h.date.year, h.date.month, h.date.day);
      map.putIfAbsent(key, () => []).add(h);
    }
    return map;
  }

  List<SchoolHoliday> get _monthHolidays {
    return widget.holidays
        .where((h) =>
            h.isActive &&
            h.date.year == _focusedMonth.year &&
            h.date.month == _focusedMonth.month)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  List<SchoolHoliday> _dayHolidays(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _holidayMap[key] ?? [];
  }

  bool _isWeekend(DateTime d) => widget.weekendDays.contains(d.weekday);
  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  Color _typeColor(HolidayType t) {
    switch (t) {
      case HolidayType.PUBLIC:
        return const Color(0xFF3B82F6);
      case HolidayType.SCHOOL:
        return const Color(0xFF8B5CF6);
      case HolidayType.OPTIONAL:
        return const Color(0xFFF59E0B);
    }
  }

  String _typeLabel(HolidayType t) {
    switch (t) {
      case HolidayType.PUBLIC:
        return 'Public';
      case HolidayType.SCHOOL:
        return 'School';
      case HolidayType.OPTIONAL:
        return 'Optional';
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isDesktop = w > 900;

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: _buildCalendarPanel()),
          Container(width: 1, color: _borderColor),
          SizedBox(width: 320, child: _buildSidePanel()),
        ],
      );
    }
    return Column(
      children: [
        _buildCalendarPanel(),
        const Divider(color: _borderColor, height: 1),
        _buildSidePanel(),
      ],
    );
  }

  // ── calendar panel ────────────────────────────────────────────────────────

  Widget _buildCalendarPanel() {
    return Container(
      color: _bgDark,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMonthHeader(),
            _buildWeekdayRow(),
            _buildDayGrid(),
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: _textPrimary, size: 22),
            onPressed: () => setState(() {
              _focusedMonth =
                  DateTime(_focusedMonth.year, _focusedMonth.month - 1);
              _selectedDay = null;
            }),
          ),
          Expanded(
            child: Text(
              DateFormat('MMMM yyyy').format(_focusedMonth),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon:
                const Icon(Icons.chevron_right, color: _textPrimary, size: 22),
            onPressed: () => setState(() {
              _focusedMonth =
                  DateTime(_focusedMonth.year, _focusedMonth.month + 1);
              _selectedDay = null;
            }),
          ),
          // Jump to today
          TextButton(
            onPressed: () => setState(() {
              _focusedMonth =
                  DateTime(DateTime.now().year, DateTime.now().month);
              _selectedDay = null;
            }),
            child: const Text('Today',
                style: TextStyle(color: _accentGreen, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayRow() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Container(
      color: _cardDark,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: days.map((d) {
          final isWknd = d == 'Sat' || d == 'Sun';
          return Expanded(
            child: Center(
              child: Text(
                d,
                style: TextStyle(
                  color: isWknd
                      ? Colors.orange.withValues(alpha: 0.8)
                      : _textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDayGrid() {
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    // weekday: Mon=1 … Sun=7 → offset = weekday - 1
    final startOffset = firstDay.weekday - 1;
    final totalCells = startOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: List.generate(rows, (row) {
          return Row(
            children: List.generate(7, (col) {
              final idx = row * 7 + col;
              final dayNum = idx - startOffset + 1;
              if (dayNum < 1 || dayNum > daysInMonth) {
                return const Expanded(child: SizedBox(height: 72));
              }
              final date =
                  DateTime(_focusedMonth.year, _focusedMonth.month, dayNum);
              return Expanded(child: _buildDayCell(date));
            }),
          );
        }),
      ),
    );
  }

  Widget _buildDayCell(DateTime date) {
    final holidays = _dayHolidays(date);
    final isSelected = _selectedDay != null &&
        _selectedDay!.year == date.year &&
        _selectedDay!.month == date.month &&
        _selectedDay!.day == date.day;
    final isToday = _isToday(date);
    final isWknd = _isWeekend(date);
    final hasHoliday = holidays.isNotEmpty;

    // Determine background / border
    Color? bg;
    Color border = _borderColor.withValues(alpha: 0.4);

    if (isSelected) {
      bg = _accentGreen.withValues(alpha: 0.25);
      border = _accentGreen;
    } else if (hasHoliday) {
      bg = _typeColor(holidays.first.type).withValues(alpha: 0.18);
      border = _typeColor(holidays.first.type).withValues(alpha: 0.6);
    } else if (isWknd) {
      bg = Colors.orange.withValues(alpha: 0.07);
    }

    return GestureDetector(
      onTap: () => setState(() => _selectedDay = date),
      child: Container(
        height: 72,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: bg ?? _cardDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isToday ? _accentGreen : border,
            width: isToday ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day number
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 5, 4, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: isToday
                        ? const BoxDecoration(
                            color: _accentGreen, shape: BoxShape.circle)
                        : null,
                    child: Center(
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          color: isToday
                              ? Colors.white
                              : isWknd
                                  ? Colors.orange
                                  : _textPrimary,
                          fontWeight:
                              isToday ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  if (hasHoliday && widget.isAdmin)
                    GestureDetector(
                      onTap: () => _showDayActions(date, holidays),
                      child: const Icon(Icons.more_horiz,
                          color: _textSecondary, size: 14),
                    ),
                ],
              ),
            ),
            // Holiday dots / labels
            if (hasHoliday)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: holidays.take(2).map((h) {
                      final c = _typeColor(h.type);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: c.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          h.title,
                          style: TextStyle(
                              color: c,
                              fontSize: 9,
                              fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Wrap(
        spacing: 16,
        runSpacing: 6,
        children: [
          _legendItem(_accentGreen, 'Today'),
          _legendItem(const Color(0xFF3B82F6), 'Public Holiday'),
          _legendItem(const Color(0xFF8B5CF6), 'School Holiday'),
          _legendItem(const Color(0xFFF59E0B), 'Optional Holiday'),
          _legendItem(Colors.orange.withValues(alpha: 0.6), 'Weekend'),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(color: _textSecondary, fontSize: 11)),
      ],
    );
  }

  // ── side / bottom panel ───────────────────────────────────────────────────

  Widget _buildSidePanel() {
    final monthHols = _monthHolidays;
    final selectedHols =
        _selectedDay != null ? _dayHolidays(_selectedDay!) : <SchoolHoliday>[];

    return Container(
      color: _bgDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: _cardDark,
              border: Border(bottom: BorderSide(color: _borderColor)),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_note, color: _accentGreen, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedDay != null
                        ? DateFormat('dd MMMM yyyy').format(_selectedDay!)
                        : DateFormat('MMMM yyyy').format(_focusedMonth),
                    style: const TextStyle(
                        color: _textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  ),
                ),
                if (widget.isAdmin && widget.onAddHoliday != null)
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline,
                        color: _accentGreen, size: 20),
                    onPressed: widget.onAddHoliday,
                    tooltip: 'Add Holiday',
                  ),
              ],
            ),
          ),
          // Holiday list
          Expanded(
            child: () {
              final list = _selectedDay != null ? selectedHols : monthHols;
              if (list.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_available,
                          color: _textSecondary.withValues(alpha: 0.5),
                          size: 40),
                      const SizedBox(height: 12),
                      Text(
                        _selectedDay != null
                            ? 'No holidays on this day'
                            : 'No holidays this month',
                        style: const TextStyle(
                            color: _textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                itemBuilder: (ctx, i) => _buildHolidayListTile(list[i]),
              );
            }(),
          ),
          // Month summary footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: _cardDark,
              border: Border(top: BorderSide(color: _borderColor)),
            ),
            child: Row(
              children: [
                _summaryChip(
                    monthHols.where((h) => h.type == HolidayType.PUBLIC).length,
                    'Public',
                    const Color(0xFF3B82F6)),
                const SizedBox(width: 8),
                _summaryChip(
                    monthHols.where((h) => h.type == HolidayType.SCHOOL).length,
                    'School',
                    const Color(0xFF8B5CF6)),
                const SizedBox(width: 8),
                _summaryChip(
                    monthHols
                        .where((h) => h.type == HolidayType.OPTIONAL)
                        .length,
                    'Optional',
                    const Color(0xFFF59E0B)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHolidayListTile(SchoolHoliday holiday) {
    final color = _typeColor(holiday.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          // Color bar
          Container(
            width: 4,
            height: 64,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                bottomLeft: Radius.circular(10),
              ),
            ),
          ),
          // Date badge
          Container(
            width: 44,
            height: 64,
            color: color.withValues(alpha: 0.1),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${holiday.date.day}',
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  DateFormat('MMM').format(holiday.date),
                  style: TextStyle(color: color, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  holiday.title,
                  style: const TextStyle(
                      color: _textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('EEEE').format(holiday.date),
                  style: const TextStyle(color: _textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 4),
                _typeTag(holiday.type),
              ],
            ),
          ),
          // Admin actions
          if (widget.isAdmin)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.onEditHoliday != null)
                  _actionBtn(Icons.edit, _textSecondary,
                      () => widget.onEditHoliday!(holiday)),
                if (widget.onDeleteHoliday != null)
                  _actionBtn(Icons.delete, Colors.red,
                      () => widget.onDeleteHoliday!(holiday)),
              ],
            ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _typeTag(HolidayType type) {
    final color = _typeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _typeLabel(type),
        style:
            TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  Widget _summaryChip(int count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count $label',
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ── day actions popup ─────────────────────────────────────────────────────

  void _showDayActions(DateTime date, List<SchoolHoliday> holidays) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardDark,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('EEEE, dd MMMM yyyy').format(date),
              style: const TextStyle(
                  color: _textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
            const SizedBox(height: 16),
            ...holidays.map((h) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 4,
                    height: 40,
                    color: _typeColor(h.type),
                  ),
                  title: Text(h.title,
                      style: const TextStyle(color: _textPrimary)),
                  subtitle: Text(_typeLabel(h.type),
                      style:
                          const TextStyle(color: _textSecondary, fontSize: 11)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.onEditHoliday != null)
                        IconButton(
                          icon: const Icon(Icons.edit,
                              color: _textSecondary, size: 18),
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onEditHoliday!(h);
                          },
                        ),
                      if (widget.onDeleteHoliday != null)
                        IconButton(
                          icon: const Icon(Icons.delete,
                              color: Colors.red, size: 18),
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onDeleteHoliday!(h);
                          },
                        ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
