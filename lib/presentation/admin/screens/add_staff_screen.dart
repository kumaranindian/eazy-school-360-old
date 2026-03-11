import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eazy_school_360/core/providers/auth_provider.dart';
import 'package:eazy_school_360/data/repositories/staff_management_repository.dart';
import 'package:eazy_school_360/domain/entities/staff_profile.dart';
import 'package:eazy_school_360/domain/entities/app_user.dart';

class AddStaffScreen extends ConsumerStatefulWidget {
  final StaffProfile? staffToEdit;

  const AddStaffScreen({super.key, this.staffToEdit});

  @override
  ConsumerState<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends ConsumerState<AddStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _employeeIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _departmentController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _designationController = TextEditingController();

  StaffType _selectedStaffType = StaffType.TEACHING;
  UserRole _selectedRole = UserRole.STAFF;
  DateTime _joiningDate = DateTime.now();
  bool _isLoading = false;
  int _currentStep = 0;
  String _selectedDepartment = 'Pre-KG';

  static const List<String> _departmentOptions = [
    'Pre-KG', 'LKG', 'UKG',
    'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI', 'XII',
    'Administration', 'Accounts', 'Library', 'Sports', 'Lab', 'Transport', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.staffToEdit != null) {
      _populateFormForEdit();
    }
  }

  void _populateFormForEdit() {
    final staff = widget.staffToEdit;
    if (staff == null) return;
    _nameController.text = staff.name;
    _employeeIdController.text = staff.employeeId;
    _emailController.text = staff.email;
    _departmentController.text = staff.department;
    _selectedDepartment = _departmentOptions.contains(staff.department) ? staff.department : 'Other';
    _phoneController.text = staff.phoneNumber ?? '';
    _addressController.text = staff.address ?? '';
    _emergencyContactController.text = staff.emergencyContact ?? '';
    _designationController.text = staff.designation ?? '';
    _selectedStaffType = staff.staffType;
    _joiningDate = staff.joiningDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _employeeIdController.dispose();
    _emailController.dispose();
    _departmentController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emergencyContactController.dispose();
    _designationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.staffToEdit != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final isDesktop = availableWidth >= 900;
        final useTwoColumns = availableWidth >= 1050;

        return Scaffold(
          backgroundColor: const Color(0xFF0D1117),
          body: Column(
            children: [
              // Header
              _buildHeader(context, isEditing, isDesktop),

              // Content
              Expanded(
                child: isDesktop
                    ? _buildDesktopLayout(isEditing, useTwoColumns: useTwoColumns)
                    : _buildMobileLayout(isEditing),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, bool isEditing, bool isDesktop) {
    return Container(
      padding: EdgeInsets.fromLTRB(isDesktop ? 32 : 16, 16, isDesktop ? 32 : 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF161B22), Color(0xFF1C2333)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEditing ? 'Edit Staff Member' : 'Add New Staff',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    isEditing ? 'Update staff information' : 'Fill in the details to add a new staff member',
                    style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.85)),
                  ),
                ],
              ),
            ),
            if (isDesktop) _buildSaveButton(isEditing),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton(bool isEditing) {
    return Material(
      color: const Color(0xFF4CAF50),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: _isLoading ? null : _saveStaff,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isEditing ? Icons.save_rounded : Icons.person_add_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      isEditing ? 'Save Changes' : 'Add Staff',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(bool isEditing, {required bool useTwoColumns}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Form(
        key: _formKey,
        child: useTwoColumns
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column - Basic Info & Role
                  Expanded(
                    child: Column(
                      children: [
                        _buildSectionCard(
                          'Basic Information',
                          Icons.person_rounded,
                          [
                            _buildTextField(_nameController, 'Full Name', Icons.badge_rounded, required: true),
                            const SizedBox(height: 16),
                            if (isEditing) ...[
                              _buildTextField(_employeeIdController, 'Employee ID', Icons.numbers_rounded, required: false, enabled: false),
                              const SizedBox(height: 16),
                            ],
                            _buildTextField(_emailController, 'Email Address', Icons.email_rounded, required: true, enabled: !isEditing, keyboardType: TextInputType.emailAddress),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildSectionCard(
                          'Role & Department',
                          Icons.work_rounded,
                          [
                            if (!isEditing) ...[
                              _buildDropdownField<UserRole>(
                                'Role',
                                Icons.admin_panel_settings_rounded,
                                _selectedRole,
                                [UserRole.STAFF, UserRole.ADMIN],
                                (v) => setState(() => _selectedRole = v!),
                                (r) => r.name,
                              ),
                              const SizedBox(height: 16),
                            ],
                            _buildDropdownField<StaffType>(
                              'Staff Type',
                              Icons.category_rounded,
                              _selectedStaffType,
                              StaffType.values,
                              (v) => setState(() => _selectedStaffType = v!),
                              (t) => t.name.replaceAll('_', ' '),
                            ),
                            const SizedBox(height: 16),
                            _buildDropdownField<String>(
                              'Department / Class',
                              Icons.business_rounded,
                              _selectedDepartment,
                              _departmentOptions,
                              (v) => setState(() { _selectedDepartment = v!; _departmentController.text = v; }),
                              (d) => d,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(_designationController, 'Designation', Icons.work_outline_rounded),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Right Column - Contact & Joining Date
                  Expanded(
                    child: Column(
                      children: [
                        _buildSectionCard(
                          'Contact Information',
                          Icons.contact_phone_rounded,
                          [
                            _buildTextField(_phoneController, 'Phone Number', Icons.phone_rounded, keyboardType: TextInputType.phone),
                            const SizedBox(height: 16),
                            _buildTextField(_addressController, 'Address', Icons.location_on_rounded, maxLines: 3),
                            const SizedBox(height: 16),
                            _buildTextField(_emergencyContactController, 'Emergency Contact', Icons.emergency_rounded),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildSectionCard(
                          'Employment Details',
                          Icons.calendar_month_rounded,
                          [
                            _buildDateField('Joining Date', _joiningDate, _selectJoiningDate),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSectionCard(
                    'Basic Information',
                    Icons.person_rounded,
                    [
                      _buildTextField(_nameController, 'Full Name', Icons.badge_rounded, required: true),
                      const SizedBox(height: 16),
                      if (isEditing) ...[
                        _buildTextField(_employeeIdController, 'Employee ID', Icons.numbers_rounded, required: false, enabled: false),
                        const SizedBox(height: 16),
                      ],
                      _buildTextField(_emailController, 'Email Address', Icons.email_rounded, required: true, enabled: !isEditing, keyboardType: TextInputType.emailAddress),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSectionCard(
                    'Role & Department',
                    Icons.work_rounded,
                    [
                      if (!isEditing) ...[
                        _buildDropdownField<UserRole>(
                          'Role',
                          Icons.admin_panel_settings_rounded,
                          _selectedRole,
                          [UserRole.STAFF, UserRole.ADMIN],
                          (v) => setState(() => _selectedRole = v!),
                          (r) => r.name,
                        ),
                        const SizedBox(height: 16),
                      ],
                      _buildDropdownField<StaffType>(
                        'Staff Type',
                        Icons.category_rounded,
                        _selectedStaffType,
                        StaffType.values,
                        (v) => setState(() => _selectedStaffType = v!),
                        (t) => t.name.replaceAll('_', ' '),
                      ),
                      const SizedBox(height: 16),
                      _buildDropdownField<String>(
                              'Department / Class',
                              Icons.business_rounded,
                              _selectedDepartment,
                              _departmentOptions,
                              (v) => setState(() { _selectedDepartment = v!; _departmentController.text = v; }),
                              (d) => d,
                            ),
                      const SizedBox(height: 16),
                      _buildTextField(_designationController, 'Designation', Icons.work_outline_rounded),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSectionCard(
                    'Contact Information',
                    Icons.contact_phone_rounded,
                    [
                      _buildTextField(_phoneController, 'Phone Number', Icons.phone_rounded, keyboardType: TextInputType.phone),
                      const SizedBox(height: 16),
                      _buildTextField(_addressController, 'Address', Icons.location_on_rounded, maxLines: 3),
                      const SizedBox(height: 16),
                      _buildTextField(_emergencyContactController, 'Emergency Contact', Icons.emergency_rounded),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSectionCard(
                    'Employment Details',
                    Icons.calendar_month_rounded,
                    [
                      _buildDateField('Joining Date', _joiningDate, _selectJoiningDate),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildMobileLayout(bool isEditing) {
    return Column(
      children: [
        // Step Indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _buildStepIndicator(0, 'Basic'),
              _buildStepConnector(0),
              _buildStepIndicator(1, 'Role'),
              _buildStepConnector(1),
              _buildStepIndicator(2, 'Contact'),
            ],
          ),
        ),
        // Form Content
        Expanded(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildCurrentStepContent(isEditing),
            ),
          ),
        ),
        // Bottom Navigation
        _buildBottomNavigation(isEditing),
      ],
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep > step;
    
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isActive || isCompleted ? const Color(0xFF4CAF50) : const Color(0xFF30363D),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                  : Text(
                      '${step + 1}',
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? const Color(0xFF4CAF50) : const Color(0xFF8B949E),
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector(int step) {
    final isCompleted = _currentStep > step;
    return Container(
      width: 40,
      height: 2,
      margin: const EdgeInsets.only(bottom: 20),
      color: isCompleted ? const Color(0xFF4CAF50) : const Color(0xFF30363D),
    );
  }

  Widget _buildCurrentStepContent(bool isEditing) {
    switch (_currentStep) {
      case 0:
        return _buildSectionCard(
          'Basic Information',
          Icons.person_rounded,
          [
            _buildTextField(_nameController, 'Full Name', Icons.badge_rounded, required: true),
            const SizedBox(height: 16),
            if (isEditing) ...[
              _buildTextField(_employeeIdController, 'Employee ID', Icons.numbers_rounded, required: false, enabled: false),
              const SizedBox(height: 16),
            ],
            _buildTextField(_emailController, 'Email Address', Icons.email_rounded, required: true, enabled: !isEditing, keyboardType: TextInputType.emailAddress),
          ],
        );
      case 1:
        return _buildSectionCard(
          'Role & Department',
          Icons.work_rounded,
          [
            if (!isEditing) ...[
              _buildDropdownField<UserRole>(
                'Role',
                Icons.admin_panel_settings_rounded,
                _selectedRole,
                [UserRole.STAFF, UserRole.ADMIN],
                (v) => setState(() => _selectedRole = v!),
                (r) => r.name,
              ),
              const SizedBox(height: 16),
            ],
            _buildDropdownField<StaffType>(
              'Staff Type',
              Icons.category_rounded,
              _selectedStaffType,
              StaffType.values,
              (v) => setState(() => _selectedStaffType = v!),
              (t) => t.name.replaceAll('_', ' '),
            ),
            const SizedBox(height: 16),
            _buildDropdownField<String>(
                              'Department / Class',
                              Icons.business_rounded,
                              _selectedDepartment,
                              _departmentOptions,
                              (v) => setState(() { _selectedDepartment = v!; _departmentController.text = v; }),
                              (d) => d,
                            ),
            const SizedBox(height: 16),
            _buildTextField(_designationController, 'Designation', Icons.work_outline_rounded),
            const SizedBox(height: 16),
            _buildDateField('Joining Date', _joiningDate, _selectJoiningDate),
          ],
        );
      case 2:
        return _buildSectionCard(
          'Contact Information',
          Icons.contact_phone_rounded,
          [
            _buildTextField(_phoneController, 'Phone Number', Icons.phone_rounded, keyboardType: TextInputType.phone, required: true),
            const SizedBox(height: 16),
            _buildTextField(_addressController, 'Address', Icons.location_on_rounded, maxLines: 3, required: true),
            const SizedBox(height: 16),
            _buildTextField(_emergencyContactController, 'Emergency Contact', Icons.emergency_rounded, required: true),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBottomNavigation(bool isEditing) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardDark,
        border: Border(top: BorderSide(color: _borderColor)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _currentStep--),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: _borderColor),
                    foregroundColor: _textPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Previous'),
                ),
              )
            else
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: _borderColor),
                    foregroundColor: _textPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _isLoading ? null : (_currentStep < 2 ? () => setState(() => _currentStep++) : _saveStaff),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_currentStep < 2 ? 'Next' : (isEditing ? 'Save Changes' : 'Add Staff')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Dark theme colors
  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  Widget _buildSectionCard(String title, IconData icon, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _accentBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _accentBlue, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool required = false,
    bool enabled = true,
    String? helperText,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: _textPrimary),
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        labelStyle: const TextStyle(color: _textSecondary),
        helperText: helperText,
        helperStyle: const TextStyle(color: _textSecondary),
        prefixIcon: Icon(icon, color: _textSecondary, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _borderColor)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _borderColor, width: 1),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _borderColor.withOpacity(0.5)),
        ),
        filled: true,
        fillColor: enabled ? _bgDark : _cardDark,
      ),
      validator: required
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter $label';
              }
              if (label == 'Email Address' && !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                return 'Please enter a valid email address';
              }
              if (label == 'Employee ID' && value.trim().length < 3) {
                return 'Employee ID must be at least 3 characters';
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildDropdownField<T>(
    String label,
    IconData icon,
    T value,
    List<T> items,
    ValueChanged<T?> onChanged,
    String Function(T) displayText,
  ) {
    return DropdownButtonFormField<T>(
      value: value,
      dropdownColor: _cardDark,
      style: const TextStyle(color: _textPrimary),
      decoration: InputDecoration(
        labelText: '$label *',
        labelStyle: const TextStyle(color: _textSecondary),
        prefixIcon: Icon(icon, color: _textSecondary, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _borderColor)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _borderColor, width: 1),
        ),
        filled: true,
        fillColor: _bgDark,
      ),
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(displayText(item), style: const TextStyle(color: _textPrimary)))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildDateField(String label, DateTime date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '$label *',
          labelStyle: const TextStyle(color: _textSecondary),
          prefixIcon: const Icon(Icons.calendar_today_rounded, color: _textSecondary, size: 20),
          suffixIcon: const Icon(Icons.arrow_drop_down_rounded, color: _textSecondary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _borderColor)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _borderColor),
          ),
          filled: true,
          fillColor: _bgDark,
        ),
        child: Text(
          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
          style: const TextStyle(fontSize: 16, color: _textPrimary),
        ),
      ),
    );
  }

  Future<void> _selectJoiningDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _joiningDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _joiningDate = date;
      });
    }
  }

  Future<void> _saveStaff() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final session = ref.read(currentSessionProvider);
    if (session == null || session.schoolId == null) {
      _showError('Session expired. Please login again.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final repository = ref.read(staffManagementRepositoryProvider);

      if (widget.staffToEdit != null) {
        // Update existing staff
        final updateRequest = UpdateStaffRequest(
          name: _nameController.text.trim(),
          department: _selectedDepartment,
          staffType: _selectedStaffType,
          phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
          emergencyContact: _emergencyContactController.text.trim().isEmpty ? null : _emergencyContactController.text.trim(),
          designation: _designationController.text.trim().isEmpty ? null : _designationController.text.trim(),
          joiningDate: _joiningDate,
        );

        await repository.updateStaff(
          session.schoolId!,
          widget.staffToEdit!.id,
          session.uid,
          updateRequest,
        );

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Staff updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Create new staff
        final createRequest = CreateStaffRequest(
          name: _nameController.text.trim(),
          employeeId: '', // Auto-generated by repository
          email: _emailController.text.trim(),
          department: _selectedDepartment,
          staffType: _selectedStaffType,
          joiningDate: _joiningDate,
          phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
          emergencyContact: _emergencyContactController.text.trim().isEmpty ? null : _emergencyContactController.text.trim(),
          designation: _designationController.text.trim().isEmpty ? null : _designationController.text.trim(),
        );

        Map<String, String> result;
        if (_selectedRole == UserRole.ADMIN) {
          result = await repository.createAdmin(session.schoolId!, session.uid, createRequest);
        } else {
          result = await repository.createStaff(session.schoolId!, session.uid, createRequest);
        }

        if (mounted) {
          // Show success dialog with staff details
          await _showSuccessDialog(result);
          if (mounted) {
            Navigator.pop(context);
          }
        }
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showSuccessDialog(Map<String, String> staffData) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.check_circle, color: Colors.green, size: 28),
              ),
              const SizedBox(width: 12),
              const Text('Staff Created Successfully', style: TextStyle(color: _textPrimary, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(color: _borderColor),
              const SizedBox(height: 12),
              _buildInfoRow('Employee ID', staffData['employeeId'] ?? '', isHighlighted: true),
              const SizedBox(height: 12),
              _buildInfoRow('Name', staffData['name'] ?? ''),
              const SizedBox(height: 8),
              _buildInfoRow('Email', staffData['email'] ?? ''),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _accentBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _accentBlue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: _accentBlue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Login credentials have been sent to the staff email.',
                        style: TextStyle(color: _textSecondary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isHighlighted = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: const TextStyle(color: _textSecondary, fontSize: 14)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: isHighlighted ? _accentBlue : _textPrimary,
              fontSize: isHighlighted ? 18 : 14,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}
