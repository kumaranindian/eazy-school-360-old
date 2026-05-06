import 'package:cloud_firestore/cloud_firestore.dart';
import 'lib/core/services/whatsapp_service.dart';

void main() async {
  print('=== WhatsApp Payment Test ===');
  
  // Test configuration
  const schoolId = 'MvTlJlUazXBy8ZZsQE8Q'; // From logs
  const phoneNumber = '+918508196981'; // As requested by user
  const studentName = 'Test Student';
  const studentId = '122'; // From logs
  
  // 1. Check WhatsApp configuration
  print('\n1. Checking WhatsApp configuration...');
  final firestore = FirebaseFirestore.instance;
  try {
    final configDoc = await firestore
        .collection('schools')
        .doc(schoolId)
        .collection('settings')
        .doc('whatsapp')
        .get();
    
    if (configDoc.exists) {
      final config = configDoc.data();
      print('✅ WhatsApp config found:');
      print('   Enabled: ${config?['enabled']}');
      print('   Has accessToken: ${config?['accessToken'] != null}');
      print('   Has phoneNumberId: ${config?['phoneNumberId'] != null}');
      print('   Payment template: ${config?['paymentConfirmationTemplate'] ?? 'payment_confirmation'}');
    } else {
      print('❌ No WhatsApp configuration found for school');
    }
  } catch (e) {
    print('❌ Error checking config: $e');
  }
  
  // 2. Check student phone number
  print('\n2. Checking student phone number...');
  try {
    final studentDoc = await firestore
        .collection('schools')
        .doc(schoolId)
        .collection('student_fee_details')
        .where('stuId', isEqualTo: int.tryParse(studentId) ?? 0)
        .where('academicYear', isEqualTo: '2026-2027')
        .limit(1)
        .get();
    
    if (studentDoc.docs.isNotEmpty) {
      final studentData = studentDoc.docs.first.data();
      final storedPhone = studentData['phoneNumber'];
      print('✅ Student found:');
      print('   Name: ${studentData['studentName']}');
      print('   Phone: $storedPhone');
      print('   Valid: ${storedPhone != null && storedPhone != 'NA' && storedPhone != ''}');
    } else {
      print('❌ Student not found');
    }
  } catch (e) {
    print('❌ Error checking student: $e');
  }
  
  // 3. Test WhatsApp service directly
  print('\n3. Testing WhatsApp service...');
  try {
    final whatsappService = WhatsAppService();
    final result = await whatsappService.sendPaymentConfirmation(
      schoolId: schoolId,
      phoneNumber: phoneNumber,
      studentName: studentName,
      paidAmount: 3000.0,
      receiptNumber: 'TEST-001',
      paymentDate: DateTime.now(),
      balanceAmount: 1500.0,
    );
    print('✅ WhatsApp test result: $result');
  } catch (e) {
    print('❌ WhatsApp test error: $e');
  }
  
  print('\n=== Test Complete ===');
}
