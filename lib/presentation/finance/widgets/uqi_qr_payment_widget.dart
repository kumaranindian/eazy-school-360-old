import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/services/upi_qr_service.dart';
import '../../../domain/entities/student_fee_ledger.dart';

const Color _cardDark = Color(0xFF161B22);
const Color _accentGreen = Color(0xFF4CAF50);
const Color _accentBlue = Color(0xFF3B82F6);
const Color _accentRed = Color(0xFFEF4444);
const Color _accentAmber = Color(0xFFF59E0B);
const Color _textPrimary = Color(0xFFE6EDF3);
const Color _textSecondary = Color(0xFF8B949E);
const Color _borderColor = Color(0xFF30363D);

class UPIQRPaymentWidget extends ConsumerStatefulWidget {
  final String schoolId;
  final StudentFeeLedger ledger;
  final double amount;
  final VoidCallback onPaymentConfirmed;
  final VoidCallback onCancel;

  const UPIQRPaymentWidget({
    super.key,
    required this.schoolId,
    required this.ledger,
    required this.amount,
    required this.onPaymentConfirmed,
    required this.onCancel,
  });

  @override
  ConsumerState<UPIQRPaymentWidget> createState() => _UPIQRPaymentWidgetState();
}

class _UPIQRPaymentWidgetState extends ConsumerState<UPIQRPaymentWidget> {
  final UPIQRService _upiService = UPIQRService();
  bool _loading = true;
  String? _upiString;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUPIConfig();
  }

  Future<void> _loadUPIConfig() async {
    try {
      final config = await _upiService.getConfig(widget.schoolId);
      if (config == null || !config.enabled) {
        setState(() {
          _loading = false;
          _error = 'UPI is not enabled for this school. Please contact admin.';
        });
        return;
      }

      final transactionRef = 'FEE-${widget.ledger.studentId}-${DateTime.now().millisecondsSinceEpoch}';
      final upiString = _upiService.generateUPIString(
        upiId: config.upiId,
        merchantName: config.merchantName,
        amount: widget.amount,
        transactionNote: config.transactionNote ?? 'School Fee Payment for ${widget.ledger.studentName}',
        transactionRef: transactionRef,
      );

      if (mounted) {
        setState(() {
          _upiString = upiString;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Error loading UPI config: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accentBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.qr_code_2,
                  color: _accentBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pay via UPI QR Code',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Scan with GPay, PhonePe, or Paytm',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: _accentBlue),
            )
          else if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _accentRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _accentRed.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: _accentRed, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: _accentRed, fontSize: 12),
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: QrImageView(
                    data: _upiString!,
                    version: QrVersions.auto,
                    size: 200.0,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _accentAmber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _accentAmber.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: _accentAmber, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Payment Instructions',
                              style: TextStyle(
                                color: _accentAmber,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '1. Scan QR code with GPay, PhonePe, or Paytm',
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '2. Enter amount: ${money.format(widget.amount)}',
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '3. Complete payment',
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '4. Click "Confirm Payment" after successful transaction',
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onCancel,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _textSecondary,
                          side: const BorderSide(color: _borderColor),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: widget.onPaymentConfirmed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Confirm Payment',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}
