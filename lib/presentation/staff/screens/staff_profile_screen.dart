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

  // Dark theme colors (match dashboard)
  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

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
      backgroundColor: _bgDark,
      body: Column(
        children: [
          Expanded(
            child: staffAsyncValue.when(
              loading: () => const Center(child: CircularProgressIndicator(color: _accentBlue)),
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
            decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: _borderColor)),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: _accentBlue,
                  child: Text(staff.name[0].toUpperCase(), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(height: 16),
                Text(staff.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _textPrimary)),
                const SizedBox(height: 4),
                Text(staff.designation ?? 'Staff Member', style: const TextStyle(fontSize: 14, color: _textSecondary)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: _accentBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(staff.department, style: const TextStyle(color: _accentBlue, fontWeight: FontWeight.w600, fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Details Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: _borderColor)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Contact Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
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
            decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: _borderColor)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Employment Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
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
          Icon(icon, size: 20, color: _textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: _textSecondary)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _textPrimary)),
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
          Icon(icon, size: 20, color: _textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: _textSecondary)),
                const SizedBox(height: 2),
                Text(
                  value.trim().isEmpty ? 'Not provided' : value,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: value.trim().isEmpty ? _textSecondary : _textPrimary),
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
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
          const SizedBox(height: 16),
          const Text('Error loading profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(error.toString(), style: const TextStyle(color: _textSecondary)),
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
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off_outlined, size: 48, color: _textSecondary),
          SizedBox(height: 16),
          Text('Profile not found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
