import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../data/repositories/student_leave_repository.dart';
import '../../../domain/entities/student_leave.dart';
import '../../../domain/entities/staff_profile.dart';

/// Screen for class teachers to view and approve/reject student leave requests
/// for their assigned class/section.
class ClassTeacherLeaveScreen extends ConsumerStatefulWidget {
  const ClassTeacherLeaveScreen({super.key});

  @override
  ConsumerState<ClassTeacherLeaveScreen> createState() => _ClassTeacherLeaveScreenState();
}

class _ClassTeacherLeaveScreenState extends ConsumerState<ClassTeacherLeaveScreen> {
  StaffProfile? _staffProfile;
  bool _isLoadingProfile = true;
  final _rejectionReasonController = TextEditingController();

  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStaffProfile());
  }

  @override
  void dispose() {
    _rejectionReasonController.dispose();
    super.dispose();
  }

  Future<void> _loadStaffProfile() async {
    final session = ref.read(currentSessionProvider);
    if (session == null) return;

    final schoolId = session.schoolId;
    final uid = session.uid;
    if (schoolId == null) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('schools').doc(schoolId).collection('staff')
          .where('userId', isEqualTo: uid)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        setState(() {
          _staffProfile = StaffProfile.fromFirestore(snap.docs.first);
          _isLoadingProfile = false;
        });
      } else {
        setState(() => _isLoadingProfile = false);
      }
    } catch (e) {
      debugPrint('[ClassTeacherLeave] Error loading profile: $e');
      setState(() => _isLoadingProfile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;

    if (_isLoadingProfile) {
      return const Center(child: CircularProgressIndicator(color: _accentBlue));
    }

    if (_staffProfile == null || !_staffProfile!.isClassTeacher) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined, size: 56, color: _textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text('Not Assigned as Class Teacher', style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Contact admin to assign you as a class teacher.', style: TextStyle(color: _textSecondary, fontSize: 14)),
          ],
        ),
      );
    }

    final schoolId = session?.schoolId;
    if (schoolId == null) {
      return const Center(child: Text('No school found', style: TextStyle(color: _textSecondary)));
    }

    final className = _staffProfile!.assignedClass!;
    final section = _staffProfile!.assignedSection!;

    final leavesAsync = ref.watch(classStudentLeavesProvider(
      (schoolId: schoolId, className: className, section: section),
    ));

    return Column(
      children: [
        // Header
        Container(
          padding: EdgeInsets.fromLTRB(isDesktop ? 24 : 16, isDesktop ? 20 : 16, isDesktop ? 24 : 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Student Leave Requests', style: TextStyle(fontSize: isDesktop ? 20 : 17, fontWeight: FontWeight.bold, color: _textPrimary)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: _accentBlue.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                        child: Text('Class $className - $section', style: const TextStyle(color: _accentBlue, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: leavesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: _accentBlue)),
            error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
            data: (leaves) {
              if (leaves.isEmpty) {
                return Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.event_available_rounded, size: 48, color: _textSecondary.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    const Text('No leave requests', style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('No student leave requests for your class yet.', style: TextStyle(color: _textSecondary, fontSize: 13)),
                  ]),
                );
              }

              // Summary
              final pending = leaves.where((l) => l.isPending).length;
              final approved = leaves.where((l) => l.isApproved).length;
              final rejected = leaves.where((l) => l.status == StudentLeaveStatus.REJECTED).length;

              return Column(
                children: [
                  // Summary bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: const BoxDecoration(color: _cardDark, border: Border(bottom: BorderSide(color: _borderColor))),
                    child: Row(children: [
                      _summaryChip('Total', '${leaves.length}', const Color(0xFF3B82F6)),
                      const SizedBox(width: 12),
                      _summaryChip('Pending', '$pending', const Color(0xFFF59E0B)),
                      const SizedBox(width: 12),
                      _summaryChip('Approved', '$approved', const Color(0xFF10B981)),
                      const SizedBox(width: 12),
                      _summaryChip('Rejected', '$rejected', Colors.red),
                    ]),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.all(isDesktop ? 24 : 12),
                      itemCount: leaves.length,
                      itemBuilder: (context, index) => _buildLeaveCard(leaves[index], isDesktop, session),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _summaryChip(String label, String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(count, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11)),
      ]),
    );
  }

  Widget _buildLeaveCard(StudentLeaveRequest leave, bool isDesktop, dynamic session) {
    final statusColor = _getStatusColor(leave.status);
    final startStr = '${leave.startDate.day.toString().padLeft(2, '0')}/${leave.startDate.month.toString().padLeft(2, '0')}/${leave.startDate.year}';
    final endStr = '${leave.endDate.day.toString().padLeft(2, '0')}/${leave.endDate.month.toString().padLeft(2, '0')}/${leave.endDate.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: student name + status
          Row(
            children: [
              CircleAvatar(
                backgroundColor: _accentBlue.withValues(alpha: 0.15),
                radius: 18,
                child: Text(leave.studentName.isNotEmpty ? leave.studentName[0].toUpperCase() : '?',
                    style: const TextStyle(color: _accentBlue, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(leave.studentName, style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                    Text('ID: ${leave.studentNumericId}', style: const TextStyle(color: _textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Text(leave.statusLabel, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Details
          Wrap(spacing: 16, runSpacing: 6, children: [
            _detailChip(Icons.category_rounded, leave.leaveTypeLabel, _textSecondary),
            _detailChip(Icons.date_range_rounded, '$startStr - $endStr', _textSecondary),
            _detailChip(Icons.timer_outlined, '${leave.totalDays} day(s)', _textSecondary),
          ]),
          if (leave.reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Reason: ${leave.reason}', style: const TextStyle(color: _textSecondary, fontSize: 12)),
          ],
          if (leave.rejectionReason != null && leave.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Rejection: ${leave.rejectionReason}', style: const TextStyle(color: Colors.orange, fontSize: 11)),
          ],
          // Actions for pending
          if (leave.isPending) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showRejectDialog(leave, session),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Reject', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red, width: 0.5),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _approveLeave(leave, session),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Approve', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailChip(IconData icon, String text, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 13),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
    ]);
  }

  Color _getStatusColor(StudentLeaveStatus status) {
    switch (status) {
      case StudentLeaveStatus.PENDING: return const Color(0xFFF59E0B);
      case StudentLeaveStatus.APPROVED: return const Color(0xFF10B981);
      case StudentLeaveStatus.REJECTED: return Colors.red;
      case StudentLeaveStatus.CANCELLED: return _textSecondary;
    }
  }

  Future<void> _approveLeave(StudentLeaveRequest leave, dynamic session) async {
    try {
      await ref.read(studentLeaveRepositoryProvider).approveLeave(
        session.schoolId as String, leave.id, session.uid as String,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Leave approved for ${leave.studentName}'), backgroundColor: _accentBlue),
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

  void _showRejectDialog(StudentLeaveRequest leave, dynamic session) {
    _rejectionReasonController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardDark,
        title: const Text('Reject Leave', style: TextStyle(color: _textPrimary, fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Reject leave for ${leave.studentName}?', style: const TextStyle(color: _textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: _rejectionReasonController,
            style: const TextStyle(color: _textPrimary, fontSize: 13),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Reason for rejection (optional)',
              hintStyle: TextStyle(color: _textSecondary.withValues(alpha: 0.5)),
              filled: true,
              fillColor: _bgDark,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _borderColor)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _borderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _accentBlue)),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _textSecondary))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(studentLeaveRepositoryProvider).rejectLeave(
                  session.schoolId as String,
                  leave.id,
                  session.uid as String,
                  _rejectionReasonController.text.trim(),
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Leave rejected for ${leave.studentName}'), backgroundColor: Colors.orange),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}
