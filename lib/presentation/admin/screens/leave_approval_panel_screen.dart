import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/leave_application.dart';
import '../../../domain/entities/permission_request.dart';
import '../widgets/leave_request_card.dart';
import '../widgets/permission_request_card.dart';

class LeaveApprovalPanelScreen extends StatefulWidget {
  final String schoolId;

  const LeaveApprovalPanelScreen({
    Key? key,
    required this.schoolId,
  }) : super(key: key);

  @override
  State<LeaveApprovalPanelScreen> createState() =>
      _LeaveApprovalPanelScreenState();
}

class _LeaveApprovalPanelScreenState extends State<LeaveApprovalPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave & Permission Approvals'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pending Leaves', icon: Icon(Icons.pending_actions)),
            Tab(text: 'Pending Permissions', icon: Icon(Icons.access_time)),
            Tab(text: 'Approved', icon: Icon(Icons.check_circle)),
            Tab(text: 'Rejected', icon: Icon(Icons.cancel)),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() => _selectedFilter = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All')),
              const PopupMenuItem(value: 'today', child: Text('Today')),
              const PopupMenuItem(value: 'week', child: Text('This Week')),
              const PopupMenuItem(value: 'month', child: Text('This Month')),
            ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingLeavesList(),
          _buildPendingPermissionsList(),
          _buildApprovedList(),
          _buildRejectedList(),
        ],
      ),
    );
  }

  Widget _buildPendingLeavesList() {
    return StreamBuilder<List<LeaveApplication>>(
      stream: _getPendingLeavesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final leaves = snapshot.data ?? [];

        if (leaves.isEmpty) {
          return _buildEmptyState('No pending leave requests');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: leaves.length,
          itemBuilder: (context, index) {
            return LeaveRequestCard(
              leave: leaves[index],
              onApprove: () => _approveLeave(leaves[index]),
              onReject: () => _rejectLeave(leaves[index]),
            );
          },
        );
      },
    );
  }

  Widget _buildPendingPermissionsList() {
    return StreamBuilder<List<PermissionRequest>>(
      stream: _getPendingPermissionsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final permissions = snapshot.data ?? [];

        if (permissions.isEmpty) {
          return _buildEmptyState('No pending permission requests');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: permissions.length,
          itemBuilder: (context, index) {
            return PermissionRequestCard(
              permission: permissions[index],
              onApprove: () => _approvePermission(permissions[index]),
              onReject: () => _rejectPermission(permissions[index]),
            );
          },
        );
      },
    );
  }

  Widget _buildApprovedList() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: Colors.black87,
            tabs: [
              Tab(text: 'Leaves'),
              Tab(text: 'Permissions'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildApprovedLeavesList(),
                _buildApprovedPermissionsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovedLeavesList() {
    return StreamBuilder<List<LeaveApplication>>(
      stream: _getApprovedLeavesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final leaves = snapshot.data ?? [];

        if (leaves.isEmpty) {
          return _buildEmptyState('No approved leaves');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: leaves.length,
          itemBuilder: (context, index) {
            return LeaveRequestCard(
              leave: leaves[index],
              isReadOnly: true,
            );
          },
        );
      },
    );
  }

  Widget _buildApprovedPermissionsList() {
    return StreamBuilder<List<PermissionRequest>>(
      stream: _getApprovedPermissionsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final permissions = snapshot.data ?? [];

        if (permissions.isEmpty) {
          return _buildEmptyState('No approved permissions');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: permissions.length,
          itemBuilder: (context, index) {
            return PermissionRequestCard(
              permission: permissions[index],
              isReadOnly: true,
            );
          },
        );
      },
    );
  }

  Widget _buildRejectedList() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: Colors.black87,
            tabs: [
              Tab(text: 'Leaves'),
              Tab(text: 'Permissions'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildRejectedLeavesList(),
                _buildRejectedPermissionsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectedLeavesList() {
    return StreamBuilder<List<LeaveApplication>>(
      stream: _getRejectedLeavesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final leaves = snapshot.data ?? [];

        if (leaves.isEmpty) {
          return _buildEmptyState('No rejected leaves');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: leaves.length,
          itemBuilder: (context, index) {
            return LeaveRequestCard(
              leave: leaves[index],
              isReadOnly: true,
            );
          },
        );
      },
    );
  }

  Widget _buildRejectedPermissionsList() {
    return StreamBuilder<List<PermissionRequest>>(
      stream: _getRejectedPermissionsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final permissions = snapshot.data ?? [];

        if (permissions.isEmpty) {
          return _buildEmptyState('No rejected permissions');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: permissions.length,
          itemBuilder: (context, index) {
            return PermissionRequestCard(
              permission: permissions[index],
              isReadOnly: true,
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Stream<List<LeaveApplication>> _getPendingLeavesStream() {
    // TODO: Implement with your LeaveApplicationRepository
    return Stream.value([]);
  }

  Stream<List<PermissionRequest>> _getPendingPermissionsStream() {
    // TODO: Implement with your PermissionRequestRepository
    return Stream.value([]);
  }

  Stream<List<LeaveApplication>> _getApprovedLeavesStream() {
    // TODO: Implement with your LeaveApplicationRepository
    return Stream.value([]);
  }

  Stream<List<PermissionRequest>> _getApprovedPermissionsStream() {
    // TODO: Implement with your PermissionRequestRepository
    return Stream.value([]);
  }

  Stream<List<LeaveApplication>> _getRejectedLeavesStream() {
    // TODO: Implement with your LeaveApplicationRepository
    return Stream.value([]);
  }

  Stream<List<PermissionRequest>> _getRejectedPermissionsStream() {
    // TODO: Implement with your PermissionRequestRepository
    return Stream.value([]);
  }

  Future<void> _approveLeave(LeaveApplication leave) async {
    final confirmed = await _showConfirmDialog(
      'Approve Leave',
      'Approve leave request for ${leave.totalDays} days?',
    );

    if (confirmed != true) return;

    try {
      // TODO: Implement with your LeaveApplicationRepository
      // await _repository.approveLeave(leave.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leave approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving leave: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectLeave(LeaveApplication leave) async {
    final reason = await _showRejectDialog();
    if (reason == null) return;

    try {
      // TODO: Implement with your LeaveApplicationRepository
      // await _repository.rejectLeave(leave.id, reason);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leave rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting leave: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _approvePermission(PermissionRequest permission) async {
    final confirmed = await _showConfirmDialog(
      'Approve Permission',
      'Approve permission request for ${permission.durationDisplayText}?',
    );

    if (confirmed != true) return;

    try {
      // TODO: Implement with your PermissionRequestRepository
      // await _repository.approvePermission(permission.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving permission: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectPermission(PermissionRequest permission) async {
    final reason = await _showRejectDialog();
    if (reason == null) return;

    try {
      // TODO: Implement with your PermissionRequestRepository
      // await _repository.rejectPermission(permission.id, reason);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting permission: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool?> _showConfirmDialog(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showRejectDialog() {
    final controller = TextEditingController();
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Request'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Rejection Reason',
            hintText: 'Enter reason for rejection',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a reason')),
                );
                return;
              }
              Navigator.pop(context, controller.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}
