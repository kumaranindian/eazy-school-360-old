import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/whatsapp_service.dart';

/// WhatsApp Configuration Screen for Admins
///
/// Allows administrators to:
/// - Configure Meta WhatsApp Business API credentials
/// - Set up admin phone numbers for notifications
/// - Test WhatsApp configuration
/// - View notification history
class WhatsAppSettingsScreen extends StatefulWidget {
  final String schoolId;

  const WhatsAppSettingsScreen({
    super.key,
    required this.schoolId,
  });

  @override
  State<WhatsAppSettingsScreen> createState() => _WhatsAppSettingsScreenState();
}

class _WhatsAppSettingsScreenState extends State<WhatsAppSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _whatsappService = WhatsAppService();

  // Controllers
  final _accessTokenController = TextEditingController();
  final _phoneNumberIdController = TextEditingController();
  final _feeDueTemplateController =
      TextEditingController(text: 'fee_due_reminder');
  final _paymentConfirmationTemplateController =
      TextEditingController(text: 'payment_confirmation');
  final _adminSummaryTemplateController =
      TextEditingController(text: 'admin_daily_summary');
  final _testPhoneController = TextEditingController();

  bool _enabled = false;
  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  List<String> _adminPhoneNumbers = [];
  final _adminPhoneController = TextEditingController();

  // Colors
  static const _bgDark = Color(0xFF0F172A);
  static const _cardDark = Color(0xFF1E293B);
  static const _borderColor = Color(0xFF334155);
  static const _textPrimary = Color(0xFFF1F5F9);
  static const _textSecondary = Color(0xFF94A3B8);
  static const _accentGreen = Color(0xFF10B981);
  static const _accentBlue = Color(0xFF3B82F6);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _accessTokenController.dispose();
    _phoneNumberIdController.dispose();
    _feeDueTemplateController.dispose();
    _paymentConfirmationTemplateController.dispose();
    _adminSummaryTemplateController.dispose();
    _testPhoneController.dispose();
    _adminPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .collection('settings')
          .doc('whatsapp')
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _enabled = (data['enabled'] as bool?) ?? false;
          _accessTokenController.text = (data['accessToken'] as String?) ?? '';
          _phoneNumberIdController.text =
              (data['phoneNumberId'] as String?) ?? '';
          _feeDueTemplateController.text =
              (data['feeDueTemplate'] as String?) ?? 'fee_due_reminder';
          _paymentConfirmationTemplateController.text =
              (data['paymentConfirmationTemplate'] as String?) ??
                  'payment_confirmation';
          _adminSummaryTemplateController.text =
              (data['adminSummaryTemplate'] as String?) ??
                  'admin_daily_summary';
          _adminPhoneNumbers =
              (data['adminPhoneNumbers'] as List?)?.cast<String>() ?? [];
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error loading settings: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .collection('settings')
          .doc('whatsapp')
          .set({
        'enabled': _enabled,
        'accessToken': _accessTokenController.text.trim(),
        'phoneNumberId': _phoneNumberIdController.text.trim(),
        'feeDueTemplate': _feeDueTemplateController.text.trim(),
        'paymentConfirmationTemplate':
            _paymentConfirmationTemplateController.text.trim(),
        'adminSummaryTemplate': _adminSummaryTemplateController.text.trim(),
        'adminPhoneNumbers': _adminPhoneNumbers,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Settings saved successfully'),
              backgroundColor: _accentGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error saving settings: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testConfiguration() async {
    if (_testPhoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a phone number to test'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _testing = true);

    try {
      final success = await _whatsappService.testConfiguration(
        schoolId: widget.schoolId,
        testPhoneNumber: _testPhoneController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Test message sent successfully!'
                : 'Test failed. Check configuration.'),
            backgroundColor: success ? _accentGreen : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Check if it's a CORS error (common in web environment)
        String errorMessage = 'Test failed: $e';
        if (e.toString().contains('Failed to fetch') ||
            e.toString().contains('ClientException')) {
          errorMessage =
              'CORS error: WhatsApp API cannot be tested from web browser. '
              'Please test from mobile app or desktop environment.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  void _addAdminNumber() {
    final phone = _adminPhoneController.text.trim();
    if (phone.isEmpty) return;

    if (_adminPhoneNumbers.contains(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Phone number already added'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() {
      _adminPhoneNumbers.add(phone);
      _adminPhoneController.clear();
    });
  }

  void _removeAdminNumber(String phone) {
    setState(() {
      _adminPhoneNumbers.remove(phone);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: _cardDark,
        elevation: 0,
        title: const Text('WhatsApp Settings',
            style: TextStyle(color: _textPrimary)),
        iconTheme: const IconThemeData(color: _textPrimary),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accentGreen))
          : SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoCard(isMobile),
                    const SizedBox(height: 24),
                    _buildConfigurationCard(isMobile),
                    const SizedBox(height: 24),
                    _buildTemplatesCard(isMobile),
                    const SizedBox(height: 24),
                    _buildAdminNumbersCard(isMobile),
                    const SizedBox(height: 24),
                    _buildTestCard(isMobile),
                    const SizedBox(height: 24),
                    _buildSaveButton(isMobile),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoCard(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E40AF).withOpacity(0.1),
        border: Border.all(color: _accentBlue.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline,
                  color: _accentBlue, size: isMobile ? 20 : 24),
              const SizedBox(width: 12),
              const Text('Setup Instructions',
                  style: TextStyle(
                      color: _accentBlue,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '1. Create a Meta Business Account at business.facebook.com\n'
            '2. Set up WhatsApp Business API\n'
            '3. Get your Access Token and Phone Number ID from Meta Business Manager\n'
            '4. Create message templates in Meta Business Manager\n'
            '5. Configure the template names below to match your approved templates',
            style: TextStyle(color: _textSecondary, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigurationCard(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: _cardDark,
        border: Border.all(color: _borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('WhatsApp Configuration',
                  style: TextStyle(
                      color: _textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              Switch(
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
                activeColor: _accentGreen,
              ),
              const SizedBox(width: 8),
              Text(_enabled ? 'Enabled' : 'Disabled',
                  style: TextStyle(
                      color: _enabled ? _accentGreen : _textSecondary)),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _accessTokenController,
            style: const TextStyle(color: _textPrimary),
            decoration: InputDecoration(
              labelText: 'Access Token *',
              labelStyle: const TextStyle(color: _textSecondary),
              hintText: 'Enter your Meta WhatsApp Business API access token',
              hintStyle: const TextStyle(color: _textSecondary),
              filled: true,
              fillColor: _bgDark,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _borderColor)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _borderColor)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _accentGreen)),
            ),
            validator: (value) => value?.trim().isEmpty ?? true
                ? 'Access token is required'
                : null,
            obscureText: true,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneNumberIdController,
            style: const TextStyle(color: _textPrimary),
            decoration: InputDecoration(
              labelText: 'Phone Number ID *',
              labelStyle: const TextStyle(color: _textSecondary),
              hintText: 'Enter your WhatsApp Business Phone Number ID',
              hintStyle: const TextStyle(color: _textSecondary),
              filled: true,
              fillColor: _bgDark,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _borderColor)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _borderColor)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _accentGreen)),
            ),
            validator: (value) => value?.trim().isEmpty ?? true
                ? 'Phone Number ID is required'
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildTemplatesCard(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: _cardDark,
        border: Border.all(color: _borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Message Templates',
              style: TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _feeDueTemplateController,
            style: const TextStyle(color: _textPrimary),
            decoration: InputDecoration(
              labelText: 'Fee Due Reminder Template',
              labelStyle: const TextStyle(color: _textSecondary),
              hintText: 'fee_due_reminder',
              hintStyle: const TextStyle(color: _textSecondary),
              filled: true,
              fillColor: _bgDark,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 8),
          _buildSampleMessage(
            'Sample Message:',
            'Dear Parent,\n\nThis is a reminder that {{Student Name}}\'s {{Term Name}} fee of {{Amount}} is due on {{Due Date}}.\n\nPlease make the payment at your earliest convenience to avoid late fees.\n\nThank you!',
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _paymentConfirmationTemplateController,
            style: const TextStyle(color: _textPrimary),
            decoration: InputDecoration(
              labelText: 'Payment Confirmation Template',
              labelStyle: const TextStyle(color: _textSecondary),
              hintText: 'payment_confirmation',
              hintStyle: const TextStyle(color: _textSecondary),
              filled: true,
              fillColor: _bgDark,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 8),
          _buildSampleMessage(
            'Sample Message:',
            'Dear Parent,\n\nPayment received for {{Student Name}}.\n\nAmount Paid: {{Amount}}\nReceipt No: {{Receipt Number}}\nDate: {{Payment Date}}\nBalance Due: {{Balance Amount}}\n\nThank you for your payment!',
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _adminSummaryTemplateController,
            style: const TextStyle(color: _textPrimary),
            decoration: InputDecoration(
              labelText: 'Admin Daily Summary Template',
              labelStyle: const TextStyle(color: _textSecondary),
              hintText: 'admin_daily_summary',
              hintStyle: const TextStyle(color: _textSecondary),
              filled: true,
              fillColor: _bgDark,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 8),
          _buildSampleMessage(
            'Sample Message:',
            'Daily Fee Collection Summary - {{Date}}\n\nTotal Collected: {{Total Amount}}\nNumber of Transactions: {{Transaction Count}}\n\nLogin to the admin portal for detailed reports.',
          ),
        ],
      ),
    );
  }

  Widget _buildAdminNumbersCard(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: _cardDark,
        border: Border.all(color: _borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Admin Phone Numbers',
              style: TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('These numbers will receive daily collection summaries',
              style: TextStyle(color: _textSecondary, fontSize: 14)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _adminPhoneController,
                  style: const TextStyle(color: _textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    labelStyle: const TextStyle(color: _textSecondary),
                    hintText: '+919876543210',
                    hintStyle: const TextStyle(color: _textSecondary),
                    filled: true,
                    fillColor: _bgDark,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _addAdminNumber,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentGreen,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
            ],
          ),
          if (_adminPhoneNumbers.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...List.generate(_adminPhoneNumbers.length, (index) {
              final phone = _adminPhoneNumbers[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _bgDark,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.phone, color: _accentGreen, size: 20),
                    const SizedBox(width: 12),
                    Text(phone, style: const TextStyle(color: _textPrimary)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _removeAdminNumber(phone),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildTestCard(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: _cardDark,
        border: Border.all(color: _borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Test Configuration',
              style: TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _testPhoneController,
                  style: const TextStyle(color: _textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Test Phone Number',
                    labelStyle: const TextStyle(color: _textSecondary),
                    hintText: '+919876543210',
                    hintStyle: const TextStyle(color: _textSecondary),
                    filled: true,
                    fillColor: _bgDark,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _testing ? null : _testConfiguration,
                icon: _testing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send),
                label: Text(_testing ? 'Sending...' : 'Test'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentBlue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(bool isMobile) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saving ? null : _saveSettings,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentGreen,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: isMobile ? 14 : 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: _saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Text('Save Settings',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSampleMessage(String label, String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _accentBlue,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              message,
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
