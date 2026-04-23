import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eazy_school_360/domain/entities/teacher.dart';
import 'package:eazy_school_360/data/repositories/teacher_repository.dart';

class AddEditTeacherScreen extends ConsumerStatefulWidget {
  final String schoolId;
  final Teacher? teacher;

  const AddEditTeacherScreen({super.key, required this.schoolId, this.teacher});

  @override
  ConsumerState<AddEditTeacherScreen> createState() => _AddEditTeacherScreenState();
}

class _AddEditTeacherScreenState extends ConsumerState<AddEditTeacherScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  // Dark theme colors (consistent with other screens)
  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  TeacherRole _selectedRole = TeacherRole.teacher;
  bool _isActive = true;
  bool _isLoading = false;
  String? _errorMessage;

  bool get _isEditing => widget.teacher != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _populateFields();
    }
  }

  void _populateFields() {
    final teacher = widget.teacher!;
    _nameController.text = teacher.name;
    _emailController.text = teacher.email;
    _phoneController.text = teacher.phone;
    _selectedRole = teacher.role;
    _isActive = teacher.isActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Teacher' : 'Add Teacher', style: const TextStyle(color: _textPrimary)),
        backgroundColor: _cardDark,
        foregroundColor: _textPrimary,
        iconTheme: const IconThemeData(color: _textPrimary),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _cardDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isEditing ? 'Edit Teacher Information' : 'Add New Teacher',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isEditing 
                          ? 'Update the teacher\'s information below'
                          : 'Fill in the details to add a new teacher. Leave and permission balances will be automatically initialized.',
                      style: const TextStyle(color: _textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Basic Information Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _cardDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Basic Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
                    const SizedBox(height: 16),

                    // Name Field
                    _buildTextField(
                      controller: _nameController,
                      label: 'Full Name *',
                      icon: Icons.person,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter the teacher\'s name';
                        }
                        if (value.trim().length < 2) {
                          return 'Name must be at least 2 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Email Field
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email Address *',
                      icon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter an email address';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Phone Field
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Phone Number *',
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a phone number';
                        }
                        if (value.trim().length < 10) {
                          return 'Please enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Role Selection
                    _buildDropdownField(),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Status Card (only for editing)
              if (_isEditing) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _cardDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Active', style: TextStyle(color: _textPrimary)),
                        subtitle: Text(
                          _isActive ? 'Teacher can access the system' : 'Teacher cannot access the system',
                          style: const TextStyle(color: _textSecondary),
                        ),
                        value: _isActive,
                        activeColor: _accentBlue,
                        onChanged: (value) {
                          setState(() {
                            _isActive = value;
                          });
                        },
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
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 14),
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
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _textPrimary,
                        side: const BorderSide(color: _borderColor),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveTeacher,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
                          : Text(_isEditing ? 'Update Teacher' : 'Add Teacher'),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: _textPrimary),
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textSecondary),
        filled: true,
        fillColor: _bgDark,
        prefixIcon: Icon(icon, color: _textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _accentBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildDropdownField() {
    return DropdownButtonFormField<TeacherRole>(
      value: _selectedRole,
      dropdownColor: _cardDark,
      style: const TextStyle(color: _textPrimary),
      decoration: InputDecoration(
        labelText: 'Role *',
        labelStyle: const TextStyle(color: _textSecondary),
        filled: true,
        fillColor: _bgDark,
        prefixIcon: const Icon(Icons.work, color: _textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _accentBlue, width: 2),
        ),
      ),
      items: TeacherRole.values.map((role) {
        return DropdownMenuItem(
          value: role,
          child: Text(role.displayName, style: const TextStyle(color: _textPrimary)),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedRole = value;
          });
        }
      },
    );
  }

  Future<void> _saveTeacher() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repository = ref.read(teacherRepositoryProvider);

      if (_isEditing) {
        // Update existing teacher
        final request = UpdateTeacherRequest(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          role: _selectedRole,
          isActive: _isActive,
        );

        await repository.updateTeacher(widget.teacher!.teacherId, request);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Teacher updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Create new teacher
        final request = CreateTeacherRequest(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          role: _selectedRole,
        );

        final result = await repository.createTeacher(widget.schoolId, request);

        if (mounted) {
          Navigator.pop(context);
          
          // Show success dialog with temporary password if it's a new user
          if (result['isNewAuthUser'] == true && (result['tempPassword'] as String?)?.isNotEmpty == true) {
            await showDialog(
              context: context,
              builder: (_) => _SuccessDialog(
                name: (result['teacher'] as dynamic)?.name ?? _nameController.text.trim(),
                email: _emailController.text.trim(),
                tempPassword: (result['tempPassword'] as String?) ?? '',
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Teacher added successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
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

// Success Dialog Widget
class _SuccessDialog extends StatelessWidget {
  final String name;
  final String email;
  final String tempPassword;

  const _SuccessDialog({
    required this.name,
    required this.email,
    required this.tempPassword,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 24),
          const SizedBox(width: 8),
          const Text('Teacher Created Successfully'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Teacher account has been created for:'),
          const SizedBox(height: 12),
          _buildInfoRow('Name:', name),
          _buildInfoRow('Email:', email),
          _buildInfoRow('Temporary Password:', tempPassword),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Please share these login credentials with the teacher. They can change their password after first login.',
              style: TextStyle(fontSize: 12, color: Colors.blue),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
