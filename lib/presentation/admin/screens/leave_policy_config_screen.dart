import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eazy_school_360/core/providers/auth_provider.dart';
import 'package:eazy_school_360/data/repositories/leave_configuration_repository.dart';
import 'package:eazy_school_360/domain/entities/leave_type_config.dart';

class LeavePolicyConfigScreen extends ConsumerStatefulWidget {
  const LeavePolicyConfigScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<LeavePolicyConfigScreen> createState() => _LeavePolicyConfigScreenState();
}

class _LeavePolicyConfigScreenState extends ConsumerState<LeavePolicyConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _leaveTypeNameController = TextEditingController();
  final _leaveTypeCodeController = TextEditingController();
  final _maxDaysController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  bool _isCarryForward = false;
  bool _isPaid = true;
  bool _isAddingNew = false;
  bool _isLoading = false;

  // Dark theme colors (match dashboard)
  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardWhite = Color(0xFF161B22); // using name for minimal diffs
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  @override
  void dispose() {
    _leaveTypeNameController.dispose();
    _leaveTypeCodeController.dispose();
    _maxDaysController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    if (session == null || !session.isAdmin || session.schoolId == null) {
      return const Scaffold(body: Center(child: Text('Access Denied')));
    }

    final leaveTypesAsync = ref.watch(schoolLeaveTypesProvider(session.schoolId!));

    return Container(
      color: _bgDark,
      child: leaveTypesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _accentBlue)),
        error: (error, stack) => _buildErrorState(context, session.schoolId!, error),
        data: (leaveTypes) => _buildContent(context, leaveTypes, isDesktop, session.schoolId!),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<LeaveTypeConfig> leaveTypes, bool isDesktop, String schoolId) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 32 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Cards
          _buildStatsRow(leaveTypes, isDesktop),
          const SizedBox(height: 24),

          // Add New Form
          if (_isAddingNew) ...[
            _buildAddForm(context, schoolId, isDesktop),
            const SizedBox(height: 24),
          ],

          // Existing Leave Types
          if (leaveTypes.isEmpty && !_isAddingNew)
            _buildEmptyState()
          else if (leaveTypes.isNotEmpty)
            _buildLeaveTypesList(leaveTypes, schoolId, isDesktop),
        ],
      ),
    );
  }

  Widget _buildStatsRow(List<LeaveTypeConfig> leaveTypes, bool isDesktop) {
    final totalTypes = leaveTypes.length;
    final activeTypes = leaveTypes.where((t) => t.isActive).length;
    final paidTypes = leaveTypes.where((t) => t.isPaid).length;
    final totalDays = leaveTypes.fold<int>(0, (sum, t) => sum + t.annualQuota);

    final stats = [
      {'title': 'Total Types', 'value': '$totalTypes', 'icon': Icons.category_rounded, 'color': const Color(0xFF8B5CF6)},
      {'title': 'Active', 'value': '$activeTypes', 'icon': Icons.check_circle_rounded, 'color': const Color(0xFF10B981)},
      {'title': 'Paid Types', 'value': '$paidTypes', 'icon': Icons.payments_rounded, 'color': const Color(0xFFF59E0B)},
      {'title': 'Total Days', 'value': '$totalDays', 'icon': Icons.calendar_today_rounded, 'color': const Color(0xFF3B82F6)},
    ];

    // Use 2x2 grid for mobile, horizontal row for desktop
    if (!isDesktop) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildStatCard(stats[0]['title'] as String, stats[0]['value'] as String, stats[0]['icon'] as IconData, stats[0]['color'] as Color)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard(stats[1]['title'] as String, stats[1]['value'] as String, stats[1]['icon'] as IconData, stats[1]['color'] as Color)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard(stats[2]['title'] as String, stats[2]['value'] as String, stats[2]['icon'] as IconData, stats[2]['color'] as Color)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard(stats[3]['title'] as String, stats[3]['value'] as String, stats[3]['icon'] as IconData, stats[3]['color'] as Color)),
            ],
          ),
        ],
      );
    }

    return Row(
      children: stats.map((stat) => Expanded(
        child: Padding(
          padding: EdgeInsets.only(right: stat == stats.last ? 0 : 12),
          child: _buildStatCard(stat['title'] as String, stat['value'] as String, stat['icon'] as IconData, stat['color'] as Color),
        ),
      )).toList(),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _textPrimary)),
                Text(title, style: const TextStyle(fontSize: 12, color: _textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddForm(BuildContext context, String schoolId, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: _accentBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.add_circle_outline, color: _accentBlue, size: 20),
                ),
                const SizedBox(width: 12),
                const Text('Add New Leave Type', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _isAddingNew = false)),
              ],
            ),
            const SizedBox(height: 20),

            // Form Fields
            isDesktop
                ? Row(
                    children: [
                      Expanded(child: _buildTextField(_leaveTypeNameController, 'Leave Type Name', Icons.label_rounded, required: true)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField(_leaveTypeCodeController, 'Code (e.g., CL, SL)', Icons.code_rounded, required: true)),
                    ],
                  )
                : Column(
                    children: [
                      _buildTextField(_leaveTypeNameController, 'Leave Type Name', Icons.label_rounded, required: true),
                      const SizedBox(height: 16),
                      _buildTextField(_leaveTypeCodeController, 'Code (e.g., CL, SL)', Icons.code_rounded, required: true),
                    ],
                  ),
            const SizedBox(height: 16),

            _buildTextField(_maxDaysController, 'Annual Quota', Icons.calendar_today_rounded, required: true, keyboardType: TextInputType.number),
            const SizedBox(height: 16),

            _buildTextField(_descriptionController, 'Description (Optional)', Icons.description_rounded),
            const SizedBox(height: 20),

            // Toggles
            Row(
              children: [
                Expanded(child: _buildToggle('Paid Leave', 'Salary deducted if unpaid', _isPaid, (v) => setState(() => _isPaid = v))),
                const SizedBox(width: 16),
                Expanded(child: _buildToggle('Carry Forward', 'Allow unused days to carry over', _isCarryForward, (v) => setState(() => _isCarryForward = v))),
              ],
            ),
            const SizedBox(height: 24),

            // Submit Button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => setState(() => _isAddingNew = false),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : () => _addLeaveType(schoolId),
                  style: ElevatedButton.styleFrom(backgroundColor: _accentBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                  child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Add Leave Type'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool required = false, TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: _textPrimary), // White text color
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textSecondary),
        prefixIcon: Icon(icon, size: 20, color: _textSecondary),
        filled: true,
        fillColor: _bgDark,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderColor, width: 1)),
      ),
      validator: required ? (v) => v == null || v.isEmpty ? 'Required' : null : null,
    );
  }

  Widget _buildToggle(String title, String subtitle, bool value, Function(bool) onChanged) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _cardWhite, borderRadius: BorderRadius.circular(10), border: Border.all(color: _borderColor)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: _textPrimary)),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: _textSecondary)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: _accentBlue,
            activeTrackColor: _accentBlue.withOpacity(0.5),
            inactiveThumbColor: _textSecondary,
            inactiveTrackColor: _borderColor,
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveTypesList(List<LeaveTypeConfig> leaveTypes, String schoolId, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Existing Leave Types', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
            ),
            if (!_isAddingNew)
              ElevatedButton.icon(
                onPressed: () => setState(() => _isAddingNew = true),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Leave Type'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        ...leaveTypes.map((type) => _buildLeaveTypeCard(type, schoolId)),
      ],
    );
  }

  Widget _buildLeaveTypeCard(LeaveTypeConfig type, String schoolId) {
    final isActive = type.isActive;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isActive ? _borderColor : Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: (isActive ? _accentBlue : _textSecondary).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.event_note_rounded, color: isActive ? _accentBlue : _textSecondary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(type.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isActive ? _textPrimary : _textSecondary)),
                    ),
                    if (!isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: const Text('Inactive', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(type.description.isEmpty ? 'No description' : type.description, style: const TextStyle(fontSize: 13, color: _textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _buildTag('${type.code}', const Color(0xFF6B7280)),
                    _buildTag('${type.annualQuota} days/year', const Color(0xFF3B82F6)),
                    if (type.isPaid) _buildTag('Paid', const Color(0xFF10B981)),
                    if (!type.isPaid) _buildTag('Unpaid', const Color(0xFFF59E0B)),
                    if (type.carryForwardAllowed) _buildTag('Carry Forward', const Color(0xFF8B5CF6)),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: _textSecondary),
            color: _cardWhite,
            onSelected: (value) {
              if (value == 'delete') _deleteLeaveType(schoolId, type.id);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(color: _cardWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), shape: BoxShape.circle),
            child: const Icon(Icons.event_busy_rounded, size: 48, color: _textSecondary),
          ),
          const SizedBox(height: 20),
          const Text('No Leave Types Configured', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 8),
          const Text('Add your first leave type to get started', style: TextStyle(color: _textSecondary)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => setState(() => _isAddingNew = true),
            icon: const Icon(Icons.add),
            label: const Text('Add Leave Type'),
            style: ElevatedButton.styleFrom(backgroundColor: _accentBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String schoolId, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
          const SizedBox(height: 16),
          const Text('Error Loading Leave Types', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(error.toString(), style: const TextStyle(color: _textSecondary)),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: () => ref.invalidate(schoolLeaveTypesProvider(schoolId)), child: const Text('Retry')),
        ],
      ),
    );
  }

  Future<void> _addLeaveType(String schoolId) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(leaveConfigurationRepositoryProvider);
      final session = ref.read(currentSessionProvider);

      final annualQuota = int.parse(_maxDaysController.text.trim());
      await repo.createLeaveTypeConfig(
        schoolId,
        session!.uid,
        CreateLeaveTypeConfigRequest(
          name: _leaveTypeNameController.text.trim(),
          code: _leaveTypeCodeController.text.trim().toUpperCase(),
          annualQuota: annualQuota,
          // Automatically set maxDaysPerRequest since the field is removed from UI.
          // Default behavior: allow up to the annual quota per request.
          maxDaysPerRequest: annualQuota,
          isPaid: _isPaid,
          carryForwardAllowed: _isCarryForward,
          maxCarryForwardDays: 0,
          description: _descriptionController.text.trim(),
        ),
      );

      _clearForm();
      setState(() {
        _isAddingNew = false;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leave type added successfully'), backgroundColor: Colors.green));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _toggleLeaveTypeStatus(String schoolId, String leaveTypeId, bool activate) async {
    try {
      final repo = ref.read(leaveConfigurationRepositoryProvider);
      final session = ref.read(currentSessionProvider);
      
      if (activate) {
        // Reactivate the leave type
        await repo.updateLeaveTypeConfig(
          schoolId,
          leaveTypeId,
          session!.uid,
          UpdateLeaveTypeConfigRequest(isActive: true),
        );
      } else {
        // Deactivate the leave type
        await repo.deactivateLeaveTypeConfig(schoolId, leaveTypeId, session!.uid);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(activate ? 'Leave type activated' : 'Leave type deactivated'),
            backgroundColor: Colors.green,
          ),
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

  Future<void> _deleteLeaveType(String schoolId, String leaveTypeId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Leave Type'),
        content: const Text('Are you sure you want to delete this leave type?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final repo = ref.read(leaveConfigurationRepositoryProvider);
        final session = ref.read(currentSessionProvider);
        await repo.deleteLeaveTypeConfig(schoolId, leaveTypeId, session!.uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leave type deleted'), backgroundColor: Colors.green));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  void _clearForm() {
    _leaveTypeNameController.clear();
    _leaveTypeCodeController.clear();
    _maxDaysController.clear();
    _descriptionController.clear();
    _isCarryForward = false;
    _isPaid = true;
  }
}
