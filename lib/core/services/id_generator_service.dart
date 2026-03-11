import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for generating auto-incrementing IDs with school short code prefix
/// Format: {SCHOOL_SHORT_CODE}_{TYPE}_{NUMBER}
/// Examples: ES360_STF_001, ES360_LV_001
class IdGeneratorService {
  final FirebaseFirestore _firestore;

  IdGeneratorService(this._firestore);

  /// Generate next staff employee ID
  /// Format: {shortCode}{paddedNumber}
  /// Example: ES360001
  Future<String> generateStaffId(String schoolId) async {
    return _generateId(schoolId, 'staffCounter', '');
  }

  /// Generate next leave application ID
  /// Format: {shortCode}_LV_{paddedNumber}
  /// Example: ES360_LV_001
  Future<String> generateLeaveId(String schoolId) async {
    return _generateId(schoolId, 'leaveCounter', 'LV');
  }

  /// Generate next permission request ID
  /// Format: {shortCode}_PM_{paddedNumber}
  /// Example: ES360_PM_001
  Future<String> generatePermissionId(String schoolId) async {
    return _generateId(schoolId, 'permissionCounter', 'PM');
  }

  /// Internal method to generate ID using Firestore transaction
  Future<String> _generateId(String schoolId, String counterField, String typePrefix) async {
    final schoolRef = _firestore.collection('schools').doc(schoolId);
    
    return _firestore.runTransaction<String>((transaction) async {
      final schoolDoc = await transaction.get(schoolRef);
      
      if (!schoolDoc.exists) {
        throw Exception('School not found');
      }
      
      final data = schoolDoc.data()!;
      final schoolName = (data['name'] as String?) ?? (data['schoolName'] as String?) ?? '';
      final shortCode = (data['shortCode'] as String?) ?? _generateShortCode(schoolName);
      final currentCounter = (data[counterField] as int?) ?? 0;
      final nextCounter = currentCounter + 1;
      
      // Update counter atomically
      transaction.update(schoolRef, {
        counterField: nextCounter,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Generate ID with padded number (3 digits minimum)
      final paddedNumber = nextCounter.toString().padLeft(3, '0');
      if (typePrefix.isEmpty) {
        // For staff IDs: schoolcode + number (e.g., ES360001)
        return '$shortCode$paddedNumber';
      }
      return '${shortCode}_${typePrefix}_$paddedNumber';
    });
  }

  /// Generate short code from school name
  static String _generateShortCode(String schoolName) {
    if (schoolName.isEmpty) return 'SCH';
    final words = schoolName.toUpperCase().split(' ').where((w) => w.isNotEmpty).toList();
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}${words.length > 2 ? words[2][0] : ''}';
    }
    return schoolName.substring(0, schoolName.length >= 3 ? 3 : schoolName.length).toUpperCase();
  }

  /// Initialize counters for a school if they don't exist
  Future<void> initializeCounters(String schoolId, String schoolName) async {
    final schoolRef = _firestore.collection('schools').doc(schoolId);
    final schoolDoc = await schoolRef.get();
    
    if (!schoolDoc.exists) return;
    
    final data = schoolDoc.data()!;
    final updates = <String, dynamic>{};
    
    if (data['shortCode'] == null) {
      updates['shortCode'] = _generateShortCode(schoolName);
    }
    if (data['staffCounter'] == null) {
      updates['staffCounter'] = 0;
    }
    if (data['leaveCounter'] == null) {
      updates['leaveCounter'] = 0;
    }
    if (data['permissionCounter'] == null) {
      updates['permissionCounter'] = 0;
    }
    
    if (updates.isNotEmpty) {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await schoolRef.update(updates);
    }
  }
}
