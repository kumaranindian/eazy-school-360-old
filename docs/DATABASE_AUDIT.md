# Eazy School 360 — Database Audit

Part of the Production Readiness Audit. See `docs/README.md` for the document index.

## Collection Structure

`firebase/firestore.rules` (the deployed copy — see `CLAUDE.md`) defines rules for **75 distinct collection/subcollection paths**. The dominant pattern is per-tenant nesting under `schools/{schoolId}/...`, which structurally prevents cross-tenant access regardless of query correctness — this is the right default and is used for the large majority of collections: `students`, `staff`, `teachers` (partially — see Tenant Isolation below), `leaves`, `permissions`, `leaveBalances`, `payroll`, `attendance` (three separate `attendance` subcollections exist under different parents — staff, student, and RFID device — verify call sites don't cross them), `fee_structures`, `feeStructuresV2`, `studentFeeLedgers`, `termFeePayments`, `bills`, `payment_transactions`, `communicationLogs`, `academicYears`, `fiscalYears`, `arrears`, and many more.

Two collections are flat top-level (not nested under `schools/{schoolId}`), scoped only by a `schoolId` field instead of the document path:
- `leave_types` (top level, referenced from `lib/data/repositories/leave_type_repository.dart`)
- `teachers` (top level, in addition to/instead of the `schools/{schoolId}/teachers` subcollection referenced in the rules list above — **this suggests the app may write teacher data to two different locations depending on code path; UNKNOWN — REQUIRES VERIFICATION** whether `teachers` top-level and `schools/{schoolId}/teachers` are both actually written to, or if one is legacy)

Rule paths also exist for two features that were found to have zero working implementation: `settings/razorpay` (Razorpay has no Cloud Function or UI wiring at all) and `settings/upi` (the UPI settings screen exists but is unreferenced dead code). These rules are not harmful, but they're evidence the schema was designed ahead of features that were never finished.

## Relationships

Core entity graph (informal, derived from repository code, not a formal ERD):
```
schools/{schoolId}
  ├── students/{studentId}          (parentName as a field, not a separate parent entity/collection)
  ├── staff/{staffId}, teachers/{teacherId}   (see note above on possible duplication)
  ├── leaves/{leaveId}, permissions/{permissionId}  → leaveBalances, monthlyPermissionUsage (backend-only writes)
  ├── fee_structures/{id} (legacy) AND feeStructuresV2/{id} (new) — two parallel systems, both live
  ├── studentFeeItems, adHocFeeAssignments, studentFeeLedgers, termFeePayments, bills
  ├── payment_transactions  (schema exists for Razorpay/cash/UPI, but no gateway populates it beyond manual cash/UPI entry)
  ├── academicYears, fiscalYears, arrears
  └── devices, rfid_cards  (RFID hardware subsystem)
users/{uid}                          (top-level, one per Firebase Auth account, holds role/schoolId/isActive)
```

Referential integrity is enforced only by application code (repository methods look up related docs before writing), not by any database-level constraint — normal for Firestore, but means every repository method that skips a validation check is a potential orphaned-reference risk. Not exhaustively audited per-repository in this pass.

## Required Fields / Audit Fields

Spot-checked 5 representative entities:

| Entity | `schoolId` | `createdAt` | `updatedAt` | `createdBy`/`updatedBy` | `status` |
|---|---|---|---|---|---|
| `Student` (`domain/entities/student.dart`) | Yes | UNKNOWN — REQUIRES VERIFICATION | Yes (set on update) | UNKNOWN — REQUIRES VERIFICATION | Yes (`StudentStatus` enum, used for soft delete) |
| `StaffProfile` | Yes (implicit via subcollection path) | UNKNOWN — REQUIRES VERIFICATION | UNKNOWN — REQUIRES VERIFICATION | UNKNOWN — REQUIRES VERIFICATION | UNKNOWN — REQUIRES VERIFICATION |
| `FeePayment` / `TermFeePayment` | Yes | Yes (transactional writes use `serverTimestamp()`) | N/A (payments are typically immutable once recorded) | Recorded (`approvedBy`/similar pattern seen elsewhere) | Has `PaymentMode` but no separate payment-status field found |
| `LeaveApplication` | Yes | Yes | Yes (`updatedAt` set on every status transition, confirmed in `leave-management.js`) | Yes (`approvedBy`/`rejectedBy`) | Yes (`status` enum, actively used) |
| `Expense` | Yes | UNKNOWN — REQUIRES VERIFICATION | UNKNOWN — REQUIRES VERIFICATION | UNKNOWN — REQUIRES VERIFICATION | UNKNOWN — REQUIRES VERIFICATION |

**This table is not exhaustive** — a full per-entity audit-field sweep across all 36 domain entities was not performed in this pass; the "UNKNOWN" cells above should be treated as a to-do for whoever picks up the Student/Staff/Expense modules next, not as confirmed gaps.

## Indexes

`firebase/firestore.indexes.json` defines **134 composite indexes**. This is a large number, consistent with an app that has many multi-field `.where().where()`/`.where().orderBy()` query chains across 31 repositories. A full cross-check of every repository query against the index file was not performed in this pass (that would require running the app against each query path and watching for Firestore's "missing index" runtime errors, which needs a live environment this audit doesn't have). **Recommend**: before production launch, exercise every screen's list/filter/search query at least once against a populated dev environment and watch the Cloud Functions/Flutter console for "The query requires an index" errors — this is the only reliable way to confirm index coverage without a live Firestore connection.

## Query Patterns — Scalability Concerns

- **`StaffManagementRepository.getSchoolStaff`**: `.limit(10000)` on the staff list stream (already flagged in the original security/bug review; not a security issue but a performance one — every staff-list screen load fetches up to 10,000 documents in one listener).
- **`StudentRepository`**: the main student list/search `.snapshots()` streams (`student_repository.dart:46,64`) have **no `.limit()` at all** — every open of the student directory fetches the entire school's student roster unbounded. For a school with a few hundred students this is fine; for a multi-branch or large school (thousands of students), this is a real cost and latency risk, and there is no pagination UI to mitigate it.
- **`StudentRepository.getClasses`**: computes the distinct list of class names by fetching **every active student** and deriving the set client-side, rather than maintaining a small `classes` reference collection — an N-read operation for what should be a handful of lookups. (Note: a genuine `classes/{classId}` collection does exist per the Firestore rules list — **UNKNOWN — REQUIRES VERIFICATION** whether it's actually populated and used elsewhere, or whether this inefficient student-scan pattern is the only place class names are derived from.)

## Tenant Isolation (database-structural view)

See `docs/SECURITY_AUDIT.md` for the full security-classification treatment. Structural summary: the `schools/{schoolId}/...` nesting pattern covers the large majority of collections and is the right default. The two flat top-level collections (`leave_types`, `teachers`) and the two Cloud Storage paths with missing school-scoping (`teacher_documents`, `leave_attachments` — see `SECURITY_AUDIT.md`'s Storage Rules section) are the confirmed exceptions.

## Data Lifecycle / Soft Deletion

Mixed pattern across repositories — not standardized:
- **Soft delete via status flag**: `Student` (`deleteStudent` sets `status: INACTIVE`, confirmed by direct code read), bills (`isDeleted`/`isBillDeleted` boolean flags plus a `deletionReason` field, per the Invoice/Receipt audit finding).
- **Hard delete**: not exhaustively confirmed for other entities in this pass — **UNKNOWN — REQUIRES VERIFICATION** for Staff, Teacher, and Fee-structure deletion specifically; recommend checking before assuming any entity is hard-deleted or soft-deleted.
- No entity was found with a formal `deletedAt`/`deletedBy` audit pair — soft-deleted records (e.g. an inactive student) don't record *when* or *by whom* they were deactivated, only that they are.

## Historical Records

- `auditLog`/`securityAuditLogs`/`balanceMutations` collections exist in the rules file, providing a structural place for historical/audit records. `balanceMutations` is actively written to by the leave/permission Cloud Function triggers (confirmed in the security-fix work this session). `securityAuditLogs` would be written to by `backend-authorization.js`'s `logSecurityViolation` method — but since that class is never called (see `SECURITY_AUDIT.md`), this collection is currently **not populated by anything**, despite existing in the rules.
- `arrears` provides a structural mechanism for carrying forward unpaid fees across academic years (part of the academic-year/promotion feature).

## Scalability Risks Summary

1. Unbounded student-list queries (no pagination) — see Query Patterns above.
2. `getSchoolStaff`'s `.limit(10000)` is a band-aid, not a real pagination strategy.
3. 134 composite indexes is a lot to keep in sync by hand across 4 Firebase environments (dev/test/uat/prod) via the custom `firebase/deploy-indexes.js` script — any index added to code without a corresponding entry in `firestore.indexes.json`, or deployed to one environment but not another, would surface as a silent runtime failure in whichever environment is missing it.
4. Two parallel fee-structure systems roughly double the number of fee-related documents/queries per school compared to a single consolidated system, with no indication either will be retired soon.
