import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eazy_school_360/domain/entities/leave_type.dart';
import 'package:eazy_school_360/data/repositories/leave_type_repository.dart';

class AddEditLeaveTypeScreen extends ConsumerStatefulWidget {
  final String schoolId;
  final LeaveType? leaveType;

  const AddEditLeaveTypeScreen({super.key, required this.schoolId, this.leaveType});

  @override
  ConsumerState<AddEditLeaveTypeScreen> createState() => _AddEditLeaveTypeScreenState();
}

class _AddEditLeaveTypeScreenState extends ConsumerState<AddEditLeaveTypeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _defaultBalanceController = TextEditingController();

  // Dark theme colors
  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  bool _isPaid = true;
  bool _isActive = true;
  bool _isLoading = false;
  String? _errorMessage;

  bool get _isEditing => widget.leaveType != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _populateFields();
    }
  }

  void _populateFields() {
    final leaveType = widget.leaveType!;
    _nameController.text = leaveType.name;
    _defaultBalanceController.text = leaveType.defaultBalance.toString();
    _isPaid = leaveType.isPaid;
    _isActive = leaveType.isActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _defaultBalanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Leave Type' : 'Add Leave Type', style: const TextStyle(color: _textPrimary)),
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
                      _isEditing ? 'Edit Leave Type' : 'Add New Leave Type',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isEditing 
                          ? 'Update the leave type information. Note: Changes to default balance will NOT affect existing teacher balances.'
                          : 'Create a new leave type. This will be automatically added to all existing teachers with the default balance.',
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
                    const Text('Leave Type Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
                    const SizedBox(height: 16),

                    // Name Field
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: _textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Leave Type Name *',
                        labelStyle: const TextStyle(color: _textSecondary),
                        hintText: 'e.g., Annual Leave, Sick Leave, Casual Leave',
                        hintStyle: const TextStyle(color: _textSecondary),
                        filled: true,
                        fillColor: _bgDark,
                        prefixIcon: const Icon(Icons.label, color: _textSecondary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _borderColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _borderColor)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _accentBlue, width: 2)),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a leave type name';
                        }
                        if (value.trim().length < 2) {
                          return 'Name must be at least 2 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Default Balance Field
                    TextFormField(
                      controller: _defaultBalanceController,
                      style: const TextStyle(color: _textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Default Balance (Days) *',
                        labelStyle: const TextStyle(color: _textSecondary),
                        hintText: 'Number of days allocated by default',
                        hintStyle: const TextStyle(color: _textSecondary),
                        filled: true,
                        fillColor: _bgDark,
                        prefixIcon: const Icon(Icons.account_balance, color: _textSecondary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _borderColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _borderColor)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _accentBlue, width: 2)),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter the default balance';
                        }
                        final balance = int.tryParse(value);
                        if (balance == null) {
                          return 'Please enter a valid number';
                        }
                        if (balance < 0) {
                          return 'Balance cannot be negative';
                        }
                        if (balance > 365) {
                          return 'Balance cannot exceed 365 days';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Settings Card
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
                    const Text('Leave Type Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
                    const SizedBox(height: 16),

                    // Paid/Unpaid Toggle
                    SwitchListTile(
                      title: const Text('Paid Leave', style: TextStyle(color: _textPrimary)),
                      subtitle: Text(
                        _isPaid 
                            ? 'Teachers will receive salary during this leave' 
                            : 'Teachers will not receive salary during this leave',
                        style: const TextStyle(color: _textSecondary),
                      ),
                      value: _isPaid,
                      activeColor: _accentBlue,
                      onChanged: (value) {
                        setState(() {
                          _isPaid = value;
                        });
                      },
                    ),

                    // Active/Inactive Toggle (only for editing)
                    if (_isEditing) ...[
                      Divider(color: _borderColor),
                      SwitchListTile(
                        title: const Text('Active', style: TextStyle(color: _textPrimary)),
                        subtitle: Text(
                          _isActive 
                              ? 'Leave type is available for use' 
                              : 'Leave type is hidden from teachers',
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
                  ],
                ),
              ),
              const SizedBox(height: 16),

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
                        'Updating this leave type will only modify the master record. Existing teacher balances will remain unchanged.',
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
                      onPressed: _isLoading ? null : _saveLeaveType,
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
                          : Text(_isEditing ? 'Update Leave Type' : 'Add Leave Type'),
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

  Future<void> _saveLeaveType() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repository = ref.read(leaveTypeRepositoryProvider);
      final defaultBalance = int.parse(_defaultBalanceController.text.trim());

      if (_isEditing) {
        // Update existing leave type
        final request = UpdateLeaveTypeRequest(
          name: _nameController.text.trim(),
          defaultBalance: defaultBalance,
          isPaid: _isPaid,
          isActive: _isActive,
        );

        await repository.updateLeaveType(widget.schoolId, widget.leaveType!.id, request);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Leave type updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Create new leave type
        final request = CreateLeaveTypeRequest(
          name: _nameController.text.trim(),
          defaultBalance: defaultBalance,
          isPaid: _isPaid,
        );

        await repository.createLeaveType(widget.schoolId, request);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Leave type added successfully and propagated to all teachers'),
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
