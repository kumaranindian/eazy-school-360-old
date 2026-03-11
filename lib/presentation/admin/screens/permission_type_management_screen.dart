import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eazy_school_360/domain/entities/permission_type.dart';
import 'package:eazy_school_360/data/repositories/permission_type_repository.dart';
import 'package:eazy_school_360/presentation/admin/screens/add_edit_permission_type_screen.dart';
import 'package:eazy_school_360/presentation/admin/providers/admin_providers.dart';

class PermissionTypeManagementScreen extends ConsumerStatefulWidget {
  const PermissionTypeManagementScreen({super.key});

  @override
  ConsumerState<PermissionTypeManagementScreen> createState() => _PermissionTypeManagementScreenState();
}

class _PermissionTypeManagementScreenState extends ConsumerState<PermissionTypeManagementScreen> {
  bool _showInactiveTypes = false;
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
              title: const Text('Permission Type Management'),
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            body: const Center(
              child: Text('Unable to get school information. Please try logging in again.'),
            ),
          );
        }
        return _buildPermissionTypeManagement(context, schoolId);
      },
      loading: () => Scaffold(
        appBar: AppBar(
          title: const Text('Permission Type Management'),
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(
          title: const Text('Permission Type Management'),
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }

  Widget _buildPermissionTypeManagement(BuildContext context, String schoolId) {
    final colorScheme = Theme.of(context).colorScheme;
    final permissionTypesAsyncValue = ref.watch(allPermissionTypesProvider(schoolId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Permission Type Management'),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToAddPermissionType(schoolId),
            tooltip: 'Add Permission Type',
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
                    hintText: 'Search permission types by name...',
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
                      value: _showInactiveTypes,
                      onChanged: (value) {
                        setState(() {
                          _showInactiveTypes = value;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    const Text('Show inactive permission types'),
                  ],
                ),
              ],
            ),
          ),
          // Permission Types List
          Expanded(
            child: permissionTypesAsyncValue.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading permission types',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(error.toString()),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.refresh(allPermissionTypesProvider(schoolId)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (List<PermissionType> permissionTypes) {
                // Filter permission types based on search and active status
                final filteredPermissionTypes = permissionTypes.where((PermissionType permissionType) {
                  final matchesSearch = _searchQuery.isEmpty ||
                      permissionType.name.toLowerCase().contains(_searchQuery);
                  
                  final matchesActiveFilter = _showInactiveTypes || permissionType.isActive;
                  
                  return matchesSearch && matchesActiveFilter;
                }).toList();

                if (filteredPermissionTypes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.schedule_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No permission types found matching "$_searchQuery"'
                              : 'No permission types found',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        if (_searchQuery.isEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Add your first permission type to get started',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _navigateToAddPermissionType(schoolId),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Permission Type'),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredPermissionTypes.length,
                  itemBuilder: (context, int index) {
                    final PermissionType permissionType = filteredPermissionTypes[index];
                    return _buildPermissionTypeCard(permissionType, colorScheme, schoolId);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionTypeCard(PermissionType permissionType, ColorScheme colorScheme, String schoolId) {
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
                // Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: permissionType.isActive 
                        ? colorScheme.primary.withOpacity(0.1)
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.schedule,
                    color: permissionType.isActive 
                        ? colorScheme.primary 
                        : Colors.grey[600],
                    size: 24,
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
                              permissionType.name,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: permissionType.isActive ? null : Colors.grey[600],
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
                              color: permissionType.isActive 
                                  ? Colors.green[100] 
                                  : Colors.red[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              permissionType.isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: permissionType.isActive 
                                    ? Colors.green[800] 
                                    : Colors.red[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Limit Information
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer, color: Colors.grey[700], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Default Limit: ',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${permissionType.defaultLimit} times',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Timestamps
            Row(
              children: [
                Expanded(
                  child: _buildTimestampInfo(
                    'Created',
                    permissionType.createdAt,
                    Icons.add_circle_outline,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTimestampInfo(
                    'Updated',
                    permissionType.updatedAt,
                    Icons.update,
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
                  onPressed: () => _editPermissionType(schoolId, permissionType),
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: permissionType.isActive 
                      ? () => _deletePermissionType(schoolId, permissionType) 
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

  Widget _buildTimestampInfo(String label, DateTime dateTime, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                '${dateTime.day}/${dateTime.month}/${dateTime.year}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _navigateToAddPermissionType(String schoolId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditPermissionTypeScreen(schoolId: schoolId),
      ),
    );
  }

  void _editPermissionType(String schoolId, PermissionType permissionType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditPermissionTypeScreen(
          schoolId: schoolId,
          permissionType: permissionType,
        ),
      ),
    );
  }

  void _deletePermissionType(String schoolId, PermissionType permissionType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Permission Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${permissionType.name}"?'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will deactivate the permission type. Existing teacher limits will remain unchanged.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
                await ref.read(permissionTypeRepositoryProvider).deletePermissionType(schoolId, permissionType.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${permissionType.name} has been deactivated'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting permission type: $e'),
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
