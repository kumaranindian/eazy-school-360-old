import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show Blob, Url, AnchorElement if (dart.library.io) '';

import '../../../core/providers/auth_provider.dart';
import '../../../data/repositories/communication_log_repository.dart';
import '../../../domain/entities/communication_log.dart';

// Theme colors
const Color _bgDark = Color(0xFF0D1117);
const Color _cardDark = Color(0xFF161B22);
const Color _accentGreen = Color(0xFF10B981);
const Color _accentBlue = Color(0xFF3B82F6);
const Color _accentAmber = Color(0xFFF59E0B);
const Color _accentRed = Color(0xFFEF4444);
const Color _accentPurple = Color(0xFF8B5CF6);
const Color _textPrimary = Color(0xFFE6EDF3);
const Color _textSecondary = Color(0xFF8B949E);
const Color _borderColor = Color(0xFF30363D);

/// Communication Logs screen - shows all outgoing messages with filters + pagination.
/// Accessible for both admin and staff users.
class CommunicationLogsScreen extends ConsumerStatefulWidget {
  const CommunicationLogsScreen({super.key});

  @override
  ConsumerState<CommunicationLogsScreen> createState() =>
      _CommunicationLogsScreenState();
}

class _CommunicationLogsScreenState
    extends ConsumerState<CommunicationLogsScreen> {
  // Filters
  CommStatus? _statusFilter;
  CommChannel? _channelFilter;
  RecipientType? _recipientTypeFilter;
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  // Pagination state
  static const int _pageSize = 25;
  final List<CommunicationLog> _logs = [];
  DocumentSnapshot? _lastDoc;
  bool _hasMore = true;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;

  // Status counts for header
  Map<CommStatus, int> _statusCounts = const {};

  // Scroll controller to detect when to load more
  final ScrollController _scrollCtrl = ScrollController();

  String? get _schoolId => ref.read(currentSessionProvider)?.schoolId;

  @override
  void initState() {
    super.initState();
    // Default date range: last 7 days (1 week)
    _startDate = DateTime.now().subtract(const Duration(days: 7));
    _endDate = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitial());
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  CommunicationLogFilter _buildFilter() => CommunicationLogFilter(
        status: _statusFilter,
        channel: _channelFilter,
        recipientType: _recipientTypeFilter,
        startDate: _startDate,
        endDate: _endDate,
        searchQuery: _searchQuery.trim().isEmpty ? null : _searchQuery.trim(),
      );

  Future<void> _loadInitial() async {
    final schoolId = _schoolId;
    final session = ref.read(currentSessionProvider);

    print('🔍 [COMM_LOGS] Loading communication logs...');
    print('🔍 [COMM_LOGS] School ID: $schoolId');
    print('🔍 [COMM_LOGS] User role: ${session?.role}');
    print('🔍 [COMM_LOGS] User email: ${session?.email}');
    print('🔍 [COMM_LOGS] User UID: ${session?.uid}');
    print('🔍 [COMM_LOGS] Session schoolId: ${session?.schoolId}');
    print('🔍 [COMM_LOGS] Active memberships: ${session?.memberships.length}');

    if (schoolId == null) {
      setState(() => _error = 'No active school');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _logs.clear();
      _lastDoc = null;
      _hasMore = true;
    });

    try {
      final repo = ref.read(communicationLogRepositoryProvider);
      final results = await Future.wait([
        repo.getLogs(
          schoolId: schoolId,
          filter: _buildFilter(),
          pageSize: _pageSize,
        ),
        repo.getStatusCounts(
          schoolId: schoolId,
          startDate: _startDate,
          endDate: _endDate,
        ),
      ]);
      final page = results[0] as CommunicationLogPage;
      final counts = results[1] as Map<CommStatus, int>;

      if (!mounted) return;
      setState(() {
        _logs.addAll(_applyClientSearch(page.logs));
        _lastDoc = page.lastDocument;
        _hasMore = page.hasMore;
        _loading = false;
        _statusCounts = counts;
      });
      print('✅ [COMM_LOGS] Successfully loaded ${page.logs.length} logs');
    } catch (e) {
      print('❌ [COMM_LOGS] Error loading logs: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load logs: $e';
      });
    }
  }

  Future<void> _loadMore() async {
    final schoolId = _schoolId;
    if (schoolId == null || _loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final repo = ref.read(communicationLogRepositoryProvider);
      final page = await repo.getLogs(
        schoolId: schoolId,
        filter: _buildFilter(),
        pageSize: _pageSize,
        lastDocument: _lastDoc,
      );
      if (!mounted) return;
      setState(() {
        _logs.addAll(_applyClientSearch(page.logs));
        _lastDoc = page.lastDocument ?? _lastDoc;
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load more: $e')),
      );
    }
  }

  /// Client-side search over recipient name / phone / message (fast and
  /// avoids needing an additional search index).
  List<CommunicationLog> _applyClientSearch(List<CommunicationLog> list) {
    if (_searchQuery.trim().isEmpty) return list;
    final q = _searchQuery.trim().toLowerCase();
    return list.where((e) {
      return e.recipientName.toLowerCase().contains(q) ||
          e.recipientPhone.toLowerCase().contains(q) ||
          e.message.toLowerCase().contains(q) ||
          e.subject.toLowerCase().contains(q);
    }).toList();
  }

  void _applyFilters() => _loadInitial();

  void _clearFilters() {
    setState(() {
      _statusFilter = null;
      _channelFilter = null;
      _recipientTypeFilter = null;
      _startDate = DateTime.now().subtract(const Duration(days: 30));
      _endDate = DateTime.now();
      _searchQuery = '';
      _searchCtrl.clear();
    });
    _loadInitial();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
        end: _endDate ?? DateTime.now(),
      ),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _accentBlue,
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
      });
      _applyFilters();
    }
  }

  Future<void> _exportToCSV() async {
    try {
      final csvData = _generateCSVData();
      final csv = const ListToCsvConverter().convert(csvData);
      final bytes = utf8.encode(csv);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      (html.AnchorElement(href: url)
        ..setAttribute('download',
            'communication_logs_${DateTime.now().millisecondsSinceEpoch}.csv')
        ..click());
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Export failed: $e'), backgroundColor: _accentRed),
      );
    }
  }

  Future<void> _exportToExcel() async {
    try {
      final excel = excel_pkg.Excel.createExcel();
      final sheet = excel['Communication Logs'];
      final headers = [
        'Date & Time', 'Recipient', 'Phone', 'Type',
        'Channel', 'Status', 'Subject', 'Message'
      ];
      sheet.appendRow(headers.map((h) => excel_pkg.TextCellValue(h)).toList());
      for (final log in _logs) {
        sheet.appendRow([
          excel_pkg.TextCellValue(DateFormat('dd MMM yyyy, HH:mm').format(log.sentAt)),
          excel_pkg.TextCellValue(log.recipientName.isEmpty ? '(no name)' : log.recipientName),
          excel_pkg.TextCellValue(log.recipientPhone),
          excel_pkg.TextCellValue(log.recipientType.displayName),
          excel_pkg.TextCellValue(log.channel.displayName),
          excel_pkg.TextCellValue(log.status.displayName),
          excel_pkg.TextCellValue(log.subject),
          excel_pkg.TextCellValue(log.message),
        ]);
      }
      final bytes = excel.encode();
      if (bytes != null) {
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        (html.AnchorElement(href: url)
          ..setAttribute('download',
              'communication_logs_${DateTime.now().millisecondsSinceEpoch}.xlsx')
          ..click());
        html.Url.revokeObjectUrl(url);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: _accentRed),
      );
    }
  }

  List<List<dynamic>> _generateCSVData() {
    final data = <List<dynamic>>[
      [
        'Date & Time',
        'Recipient',
        'Phone',
        'Type',
        'Channel',
        'Purpose',
        'Status',
        'Subject',
        'Message'
      ],
    ];

    for (final log in _logs) {
      data.add([
        DateFormat('dd MMM yyyy, HH:mm').format(log.sentAt),
        log.recipientName.isEmpty ? '(no name)' : log.recipientName,
        log.recipientPhone,
        log.recipientType.displayName,
        log.channel.displayName,
        log.status.displayName,
        log.subject,
        log.message,
      ]);
    }

    return data;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    return Scaffold(
      backgroundColor: _bgDark,
      body: Column(
        children: [
          _buildHeader(isMobile),
          _buildStatusSummary(isMobile),
          _buildFilterBar(isMobile),
          Expanded(child: _buildContent(isMobile)),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 14),
      decoration: const BoxDecoration(
        color: _cardDark,
        border: Border(bottom: BorderSide(color: _borderColor)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _accentBlue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Icon(Icons.forum_rounded, color: _accentBlue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Communication Logs',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!isMobile)
                  const Text(
                    'All outgoing messages, status, recipient & purpose',
                    style: TextStyle(color: _textSecondary, fontSize: 12),
                  ),
              ],
            ),
          ),
          if (!isMobile) ...[
            Tooltip(
              message: 'Export to Excel',
              child: IconButton(
                onPressed: _logs.isEmpty ? null : _exportToExcel,
                icon: const Icon(Icons.table_chart, color: _accentGreen),
              ),
            ),
            Tooltip(
              message: 'Export to CSV',
              child: IconButton(
                onPressed: _logs.isEmpty ? null : _exportToCSV,
                icon: const Icon(Icons.download, color: _accentBlue),
              ),
            ),
          ],
          if (isMobile)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: _textSecondary),
              onSelected: (value) {
                if (value == 'excel') _exportToExcel();
                if (value == 'csv') _exportToCSV();
                if (value == 'refresh') _loadInitial();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'excel',
                  child: Row(
                    children: [
                      Icon(Icons.table_chart, color: _accentGreen, size: 20),
                      SizedBox(width: 12),
                      Text('Export to Excel'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'csv',
                  child: Row(
                    children: [
                      Icon(Icons.download, color: _accentBlue, size: 20),
                      SizedBox(width: 12),
                      Text('Export to CSV'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh, color: _textSecondary, size: 20),
                      SizedBox(width: 12),
                      Text('Refresh'),
                    ],
                  ),
                ),
              ],
            ),
          if (!isMobile)
            IconButton(
              onPressed: _loading ? null : _loadInitial,
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh, color: _textSecondary),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusSummary(bool isMobile) {
    final items = [
      _StatCard(
        label: 'Sent',
        count: _statusCounts[CommStatus.sent] ?? 0,
        color: _accentBlue,
        icon: Icons.send_rounded,
      ),
      _StatCard(
        label: 'Delivered',
        count: _statusCounts[CommStatus.delivered] ?? 0,
        color: _accentGreen,
        icon: Icons.check_circle_outline,
      ),
      _StatCard(
        label: 'Read',
        count: _statusCounts[CommStatus.read] ?? 0,
        color: _accentPurple,
        icon: Icons.mark_chat_read_outlined,
      ),
      _StatCard(
        label: 'Pending',
        count: _statusCounts[CommStatus.pending] ?? 0,
        color: _accentAmber,
        icon: Icons.schedule,
      ),
      _StatCard(
        label: 'Failed',
        count: _statusCounts[CommStatus.failed] ?? 0,
        color: _accentRed,
        icon: Icons.error_outline,
      ),
    ];

    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final item in items) ...[
              SizedBox(width: isMobile ? 120 : 150, child: item),
              const SizedBox(width: 10),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(bool isMobile) {
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 8),
      decoration: const BoxDecoration(
        color: _cardDark,
        border: Border(bottom: BorderSide(color: _borderColor)),
      ),
      child: Column(
        children: [
          // Search + date range
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) {
                    setState(() => _searchQuery = v);
                  },
                  onSubmitted: (_) => _applyFilters(),
                  style: const TextStyle(color: _textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search by name, phone or message...',
                    hintStyle:
                        const TextStyle(color: _textSecondary, fontSize: 12),
                    prefixIcon: const Icon(Icons.search,
                        color: _textSecondary, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close,
                                color: _textSecondary, size: 16),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _searchCtrl.clear();
                              });
                              _applyFilters();
                            },
                          )
                        : null,
                    isDense: true,
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
                      borderSide: const BorderSide(color: _accentBlue),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _pickDateRange,
                icon: const Icon(Icons.date_range, size: 16),
                label: Text(
                  _startDate != null && _endDate != null
                      ? '${DateFormat('dd/MM').format(_startDate!)} - ${DateFormat('dd/MM').format(_endDate!)}'
                      : 'Date',
                  style: const TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _textPrimary,
                  side: const BorderSide(color: _borderColor),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Chip filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDropdownFilter<CommStatus>(
                  label: 'Status',
                  value: _statusFilter,
                  options: CommStatus.values,
                  labelOf: (v) => v.displayName,
                  onChanged: (v) {
                    setState(() => _statusFilter = v);
                    _applyFilters();
                  },
                ),
                const SizedBox(width: 8),
                _buildDropdownFilter<CommChannel>(
                  label: 'Channel',
                  value: _channelFilter,
                  options: CommChannel.values,
                  labelOf: (v) => v.displayName,
                  onChanged: (v) {
                    setState(() => _channelFilter = v);
                    _applyFilters();
                  },
                ),
                const SizedBox(width: 8),
                _buildDropdownFilter<RecipientType>(
                  label: 'Recipient',
                  value: _recipientTypeFilter,
                  options: RecipientType.values,
                  labelOf: (v) => v.displayName,
                  onChanged: (v) {
                    setState(() => _recipientTypeFilter = v);
                    _applyFilters();
                  },
                ),
                const SizedBox(width: 8),
                if (_hasActiveFilters())
                  TextButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.clear, size: 14),
                    label: const Text('Clear', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: _accentRed,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _hasActiveFilters() =>
      _statusFilter != null ||
      _channelFilter != null ||
      _recipientTypeFilter != null ||
      _searchQuery.isNotEmpty;

  Widget _buildDropdownFilter<T>({
    required String label,
    required T? value,
    required List<T> options,
    required String Function(T) labelOf,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _bgDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: value != null ? _accentBlue : _borderColor,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T?>(
          value: value,
          isDense: true,
          dropdownColor: _cardDark,
          hint: Text(label,
              style: const TextStyle(color: _textSecondary, fontSize: 12)),
          icon: const Icon(Icons.arrow_drop_down,
              color: _textSecondary, size: 18),
          style: const TextStyle(color: _textPrimary, fontSize: 12),
          items: [
            DropdownMenuItem<T?>(
              value: null,
              child: Text('All $label',
                  style: const TextStyle(color: _textSecondary)),
            ),
            for (final o in options)
              DropdownMenuItem<T?>(
                value: o,
                child: Text(labelOf(o)),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildContent(bool isMobile) {
    if (_loading && _logs.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _accentBlue));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: _accentRed, size: 40),
              const SizedBox(height: 8),
              Text(_error!,
                  style: const TextStyle(color: _accentRed),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _loadInitial,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, color: _textSecondary, size: 56),
            const SizedBox(height: 10),
            const Text('No communication logs found',
                style: TextStyle(color: _textSecondary, fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              _hasActiveFilters()
                  ? 'Try changing the filters'
                  : 'Send messages to see them here',
              style: const TextStyle(color: _textSecondary, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollCtrl,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildTable(),
            ),
          ),
        ),
        _buildTableFooter(),
      ],
    );
  }

  // -------- Table --------

  static const _cols = [
    '#', 'Date & Time', 'Recipient', 'Phone', 'Type', 'Channel', 'Status', 'Message', ''
  ];
  static const _colWidths = [
    40.0, 130.0, 150.0, 120.0, 80.0, 90.0, 90.0, 260.0, 44.0
  ];

  Widget _buildTable() {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: MediaQuery.of(context).size.width - 32,
      ),
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        columnWidths: {
          for (int i = 0; i < _colWidths.length; i++)
            i: FixedColumnWidth(_colWidths[i]),
        },
        border: TableBorder(
          horizontalInside: BorderSide(color: _borderColor.withOpacity(0.5)),
          bottom: const BorderSide(color: _borderColor),
        ),
        children: [
          _buildHeaderRow(),
          for (int i = 0; i < _logs.length; i++) _buildDataRow(i, _logs[i]),
        ],
      ),
    );
  }

  TableRow _buildHeaderRow() {
    return TableRow(
      decoration: const BoxDecoration(color: Color(0xFF1C2128)),
      children: [
        for (int i = 0; i < _cols.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Text(
              _cols[i],
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ),
      ],
    );
  }

  TableRow _buildDataRow(int index, CommunicationLog log) {
    final isEven = index.isEven;
    final statusColor = _statusColor(log.status);

    return TableRow(
      decoration: BoxDecoration(
        color: isEven ? _cardDark : _bgDark,
      ),
      children: [
        // #
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Text('${index + 1}',
              style: const TextStyle(color: _textSecondary, fontSize: 11)),
        ),
        // Date
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Text(
            DateFormat('dd MMM yy\nHH:mm').format(log.sentAt),
            style: const TextStyle(color: _textSecondary, fontSize: 11, height: 1.4),
          ),
        ),
        // Recipient
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Text(
            log.recipientName.isEmpty ? '—' : log.recipientName,
            style: const TextStyle(color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Phone
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Text(log.recipientPhone,
              style: const TextStyle(color: _textSecondary, fontSize: 11)),
        ),
        // Type
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: _Pill(label: log.recipientType.displayName, color: _textSecondary, filled: false),
        ),
        // Channel
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_channelIcon(log.channel), color: _accentBlue, size: 13),
              const SizedBox(width: 4),
              Text(log.channel.displayName,
                  style: const TextStyle(color: _accentBlue, fontSize: 11)),
            ],
          ),
        ),
        // Status
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: _Pill(label: log.status.displayName, color: statusColor),
        ),
        // Message
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                log.message.isNotEmpty ? log.message : log.subject,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _textSecondary, fontSize: 11, height: 1.4),
              ),
              if (log.status == CommStatus.failed && log.errorMessage != null) ...
                [
                  const SizedBox(height: 3),
                  Text(
                    log.errorMessage!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _accentRed, fontSize: 10),
                  ),
                ],
            ],
          ),
        ),
        // View button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => _showDetails(context, log),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.open_in_new_rounded, color: _textSecondary, size: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: _cardDark,
        border: Border(top: BorderSide(color: _borderColor)),
      ),
      child: Row(
        children: [
          Text(
            '${_logs.length} record${_logs.length == 1 ? '' : 's'} shown',
            style: const TextStyle(color: _textSecondary, fontSize: 11),
          ),
          const Spacer(),
          if (_loadingMore)
            const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(color: _accentBlue, strokeWidth: 2),
            )
          else if (_hasMore)
            TextButton(
              onPressed: _loadMore,
              child: const Text('Load more', style: TextStyle(fontSize: 12)),
            )
          else
            const Text('— End of list —',
                style: TextStyle(color: _textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  // -------- Helpers --------

  static Color _statusColor(CommStatus s) {
    switch (s) {
      case CommStatus.sent:      return _accentBlue;
      case CommStatus.delivered: return _accentGreen;
      case CommStatus.read:      return _accentPurple;
      case CommStatus.failed:    return _accentRed;
      case CommStatus.pending:   return _accentAmber;
    }
  }

  static IconData _channelIcon(CommChannel c) {
    switch (c) {
      case CommChannel.whatsapp: return Icons.chat_bubble_rounded;
      case CommChannel.sms:      return Icons.sms_rounded;
      case CommChannel.email:    return Icons.email_rounded;
      case CommChannel.push:     return Icons.notifications_active_rounded;
      case CommChannel.inApp:    return Icons.app_registration_rounded;
    }
  }

  void _showDetails(BuildContext context, CommunicationLog log) {
    showDialog(
      context: context,
      builder: (_) => _LogDetailDialog(log: log),
    );
  }
}

// ---------------- Helper widgets ----------------

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style:
                        const TextStyle(color: _textSecondary, fontSize: 10)),
                Text('$count',
                    style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogDetailDialog extends StatelessWidget {
  final CommunicationLog log;
  const _LogDetailDialog({required this.log});

  IconData get _channelIcon {
    switch (log.channel) {
      case CommChannel.whatsapp: return Icons.chat_bubble_rounded;
      case CommChannel.sms:      return Icons.sms_rounded;
      case CommChannel.email:    return Icons.email_rounded;
      case CommChannel.push:     return Icons.notifications_active_rounded;
      case CommChannel.inApp:    return Icons.app_registration_rounded;
    }
  }

  Color get _statusColor {
    switch (log.status) {
      case CommStatus.sent:      return _accentBlue;
      case CommStatus.delivered: return _accentGreen;
      case CommStatus.read:      return _accentPurple;
      case CommStatus.failed:    return _accentRed;
      case CommStatus.pending:   return _accentAmber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(_channelIcon, color: _accentBlue, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Message Details',
                        style: TextStyle(
                            color: _textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: _textSecondary, size: 18),
                  ),
                ],
              ),
              const Divider(color: _borderColor),
              _detailRow('Channel', log.channel.displayName),
              _detailRow('Status', log.status.displayName, color: _statusColor),
              _detailRow('Recipient', '${log.recipientName} (${log.recipientPhone})'),
              _detailRow('Recipient Type', log.recipientType.displayName),
              if (log.recipientEmail != null) _detailRow('Email', log.recipientEmail!),
              _detailRow('Subject', log.subject),
              _detailRow('Sent At', DateFormat('dd MMM yyyy, HH:mm:ss').format(log.sentAt)),
              if (log.deliveredAt != null)
                _detailRow('Delivered At', DateFormat('dd MMM yyyy, HH:mm:ss').format(log.deliveredAt!)),
              if (log.readAt != null)
                _detailRow('Read At', DateFormat('dd MMM yyyy, HH:mm:ss').format(log.readAt!)),
              if (log.sentByName != null) _detailRow('Sent By', log.sentByName!),
              const SizedBox(height: 8),
              const Text('Message',
                  style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _bgDark,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _borderColor),
                ),
                child: SelectableText(
                  log.message,
                  style: const TextStyle(color: _textPrimary, fontSize: 12, height: 1.5),
                ),
              ),
              if (log.errorMessage != null) ...[
                const SizedBox(height: 8),
                const Text('Error',
                    style: TextStyle(color: _accentRed, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _accentRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(log.errorMessage!,
                      style: const TextStyle(color: _accentRed, fontSize: 12)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(color: _textSecondary, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: color ?? _textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  const _Pill({required this.label, required this.color, this.filled = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(filled ? 0.4 : 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
