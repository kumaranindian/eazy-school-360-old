import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:eazy_school_360/domain/entities/staff_profile.dart';
import 'package:eazy_school_360/domain/entities/app_user.dart';
import 'package:eazy_school_360/domain/entities/leave_application.dart';
import 'package:eazy_school_360/domain/entities/permission_request.dart';
import 'package:eazy_school_360/presentation/admin/screens/add_staff_screen.dart';
import 'package:eazy_school_360/core/providers/auth_provider.dart';
import 'package:eazy_school_360/data/repositories/staff_management_repository.dart';
import 'package:eazy_school_360/data/repositories/leave_application_repository.dart';
import 'package:eazy_school_360/data/repositories/permission_request_repository.dart';

class StaffDetailsScreen extends ConsumerStatefulWidget {
  final StaffProfile staff;

  const StaffDetailsScreen({super.key, required this.staff});

  @override
  ConsumerState<StaffDetailsScreen> createState() => _StaffDetailsScreenState();
}

class _StaffDetailsScreenState extends ConsumerState<StaffDetailsScreen> {
  late StaffProfile _staff;
  bool _isToggling = false;

  // Dark theme colors
  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  @override
  void initState() {
    super.initState();
    _staff = widget.staff;
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _staff.status == UserStatus.ACTIVE;

    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        title: Text(_staff.name, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF161B22),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _navigateToEdit(context),
            tooltip: 'Edit Staff',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header with Toggle
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _cardDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _borderColor),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: isActive ? _accentBlue : _textSecondary,
                        child: Text(
                          _staff.name.isNotEmpty ? _staff.name[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_staff.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _textPrimary)),
                            const SizedBox(height: 4),
                            Text(_staff.designation ?? _staff.department, style: const TextStyle(fontSize: 14, color: _textSecondary)),
                            const SizedBox(height: 8),
                            _buildStatusChip(_staff.status),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Basic Information
            _buildInfoCard(
              'Basic Information',
              Icons.person_rounded,
              [
                _buildInfoRow('Employee ID', _staff.employeeId),
                _buildInfoRow('Email', _staff.email),
                _buildInfoRow('Department', _staff.department),
                _buildInfoRow('Staff Type', _staff.staffType.name.replaceAll('_', ' ')),
                _buildInfoRow('Joining Date', _formatDate(_staff.joiningDate)),
                if (_staff.designation != null) _buildInfoRow('Designation', _staff.designation!),
              ],
            ),
            const SizedBox(height: 16),

            // Contact Information
            _buildInfoCard(
              'Contact Information',
              Icons.contact_phone_rounded,
              [
                _buildInfoRow('Phone', _staff.phoneNumber ?? 'Not provided'),
                _buildInfoRow('Address', _staff.address ?? 'Not provided'),
                _buildInfoRow('Emergency Contact', _staff.emergencyContact ?? 'Not provided'),
              ],
            ),
            const SizedBox(height: 16),

            // System Information
            _buildInfoCard(
              'System Information',
              Icons.settings_rounded,
              [
                _buildInfoRow('User ID', _staff.userId),
                _buildInfoRow('Status', _staff.status.name),
                _buildInfoRow('Created', _formatDateTime(_staff.createdAt)),
                _buildInfoRow('Last Updated', _formatDateTime(_staff.updatedAt)),
              ],
            ),
            const SizedBox(height: 16),

            // Leave History
            _buildLeaveHistorySection(),
            const SizedBox(height: 16),

            // Permission History
            _buildPermissionHistorySection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(UserStatus status) {
    final isActive = status == UserStatus.ACTIVE;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        status.name,
        style: TextStyle(color: isActive ? Colors.green : Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildInfoCard(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _accentBlue.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: _accentBlue, size: 18),
              ),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(color: _textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${_formatDate(dateTime)} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleStaffStatus(bool activate) async {
    setState(() => _isToggling = true);

    try {
      final session = ref.read(currentSessionProvider);
      final repo = ref.read(staffManagementRepositoryProvider);

      await repo.toggleStaffStatus(session!.schoolId!, _staff.id, session.uid);

      // Update local state
      setState(() {
        _staff = _staff.copyWith(
          status: activate ? UserStatus.ACTIVE : UserStatus.DISABLED,
        );
        _isToggling = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(activate ? 'Staff activated' : 'Staff deactivated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isToggling = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _navigateToEdit(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddStaffScreen(staffToEdit: _staff),
      ),
    ).then((_) {
      // Refresh staff data when returning from edit
      // This would require fetching fresh data from the repository
    });
  }

  Widget _buildLeaveHistorySection() {
    final session = ref.watch(currentSessionProvider);
    if (session?.schoolId == null) return const SizedBox.shrink();

    final leavesAsync = ref.watch(staffLeaveApplicationsProvider((
      schoolId: session!.schoolId!,
      applicantId: _staff.userId,
    )));

    return Container(
      padding: const EdgeInsets.all(16),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.event_note_rounded, color: Color(0xFF3B82F6), size: 18),
              ),
              const SizedBox(width: 12),
              const Text('Leave History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          leavesAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: _accentBlue, strokeWidth: 2))),
            error: (e, _) => Text('Error loading leaves: $e', style: const TextStyle(color: Colors.red, fontSize: 12)),
            data: (leaves) {
              if (leaves.isEmpty) {
                return const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('No leave records found', style: TextStyle(color: _textSecondary))));
              }
              final sortedLeaves = List<LeaveApplication>.from(leaves)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
              final displayLeaves = sortedLeaves.take(10).toList();
              return Column(
                children: [
                  ...displayLeaves.map((leave) => _buildLeaveItem(leave)),
                  if (leaves.length > 10)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('+ ${leaves.length - 10} more leaves', style: const TextStyle(color: _textSecondary, fontSize: 12)),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveItem(LeaveApplication leave) {
    final statusColor = _getLeaveStatusColor(leave.status);
    final dateFormat = DateFormat('dd MMM yyyy');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bgDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(leave.metadata?['leaveTypeName'] as String? ?? leave.leaveTypeCode, style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 4),
                Text('${dateFormat.format(leave.startDate)} - ${dateFormat.format(leave.endDate)}', style: const TextStyle(color: _textSecondary, fontSize: 12)),
                const SizedBox(height: 2),
                Text('${leave.totalDays} day${leave.totalDays > 1 ? 's' : ''}', style: const TextStyle(color: _textSecondary, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
            child: Text(leave.status.name, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Color _getLeaveStatusColor(LeaveApplicationStatus status) {
    switch (status) {
      case LeaveApplicationStatus.APPROVED: return const Color(0xFF10B981);
      case LeaveApplicationStatus.PENDING: return const Color(0xFFF59E0B);
      case LeaveApplicationStatus.REJECTED: return const Color(0xFFEF4444);
      case LeaveApplicationStatus.CANCELLED: return const Color(0xFF6B7280);
    }
  }

  Widget _buildPermissionHistorySection() {
    final session = ref.watch(currentSessionProvider);
    if (session?.schoolId == null) return const SizedBox.shrink();

    final permissionsAsync = ref.watch(staffPermissionRequestsProvider((
      schoolId: session!.schoolId!,
      applicantId: _staff.userId,
    )));

    return Container(
      padding: const EdgeInsets.all(16),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.access_time_rounded, color: Color(0xFF8B5CF6), size: 18),
              ),
              const SizedBox(width: 12),
              const Text('Permission History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          permissionsAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: _accentBlue, strokeWidth: 2))),
            error: (e, _) => Text('Error loading permissions: $e', style: const TextStyle(color: Colors.red, fontSize: 12)),
            data: (permissions) {
              if (permissions.isEmpty) {
                return const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('No permission records found', style: TextStyle(color: _textSecondary))));
              }
              final sortedPermissions = List<PermissionRequest>.from(permissions)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
              final displayPermissions = sortedPermissions.take(10).toList();
              return Column(
                children: [
                  ...displayPermissions.map((perm) => _buildPermissionItem(perm)),
                  if (permissions.length > 10)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('+ ${permissions.length - 10} more permissions', style: const TextStyle(color: _textSecondary, fontSize: 12)),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionItem(PermissionRequest perm) {
    final statusColor = _getPermissionStatusColor(perm.status);
    final dateFormat = DateFormat('dd MMM yyyy');
    final timeFormat = DateFormat('hh:mm a');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bgDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(perm.metadata?['permissionTypeName'] as String? ?? 'Permission', style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 4),
                Text(dateFormat.format(perm.requestDate), style: const TextStyle(color: _textSecondary, fontSize: 12)),
                const SizedBox(height: 2),
                Text('${timeFormat.format(perm.startTime)} - ${timeFormat.format(perm.endTime)}', style: const TextStyle(color: _textSecondary, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
            child: Text(perm.status.name, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Color _getPermissionStatusColor(PermissionRequestStatus status) {
    switch (status) {
      case PermissionRequestStatus.APPROVED: return const Color(0xFF10B981);
      case PermissionRequestStatus.PENDING: return const Color(0xFFF59E0B);
      case PermissionRequestStatus.REJECTED: return const Color(0xFFEF4444);
      case PermissionRequestStatus.CANCELLED: return const Color(0xFF6B7280);
    }
  }
}
