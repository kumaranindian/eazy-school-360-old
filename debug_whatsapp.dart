import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  print('=== Debug WhatsApp Payment ===');
  
  const schoolId = 'MvTlJlUazXBy8ZZsQE8Q';
  const studentId = '122';
  const academicYear = '2026-2027';
  const testPhone = '+918508196981';
  
  // 1. Check student phone number in student_fee_details
  print('\n1. Checking student phone number...');
  try {
    final studentDoc = await FirebaseFirestore.instance
        .collection('schools')
        .doc(schoolId)
        .collection('student_fee_details')
        .where('stuId', isEqualTo: int.tryParse(studentId) ?? 0)
        .where('academicYear', isEqualTo: academicYear)
        .limit(1)
        .get();
    
    if (studentDoc.docs.isNotEmpty) {
      final data = studentDoc.docs.first.data();
      print('✅ Student found:');
      print('   Name: ${data['studentName']}');
      print('   Phone: ${data['phoneNumber']}');
      print('   Phone type: ${data['phoneNumber'].runtimeType}');
      print('   Is valid: ${data['phoneNumber'] != null && data['phoneNumber'] != 'NA' && data['phoneNumber'].toString().trim() != ''}');
      
      // Test with your specified phone
      print('\n2. Testing with your phone: $testPhone');
      print('   Format check: ${testPhone.startsWith('+') ? 'E.164 format' : 'Not E.164'}');
      
    } else {
      print('❌ Student not found with stuId=$studentId, AY=$academicYear');
      
      // Try without academic year filter
      print('\n2. Trying without academic year filter...');
      final allStudents = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('student_fee_details')
          .where('stuId', isEqualTo: int.tryParse(studentId) ?? 0)
          .limit(5)
          .get();
      
      print('   Found ${allStudents.docs.length} students with stuId=$studentId');
      for (final doc in allStudents.docs) {
        final data = doc.data();
        print('   - AY: ${data['academicYear']}, Phone: ${data['phoneNumber']}, Name: ${data['studentName']}');
      }
    }
  } catch (e) {
    print('❌ Error: $e');
  }
  
  // 3. Check recent payment notifications
  print('\n3. Checking recent payment notifications...');
  try {
    final notifications = await FirebaseFirestore.instance
        .collection('schools')
        .doc(schoolId)
        .collection('whatsapp_notifications')
        .where('type', isEqualTo: 'payment_confirmation')
        .orderBy('timestamp', descending: true)
        .limit(5)
        .get();
    
    print('   Found ${notifications.docs.length} recent payment notifications');
    for (final doc in notifications.docs) {
      final data = doc.data();
      print('   - ${data['timestamp']}: ${data['status']} to ${data['recipient']} for ${data['studentName']}');
      if (data['status'] == 'failed') {
        print('     Error: ${data['metadata']['error'] ?? 'No error info'}');
      }
    }
  } catch (e) {
    print('   Error checking notifications: $e');
  }
  
  print('\n=== Debug Complete ===');
}
