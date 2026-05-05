import 'package:flutter/material.dart';
import '../../../data/repositories/staff_attendance_repository.dart';

class AttendanceStatisticsCard extends StatelessWidget {
  final AttendanceStatistics statistics;

  const AttendanceStatisticsCard({
    Key? key,
    required this.statistics,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'This Month',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getAttendanceColor(statistics.attendancePercentage),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${statistics.attendancePercentage.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Present',
                    statistics.presentCount.toString(),
                    Colors.green,
                    Icons.check_circle,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Absent',
                    statistics.absentCount.toString(),
                    Colors.orange,
                    Icons.cancel,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Leave',
                    statistics.leaveCount.toString(),
                    Colors.yellow.shade700,
                    Icons.event_busy,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'LOP',
                    statistics.lopCount.toString(),
                    Colors.red,
                    Icons.money_off,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Permission',
                    statistics.permissionCount.toString(),
                    Colors.blue,
                    Icons.access_time,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Late',
                    statistics.lateCount.toString(),
                    Colors.deepOrange,
                    Icons.schedule,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Holiday',
                    statistics.holidayCount.toString(),
                    Colors.grey,
                    Icons.beach_access,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Working',
                    statistics.workingDays.toString(),
                    Colors.blueGrey,
                    Icons.work,
                  ),
                ),
              ],
            ),
            if (statistics.lateCount > 0) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Average late: ${statistics.averageLateMinutes.toStringAsFixed(0)} minutes',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Color _getAttendanceColor(double percentage) {
    if (percentage >= 90) return Colors.green;
    if (percentage >= 75) return Colors.orange;
    return Colors.red;
  }
}
