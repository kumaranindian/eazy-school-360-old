import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eazy_school_360/domain/entities/school.dart';

/// School statistics for super admin dashboard
class SchoolStats {
  final String schoolId;
  final String schoolName;
  final int totalStaff;
  final int activeStaff;
  final int pendingRequests;
  final bool isActive;
  final DateTime? lastActivityAt;
  final Map<String, dynamic>? subscription;

  const SchoolStats({
    required this.schoolId,
    required this.schoolName,
    required this.totalStaff,
    required this.activeStaff,
    required this.pendingRequests,
    required this.isActive,
    this.lastActivityAt,
    this.subscription,
  });
}

/// Platform-wide statistics for super admin
class PlatformStats {
  final int totalSchools;
  final int activeSchools;
  final int pendingSchools;
  final int totalUsers;
  final int totalStaff;
  final int totalAdmins;
  final int pendingApprovals;
  final DateTime lastUpdated;

  const PlatformStats({
    required this.totalSchools,
    required this.activeSchools,
    required this.pendingSchools,
    required this.totalUsers,
    required this.totalStaff,
    required this.totalAdmins,
    required this.pendingApprovals,
    required this.lastUpdated,
  });

  factory PlatformStats.empty() {
    return PlatformStats(
      totalSchools: 0,
      activeSchools: 0,
      pendingSchools: 0,
      totalUsers: 0,
      totalStaff: 0,
      totalAdmins: 0,
      pendingApprovals: 0,
      lastUpdated: DateTime.now(),
    );
  }
}

/// School Management Repository for Super Admin operations
class SchoolManagementRepository {
  final FirebaseFirestore _firestore;
  
  // Cache for platform stats
  PlatformStats? _platformStatsCache;
  DateTime? _platformStatsCacheTime;
  final Duration _cacheDuration = const Duration(minutes: 5);

  SchoolManagementRepository(this._firestore);

  /// Get all schools with pagination support
  Stream<List<School>> getAllSchools({
    int limit = 50,
    DocumentSnapshot? startAfter,
    bool activeOnly = false,
  }) {
    Query query = _firestore
        .collection('schools')
        .orderBy('createdAt', descending: true);

    if (activeOnly) {
      query = query.where('isActive', isEqualTo: true);
    }

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query.limit(limit).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => School.fromFirestore(doc)).toList();
    });
  }

  /// Get pending school registrations
  Stream<List<School>> getPendingSchools() {
    return _firestore
        .collection('schools')
        .where('isActive', isEqualTo: false)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => School.fromFirestore(doc)).toList();
        });
  }

  /// Get school by ID
  Future<School?> getSchoolById(String schoolId) async {
    try {
      final doc = await _firestore.collection('schools').doc(schoolId).get();
      if (doc.exists) {
        return School.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('❌ [SCHOOL_REPO] Error getting school: $e');
      throw Exception('Failed to get school: $e');
    }
  }

  /// Get school statistics
  Future<SchoolStats> getSchoolStats(String schoolId) async {
    try {
      final schoolDoc = await _firestore.collection('schools').doc(schoolId).get();
      if (!schoolDoc.exists) {
        throw Exception('School not found');
      }

      final schoolData = schoolDoc.data()!;

      // Get staff counts
      final staffSnapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('staff')
          .get();

      int totalStaff = staffSnapshot.docs.length;
      int activeStaff = staffSnapshot.docs.where((doc) {
        return doc.data()['status'] == 'ACTIVE';
      }).length;

      // Get pending requests count
      final pendingLeavesCount = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaves')
          .where('status', isEqualTo: 'PENDING')
          .count()
          .get();

      final pendingPermissionsCount = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('permissions')
          .where('status', isEqualTo: 'PENDING')
          .count()
          .get();

      return SchoolStats(
        schoolId: schoolId,
        schoolName: schoolData['name'] as String? ?? 'Unknown',
        totalStaff: totalStaff,
        activeStaff: activeStaff,
        pendingRequests: (pendingLeavesCount.count ?? 0) + (pendingPermissionsCount.count ?? 0),
        isActive: schoolData['isActive'] as bool? ?? false,
        lastActivityAt: (schoolData['updatedAt'] as Timestamp?)?.toDate(),
        subscription: schoolData['subscription'] as Map<String, dynamic>?,
      );
    } catch (e) {
      print('❌ [SCHOOL_REPO] Error getting school stats: $e');
      rethrow;
    }
  }

  /// Activate a school and its admin
  Future<void> activateSchool(String schoolId, String approvedBy) async {
    try {
      final batch = _firestore.batch();

      // Update school status
      final schoolRef = _firestore.collection('schools').doc(schoolId);
      batch.update(schoolRef, {
        'isActive': true,
        'activatedAt': FieldValue.serverTimestamp(),
        'activatedBy': approvedBy,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Find and activate the admin user for this school
      // Query for both 'ADMIN' and 'tenant_admin' roles since signup creates tenant_admin
      final adminSnapshot = await _firestore
          .collection('users')
          .where('schoolId', isEqualTo: schoolId)
          .where('role', whereIn: ['ADMIN', 'tenant_admin'])
          .get();

      for (final adminDoc in adminSnapshot.docs) {
        final uid = adminDoc.id;
        
        // Update user document
        batch.update(adminDoc.reference, {
          'isActive': true,
          'status': 'ACTIVE',
          'activatedAt': FieldValue.serverTimestamp(),
          'activatedBy': approvedBy,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // Update membership document
        final membershipRef = _firestore
            .collection('userMemberships')
            .doc(uid)
            .collection('schools')
            .doc(schoolId);
        batch.update(membershipRef, {
          'isActive': true,
          'schoolIsActive': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      print('✅ [SCHOOL_REPO] School activated: $schoolId');
    } catch (e) {
      print('❌ [SCHOOL_REPO] Error activating school: $e');
      throw Exception('Failed to activate school: $e');
    }
  }

  /// Deactivate a school
  Future<void> deactivateSchool(String schoolId, String deactivatedBy, String reason) async {
    try {
      final batch = _firestore.batch();

      // Update school status
      final schoolRef = _firestore.collection('schools').doc(schoolId);
      batch.update(schoolRef, {
        'isActive': false,
        'deactivatedAt': FieldValue.serverTimestamp(),
        'deactivatedBy': deactivatedBy,
        'deactivationReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Deactivate all users in this school
      final usersSnapshot = await _firestore
          .collection('users')
          .where('schoolId', isEqualTo: schoolId)
          .get();

      for (final userDoc in usersSnapshot.docs) {
        batch.update(userDoc.reference, {
          'isActive': false,
          'status': 'DISABLED',
          'deactivatedAt': FieldValue.serverTimestamp(),
          'deactivatedBy': deactivatedBy,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      print('✅ [SCHOOL_REPO] School deactivated: $schoolId');
    } catch (e) {
      print('❌ [SCHOOL_REPO] Error deactivating school: $e');
      throw Exception('Failed to deactivate school: $e');
    }
  }

  /// Update school details
  Future<void> updateSchool(String schoolId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      
      await _firestore.collection('schools').doc(schoolId).update(updates);
      print('✅ [SCHOOL_REPO] School updated: $schoolId');
    } catch (e) {
      print('❌ [SCHOOL_REPO] Error updating school: $e');
      throw Exception('Failed to update school: $e');
    }
  }

  /// Delete school (soft delete)
  Future<void> deleteSchool(String schoolId, String deletedBy) async {
    try {
      await _firestore.collection('schools').doc(schoolId).update({
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedBy': deletedBy,
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ [SCHOOL_REPO] School soft deleted: $schoolId');
    } catch (e) {
      print('❌ [SCHOOL_REPO] Error deleting school: $e');
      throw Exception('Failed to delete school: $e');
    }
  }

  /// Get platform-wide statistics for super admin
  Future<PlatformStats> getPlatformStats({bool forceRefresh = false}) async {
    // Check cache
    if (!forceRefresh && 
        _platformStatsCache != null && 
        _platformStatsCacheTime != null &&
        DateTime.now().difference(_platformStatsCacheTime!) < _cacheDuration) {
      return _platformStatsCache!;
    }

    try {
      // Execute parallel queries for performance
      final results = await Future.wait([
        _firestore.collection('schools').count().get(),
        _firestore.collection('schools').where('isActive', isEqualTo: true).count().get(),
        _firestore.collection('schools').where('isActive', isEqualTo: false).count().get(),
        _firestore.collection('users').count().get(),
        _firestore.collection('users').where('role', isEqualTo: 'STAFF').count().get(),
        _firestore.collection('users').where('role', isEqualTo: 'ADMIN').count().get(),
      ]);

      final stats = PlatformStats(
        totalSchools: results[0].count ?? 0,
        activeSchools: results[1].count ?? 0,
        pendingSchools: results[2].count ?? 0,
        totalUsers: results[3].count ?? 0,
        totalStaff: results[4].count ?? 0,
        totalAdmins: results[5].count ?? 0,
        pendingApprovals: results[2].count ?? 0,
        lastUpdated: DateTime.now(),
      );

      // Update cache
      _platformStatsCache = stats;
      _platformStatsCacheTime = DateTime.now();

      return stats;
    } catch (e) {
      print('❌ [SCHOOL_REPO] Error getting platform stats: $e');
      return _platformStatsCache ?? PlatformStats.empty();
    }
  }

  /// Search schools by name or email
  Future<List<School>> searchSchools(String query) async {
    try {
      final queryLower = query.toLowerCase();
      
      // Firestore doesn't support full-text search, so we fetch and filter
      // For production, consider using Algolia or similar
      final snapshot = await _firestore
          .collection('schools')
          .orderBy('name')
          .limit(100)
          .get();

      return snapshot.docs
          .map((doc) => School.fromFirestore(doc))
          .where((school) =>
              school.schoolName.toLowerCase().contains(queryLower))
          .toList();
    } catch (e) {
      print('❌ [SCHOOL_REPO] Error searching schools: $e');
      return [];
    }
  }

  /// Get schools by subscription status
  Future<List<School>> getSchoolsBySubscription(String status) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .where('subscription.status', isEqualTo: status)
          .get();

      return snapshot.docs.map((doc) => School.fromFirestore(doc)).toList();
    } catch (e) {
      print('❌ [SCHOOL_REPO] Error getting schools by subscription: $e');
      return [];
    }
  }

  /// Update school subscription
  Future<void> updateSubscription(
    String schoolId,
    Map<String, dynamic> subscriptionData,
  ) async {
    try {
      await _firestore.collection('schools').doc(schoolId).update({
        'subscription': subscriptionData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ [SCHOOL_REPO] Subscription updated for school: $schoolId');
    } catch (e) {
      print('❌ [SCHOOL_REPO] Error updating subscription: $e');
      throw Exception('Failed to update subscription: $e');
    }
  }

  /// Get audit log for a school
  Future<List<Map<String, dynamic>>> getSchoolAuditLog(
    String schoolId, {
    int limit = 50,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('auditLog')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('❌ [SCHOOL_REPO] Error getting audit log: $e');
      return [];
    }
  }

  /// Add audit log entry
  Future<void> addAuditLogEntry(
    String schoolId,
    String action,
    String performedBy,
    Map<String, dynamic>? details,
  ) async {
    try {
      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('auditLog')
          .add({
        'action': action,
        'performedBy': performedBy,
        'timestamp': FieldValue.serverTimestamp(),
        'details': details,
      });
    } catch (e) {
      print('❌ [SCHOOL_REPO] Error adding audit log: $e');
    }
  }

  /// Clear platform stats cache
  void clearCache() {
    _platformStatsCache = null;
    _platformStatsCacheTime = null;
  }
}

/// Providers
final schoolManagementRepositoryProvider = Provider<SchoolManagementRepository>((ref) {
  return SchoolManagementRepository(FirebaseFirestore.instance);
});

/// All schools stream provider
final allSchoolsProvider = StreamProvider.family<List<School>, bool>((ref, activeOnly) {
  final repository = ref.watch(schoolManagementRepositoryProvider);
  return repository.getAllSchools(activeOnly: activeOnly);
});

/// Pending schools stream provider
final pendingSchoolsProvider = StreamProvider<List<School>>((ref) {
  final repository = ref.watch(schoolManagementRepositoryProvider);
  return repository.getPendingSchools();
});

/// School by ID provider
final schoolByIdProvider = FutureProvider.family<School?, String>((ref, schoolId) {
  final repository = ref.watch(schoolManagementRepositoryProvider);
  return repository.getSchoolById(schoolId);
});

/// School stats provider
final schoolStatsProvider = FutureProvider.family<SchoolStats, String>((ref, schoolId) {
  final repository = ref.watch(schoolManagementRepositoryProvider);
  return repository.getSchoolStats(schoolId);
});

/// Platform stats provider
final platformStatsProvider = FutureProvider<PlatformStats>((ref) {
  final repository = ref.watch(schoolManagementRepositoryProvider);
  return repository.getPlatformStats();
});

/// School search provider
final schoolSearchProvider = FutureProvider.family<List<School>, String>((ref, query) {
  final repository = ref.watch(schoolManagementRepositoryProvider);
  return repository.searchSchools(query);
});
