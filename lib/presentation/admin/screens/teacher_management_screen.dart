import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eazy_school_360/domain/entities/teacher.dart';
import 'package:eazy_school_360/data/repositories/teacher_repository.dart';
import 'package:eazy_school_360/presentation/admin/screens/add_edit_teacher_screen.dart';
import 'package:eazy_school_360/presentation/admin/providers/admin_providers.dart';

class TeacherManagementScreen extends ConsumerStatefulWidget {
  const TeacherManagementScreen({super.key});

  @override
  ConsumerState<TeacherManagementScreen> createState() => _TeacherManagementScreenState();
}

class _TeacherManagementScreenState extends ConsumerState<TeacherManagementScreen> {
  bool _showInactiveTeachers = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final schoolIdAsyncValue = ref.watch(currentSchoolIdProvider);

    return schoolIdAsyncValue.when(
      data: (schoolId) {
        if (schoolId == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Teacher Management'),
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            body: const Center(
              child: Text('Unable to get school information. Please try logging in again.'),
            ),
          );
        }
        return _buildTeacherManagement(context, schoolId);
      },
      loading: () => Scaffold(
        appBar: AppBar(
          title: const Text('Teacher Management'),
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(
          title: const Text('Teacher Management'),
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }

  Widget _buildTeacherManagement(BuildContext context, String schoolId) {
    final colorScheme = Theme.of(context).colorScheme;
    final teachersAsyncValue = ref.watch(allTeachersProvider(schoolId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Management'),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToAddTeacher(schoolId),
            tooltip: 'Add Teacher',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search teachers by name or email...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
                const SizedBox(height: 12),
                // Filter Toggle
                Row(
                  children: [
                    Switch(
                      value: _showInactiveTeachers,
                      onChanged: (value) {
                        setState(() {
                          _showInactiveTeachers = value;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    const Text('Show inactive teachers'),
                  ],
                ),
              ],
            ),
          ),
          // Teachers List
          Expanded(
            child: teachersAsyncValue.when(
              data: (List<Teacher> teachers) {
                // Filter teachers based on search and active status
                final filteredTeachers = teachers.where((Teacher teacher) {
                  final matchesSearch = _searchQuery.isEmpty ||
                      teacher.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      teacher.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      teacher.phone.contains(_searchQuery);

                  final matchesActiveFilter = _showInactiveTeachers || teacher.isActive;

                  return matchesSearch && matchesActiveFilter;
                }).toList();

                if (filteredTeachers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No teachers found matching "$_searchQuery"'
                              : 'No teachers found',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        if (_searchQuery.isEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Add your first teacher to get started',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _navigateToAddTeacher(schoolId),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Teacher'),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredTeachers.length,
                  itemBuilder: (context, int index) {
                    final Teacher teacher = filteredTeachers[index];
                    return _buildTeacherCard(teacher, colorScheme);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading teachers',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(error.toString()),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.refresh(allTeachersProvider(schoolId)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ref.refresh(allTeachersProvider(schoolId));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Teachers refreshed')),
          );
        },
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildTeacherCard(Teacher teacher, ColorScheme colorScheme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: teacher.isActive
                      ? colorScheme.primary
                      : Colors.grey[400],
                  child: Text(
                    teacher.name.isNotEmpty
                        ? teacher.name[0].toUpperCase()
                        : 'T',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Name and Status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              teacher.name,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: teacher.isActive ? null : Colors.grey[600],
                              ),
                            ),
                          ),
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: teacher.isActive
                                  ? Colors.green[100]
                                  : Colors.red[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              teacher.isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: teacher.isActive
                                    ? Colors.green[800]
                                    : Colors.red[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        teacher.role.displayName,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Contact Information
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(Icons.email, teacher.email),
                      const SizedBox(height: 4),
                      _buildInfoRow(Icons.phone, teacher.phone),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Balance Summary
            Row(
              children: [
                Expanded(
                  child: _buildBalanceSummary(
                    'Leave Balances',
                    teacher.leaveBalances.length,
                    Icons.calendar_today,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildBalanceSummary(
                    'Permission Limits',
                    teacher.permissionLimits.length,
                    Icons.schedule,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _viewTeacherDetails(teacher),
                  icon: const Icon(Icons.visibility),
                  label: const Text('View'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _editTeacher(teacher),
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: teacher.isActive
                      ? () => _deleteTeacher(teacher)
                      : null,
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red[700],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceSummary(String title, int count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToAddTeacher(String schoolId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditTeacherScreen(schoolId: schoolId),
      ),
    );
  }

  void _editTeacher(Teacher teacher) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditTeacherScreen(
          schoolId: teacher.schoolId,
          teacher: teacher,
        ),
      ),
    );
  }

  void _viewTeacherDetails(Teacher teacher) {
    showDialog(
      context: context,
      builder: (context) => _TeacherDetailsDialog(teacher: teacher),
    );
  }

  void _deleteTeacher(Teacher teacher) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Teacher'),
        content: Text(
          'Are you sure you want to delete ${teacher.name}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(teacherRepositoryProvider).deleteTeacher(teacher.teacherId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${teacher.name} has been deleted'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting teacher: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _TeacherDetailsDialog extends StatelessWidget {
  final Teacher teacher;

  const _TeacherDetailsDialog({required this.teacher});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    teacher.name.isNotEmpty ? teacher.name[0].toUpperCase() : 'T',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teacher.name,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        teacher.role.displayName,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Basic Information
            _buildSection(
              'Basic Information',
              [
                _buildDetailRow('Email', teacher.email),
                _buildDetailRow('Phone', teacher.phone),
                _buildDetailRow('Status', teacher.isActive ? 'Active' : 'Inactive'),
                _buildDetailRow('Created', _formatDate(teacher.createdAt)),
                _buildDetailRow('Updated', _formatDate(teacher.updatedAt)),
              ],
            ),
            const SizedBox(height: 16),
            // Leave Balances
            _buildSection(
              'Leave Balances',
              teacher.leaveBalances.entries
                  .map((entry) => _buildDetailRow(entry.key, '${entry.value} days'))
                  .toList(),
            ),
            const SizedBox(height: 16),
            // Permission Limits
            _buildSection(
              'Permission Limits',
              teacher.permissionLimits.entries
                  .map((entry) => _buildDetailRow(entry.key, '${entry.value} times'))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
