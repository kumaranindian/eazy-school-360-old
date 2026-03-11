import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eazy_school_360/domain/entities/permission_type.dart';
import 'package:eazy_school_360/data/repositories/permission_type_repository.dart';

class AddEditPermissionTypeScreen extends ConsumerStatefulWidget {
  final String schoolId;
  final PermissionType? permissionType;

  const AddEditPermissionTypeScreen({super.key, required this.schoolId, this.permissionType});

  @override
  ConsumerState<AddEditPermissionTypeScreen> createState() => _AddEditPermissionTypeScreenState();
}

class _AddEditPermissionTypeScreenState extends ConsumerState<AddEditPermissionTypeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _defaultLimitController = TextEditingController();

  bool _isActive = true;
  bool _isLoading = false;
  String? _errorMessage;

  bool get _isEditing => widget.permissionType != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _populateFields();
    }
  }

  void _populateFields() {
    final permissionType = widget.permissionType!;
    _nameController.text = permissionType.name;
    _defaultLimitController.text = permissionType.defaultLimit.toString();
    _isActive = permissionType.isActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _defaultLimitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Permission Type' : 'Add Permission Type'),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEditing ? 'Edit Permission Type' : 'Add New Permission Type',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isEditing 
                            ? 'Update the permission type information. Note: Changes to default limit will NOT affect existing teacher limits.'
                            : 'Create a new permission type. This will be automatically added to all existing teachers with the default limit.',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Basic Information Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Permission Type Information',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Name Field
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Permission Type Name *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.label),
                          hintText: 'e.g., Early Departure, Late Arrival, Lunch Extension',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a permission type name';
                          }
                          if (value.trim().length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Default Limit Field
                      TextFormField(
                        controller: _defaultLimitController,
                        decoration: const InputDecoration(
                          labelText: 'Default Limit (Times) *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.timer),
                          hintText: 'Number of times allowed by default',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter the default limit';
                          }
                          final limit = int.tryParse(value);
                          if (limit == null) {
                            return 'Please enter a valid number';
                          }
                          if (limit < 0) {
                            return 'Limit cannot be negative';
                          }
                          if (limit > 100) {
                            return 'Limit cannot exceed 100 times';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Settings Card (only for editing)
              if (_isEditing) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Permission Type Settings',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Active/Inactive Toggle
                        SwitchListTile(
                          title: const Text('Active'),
                          subtitle: Text(
                            _isActive 
                                ? 'Permission type is available for use' 
                                : 'Permission type is hidden from teachers',
                          ),
                          value: _isActive,
                          onChanged: (value) {
                            setState(() {
                              _isActive = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Warning Card for Editing
              if (_isEditing) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.orange[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Important Note',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[800],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Updating this permission type will only modify the master record. Existing teacher limits will remain unchanged.',
                        style: TextStyle(color: Colors.orange[800]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Error Message
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _savePermissionType,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(_isEditing ? 'Update Permission Type' : 'Add Permission Type'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _savePermissionType() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repository = ref.read(permissionTypeRepositoryProvider);
      final defaultLimit = int.parse(_defaultLimitController.text.trim());

      if (_isEditing) {
        // Update existing permission type
        final request = UpdatePermissionTypeRequest(
          name: _nameController.text.trim(),
          defaultLimit: defaultLimit,
          isActive: _isActive,
        );

        await repository.updatePermissionType(widget.schoolId, widget.permissionType!.id, request);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permission type updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Create new permission type
        final request = CreatePermissionTypeRequest(
          name: _nameController.text.trim(),
          defaultLimit: defaultLimit,
        );

        await repository.createPermissionType(widget.schoolId, request);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permission type added successfully and propagated to all teachers'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
