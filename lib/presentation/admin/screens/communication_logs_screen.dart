import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
  CommPurpose? _purposeFilter;
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
    // Default date range: last 30 days
    _startDate = DateTime.now().subtract(const Duration(days: 30));
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
        purpose: _purposeFilter,
        channel: _channelFilter,
        recipientType: _recipientTypeFilter,
        startDate: _startDate,
        endDate: _endDate,
        searchQuery: _searchQuery.trim().isEmpty ? null : _searchQuery.trim(),
      );

  Future<void> _loadInitial() async {
    final schoolId = _schoolId;
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
    } catch (e) {
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
      _purposeFilter = null;
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
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 20, vertical: 14),
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
            child: const Icon(Icons.forum_rounded,
                color: _accentBlue, size: 20),
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
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 16, vertical: 12),
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
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 16, vertical: 8),
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
                    hintStyle: const TextStyle(
                        color: _textSecondary, fontSize: 12),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 10),
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
                _buildDropdownFilter<CommPurpose>(
                  label: 'Purpose',
                  value: _purposeFilter,
                  options: CommPurpose.values,
                  labelOf: (v) => v.displayName,
                  onChanged: (v) {
                    setState(() => _purposeFilter = v);
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
      _purposeFilter != null ||
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
      return const Center(
          child: CircularProgressIndicator(color: _accentBlue));
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
            const Icon(Icons.inbox_outlined,
                color: _textSecondary, size: 56),
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

    return RefreshIndicator(
      onRefresh: _loadInitial,
      color: _accentBlue,
      child: ListView.separated(
        controller: _scrollCtrl,
        padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 8 : 16, vertical: 12),
        itemCount: _logs.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          if (i == _logs.length) {
            // Footer: loading more or "end of list"
            if (_loadingMore) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                    child: CircularProgressIndicator(color: _accentBlue)),
              );
            }
            if (!_hasMore) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('— End of logs (${_logs.length} shown) —',
                      style: const TextStyle(
                          color: _textSecondary, fontSize: 11)),
                ),
              );
            }
            // Manual load more button as fallback
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: TextButton(
                  onPressed: _loadMore,
                  child: const Text('Load more'),
                ),
              ),
            );
          }
          return _LogTile(log: _logs[i], isMobile: isMobile);
        },
      ),
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
                    style: const TextStyle(
                        color: _textSecondary, fontSize: 10)),
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

class _LogTile extends StatelessWidget {
  final CommunicationLog log;
  final bool isMobile;

  const _LogTile({required this.log, required this.isMobile});

  Color _statusColor() {
    switch (log.status) {
      case CommStatus.sent:
        return _accentBlue;
      case CommStatus.delivered:
        return _accentGreen;
      case CommStatus.read:
        return _accentPurple;
      case CommStatus.failed:
        return _accentRed;
      case CommStatus.pending:
        return _accentAmber;
    }
  }

  IconData _channelIcon() {
    switch (log.channel) {
      case CommChannel.whatsapp:
        return Icons.chat_bubble_rounded;
      case CommChannel.sms:
        return Icons.sms_rounded;
      case CommChannel.email:
        return Icons.email_rounded;
      case CommChannel.push:
        return Icons.notifications_active_rounded;
      case CommChannel.inApp:
        return Icons.app_registration_rounded;
    }
  }

  Color _purposeColor() {
    switch (log.purpose) {
      case CommPurpose.paymentDue:
      case CommPurpose.feeReminder:
        return _accentAmber;
      case CommPurpose.paymentReceipt:
        return _accentGreen;
      case CommPurpose.attendance:
        return _accentBlue;
      case CommPurpose.leaveUpdate:
        return _accentPurple;
      case CommPurpose.announcement:
      case CommPurpose.welcome:
      case CommPurpose.custom:
        return _textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    final purposeColor = _purposeColor();

    return InkWell(
      onTap: () => _showDetails(context),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _cardDark,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: channel + purpose + status + time
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _accentBlue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(_channelIcon(),
                      color: _accentBlue, size: 14),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _Pill(
                        label: log.purpose.displayName,
                        color: purposeColor,
                      ),
                      _Pill(
                        label: log.status.displayName,
                        color: statusColor,
                      ),
                      _Pill(
                        label: log.recipientType.displayName,
                        color: _textSecondary,
                        filled: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('dd MMM, HH:mm').format(log.sentAt),
                  style: const TextStyle(
                      color: _textSecondary, fontSize: 10),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Recipient info
            Row(
              children: [
                const Icon(Icons.person_outline,
                    color: _textSecondary, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    log.recipientName.isEmpty
                        ? '(no name)'
                        : log.recipientName,
                    style: const TextStyle(
                      color: _textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.phone_outlined,
                    color: _textSecondary, size: 14),
                const SizedBox(width: 4),
                Text(
                  log.recipientPhone,
                  style: const TextStyle(
                      color: _textSecondary, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Message preview
            Text(
              log.message.isNotEmpty ? log.message : log.subject,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 12,
                height: 1.3,
              ),
            ),
            // Error message if failed
            if (log.status == CommStatus.failed &&
                log.errorMessage != null) ...[
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _accentRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _accentRed.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: _accentRed, size: 12),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        log.errorMessage!,
                        style: const TextStyle(
                            color: _accentRed, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: _cardDark,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    Icon(_channelIcon(), color: _accentBlue, size: 20),
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
                      icon: const Icon(Icons.close,
                          color: _textSecondary, size: 18),
                    ),
                  ],
                ),
                const Divider(color: _borderColor),
                _detailRow('Purpose', log.purpose.displayName),
                _detailRow('Channel', log.channel.displayName),
                _detailRow('Status', log.status.displayName,
                    color: _statusColor()),
                _detailRow(
                    'Recipient', '${log.recipientName} (${log.recipientPhone})'),
                _detailRow('Recipient Type', log.recipientType.displayName),
                if (log.recipientEmail != null)
                  _detailRow('Email', log.recipientEmail!),
                _detailRow('Subject', log.subject),
                _detailRow('Sent At',
                    DateFormat('dd MMM yyyy, HH:mm:ss').format(log.sentAt)),
                if (log.deliveredAt != null)
                  _detailRow(
                      'Delivered At',
                      DateFormat('dd MMM yyyy, HH:mm:ss')
                          .format(log.deliveredAt!)),
                if (log.readAt != null)
                  _detailRow('Read At',
                      DateFormat('dd MMM yyyy, HH:mm:ss').format(log.readAt!)),
                if (log.sentByName != null)
                  _detailRow('Sent By', log.sentByName!),
                const SizedBox(height: 8),
                const Text('Message',
                    style: TextStyle(
                        color: _textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
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
                    style: const TextStyle(
                        color: _textPrimary, fontSize: 12, height: 1.5),
                  ),
                ),
                if (log.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  const Text('Error',
                      style: TextStyle(
                          color: _accentRed,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _accentRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      log.errorMessage!,
                      style:
                          const TextStyle(color: _accentRed, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
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
                style: const TextStyle(
                    color: _textSecondary, fontSize: 12)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: color ?? _textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
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
