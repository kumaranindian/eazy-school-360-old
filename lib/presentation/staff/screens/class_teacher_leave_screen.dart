import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';

/// Screen for class teachers to view and approve/reject student leave requests
/// for their assigned class/section.
class ClassTeacherLeaveScreen extends ConsumerStatefulWidget {
  const ClassTeacherLeaveScreen({super.key});

  @override
  ConsumerState<ClassTeacherLeaveScreen> createState() => _ClassTeacherLeaveScreenState();
}

class _ClassTeacherLeaveScreenState extends ConsumerState<ClassTeacherLeaveScreen> {
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStaffProfile());
  }

  Future<void> _loadStaffProfile() async {
    final session = ref.read(currentSessionProvider);
    if (session == null) return;

    final schoolId = session.schoolId;
    if (schoolId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('schools').doc(schoolId).collection('staff')
          .limit(1)
          .get();
    } catch (e) {
      debugPrint('[ClassTeacherLeave] Error loading profile: $e');
    }
    setState(() => _isLoadingProfile = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
    }

    // Class teacher functionality disabled - fields removed from StaffProfile
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_outlined, size: 56, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text('Class Teacher Functionality Unavailable', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Class teacher assignment has been removed from the system.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14)),
        ],
      ),
    );
  }
}
