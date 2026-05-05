import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eazy_school_360/core/providers/auth_provider.dart';
import 'package:eazy_school_360/data/repositories/staff_management_repository.dart';
import 'package:eazy_school_360/domain/entities/staff_profile.dart';

class StaffProfileScreen extends ConsumerStatefulWidget {
  const StaffProfileScreen({super.key});

  @override
  ConsumerState<StaffProfileScreen> createState() => _StaffProfileScreenState();
}

class _StaffProfileScreenState extends ConsumerState<StaffProfileScreen> {
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _emergencyContactController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider);
    final isDesktop = MediaQuery.of(context).size.width > 900;

    if (session == null || !session.isStaff || session.schoolId == null) {
      return const Scaffold(body: Center(child: Text('Access Denied')));
    }

    final staffAsyncValue = ref.watch(staffByUserIdProvider((
      schoolId: session.schoolId!,
      userId: session.uid,
    )));

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          Expanded(
            child: staffAsyncValue.when(
              loading: () => Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
              error: (error, stack) => _buildErrorState(error, session.schoolId!, session.uid),
              data: (staff) {
                if (staff == null) return _buildNotFoundState();
                _phoneController.text = staff.phoneNumber ?? '';
                _addressController.text = staff.address ?? '';
                _emergencyContactController.text = staff.emergencyContact ?? '';
                return _buildProfileContent(staff, isDesktop, session.schoolId!);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent(StaffProfile staff, bool isDesktop, String schoolId) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 32 : 16),
      child: Column(
        children: [
          // Profile Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(context).colorScheme.outline)),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(staff.name[0].toUpperCase(), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(height: 16),
                Text(staff.name, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 4),
                Text(staff.designation ?? 'Staff Member', style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Details Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(context).colorScheme.outline)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Contact Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 16),
                _buildInfoRow(Icons.email_outlined, 'Email', staff.email),
                _buildInfoRow(Icons.badge_outlined, 'Employee ID', staff.employeeId),
                _buildReadOnlyRow(Icons.phone_outlined, 'Phone', _phoneController.text),
                _buildReadOnlyRow(Icons.home_outlined, 'Address', _addressController.text),
                _buildReadOnlyRow(Icons.emergency_outlined, 'Emergency Contact', _emergencyContactController.text),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Stats Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(context).colorScheme.outline)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Employment Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 16),
                _buildInfoRow(Icons.work_outline, 'Staff Type', staff.staffType.name),
                _buildInfoRow(Icons.calendar_today_outlined, 'Joining Date', _formatDate(staff.joiningDate)),
                _buildInfoRow(Icons.verified_outlined, 'Status', staff.status.name),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(
                  value.trim().isEmpty ? 'Not provided' : value,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: value.trim().isEmpty ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.onSurface),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error, String schoolId, String userId) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          Text('Error loading profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 8),
          Text(error.toString(), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => ref.refresh(staffByUserIdProvider((schoolId: schoolId, userId: userId))),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFoundState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off_outlined, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text('Profile not found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
