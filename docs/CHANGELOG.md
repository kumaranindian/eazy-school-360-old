# Eazy School 360 — Changelog

Part of the Production Readiness Audit. Tracks changes made as part of the audit/implementation workflow described in `docs/README.md`. Ordinary feature-development commits outside this workflow are tracked in git history, not duplicated here.

## Implementation session (P0 blockers, following the audit)

- **IMPL-10 (GAP-006) — Done, pending live verification**: Fixed cross-tenant scoping gaps in `storage.rules` for `teacher_documents` (was readable by any authenticated user from any school; now scoped to same-school members, super admin, or the teacher themself) and `leave_attachments` (was readable AND writable by any authenticated user from any school; now scoped to same-school members or super admin, matching `firestore.rules`'s existing `leaves` collection scoping). **Not deployed or live-tested** — no Firebase project credentials/emulator available in this session; verified by structural check and pattern-matching against the already-correct `payslips` rule and the Firestore `leaves` rule. See `docs/IMPLEMENTATION_PLAN.md` IMPL-10 for the specific manual tests recommended before this is trusted in production.

## Audit session (previous session)

### Security fixes (see `docs/IMPLEMENTATION_PLAN.md` IMPL-01 through IMPL-06 for full detail)

- **Fixed**: RFID device registration (`/register-device`) had no authentication; now requires an admin's Firebase ID token scoped to the target school. (`functions/src/rfid-attendance/index.js`, new `middleware/adminAuth.js`)
- **Fixed**: Device keys were stored/compared in plaintext; now stored as a SHA-256 hash, compared with `crypto.timingSafeEqual`. (`functions/src/rfid-attendance/controllers/deviceController.js`, `middleware/deviceAuth.js`)
- **Fixed**: `standardizeAcademicYears` and `updateAllStudentPhoneNumbers` shipped with authentication commented out; both re-enforce admin auth scoped to the target school. (`functions/src/data-cleanup.js`, `functions/src/student-phone-update.js`)
- **Fixed**: `setUserClaims` allowed any authenticated user to set any uid's custom claims to a client-supplied object; now SUPER_ADMIN-only, claims re-derived server-side. (`functions/index.js`)
- **Fixed**: Missing cross-tenant `schoolId` verification in `approveLeave`/`rejectLeave`/`approvePermission`/`rejectPermission`/`adjustLeaveBalance`/`adjustPermissionBalance`/`mapRfidToStaff`/`listRfidCards`/`unmapRfidCard`. (`functions/src/leave-permission-management.js`, `functions/src/student-phone-update.js`)
- **Fixed**: `onLeaveStatusChange`/`onPermissionStatusChange` had no idempotency guard against Cloud Functions retry delivery; added a `processedAt` guard inside the balance-mutation transaction. (`functions/src/leave-management.js`)
- **Fixed**: Raw/generated passwords logged to console on login and staff-account creation; removed. (`lib/core/providers/auth_provider.dart`, `lib/data/repositories/staff_management_repository.dart`, `lib/data/repositories/teacher_repository.dart`)
- **Fixed**: `getSchoolStaff` ran unawaited debug probing and wrote/deleted a live `test-doc` on every call; removed entirely. (`lib/data/repositories/staff_management_repository.dart`)
- **Fixed**: Two broken exports (`dailyAttendanceFinalizer`, `revertStudentPhoneNumbers`) referenced non-existent functions; removed. (`functions/index.js`)
- **Fixed**: `previewPhoneNumberUpdate` used `.docs.take(10)`, not a real JS Array method, throwing on every call; changed to `.slice(0, 10)`. (`functions/src/student-phone-update.js`)
- **Documented (not fixed)**: `functions/src/security/backend-authorization.js` marked in-code as not currently called by any deployed function, so it isn't mistaken for active protection.
- **Documented (not fixed)**: `functions/src/leave-management.js`'s unexported `onLeaveCreate` marked as a do-not-export landmine (duplicate balance-reservation logic).
- **Documented (not fixed)**: `lib/data/services/leave_approval_service.dart` / `permission_approval_service.dart` marked as dead code that would double-process balances if ever wired up without also removing the corresponding Cloud Function trigger.

### Audit documentation created

- `docs/PROJECT_ANALYSIS.md`, `docs/SECURITY_AUDIT.md`, `docs/DATABASE_AUDIT.md`, `docs/TESTING_STRATEGY.md`, `docs/END_TO_END_FLOW_AUDIT.md`, `docs/PRODUCTION_CONFIGURATION_AUDIT.md`, `docs/FEATURE_READINESS_MATRIX.md`, `docs/PRODUCTION_GAP_REGISTER.md`, `docs/IMPLEMENTATION_PLAN.md`, `docs/DEPLOYMENT_CHECKLIST.md`, `docs/README.md` — all new, this session.
- `CLAUDE.md` updated with the change-discipline rules from the audit protocol (Step 13).
- `CODEBASE_ANALYSIS.md` (repo root, predates this formal `docs/` structure) — retained as the original narrative-form review; the `docs/` audit above supersedes it as the structured, actionable version but doesn't contradict it.

### New findings surfaced during the audit that were NOT fixed (see `docs/PRODUCTION_GAP_REGISTER.md` for full detail)

- Storage rules (`teacher_documents`, `leave_attachments`) allow cross-tenant read/write — new finding, not covered by the original two review passes (GAP-006).
- Super Admin dashboard is largely non-functional/hardcoded data with no path to activate a new school (GAP-001) — the highest-priority open item.
- Payroll admin screen and Student Promotion screen are fully built but unreachable from live navigation (GAP-009, GAP-011).
- `node_modules/` is committed to git, 44,828 files, un-gitignored (GAP-025).
- Bill/invoice numbering is non-transactional and collision-prone (GAP-014); bill deletion doesn't atomically reverse ledger effects (GAP-008).
- No late-fee calculation despite a complete rule schema (GAP-017); no refunds (GAP-018); no reconciliation feature (GAP-020); no parent-initiated payment (GAP-019); Razorpay has zero backend implementation (GAP-010).

## Format for future entries

Each implementation task completed under the "Implement the next task" workflow should add an entry here referencing its Task ID from `IMPLEMENTATION_PLAN.md`, in the same style as the "Security fixes" section above: what changed, in which files, and a link back to the Gap Register ID it closes.
