import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';

class UPIConfig {
  final String upiId;
  final String merchantName;
  final String? transactionNote;
  final bool enabled;

  const UPIConfig({
    required this.upiId,
    required this.merchantName,
    this.transactionNote,
    this.enabled = true,
  });

  factory UPIConfig.fromFirestore(Map<String, dynamic> data) {
    return UPIConfig(
      upiId: data['upiId'] as String? ?? '',
      merchantName: data['merchantName'] as String? ?? 'School',
      transactionNote: data['transactionNote'] as String?,
      enabled: data['enabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'upiId': upiId,
      'merchantName': merchantName,
      'transactionNote': transactionNote,
      'enabled': enabled,
    };
  }
}

class UPIQRService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<UPIConfig?> getConfig(String schoolId) async {
    try {
      final doc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('settings')
          .doc('upi')
          .get();

      if (!doc.exists) return null;
      return UPIConfig.fromFirestore(doc.data()!);
    } catch (e) {
      print('[UPI QR] Error fetching config: $e');
      return null;
    }
  }

  String generateUPIString({
    required String upiId,
    required String merchantName,
    required double amount,
    String? transactionNote,
    String? transactionRef,
    String? payerName,
  }) {
    // UPI URL format: upi://pay?pa=upi_id&pn=merchant_name&am=amount&tn=transaction_note&tr=transaction_ref
    final buffer = StringBuffer('upi://pay?');
    buffer.write('pa=$upiId');
    buffer.write('&pn=${Uri.encodeComponent(merchantName)}');
    buffer.write('&am=$amount');
    
    if (transactionNote != null && transactionNote.isNotEmpty) {
      buffer.write('&tn=${Uri.encodeComponent(transactionNote)}');
    }
    
    if (transactionRef != null && transactionRef.isNotEmpty) {
      buffer.write('&tr=$transactionRef');
    }
    
    if (payerName != null && payerName.isNotEmpty) {
      buffer.write('&pn=${Uri.encodeComponent(payerName)}');
    }
    
    return buffer.toString();
  }

  Future<bool> saveConfig({
    required String schoolId,
    required String upiId,
    required String merchantName,
    String? transactionNote,
    bool enabled = true,
  }) async {
    try {
      final config = UPIConfig(
        upiId: upiId,
        merchantName: merchantName,
        transactionNote: transactionNote,
        enabled: enabled,
      );

      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('settings')
          .doc('upi')
          .set(config.toFirestore());

      print('[UPI QR] Configuration saved');
      return true;
    } catch (e) {
      print('[UPI QR] Error saving config: $e');
      return false;
    }
  }
}
