import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eazy_school_360/core/providers/auth_provider.dart';
import 'package:eazy_school_360/data/repositories/leave_application_repository.dart';
import 'package:eazy_school_360/domain/entities/leave_application.dart';

class LeaveApprovalScreen extends ConsumerStatefulWidget {
  const LeaveApprovalScreen({super.key});

  @override
  ConsumerState<LeaveApprovalScreen> createState() => _LeaveApprovalScreenState();
}

class _LeaveApprovalScreenState extends ConsumerState<LeaveApprovalScreen> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  String _searchQuery = '';

  // Dark theme colors (match dashboard)
  static const Color _headerDark = Color(0xFF161B22);
  static const Color _bgLight = Color(0xFF0D1117);
  static const Color _cardWhite = Color(0xFF161B22);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  bool get _isDesktop => MediaQuery.of(context).size.width > 900;

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

    if (session == null || !session.isAdmin || session.schoolId == null) {
      return const Scaffold(body: Center(child: Text('Access Denied')));
    }

    return Container(
      color: _bgLight,
      child: Column(
        children: [
          // Tab bar header
          Container(
            color: _headerDark,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              tabs: const [
                Tab(icon: Icon(Icons.pending_actions, size: 20), text: 'Pending'),
                Tab(icon: Icon(Icons.list_alt, size: 20), text: 'All Requests'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPendingTab(session.schoolId!),
                _buildAllRequestsTab(session.schoolId!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingTab(String schoolId) {
    final pendingAsync = ref.watch(pendingLeaveApplicationsProvider(schoolId));

    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: pendingAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: _accentBlue)),
            error: (error, stack) => _buildErrorState(error),
            data: (applications) {
              final filtered = _filterApplications(applications);
              if (filtered.isEmpty) {
                return _buildEmptyState('No pending requests', 'All leave requests have been processed');
              }
              return _buildApplicationsList(filtered, schoolId);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAllRequestsTab(String schoolId) {
    final allAsync = ref.watch(schoolLeaveApplicationsProvider(schoolId));

    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: allAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: _accentBlue)),
            error: (error, stack) => _buildErrorState(error),
            data: (applications) {
              final filtered = _filterApplications(applications);
              if (filtered.isEmpty) {
                return _buildEmptyState('No leave requests', 'No leave requests found');
              }
              return _buildApplicationsList(filtered, schoolId);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: _bgLight,
      child: Container(
        height: 42,
        decoration: BoxDecoration(color: _cardWhite, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderColor)),
        child: TextField(
          style: const TextStyle(color: _textPrimary, fontSize: 13),
          decoration: const InputDecoration(
            hintText: 'Search by staff name or leave type...',
            hintStyle: TextStyle(color: _textSecondary, fontSize: 13),
            prefixIcon: Icon(Icons.search, color: _textSecondary, size: 18),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 12),
          ),
          onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
        ),
      ),
    );
  }

  Widget _buildApplicationsList(List<LeaveApplication> applications, String schoolId) {
    if (_isDesktop) {
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2.2,
        ),
        itemCount: applications.length,
        itemBuilder: (context, index) => _buildApplicationCard(applications[index], schoolId),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: applications.length,
      itemBuilder: (context, index) => _buildApplicationCard(applications[index], schoolId),
    );
  }

  Widget _buildApplicationCard(LeaveApplication app, String schoolId) {
    final statusColor = _getStatusColor(app.status);
    final statusLabel = _getStatusLabel(app.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: _accentBlue.withOpacity(0.1),
                radius: 20,
                child: Text(
                  app.applicantId[0].toUpperCase(),
                  style: const TextStyle(color: _accentBlue, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(app.staffId, style: const TextStyle(fontWeight: FontWeight.bold, color: _textPrimary)),
                    Text(app.leaveTypeCode, style: const TextStyle(fontSize: 13, color: _textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(statusLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildInfoChip(Icons.calendar_today, '${_formatDate(app.startDate)} - ${_formatDate(app.endDate)}'),
              const SizedBox(width: 12),
              _buildInfoChip(Icons.timelapse, '${app.totalDays} day${app.totalDays > 1 ? 's' : ''}'),
            ],
          ),
          if (app.reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(app.reason, style: const TextStyle(fontSize: 13, color: _textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          if (app.status == LeaveApplicationStatus.PENDING) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleAction(schoolId, app.id, false),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleAction(schoolId, app.id, true),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: _textSecondary),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: _textSecondary)),
      ],
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_outline, size: 48, color: _textSecondary),
          ),
          const SizedBox(height: 20),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: _textSecondary)),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
          const SizedBox(height: 16),
          const Text('Error Loading Requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(error.toString(), style: const TextStyle(color: _textSecondary)),
        ],
      ),
    );
  }

  List<LeaveApplication> _filterApplications(List<LeaveApplication> applications) {
    if (_searchQuery.isEmpty) return applications;
    return applications.where((app) {
      return app.staffId.toLowerCase().contains(_searchQuery) ||
          app.leaveTypeCode.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  Future<void> _handleAction(String schoolId, String applicationId, bool approve) async {
    try {
      final session = ref.read(currentSessionProvider);
      final repo = ref.read(leaveApplicationRepositoryProvider);
      
      final request = LeaveApprovalRequest(
        status: approve ? LeaveApplicationStatus.APPROVED : LeaveApplicationStatus.REJECTED,
        rejectionReason: approve ? null : 'Rejected by admin',
      );
      await repo.approveLeaveApplication(schoolId, applicationId, session!.uid, request);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(approve ? 'Leave approved' : 'Leave rejected'), backgroundColor: approve ? Colors.green : Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Color _getStatusColor(LeaveApplicationStatus status) {
    switch (status) {
      case LeaveApplicationStatus.PENDING: return const Color(0xFFF59E0B);
      case LeaveApplicationStatus.APPROVED: return const Color(0xFF10B981);
      case LeaveApplicationStatus.REJECTED: return const Color(0xFFEF4444);
      case LeaveApplicationStatus.CANCELLED: return const Color(0xFF6B7280);
    }
  }

  String _getStatusLabel(LeaveApplicationStatus status) {
    switch (status) {
      case LeaveApplicationStatus.PENDING: return 'Pending';
      case LeaveApplicationStatus.APPROVED: return 'Approved';
      case LeaveApplicationStatus.REJECTED: return 'Rejected';
      case LeaveApplicationStatus.CANCELLED: return 'Cancelled';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
