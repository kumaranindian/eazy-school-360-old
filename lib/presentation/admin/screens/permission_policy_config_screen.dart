import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eazy_school_360/core/providers/auth_provider.dart';
import 'package:eazy_school_360/data/repositories/permission_type_repository.dart';
import 'package:eazy_school_360/domain/entities/permission_type.dart';

class PermissionPolicyConfigScreen extends ConsumerStatefulWidget {
  const PermissionPolicyConfigScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<PermissionPolicyConfigScreen> createState() => _PermissionPolicyConfigScreenState();
}

class _PermissionPolicyConfigScreenState extends ConsumerState<PermissionPolicyConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _permissionTypeNameController = TextEditingController();
  final _defaultLimitController = TextEditingController();
  
  bool _isLoading = false;

  // Dark theme colors (match dashboard)
  static const Color _bgLight = Color(0xFF0D1117);
  static const Color _cardWhite = Color(0xFF161B22);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  @override
  void dispose() {
    _permissionTypeNameController.dispose();
    _defaultLimitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final session = ref.watch(currentSessionProvider);

    if (session?.schoolId == null) {
      return const Center(child: Text('No school selected', style: TextStyle(color: _textSecondary)));
    }

    final permissionTypesAsync = ref.watch(allPermissionTypesProvider(session!.schoolId!));

    return Container(
      color: _bgLight,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isDesktop ? 32 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAddForm(isDesktop, session.schoolId!),
            const SizedBox(height: 24),
            _buildExistingTypes(permissionTypesAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildAddForm(bool isDesktop, String schoolId) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: _cardWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor)),
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
                const Text('Add New Permission Type', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
              ],
            ),
            const SizedBox(height: 20),

            // Form Fields
            isDesktop
                ? Row(
                    children: [
                      Expanded(child: _buildTextField(_permissionTypeNameController, 'Permission Type Name', Icons.label_rounded)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField(_defaultLimitController, 'Default Limit (hours)', Icons.access_time_rounded, keyboardType: TextInputType.number)),
                    ],
                  )
                : Column(
                    children: [
                      _buildTextField(_permissionTypeNameController, 'Permission Type Name', Icons.label_rounded),
                      const SizedBox(height: 16),
                      _buildTextField(_defaultLimitController, 'Default Limit (hours)', Icons.access_time_rounded, keyboardType: TextInputType.number),
                    ],
                  ),
            const SizedBox(height: 24),

            // Submit Button
            Center(
              child: _isLoading
                  ? const CircularProgressIndicator(color: _accentBlue)
                  : OutlinedButton.icon(
                      onPressed: () => _addPermissionType(schoolId),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Permission Type'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _accentBlue,
                        side: const BorderSide(color: _accentBlue),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: _textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textSecondary),
        prefixIcon: Icon(icon, size: 20, color: _textSecondary),
        filled: true,
        fillColor: _bgLight,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderColor, width: 1)),
      ),
    );
  }

  Widget _buildExistingTypes(AsyncValue<List<PermissionType>> permissionTypesAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Existing Permission Types', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
        const SizedBox(height: 16),
        permissionTypesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: _accentBlue)),
          error: (error, stack) => Center(child: Text('Error: $error', style: const TextStyle(color: Colors.red))),
          data: (permissionTypes) {
            if (permissionTypes.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(color: _cardWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor)),
                child: const Center(
                  child: Column(
                    children: [
                      Icon(Icons.hourglass_empty, size: 48, color: _textSecondary),
                      SizedBox(height: 16),
                      Text('No permission types configured', style: TextStyle(color: _textSecondary)),
                    ],
                  ),
                ),
              );
            }
            return Column(children: permissionTypes.map((type) => _buildPermissionCard(type)).toList());
          },
        ),
      ],
    );
  }

  Widget _buildPermissionCard(PermissionType type) {
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
                const SizedBox(height: 8),
                Text('Default Limit: ${type.defaultLimit} hours', style: const TextStyle(fontSize: 13, color: _textSecondary)),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: _textSecondary),
            color: _cardWhite,
            onSelected: (value) {
              if (value == 'delete') {
                _deletePermissionType(type.id, type.name);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _addPermissionType(String schoolId) async {
    if (_permissionTypeNameController.text.isEmpty || _defaultLimitController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in required fields'), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(permissionTypeRepositoryProvider);
      await repo.createPermissionType(
        schoolId,
        CreatePermissionTypeRequest(
          name: _permissionTypeNameController.text,
          defaultLimit: int.tryParse(_defaultLimitController.text) ?? 1,
        ),
      );

      _permissionTypeNameController.clear();
      _defaultLimitController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permission type added'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _deletePermissionType(String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardWhite,
        title: const Text('Delete Permission Type', style: TextStyle(color: _textPrimary)),
        content: Text('Are you sure you want to delete "$name"?', style: const TextStyle(color: _textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final repo = ref.read(permissionTypeRepositoryProvider);
                final session = ref.read(currentSessionProvider);
                await repo.deletePermissionType(session!.schoolId!, id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permission type deleted'), backgroundColor: Colors.green));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
