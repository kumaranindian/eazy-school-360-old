import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/providers/auth_provider.dart';

const Color _bgDark = Color(0xFF0D1117);
const Color _cardDark = Color(0xFF161B22);
const Color _accentBlue = Color(0xFF4CAF50);
const Color _textPrimary = Color(0xFFE6EDF3);
const Color _textSecondary = Color(0xFF8B949E);
const Color _borderColor = Color(0xFF30363D);

class SchoolSettingsScreen extends ConsumerStatefulWidget {
  const SchoolSettingsScreen({super.key});

  @override
  ConsumerState<SchoolSettingsScreen> createState() => _SchoolSettingsScreenState();
}

class _SchoolSettingsScreenState extends ConsumerState<SchoolSettingsScreen> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _schoolDocId;

  @override
  void initState() {
    super.initState();
    _loadSchoolInfo();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _loadSchoolInfo() async {
    final session = ref.read(currentSessionProvider);
    if (session == null || session.schoolId == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('schools').doc(session.schoolId!).get();
      if (doc.exists) {
        final data = doc.data()!;
        _schoolDocId = doc.id;
        _nameController.text = data['name'] as String? ?? '';
        _addressController.text = data['address'] as String? ?? '';
        _phoneController.text = data['phone'] as String? ?? '';
        _emailController.text = data['email'] as String? ?? '';
        _websiteController.text = data['website'] as String? ?? '';
      }
    } catch (e) {
      debugPrint('Error loading school info: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveSchoolInfo() async {
    if (_schoolDocId == null) return;
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('schools').doc(_schoolDocId!).update({
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'website': _websiteController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('School info updated'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _accentBlue));
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 28 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 4),
          const Text('Manage your school information and preferences', style: TextStyle(color: _textSecondary)),
          const SizedBox(height: 24),

          // School Info Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: _borderColor)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: _accentBlue.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.school_rounded, color: _accentBlue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('School Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
                ]),
                const SizedBox(height: 20),
                isDesktop
                    ? Row(children: [
                        Expanded(child: _buildField('School Name', _nameController, Icons.badge_rounded)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildField('Email', _emailController, Icons.email_rounded)),
                      ])
                    : Column(children: [
                        _buildField('School Name', _nameController, Icons.badge_rounded),
                        const SizedBox(height: 14),
                        _buildField('Email', _emailController, Icons.email_rounded),
                      ]),
                const SizedBox(height: 14),
                isDesktop
                    ? Row(children: [
                        Expanded(child: _buildField('Phone', _phoneController, Icons.phone_rounded)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildField('Website', _websiteController, Icons.language_rounded)),
                      ])
                    : Column(children: [
                        _buildField('Phone', _phoneController, Icons.phone_rounded),
                        const SizedBox(height: 14),
                        _buildField('Website', _websiteController, Icons.language_rounded),
                      ]),
                const SizedBox(height: 14),
                _buildField('Address', _addressController, Icons.location_on_rounded, maxLines: 2),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveSchoolInfo,
                    icon: _isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_rounded, size: 18),
                    label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Account Info Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: _borderColor)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF8B5CF6), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('Admin Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
                ]),
                const SizedBox(height: 16),
                Builder(builder: (context) {
                  final session = ref.watch(currentSessionProvider);
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _infoRow(Icons.person_rounded, 'Name', session?.displayName ?? 'N/A'),
                    const SizedBox(height: 10),
                    _infoRow(Icons.email_rounded, 'Email', session?.email ?? 'N/A'),
                    const SizedBox(height: 10),
                    _infoRow(Icons.security_rounded, 'Role', session?.role.name ?? 'N/A'),
                    const SizedBox(height: 10),
                    _infoRow(Icons.key_rounded, 'School ID', session?.schoolId ?? 'N/A'),
                  ]);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: _textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textSecondary, fontSize: 13),
        prefixIcon: Icon(icon, color: _textSecondary, size: 18),
        filled: true,
        fillColor: _bgDark,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _accentBlue)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(children: [
      Icon(icon, size: 16, color: _textSecondary),
      const SizedBox(width: 10),
      Text('$label: ', style: const TextStyle(color: _textSecondary, fontSize: 13)),
      Expanded(child: Text(value, style: const TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w500))),
    ]);
  }
}
