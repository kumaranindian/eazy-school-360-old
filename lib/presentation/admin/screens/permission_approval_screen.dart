import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eazy_school_360/core/providers/auth_provider.dart';
import 'package:eazy_school_360/data/repositories/permission_request_repository.dart';
import 'package:eazy_school_360/domain/entities/permission_request.dart';

class PermissionApprovalScreen extends ConsumerStatefulWidget {
  const PermissionApprovalScreen({super.key});

  @override
  ConsumerState<PermissionApprovalScreen> createState() => _PermissionApprovalScreenState();
}

class _PermissionApprovalScreenState extends ConsumerState<PermissionApprovalScreen> with SingleTickerProviderStateMixin {
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
                _buildPendingTab(session.schoolId!, isDesktop),
                _buildAllRequestsTab(session.schoolId!, isDesktop),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingTab(String schoolId, bool isDesktop) {
    final pendingAsync = ref.watch(pendingPermissionRequestsProvider(schoolId));

    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: pendingAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: _accentBlue)),
            error: (error, stack) => _buildErrorState(error),
            data: (requests) {
              final filtered = _filterRequests(requests);
              if (filtered.isEmpty) {
                return _buildEmptyState('No pending requests', 'All permission requests have been processed');
              }
              return _buildRequestsList(filtered, schoolId, isDesktop);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAllRequestsTab(String schoolId, bool isDesktop) {
    final allAsync = ref.watch(schoolPermissionRequestsProvider(schoolId));

    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: allAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: _accentBlue)),
            error: (error, stack) => _buildErrorState(error),
            data: (requests) {
              final filtered = _filterRequests(requests);
              if (filtered.isEmpty) {
                return _buildEmptyState('No permission requests', 'No permission requests found');
              }
              return _buildRequestsList(filtered, schoolId, isDesktop);
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
            hintText: 'Search by staff name or reason...',
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

  Widget _buildRequestsList(List<PermissionRequest> requests, String schoolId, bool isDesktop) {
    if (isDesktop) {
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2.2,
        ),
        itemCount: requests.length,
        itemBuilder: (context, index) => _buildRequestCard(requests[index], schoolId),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, index) => _buildRequestCard(requests[index], schoolId),
    );
  }

  Widget _buildRequestCard(PermissionRequest request, String schoolId) {
    final statusColor = _getStatusColor(request.status);
    final statusLabel = _getStatusLabel(request.status);

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
                  request.applicantId.isNotEmpty ? request.applicantId[0].toUpperCase() : 'P',
                  style: const TextStyle(color: _accentBlue, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.staffId, style: const TextStyle(fontWeight: FontWeight.bold, color: _textPrimary)),
                    Text('Permission Request', style: const TextStyle(fontSize: 13, color: _textSecondary)),
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
              _buildInfoChip(Icons.calendar_today, _formatDate(request.requestDate)),
              const SizedBox(width: 12),
              _buildInfoChip(Icons.access_time, '${_formatTime(request.startTime)} - ${_formatTime(request.endTime)}'),
              const SizedBox(width: 12),
              _buildInfoChip(Icons.timelapse, request.durationDisplayText),
            ],
          ),
          if (request.reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(request.reason, style: const TextStyle(fontSize: 13, color: _textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          if (request.status == PermissionRequestStatus.PENDING) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showRejectDialog(schoolId, request.id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleAction(schoolId, request.id, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
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
          const Text('Error Loading Requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 8),
          Text(error.toString(), style: const TextStyle(color: _textSecondary)),
        ],
      ),
    );
  }

  List<PermissionRequest> _filterRequests(List<PermissionRequest> requests) {
    if (_searchQuery.isEmpty) return requests;
    return requests.where((request) {
      return request.staffId.toLowerCase().contains(_searchQuery) ||
          request.reason.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  void _showRejectDialog(String schoolId, String requestId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Reject Permission Request', style: TextStyle(color: _textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:', style: TextStyle(color: _textSecondary)),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: _textPrimary),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter rejection reason...',
                hintStyle: const TextStyle(color: _textSecondary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _borderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _borderColor)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _accentBlue)),
                filled: true,
                fillColor: _bgLight,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleAction(schoolId, requestId, false, rejectionReason: reasonController.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(String schoolId, String requestId, bool approve, {String? rejectionReason}) async {
    try {
      final session = ref.read(currentSessionProvider);
      final repo = ref.read(permissionRequestRepositoryProvider);
      
      final request = PermissionApprovalRequest(
        status: approve ? PermissionRequestStatus.APPROVED : PermissionRequestStatus.REJECTED,
        rejectionReason: approve ? null : (rejectionReason ?? 'Rejected by admin'),
      );
      await repo.processPermissionRequest(schoolId, requestId, session!.uid, request);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? 'Permission approved' : 'Permission rejected'),
            backgroundColor: approve ? Colors.green : Colors.orange,
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

  Color _getStatusColor(PermissionRequestStatus status) {
    switch (status) {
      case PermissionRequestStatus.PENDING: return const Color(0xFFF59E0B);
      case PermissionRequestStatus.APPROVED: return const Color(0xFF10B981);
      case PermissionRequestStatus.REJECTED: return const Color(0xFFEF4444);
      case PermissionRequestStatus.CANCELLED: return const Color(0xFF6B7280);
    }
  }

  String _getStatusLabel(PermissionRequestStatus status) {
    switch (status) {
      case PermissionRequestStatus.PENDING: return 'Pending';
      case PermissionRequestStatus.APPROVED: return 'Approved';
      case PermissionRequestStatus.REJECTED: return 'Rejected';
      case PermissionRequestStatus.CANCELLED: return 'Cancelled';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
