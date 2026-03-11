import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/repositories/student_leave_repository.dart';
import '../../../domain/entities/student.dart';
import '../../../domain/entities/student_leave.dart';

class StudentLeaveHistoryScreen extends ConsumerWidget {
  final Student student;
  final String schoolId;

  const StudentLeaveHistoryScreen({super.key, required this.student, required this.schoolId});

  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leavesAsync = ref.watch(studentLeavesProvider((schoolId: schoolId, studentId: student.id)));
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;

    return Container(
      color: _bgDark,
      child: leavesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _accentBlue)),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
        data: (leaves) {
          if (leaves.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.event_note_rounded, size: 48, color: _textSecondary.withOpacity(0.5)),
              const SizedBox(height: 16),
              const Text('No leave requests found', style: TextStyle(color: _textSecondary, fontSize: 14)),
            ]));
          }

          // Summary counts
          final pending = leaves.where((l) => l.status == StudentLeaveStatus.PENDING).length;
          final approved = leaves.where((l) => l.status == StudentLeaveStatus.APPROVED).length;
          final rejected = leaves.where((l) => l.status == StudentLeaveStatus.REJECTED).length;

          return Column(children: [
            // Summary bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            // List
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(isDesktop ? 24 : 12),
                itemCount: leaves.length,
                itemBuilder: (context, index) => _buildLeaveCard(context, leaves[index], isDesktop, ref),
              ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _summaryChip(String label, String value, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: _textSecondary, fontSize: 10)),
      ]),
    ));
  }

  Widget _buildLeaveCard(BuildContext context, StudentLeaveRequest leave, bool isDesktop, WidgetRef ref) {
    final statusColor = _getStatusColor(leave.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Icon(_getLeaveIcon(leave.leaveType), color: statusColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(leave.leaveTypeLabel, style: const TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text('${DateFormat('dd MMM yyyy').format(leave.startDate)} - ${DateFormat('dd MMM yyyy').format(leave.endDate)}',
                style: const TextStyle(color: _textSecondary, fontSize: 11)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
              child: Text(leave.statusLabel, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _bgDark, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.notes_rounded, color: _textSecondary, size: 14),
              const SizedBox(width: 8),
              Expanded(child: Text(leave.reason, style: const TextStyle(color: _textSecondary, fontSize: 12))),
            ]),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.calendar_today_rounded, color: _textSecondary.withOpacity(0.5), size: 12),
            const SizedBox(width: 4),
            Text('${leave.totalDays} day(s)', style: const TextStyle(color: _textSecondary, fontSize: 11)),
            const SizedBox(width: 16),
            Icon(Icons.access_time_rounded, color: _textSecondary.withOpacity(0.5), size: 12),
            const SizedBox(width: 4),
            Text('Applied ${DateFormat('dd MMM yyyy, hh:mm a').format(leave.createdAt)}',
              style: const TextStyle(color: _textSecondary, fontSize: 11)),
          ]),
          if (leave.rejectionReason != null && leave.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, color: Colors.red, size: 14),
                const SizedBox(width: 6),
                Expanded(child: Text('Reason: ${leave.rejectionReason}', style: const TextStyle(color: Colors.red, fontSize: 11))),
              ]),
            ),
          ],
          // Cancel button for pending leaves
          if (leave.isPending) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: _cardDark,
                      title: const Text('Cancel Leave', style: TextStyle(color: _textPrimary)),
                      content: const Text('Are you sure you want to cancel this leave request?', style: TextStyle(color: _textSecondary)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No', style: TextStyle(color: _textSecondary))),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes, Cancel', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    try {
                      await ref.read(studentLeaveRepositoryProvider).cancelLeave(schoolId, leave.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Leave request cancelled'), backgroundColor: Color(0xFF10B981)),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  }
                },
                icon: const Icon(Icons.cancel_outlined, size: 16),
                label: const Text('Cancel Request', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Color _getStatusColor(StudentLeaveStatus status) {
    switch (status) {
      case StudentLeaveStatus.PENDING: return const Color(0xFFF59E0B);
      case StudentLeaveStatus.APPROVED: return const Color(0xFF10B981);
      case StudentLeaveStatus.REJECTED: return Colors.red;
      case StudentLeaveStatus.CANCELLED: return _textSecondary;
    }
  }

  IconData _getLeaveIcon(StudentLeaveType type) {
    switch (type) {
      case StudentLeaveType.SICK_LEAVE: return Icons.local_hospital_rounded;
      case StudentLeaveType.CASUAL_LEAVE: return Icons.beach_access_rounded;
      case StudentLeaveType.PERMISSION: return Icons.access_time_rounded;
      case StudentLeaveType.FAMILY_EMERGENCY: return Icons.family_restroom_rounded;
      case StudentLeaveType.OTHER: return Icons.event_note_rounded;
    }
  }
}
