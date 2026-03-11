import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../data/repositories/student_leave_repository.dart';
import '../../../domain/entities/student_leave.dart';

class StudentLeaveApprovalScreen extends ConsumerStatefulWidget {
  const StudentLeaveApprovalScreen({super.key});

  @override
  ConsumerState<StudentLeaveApprovalScreen> createState() => _StudentLeaveApprovalScreenState();
}

class _StudentLeaveApprovalScreenState extends ConsumerState<StudentLeaveApprovalScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
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
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _rejectionReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider);
    if (session == null || session.schoolId == null) {
      return const Center(child: Text('Access Denied', style: TextStyle(color: _textPrimary)));
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;

    return Container(
      color: _bgDark,
      child: Column(children: [
        Container(
          color: _cardDark,
          child: TabBar(
            controller: _tabController,
            indicatorColor: _accentBlue,
            labelColor: _accentBlue,
            unselectedLabelColor: _textSecondary,
            tabs: const [
              Tab(text: 'Pending Requests'),
              Tab(text: 'All Requests'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPendingTab(session, isDesktop),
              _buildAllTab(session, isDesktop),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildPendingTab(dynamic session, bool isDesktop) {
    final pendingAsync = ref.watch(pendingStudentLeavesProvider(session.schoolId as String));

    return pendingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: _accentBlue)),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
      data: (leaves) {
        if (leaves.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.check_circle_outline_rounded, size: 48, color: _textSecondary.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text('No pending leave requests', style: TextStyle(color: _textSecondary, fontSize: 14)),
          ]));
        }
        return ListView.builder(
          padding: EdgeInsets.all(isDesktop ? 20 : 12),
          itemCount: leaves.length,
          itemBuilder: (context, index) => _buildLeaveCard(leaves[index], session, isDesktop, showActions: true),
        );
      },
    );
  }

  Widget _buildAllTab(dynamic session, bool isDesktop) {
    final allAsync = ref.watch(schoolStudentLeavesProvider(session.schoolId as String));

    return allAsync.when(
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

        return ListView.builder(
          padding: EdgeInsets.all(isDesktop ? 20 : 12),
          itemCount: leaves.length,
          itemBuilder: (context, index) => _buildLeaveCard(leaves[index], session, isDesktop, showActions: leaves[index].isPending),
        );
      },
    );
  }

  Widget _buildLeaveCard(StudentLeaveRequest leave, dynamic session, bool isDesktop, {required bool showActions}) {
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
          // Header row
          Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: statusColor.withOpacity(0.2),
              child: Text(leave.studentName.isNotEmpty ? leave.studentName[0].toUpperCase() : '?',
                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(leave.studentName, style: const TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
              Text('Class ${leave.className} - ${leave.section} • ID: ${leave.studentNumericId}',
                style: const TextStyle(color: _textSecondary, fontSize: 11)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
              child: Text(leave.statusLabel, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 12),

          // Leave details
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _bgDark, borderRadius: BorderRadius.circular(8)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _detailChip(Icons.event_note_rounded, leave.leaveTypeLabel, const Color(0xFF3B82F6)),
                const SizedBox(width: 12),
                _detailChip(Icons.calendar_today_rounded,
                  '${DateFormat('dd MMM').format(leave.startDate)} - ${DateFormat('dd MMM yyyy').format(leave.endDate)}',
                  _accentBlue),
                const SizedBox(width: 12),
                _detailChip(Icons.timelapse_rounded, '${leave.totalDays} day(s)', const Color(0xFF8B5CF6)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.notes_rounded, color: _textSecondary, size: 14),
                const SizedBox(width: 6),
                Expanded(child: Text(leave.reason, style: const TextStyle(color: _textSecondary, fontSize: 12))),
              ]),
              if (leave.parentName != null && leave.parentName!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.person_rounded, color: _textSecondary, size: 14),
                  const SizedBox(width: 6),
                  Text('Parent: ${leave.parentName}', style: const TextStyle(color: _textSecondary, fontSize: 11)),
                  if (leave.parentPhone != null) ...[
                    const SizedBox(width: 8),
                    Text('• ${leave.parentPhone}', style: const TextStyle(color: _textSecondary, fontSize: 11)),
                  ],
                ]),
              ],
            ]),
          ),

          // Rejection reason if exists
          if (leave.rejectionReason != null && leave.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, color: Colors.red, size: 14),
                const SizedBox(width: 6),
                Expanded(child: Text('Rejection: ${leave.rejectionReason}', style: const TextStyle(color: Colors.red, fontSize: 11))),
              ]),
            ),
          ],

          // Action buttons
          if (showActions && leave.isPending) ...[
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              // Reject
              OutlinedButton.icon(
                onPressed: () => _showRejectDialog(leave, session),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Reject', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 10),
              // Approve
              ElevatedButton.icon(
                onPressed: () => _approveLeave(leave, session),
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Approve', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ]),
          ],

          // Footer
          const SizedBox(height: 8),
          Text('Applied ${DateFormat('dd MMM yyyy, hh:mm a').format(leave.createdAt)}',
            style: TextStyle(color: _textSecondary.withOpacity(0.5), fontSize: 10)),
        ]),
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

  Future<void> _approveLeave(StudentLeaveRequest leave, dynamic session) async {
    try {
      await ref.read(studentLeaveRepositoryProvider).approveLeave(
        session.schoolId as String, leave.id, session.uid as String,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Leave approved for ${leave.studentName}'), backgroundColor: const Color(0xFF10B981)),
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
        title: const Text('Reject Leave Request', style: TextStyle(color: _textPrimary, fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Reject leave for ${leave.studentName}?', style: const TextStyle(color: _textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: _rejectionReasonController,
            style: const TextStyle(color: _textPrimary, fontSize: 13),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Reason for rejection (optional)',
              hintStyle: TextStyle(color: _textSecondary.withOpacity(0.5)),
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

  Color _getStatusColor(StudentLeaveStatus status) {
    switch (status) {
      case StudentLeaveStatus.PENDING: return const Color(0xFFF59E0B);
      case StudentLeaveStatus.APPROVED: return const Color(0xFF10B981);
      case StudentLeaveStatus.REJECTED: return Colors.red;
      case StudentLeaveStatus.CANCELLED: return _textSecondary;
    }
  }
}
