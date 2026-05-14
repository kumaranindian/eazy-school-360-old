import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/auth_provider.dart';

const Color _bgDark = Color(0xFF0D1117);
const Color _cardDark = Color(0xFF161B22);
const Color _accentGreen = Color(0xFF4CAF50);
const Color _accentRed = Color(0xFFEF4444);
const Color _textPrimary = Color(0xFFE6EDF3);
const Color _textSecondary = Color(0xFF8B949E);
const Color _borderColor = Color(0xFF30363D);

class RfidAttendanceEntriesScreen extends ConsumerStatefulWidget {
  const RfidAttendanceEntriesScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<RfidAttendanceEntriesScreen> createState() =>
      _RfidAttendanceEntriesScreenState();
}

class _RfidAttendanceEntriesScreenState
    extends ConsumerState<RfidAttendanceEntriesScreen> {
  List<Map<String, dynamic>> _attendanceEntries = [];
  List<Map<String, dynamic>> _staffList = [];
  Map<String, dynamic>? _selectedStaff;
  bool _isLoading = false;
  DateTime? _startDate;
  DateTime? _endDate;
  Map<String, String> _staffNameMap = {};
  String _selectedDateFilter = 'All Time';

  static const List<String> _dateFilterOptions = [
    'All Time',
    'This Week',
    'This Month',
    'This Quarter',
    'This Academic Year',
    'Custom',
  ];

  String? get _schoolId => ref.read(currentSessionProvider)?.schoolId;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _startDate = null;
    _endDate = null;
    _selectedDateFilter = 'All Time';
    _loadStaffList();
    _loadAttendanceEntries();
  }

  void _setDateRangeForFilter(String filter) {
    final now = DateTime.now();
    setState(() {
      _selectedDateFilter = filter;
      switch (filter) {
        case 'All Time':
          _startDate = null;
          _endDate = null;
          break;
        case 'This Week':
          _startDate = now.subtract(Duration(days: now.weekday - 1));
          _endDate = now;
          break;
        case 'This Month':
          _startDate = DateTime(now.year, now.month, 1);
          _endDate = DateTime(now.year, now.month + 1, 0);
          break;
        case 'This Quarter':
          final quarter = ((now.month - 1) ~/ 3) + 1;
          _startDate = DateTime(now.year, (quarter - 1) * 3 + 1, 1);
          _endDate = DateTime(now.year, quarter * 3 + 1, 0);
          break;
        case 'This Academic Year':
          // Assuming academic year starts in April
          if (now.month >= 4) {
            _startDate = DateTime(now.year, 4, 1);
            _endDate = DateTime(now.year + 1, 3, 31);
          } else {
            _startDate = DateTime(now.year - 1, 4, 1);
            _endDate = DateTime(now.year, 3, 31);
          }
          break;
        case 'Custom':
          // Keep existing dates or set to null
          break;
      }
    });
  }

  Future<void> _loadStaffList() async {
    if (_schoolId == null) return;
    setState(() => _isLoading = true);
    try {
      final snap = await _firestore
          .collection('schools')
          .doc(_schoolId)
          .collection('staff')
          .where('status', isEqualTo: 'ACTIVE')
          .orderBy('name')
          .get();

      if (mounted) {
        setState(() {
          _staffList = snap.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
          
          // Create staff name map
          _staffNameMap = {};
          for (var staff in _staffList) {
            final staffId = staff['id']?.toString();
            if (staffId != null) {
              _staffNameMap[staffId] = staff['name']?.toString() ?? staff['displayName']?.toString() ?? 'Unknown';
            }
          }
          
          _isLoading = false;
        });
      }
    } catch (e) {
      print('[RfidAttendanceEntries] Error loading staff: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAttendanceEntries() async {
    if (_schoolId == null) return;
    setState(() => _isLoading = true);
    try {
      Query query = _firestore
          .collection('schools')
          .doc(_schoolId)
          .collection('attendance');

      // Apply staff filter first if selected
      if (_selectedStaff != null) {
        query = query.where('staffId', isEqualTo: _selectedStaff!['id']);
      }

      // Then apply date range filter
      if (_startDate != null) {
        query = query.where('scannedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate!));
      }
      if (_endDate != null) {
        query = query.where('scannedAt',
            isLessThanOrEqualTo: Timestamp.fromDate(
                _endDate!.add(const Duration(days: 1))));
      }

      // Finally apply ordering
      query = query.orderBy('scannedAt', descending: true);

      final snap = await query.limit(500).get();

      if (mounted) {
        // Group attendance by staff and date
        Map<String, List<Map<String, dynamic>>> groupedAttendance = {};
        
        for (var doc in snap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          
          final staffId = data['staffId']?.toString();
          final scannedAt = data['scannedAt'] as Timestamp?;
          
          if (staffId != null && scannedAt != null) {
            final date = DateFormat('yyyy-MM-dd').format(scannedAt.toDate());
            final key = '$staffId-$date';
            
            if (!groupedAttendance.containsKey(key)) {
              groupedAttendance[key] = [];
            }
            groupedAttendance[key]!.add(data);
          }
        }
        
        // Calculate first in, last out, and total time for each group
        List<Map<String, dynamic>> aggregatedEntries = [];
        
        for (var entries in groupedAttendance.values) {
          if (entries.isEmpty) continue;
          
          // Sort by scannedAt to find first and last
          entries.sort((a, b) {
            final aTime = (a['scannedAt'] as Timestamp).toDate();
            final bTime = (b['scannedAt'] as Timestamp).toDate();
            return aTime.compareTo(bTime);
          });
          
          final firstEntry = entries.first;
          final lastEntry = entries.last;
          
          final firstIn = (firstEntry['scannedAt'] as Timestamp).toDate();
          final lastOut = (lastEntry['scannedAt'] as Timestamp).toDate();
          final totalDuration = lastOut.difference(firstIn);
          
          // Format total duration
          String totalDurationStr;
          if (totalDuration.inHours > 0) {
            totalDurationStr = '${totalDuration.inHours}h ${totalDuration.inMinutes.remainder(60)}m';
          } else {
            totalDurationStr = '${totalDuration.inMinutes}m';
          }
          
          aggregatedEntries.add({
            'staffId': firstEntry['staffId'],
            'rfidTag': firstEntry['rfidTag'],
            'date': firstIn,
            'firstIn': firstIn,
            'lastOut': lastOut,
            'totalDuration': totalDurationStr,
            'totalDurationMinutes': totalDuration.inMinutes,
            'status': firstEntry['status'],
            'entryCount': entries.length,
          });
        }
        
        // Sort aggregated entries by date descending
        aggregatedEntries.sort((a, b) {
          return (b['date'] as DateTime).compareTo(a['date'] as DateTime);
        });
        
        setState(() {
          _attendanceEntries = aggregatedEntries;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('[RfidAttendanceEntries] Error loading entries: $e');
      if (mounted) setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading attendance entries: $e')),
      );
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _accentGreen,
            surface: _cardDark,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _selectedDateFilter = 'Custom';
      });
      _loadAttendanceEntries();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: _cardDark,
        title: const Text('RFID Attendance Entries',
            style: TextStyle(color: _textPrimary)),
        iconTheme: const IconThemeData(color: _textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: _accentGreen),
            onPressed: _selectDateRange,
            tooltip: 'Select Date Range',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: _accentGreen),
            onPressed: _loadAttendanceEntries,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(_accentGreen)))
                : _attendanceEntries.isEmpty
                    ? _buildEmptyState()
                    : _buildAttendanceTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: _cardDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStaffDropdown(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDateFilterDropdown(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilterDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: _bgDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedDateFilter,
          dropdownColor: _cardDark,
          iconEnabledColor: _accentGreen,
          style: const TextStyle(color: _textPrimary, fontSize: 14),
          items: _dateFilterOptions.map((String option) {
            return DropdownMenuItem<String>(
              value: option,
              child: Text(option,
                  style: const TextStyle(color: _textPrimary, fontSize: 14)),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              if (value == 'Custom') {
                _selectDateRange();
              } else {
                _setDateRangeForFilter(value);
                _loadAttendanceEntries();
              }
            }
          },
        ),
      ),
    );
  }

  Widget _buildStaffDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: _bgDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Map<String, dynamic>>(
          value: _selectedStaff,
          hint: const Text('All Staff',
              style: TextStyle(color: _textSecondary, fontSize: 14)),
          dropdownColor: _cardDark,
          iconEnabledColor: _accentGreen,
          style: const TextStyle(color: _textPrimary, fontSize: 14),
          items: [
            const DropdownMenuItem<Map<String, dynamic>>(
              value: null,
              child: Text('All Staff',
                  style: TextStyle(color: _textPrimary, fontSize: 14)),
            ),
            ..._staffList.map((staff) {
              return DropdownMenuItem<Map<String, dynamic>>(
                value: staff,
                child: Text(staff['name']?.toString() ?? 'Unknown',
                    style: const TextStyle(color: _textPrimary, fontSize: 14)),
              );
            }),
          ],
          onChanged: (value) {
            setState(() => _selectedStaff = value);
            _loadAttendanceEntries();
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.nfc_rounded, size: 64, color: _borderColor),
          const SizedBox(height: 16),
          Text(
            'No RFID attendance entries found',
            style: TextStyle(color: _textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a date range and staff to view entries',
            style: TextStyle(color: _textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceTable() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: _cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(_bgDark),
            dataRowColor: WidgetStateProperty.all(_cardDark),
            columns: const [
              DataColumn(
                  label: Text('Date',
                      style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold))),
              DataColumn(
                  label: Text('Staff Name',
                      style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold))),
              DataColumn(
                  label: Text('First In',
                      style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold))),
              DataColumn(
                  label: Text('Last Out',
                      style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold))),
              DataColumn(
                  label: Text('Total Time',
                      style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold))),
              DataColumn(
                  label: Text('Status',
                      style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold))),
            ],
            rows: _attendanceEntries.map((entry) {
              final date = entry['date'] as DateTime?;
              final staffId = entry['staffId']?.toString();
              final staffName = staffId != null ? (_staffNameMap[staffId] ?? 'Unknown') : 'Unknown';
              final firstIn = entry['firstIn'] as DateTime?;
              final lastOut = entry['lastOut'] as DateTime?;
              final totalDuration = entry['totalDuration']?.toString() ?? 'N/A';
              
              return DataRow(
                cells: [
                  DataCell(Text(
                      date != null
                          ? DateFormat('dd MMM yyyy').format(date)
                          : 'N/A',
                      style: const TextStyle(color: _textSecondary))),
                  DataCell(Text(staffName,
                      style: const TextStyle(color: _textPrimary))),
                  DataCell(Text(
                      firstIn != null
                          ? DateFormat('HH:mm:ss').format(firstIn)
                          : 'N/A',
                      style: const TextStyle(color: _textSecondary))),
                  DataCell(Text(
                      lastOut != null
                          ? DateFormat('HH:mm:ss').format(lastOut)
                          : 'N/A',
                      style: const TextStyle(color: _textSecondary))),
                  DataCell(Text(totalDuration,
                      style: const TextStyle(color: _textPrimary))),
                  DataCell(_buildStatusChip(entry['status']?.toString() ?? 'Unknown')),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color chipColor;
    switch (status.toLowerCase()) {
      case 'present':
      case 'check-in':
        chipColor = _accentGreen;
        break;
      case 'absent':
        chipColor = _accentRed;
        break;
      case 'late':
        chipColor = Colors.orange;
        break;
      default:
        chipColor = _textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor.withOpacity(0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: chipColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
