import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/upi_qr_service.dart';

const Color _bgDark = Color(0xFF0F172A);
const Color _cardDark = Color(0xFF1E293B);
const Color _accentGreen = Color(0xFF10B981);
const Color _accentBlue = Color(0xFF3B82F6);
const Color _accentRed = Color(0xFFEF4444);
const Color _textPrimary = Color(0xFFF1F5F9);
const Color _textSecondary = Color(0xFF94A3B8);
const Color _borderColor = Color(0xFF334155);

class UPISettingsScreen extends StatefulWidget {
  final String schoolId;

  const UPISettingsScreen({
    super.key,
    required this.schoolId,
  });

  @override
  State<UPISettingsScreen> createState() => _UPISettingsScreenState();
}

class _UPISettingsScreenState extends State<UPISettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _upiIdController = TextEditingController();
  final _merchantNameController = TextEditingController();
  final _transactionNoteController = TextEditingController();

  bool _enabled = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _upiIdController.dispose();
    _merchantNameController.dispose();
    _transactionNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final service = UPIQRService();
      final config = await service.getConfig(widget.schoolId);

      if (config != null && mounted) {
        setState(() {
          _enabled = config.enabled;
          _upiIdController.text = config.upiId;
          _merchantNameController.text = config.merchantName;
          _transactionNoteController.text = config.transactionNote ?? '';
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
            backgroundColor: _accentRed,
          ),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final service = UPIQRService();
      final success = await service.saveConfig(
        schoolId: widget.schoolId,
        upiId: _upiIdController.text.trim(),
        merchantName: _merchantNameController.text.trim(),
        transactionNote: _transactionNoteController.text.trim().isEmpty
            ? null
            : _transactionNoteController.text.trim(),
        enabled: _enabled,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('UPI settings saved successfully'),
              backgroundColor: _accentGreen,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save settings'),
              backgroundColor: _accentRed,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: _accentRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: _cardDark,
        elevation: 0,
        title: const Text(
          'UPI Settings',
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _accentBlue),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoCard(),
                    const SizedBox(height: 16),
                    _buildConfigurationCard(),
                    const SizedBox(height: 16),
                    _buildTestingCard(),
                    const SizedBox(height: 24),
                    _buildSaveButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _accentBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accentBlue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: _accentBlue, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Setup Instructions',
                style: TextStyle(
                  color: _accentBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoStep('1', 'Get your UPI ID from GPay, PhonePe, or Paytm'),
          _buildInfoStep('2', 'Enter your UPI ID below (e.g., name@upi)'),
          _buildInfoStep('3', 'Set your merchant name (e.g., school name)'),
          _buildInfoStep('4', 'Enable UPI QR code payments'),
          _buildInfoStep('5', 'Save settings to generate QR codes in payment dialog'),
        ],
      ),
    );
  }

  Widget _buildInfoStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _accentBlue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: _accentBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigurationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'UPI Configuration',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  Text(
                    _enabled ? 'Enabled' : 'Disabled',
                    style: TextStyle(
                      color: _enabled ? _accentGreen : _textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _enabled,
                    onChanged: (value) => setState(() => _enabled = value),
                    activeColor: _accentGreen,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _upiIdController,
            style: const TextStyle(color: _textPrimary),
            decoration: InputDecoration(
              labelText: 'UPI ID *',
              labelStyle: const TextStyle(color: _textSecondary),
              hintText: 'e.g., schoolname@okaxis',
              hintStyle: const TextStyle(color: _textSecondary),
              filled: true,
              fillColor: _bgDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _accentBlue),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'UPI ID is required';
              }
              if (!value.contains('@')) {
                return 'Invalid UPI ID format (must contain @)';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _merchantNameController,
            style: const TextStyle(color: _textPrimary),
            decoration: InputDecoration(
              labelText: 'Merchant Name *',
              labelStyle: const TextStyle(color: _textSecondary),
              hintText: 'Your School Name',
              hintStyle: const TextStyle(color: _textSecondary),
              filled: true,
              fillColor: _bgDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _accentBlue),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Merchant name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _transactionNoteController,
            style: const TextStyle(color: _textPrimary),
            decoration: InputDecoration(
              labelText: 'Transaction Note (Optional)',
              labelStyle: const TextStyle(color: _textSecondary),
              hintText: 'e.g., School Fee Payment',
              hintStyle: const TextStyle(color: _textSecondary),
              filled: true,
              fillColor: _bgDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _accentBlue),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _accentAmber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accentAmber.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber, color: _accentAmber, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Important Notes',
                style: TextStyle(
                  color: _accentAmber,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'QR code payments require manual verification. After payment, you need to manually confirm the payment in the payment dialog.',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saving ? null : _saveSettings,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
        child: _saving
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Save Settings',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

const Color _accentAmber = Color(0xFFF59E0B);
