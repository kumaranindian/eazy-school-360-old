import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../core/security/firebase_indexes_verifier.dart';

/// Status of a single provisioning step.
enum ProvisioningStatus { pending, running, done, skipped, failed }

/// Single progress event streamed by [TenantProvisioningService].
@immutable
class ProvisioningEvent {
  final String stepId;
  final String title;
  final ProvisioningStatus status;
  final String? message;
  final int index; // 0-based
  final int total;

  const ProvisioningEvent({
    required this.stepId,
    required this.title,
    required this.status,
    required this.index,
    required this.total,
    this.message,
  });

  ProvisioningEvent copyWith({
    ProvisioningStatus? status,
    String? message,
  }) =>
      ProvisioningEvent(
        stepId: stepId,
        title: title,
        status: status ?? this.status,
        index: index,
        total: total,
        message: message ?? this.message,
      );
}

/// Declarative description of one idempotent provisioning step.
///
/// * [exists] — cheap read that returns `true` if the step's target is
///   already present. The step is then skipped. Failures in [exists] are
///   treated as "unknown" and the step still runs.
/// * [apply] — writes the seed data. Must itself be safe to re-run.
class _Step {
  final String id;
  final String title;
  final Future<bool> Function() exists;
  final Future<void> Function() apply;

  const _Step({
    required this.id,
    required this.title,
    required this.exists,
    required this.apply,
  });
}

/// Per-tenant provisioning.
///
/// Firestore does not require explicit "create collection" calls — a
/// collection exists as soon as a document is written into it. This service
/// therefore seeds the minimal set of documents every new school needs so
/// that downstream features (leave, permissions, payroll, settings, etc.)
/// have a baseline to read from.
///
/// Composite indexes and security rules are **project-wide** in Firestore
/// and cannot be created from the client SDK; they are deployed via the
/// Firebase CLI. We still run them as steps so the UI can surface their
/// status and skip them when they are already in place (idempotent).
///
/// Every step:
///   * checks if its target already exists (skipped on match)
///   * otherwise performs its write
///   * emits a [ProvisioningEvent] at each transition
class TenantProvisioningService {
  final FirebaseFirestore _firestore;

  TenantProvisioningService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Runs the provisioning pipeline for [schoolId].
  ///
  /// The returned stream emits one event per step transition. It completes
  /// after the last step finishes (whether done, skipped, or failed). The
  /// service keeps going past a failed step so the admin can see the full
  /// picture; partial provisioning is recoverable because every step is
  /// idempotent.
  Stream<ProvisioningEvent> provisionSchool({
    required String schoolId,
    required String createdByUid,
  }) async* {
    final steps = _buildSteps(schoolId: schoolId, createdByUid: createdByUid);
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      var event = ProvisioningEvent(
        stepId: step.id,
        title: step.title,
        status: ProvisioningStatus.running,
        index: i,
        total: steps.length,
      );
      yield event;

      try {
        final already = await step.exists().catchError((e) {
          debugPrint('[provision] exists-check failed for ${step.id}: $e');
          return false;
        });
        if (already) {
          yield event.copyWith(
              status: ProvisioningStatus.skipped,
              message: 'Already configured');
          continue;
        }

        await step.apply();
        yield event.copyWith(status: ProvisioningStatus.done);
      } catch (e) {
        debugPrint('[provision] step ${step.id} failed: $e');
        yield event.copyWith(
          status: ProvisioningStatus.failed,
          message: e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Step definitions
  // ---------------------------------------------------------------------------

  List<_Step> _buildSteps({
    required String schoolId,
    required String createdByUid,
  }) {
    final schoolRef =
        _firestore.collection(AppConstants.schoolsCollection).doc(schoolId);

    DocumentReference<Map<String, dynamic>> settingsDoc(String id) =>
        schoolRef.collection(AppConstants.settingsCollection).doc(id);

    final now = FieldValue.serverTimestamp();
    final seededBy = {
      'seededBy': createdByUid,
      'seededAt': now,
    };

    Future<bool> _docExists(DocumentReference ref) async {
      final snap = await ref.get();
      return snap.exists;
    }

    return [
      // ----- School settings ------------------------------------------------
      _Step(
        id: 'settings.config',
        title: 'Initialize school settings',
        exists: () => _docExists(settingsDoc('config')),
        apply: () => settingsDoc('config').set({
          'schoolId': schoolId,
          'locale': 'en_IN',
          'timezone': 'Asia/Kolkata',
          'currency': 'INR',
          'weekStartsOn': 'Monday',
          'features': {
            'leaves': true,
            'payroll': true,
            'attendance': true,
            'fees': true,
            'notifications': true,
          },
          ...seededBy,
        }),
      ),

      // ----- Academic year --------------------------------------------------
      _Step(
        id: 'settings.academicYear',
        title: 'Set up default academic year',
        exists: () => _docExists(settingsDoc('academicYear')),
        apply: () {
          final now = DateTime.now();
          final startYear = now.month >= 6 ? now.year : now.year - 1;
          final endYear = startYear + 1;
          return settingsDoc('academicYear').set({
            'current': '$startYear-$endYear',
            'startDate': DateTime(startYear, 6, 1).millisecondsSinceEpoch,
            'endDate': DateTime(endYear, 5, 31).millisecondsSinceEpoch,
            ...seededBy,
          });
        },
      ),

      // ----- Holidays placeholder ------------------------------------------
      _Step(
        id: 'holidays.init',
        title: 'Initialize holiday calendar',
        exists: () => _docExists(settingsDoc('holidays')),
        apply: () => settingsDoc('holidays').set({
          'holidays': <Map<String, dynamic>>[],
          ...seededBy,
        }),
      ),

      // ----- Notifications index doc ---------------------------------------
      _Step(
        id: 'notifications.init',
        title: 'Prepare notifications channel',
        exists: () => _docExists(settingsDoc('notifications')),
        apply: () => settingsDoc('notifications').set({
          'enabled': true,
          'channels': ['in_app'],
          ...seededBy,
        }),
      ),

      // ----- Clean up any legacy placeholder `_meta` docs ------------------
      //
      // An earlier version of this service seeded a `_meta` doc inside every
      // tenant subcollection to make them visible in the Firebase console.
      // That turned out to contaminate unfiltered count queries (e.g. the
      // admin dashboard was reporting "Total Students: 1" for a brand-new
      // school). Firestore collections auto-materialise on first real write,
      // so the placeholders were never actually needed.
      //
      // This step deletes those placeholders if they exist; for fresh
      // tenants there is nothing to clean up and the step reports SKIPPED.
      _Step(
        id: 'subcollections.cleanup',
        title: 'Clean up placeholder documents',
        exists: () async {
          // Sentinel: if the well-known legacy placeholder `bills/_meta`
          // is gone, assume cleanup has already run (or was never needed).
          final ref = schoolRef.collection('bills').doc('_meta');
          final snap = await ref.get();
          return !snap.exists;
        },
        apply: () async {
          const legacySubcollections = <String>[
            'classes', 'students', 'academicYears', 'fiscalYears',
            'admissionProvisioning', 'teachers', 'staff', 'staffRoles',
            'staffEntitlements', 'leaves', 'leaveCancellations',
            'leaveBalances', 'staffLeaveBalances', 'permissions',
            'permissionRequests', 'permissionCancellations',
            'permissionTypes', 'permissionConfig', 'staffPermissionBalances',
            'monthlyPermissionUsage', 'bills', 'fee_structures',
            'feeStructures', 'feeCollections', 'student_fee_details',
            'arrears', 'attendance', 'studentAttendance', 'studentLeaves',
            'salaryStructures', 'payroll', 'holidays', 'notifications',
            'auditLog',
          ];

          final batch = _firestore.batch();
          for (final name in legacySubcollections) {
            final ref = schoolRef.collection(name).doc('_meta');
            // Unconditionally schedule a delete; deleting a non-existent
            // doc is a no-op for Firestore batch writes.
            batch.delete(ref);
          }
          await batch.commit();
        },
      ),

      // ----- Indexes verification (project-wide, idempotent) ---------------
      //
      // Composite indexes are a *project*-level resource, not a per-tenant
      // one. The Firebase client SDK cannot create them — they are deployed
      // once via `firebase deploy --only firestore:indexes` and shared by
      // every school. This step actively tests whether the indexes needed
      // by business queries (`bills`, `leaves`, `permissions`, `holidays`
      // …) are live and reports one of:
      //
      //   SKIPPED  — indexes already verified in a previous provisioning
      //   DONE     — verified right now, all indexes are live
      //   FAILED   — at least one index is missing or still building.
      //              Message includes the Firestore console URL so the
      //              operator can watch index build progress or click the
      //              "Create index" button Firebase surfaces for missing
      //              ones.
      _Step(
        id: 'firestore.indexes',
        title: 'Verify Firestore indexes',
        exists: () async {
          final ok = await FirebaseIndexesVerifier.verifyIndexes();
          return ok;
        },
        apply: () async {
          final ok = await FirebaseIndexesVerifier.verifyIndexes();
          if (!ok) {
            throw Exception(
              'Firestore composite indexes are not fully live yet.\n'
              'They may still be building (can take 1-10 minutes on a fresh '
              "project) or haven't been deployed.\n\n"
              'Check status / deploy at:\n'
              'https://console.firebase.google.com/project/'
              'eazy-school-360/firestore/indexes\n\n'
              'To deploy from your machine:\n'
              '  firebase deploy --only firestore:indexes',
            );
          }
        },
      ),
    ];
  }
}
