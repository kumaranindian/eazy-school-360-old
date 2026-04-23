import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/entities/membership.dart';

/// Service for managing [Membership] records that link one Firebase Auth
/// account (uid / email) to many schools, each with one or more roles.
///
/// Data layout:
///   userMemberships/{uid}/schools/{schoolId}   -> Membership doc
///
/// The service is additive — it never mutates Firebase Auth accounts and
/// it is safe to call on legacy users that only live in `users/{uid}`
/// (callers typically also keep that doc up to date for back-compat).
class MembershipService {
  final FirebaseFirestore _firestore;

  MembershipService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) => _firestore
      .collection('userMemberships')
      .doc(uid)
      .collection('schools');

  DocumentReference<Map<String, dynamic>> _doc(String uid, String schoolId) =>
      _col(uid).doc(schoolId);

  /// List all memberships for [uid], newest first. Never throws.
  Future<List<Membership>> listForUser(String uid) async {
    try {
      final snap = await _col(uid).get();
      final list = snap.docs.map(Membership.fromFirestore).toList();
      list.sort((a, b) => b.joinedAt.compareTo(a.joinedAt));
      return list;
    } catch (e) {
      debugPrint('[MembershipService] listForUser($uid) error: $e');
      return const [];
    }
  }

  /// Active memberships only, with the school itself still active.
  Future<List<Membership>> listActiveForUser(String uid) async {
    final all = await listForUser(uid);
    return all.where((m) => m.isActive && m.schoolIsActive).toList();
  }

  Stream<List<Membership>> watchForUser(String uid) {
    return _col(uid).snapshots().map(
          (s) => s.docs.map(Membership.fromFirestore).toList()
            ..sort((a, b) => b.joinedAt.compareTo(a.joinedAt)),
        );
  }

  /// Read a single membership, or null if it doesn't exist.
  Future<Membership?> get(String uid, String schoolId) async {
    try {
      final snap = await _doc(uid, schoolId).get();
      if (!snap.exists) return null;
      return Membership.fromFirestore(snap);
    } catch (e) {
      debugPrint('[MembershipService] get($uid,$schoolId) error: $e');
      return null;
    }
  }

  /// Create a membership if missing, otherwise MERGE roles into the existing
  /// doc (no duplicates) and refresh denormalised fields. This is the primary
  /// write API used by the signup, admin-creates-user, and activation flows.
  ///
  /// Pass [ensureActive] to mark the membership active on upsert (defaults
  /// to keeping the existing state, or true for brand-new docs).
  Future<Membership> upsertRoles({
    required String uid,
    required String schoolId,
    required String schoolName,
    required List<UserRole> roles,
    bool isOwner = false,
    bool? ensureActive,
    bool schoolIsActive = true,
    String? schoolShortCode,
    String? createdBy,
  }) async {
    assert(roles.isNotEmpty, 'upsertRoles requires at least one role');
    final ref = _doc(uid, schoolId);
    final existing = await get(uid, schoolId);

    final mergedRoles = <UserRole>{...?existing?.roles, ...roles}.toList();
    // Drop NONE if other real roles are present.
    if (mergedRoles.length > 1) mergedRoles.remove(UserRole.NONE);

    final membership = Membership(
      schoolId: schoolId,
      schoolName: schoolName,
      schoolShortCode:
          schoolShortCode ?? existing?.schoolShortCode ?? '',
      roles: mergedRoles,
      isActive: ensureActive ?? existing?.isActive ?? true,
      isOwner: existing?.isOwner == true || isOwner,
      schoolIsActive: schoolIsActive,
      joinedAt: existing?.joinedAt ?? DateTime.now(),
      lastAccessedAt: existing?.lastAccessedAt,
      createdBy: existing?.createdBy ?? createdBy,
    );

    await ref.set(membership.toFirestore(), SetOptions(merge: true));
    return membership;
  }

  /// Remove a role from a school without deleting the membership. If the
  /// removal leaves no roles, the membership is deactivated.
  Future<void> removeRole({
    required String uid,
    required String schoolId,
    required UserRole role,
  }) async {
    final existing = await get(uid, schoolId);
    if (existing == null) return;
    final remaining = existing.roles.where((r) => r != role).toList();
    if (remaining.isEmpty) {
      await _doc(uid, schoolId).set({
        'roles': <String>[],
        'isActive': false,
        'lastAccessedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      await _doc(uid, schoolId).set({
        'roles': remaining.map((r) => r.name).toList(),
      }, SetOptions(merge: true));
    }
  }

  /// Activate / deactivate an entire membership at a school without touching
  /// Firebase Auth. This lets an admin revoke a user's access to school A
  /// while they keep working at school B under the same email.
  Future<void> setActive({
    required String uid,
    required String schoolId,
    required bool isActive,
  }) async {
    await _doc(uid, schoolId).set({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> touchLastAccessed({
    required String uid,
    required String schoolId,
  }) async {
    try {
      await _doc(uid, schoolId).set({
        'lastAccessedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {/* non-critical */}
  }

  /// Cascade: mark all memberships for a school as inactive (used when a
  /// school is deactivated/deleted). Uses a collection-group query so we
  /// don't need to know which users are members.
  Future<void> deactivateAllForSchool(String schoolId) async {
    try {
      final snap = await _firestore
          .collectionGroup('schools')
          .where('schoolId', isEqualTo: schoolId)
          .get();
      final batch = _firestore.batch();
      for (final d in snap.docs) {
        batch.set(d.reference, {
          'schoolIsActive': false,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[MembershipService] deactivateAllForSchool error: $e');
    }
  }

  /// Propagate a school's active flag to every membership (called when a
  /// super admin activates / deactivates a school).
  Future<void> propagateSchoolActive({
    required String schoolId,
    required bool isActive,
  }) async {
    try {
      final snap = await _firestore
          .collectionGroup('schools')
          .where('schoolId', isEqualTo: schoolId)
          .get();
      final batch = _firestore.batch();
      for (final d in snap.docs) {
        batch.set(d.reference, {
          'schoolIsActive': isActive,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[MembershipService] propagateSchoolActive error: $e');
    }
  }
}
