import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/staff_attendance.dart';

class AttendanceDetailDialog extends StatelessWidget {
  final StaffAttendance attendance;

  const AttendanceDetailDialog({
    Key? key,
    required this.attendance,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getStatusIcon(),
                  color: _getStatusColor(),
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE, MMM d, y').format(attendance.date),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor().withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          attendance.statusDisplayName,
                          style: TextStyle(
                            color: _getStatusColor(),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            if (attendance.loginTime != null) ...[
              _buildDetailRow(
                'Login Time',
                DateFormat('hh:mm a').format(attendance.loginTime!),
                Icons.login,
              ),
              const SizedBox(height: 12),
            ],
            if (attendance.logoutTime != null) ...[
              _buildDetailRow(
                'Logout Time',
                DateFormat('hh:mm a').format(attendance.logoutTime!),
                Icons.logout,
              ),
              const SizedBox(height: 12),
            ],
            if (attendance.workingHoursDisplay != null) ...[
              _buildDetailRow(
                'Working Hours',
                attendance.workingHoursDisplay!,
                Icons.access_time,
              ),
              const SizedBox(height: 12),
            ],
            if (attendance.isLate) ...[
              _buildDetailRow(
                'Late By',
                '${attendance.lateByMinutes} minutes',
                Icons.schedule,
                color: Colors.red,
              ),
              const SizedBox(height: 12),
            ],
            if (attendance.leaveType != null) ...[
              _buildDetailRow(
                'Leave Type',
                attendance.leaveType!,
                Icons.event_busy,
              ),
              const SizedBox(height: 12),
            ],
            if (attendance.permissionMinutes != null) ...[
              _buildDetailRow(
                'Permission Duration',
                '${attendance.permissionMinutes! ~/ 60}h ${attendance.permissionMinutes! % 60}m',
                Icons.timer,
              ),
              const SizedBox(height: 12),
            ],
            if (attendance.swipes != null && attendance.swipes!.isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                'Swipe History',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              ...attendance.swipes!.map((swipe) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.credit_card, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('hh:mm:ss a').format(swipe.timestamp),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  )),
            ],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon,
      {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color ?? Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getStatusIcon() {
    switch (attendance.status) {
      case StaffAttendanceStatus.PRESENT:
        return Icons.check_circle;
      case StaffAttendanceStatus.ABSENT:
        return Icons.cancel;
      case StaffAttendanceStatus.LEAVE:
        return Icons.event_busy;
      case StaffAttendanceStatus.PERMISSION:
        return Icons.access_time;
      case StaffAttendanceStatus.LOP:
        return Icons.money_off;
      case StaffAttendanceStatus.HOLIDAY:
        return Icons.beach_access;
      case StaffAttendanceStatus.PARTIAL:
        return Icons.warning;
    }
  }

  Color _getStatusColor() {
    switch (attendance.status) {
      case StaffAttendanceStatus.PRESENT:
        return Colors.green;
      case StaffAttendanceStatus.ABSENT:
        return Colors.orange;
      case StaffAttendanceStatus.LEAVE:
        return Colors.yellow.shade700;
      case StaffAttendanceStatus.PERMISSION:
        return Colors.blue;
      case StaffAttendanceStatus.LOP:
        return Colors.red;
      case StaffAttendanceStatus.HOLIDAY:
        return Colors.grey;
      case StaffAttendanceStatus.PARTIAL:
        return Colors.amber;
    }
  }
}
