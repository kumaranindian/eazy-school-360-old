# Eazy School 360 — Implementation Plan

Part of the Production Readiness Audit. See `docs/README.md` for the document index. Ordered by the priority the audit requires: security → data integrity → core business logic → critical workflows → production blockers → reliability → performance → UX → nice-to-have. **Not** ordered by UI navigation convenience.

Per `CLAUDE.md`'s implementation-mode rules: each task is implemented one at a time, only when explicitly requested ("Implement the next task" or naming a Task ID), with the smallest safe change, and every completed task updates `FEATURE_READINESS_MATRIX.md`, `PRODUCTION_GAP_REGISTER.md`, this file, and `CHANGELOG.md`.

Six tasks below (IMPL-01 through IMPL-06) are already **Done** — they were fixed during the audit session itself, before this formal plan existed, because they were unambiguous, narrowly-scoped security fixes with no risk of touching unrelated functionality. They're recorded here for completeness and traceability, not as something to redo.

---

## Completed this session (security fixes, done before this plan was formalized)

### IMPL-01
**Module**: RFID Attendance | **Feature**: Device registration
**Current State (before)**: `/register-device` required no authentication at all.
**Expected State**: Requires a Firebase ID token from an admin of the target school (or a super admin).
**Problem**: Full authentication bypass — anyone could self-register a device and receive a valid, permanent device key.
**Implementation**: New middleware `functions/src/rfid-attendance/middleware/adminAuth.js`; wired into the `/register-device` route.
**Files Changed**: `functions/src/rfid-attendance/index.js`, `functions/src/rfid-attendance/middleware/adminAuth.js` (new).
**Dependencies**: None. **Database Changes**: None. **Security Impact**: Closes GAP-002.
**Testing Required**: Manual verification that the route rejects missing/invalid tokens and wrong-school admins (done via code trace of the new middleware and its callers; no automated test written — see TESTING_STRATEGY.md item 4 for the test that should exist).
**Acceptance Criteria**: Met — endpoint now requires valid admin auth scoped to the target school.
**Status**: **Done**

### IMPL-02
**Module**: Backend / Cloud Functions | **Feature**: `standardizeAcademicYears`, `updateAllStudentPhoneNumbers`
**Current State (before)**: Authentication checks fully commented out on both.
**Expected State**: Both enforce admin auth scoped to the target school.
**Problem**: Unauthenticated bulk data mutation, live in production.
**Implementation**: Re-implemented the auth checks (Bearer-token verification for the `onRequest` function, `context.auth` + role/school check for the callable).
**Files Changed**: `functions/src/data-cleanup.js`, `functions/src/student-phone-update.js`.
**Dependencies**: None. **Database Changes**: None. **Security Impact**: Closes GAP-003.
**Testing Required**: Same caveat as IMPL-01 — traced, not automated-tested.
**Acceptance Criteria**: Met.
**Status**: **Done**

### IMPL-03
**Module**: Backend / Auth | **Feature**: `setUserClaims`
**Current State (before)**: Any authenticated user could set any uid's custom claims to a client-supplied object.
**Expected State**: SUPER_ADMIN-only; claims re-derived server-side from the target user's own document.
**Problem**: Direct privilege-escalation path.
**Implementation**: Added a SUPER_ADMIN role check on the caller; replaced the client-trusted `claims` parameter with server-side derivation via the existing `roleToClaimFlags` helper.
**Files Changed**: `functions/index.js`.
**Dependencies**: None. **Database Changes**: None. **Security Impact**: Closes GAP-004.
**Testing Required**: Confirmed via trace that no Flutter code calls this function today, so nothing legitimate could break; no automated test exists.
**Acceptance Criteria**: Met.
**Status**: **Done**

### IMPL-04
**Module**: Backend / Cloud Functions | **Feature**: Cross-tenant scoping on 9 functions
**Current State (before)**: `approveLeave`/`rejectLeave`/`approvePermission`/`rejectPermission`/`adjustLeaveBalance`/`adjustPermissionBalance`/`mapRfidToStaff`/`listRfidCards`/`unmapRfidCard` checked role but not school match.
**Expected State**: All 9 verify the caller's own `schoolId` matches the target `schoolId` (SUPER_ADMIN exempted).
**Problem**: Cross-tenant admin action was possible.
**Implementation**: Shared `assertAdminSchoolAccess(userData, schoolId)` helper, called after the existing role check in each function.
**Files Changed**: `functions/src/leave-permission-management.js`, `functions/src/student-phone-update.js`.
**Dependencies**: None. **Database Changes**: None. **Security Impact**: Closes GAP-005 for the 9 functions found; does not guarantee no other function has the same gap.
**Testing Required**: Traced Flutter callers to confirm the fix doesn't break legitimate same-school usage (confirmed for RFID admin calls via `widget.schoolId`; the leave/permission callables were found to have no live Flutter caller at all — see IMPL-06 note).
**Acceptance Criteria**: Met for the 9 functions found.
**Status**: **Done**

### IMPL-05
**Module**: Backend / Data Integrity | **Feature**: Leave/permission trigger idempotency
**Current State (before)**: `onLeaveStatusChange`/`onPermissionStatusChange` had no guard against Cloud Functions retry delivery.
**Expected State**: A retried trigger invocation is a no-op.
**Problem**: Retry could double-apply a balance mutation.
**Implementation**: Ported the `processedAt`-guard pattern from the unused `atomic-leave-approval.js`/`atomic-permission-approval.js` into the live triggers, set inside the same transaction as the balance write, with an additional in-transaction re-check for concurrent invocations.
**Files Changed**: `functions/src/leave-management.js`.
**Dependencies**: None. **Database Changes**: New `processedAt` field on leave/permission documents (additive, no migration needed for existing docs). **Security Impact**: Closes GAP-012 (data integrity, not strictly a security issue).
**Testing Required**: No automated test exists yet — see TESTING_STRATEGY.md item 2 for the test that should be written to guard this fix long-term.
**Acceptance Criteria**: Met — logic traced and confirmed correct; not exercised against a live retry scenario (would require a Firestore emulator + forced retry, out of scope for this session's tooling).
**Status**: **Done**

### IMPL-06
**Module**: Auth / Frontend | **Feature**: Password/credential logging
**Current State (before)**: Raw and generated passwords printed to console on login and staff-account creation; `getSchoolStaff` ran unawaited debug writes (including a live `test-doc` write/delete) on every call.
**Expected State**: No credential logging; no debug side-effects in the staff-list read path.
**Problem**: Credential leakage into logs; unintended data mutation as a side effect of a read.
**Implementation**: Removed the offending `print()` calls and the entire debug-probing block from `getSchoolStaff`.
**Files Changed**: `lib/core/providers/auth_provider.dart`, `lib/data/repositories/staff_management_repository.dart`, `lib/data/repositories/teacher_repository.dart`.
**Dependencies**: None. **Database Changes**: None (removes an unwanted write, doesn't add one). **Security Impact**: Closes GAP-013.
**Testing Required**: No Dart toolchain available in the audit environment to run `flutter analyze`/`flutter test` — changes were reviewed by hand for syntactic correctness. **Recommend running `flutter analyze` and `flutter test` before the next deploy**, since this is the one class of change in this plan that hasn't been tool-verified.
**Acceptance Criteria**: Met per code review; not compiler-verified.
**Status**: **Done, pending compiler verification**

---

## Next Up (not yet implemented — ordered by priority)

### IMPL-07 — GAP-001: Super Admin tenant activation
**Module**: Core / Super Admin | **Feature**: School activation after self-signup
**Current State**: `super_admin_dashboard_screen.dart` shows hardcoded fake stats; "Add School" is `onTap: () {}`; no path to call `activateSchool`.
**Expected State**: A real "Pending Schools" list with working Activate/Deactivate actions, backed by the already-implemented `SchoolManagementRepository`.
**Problem**: Blocks all new-tenant onboarding — the highest-priority functional gap in the app.
**Implementation**: Replace the dashboard's hardcoded data with live providers (`pendingSchoolsProvider`, `platformStatsProvider`, already implemented and unused); build/wire a minimal "Schools" management screen calling `activateSchool`/`deactivateSchool`.
**Files Expected To Change**: `lib/presentation/dashboard/screens/super_admin_dashboard_screen.dart`, possibly a new `lib/presentation/admin/screens/school_management_screen.dart` (or similar) if one doesn't already exist in usable form.
**Dependencies**: None — backend logic already exists.
**Database Changes**: None.
**Security Impact**: None negative; this is purely additive UI wiring to existing, already-correct backend logic.
**Testing Required**: Manual end-to-end test: sign up a new school, confirm it appears in the pending list, activate it, confirm the school's admin can then log in successfully.
**Acceptance Criteria**: A newly-signed-up school can be activated through the app with no manual Firestore edit required.
**Status**: **Not started**

### IMPL-08 — GAP-009: Payroll admin UI wiring
**Module**: Finance / Payroll | **Feature**: Admin payroll management entry point
**Current State**: Dashboard nav routes to `_buildComingSoonScreen('Payroll Management')`.
**Expected State**: Routes to the real, already-built `PayrollManagementScreen`.
**Problem**: Entire payroll feature is inert despite correct backend code.
**Implementation**: One-line navigation change; then a full manual test of salary-structure entry → payroll run → payslip generation, since this path has never been exercised in production.
**Files Expected To Change**: `lib/presentation/dashboard/screens/admin_dashboard_screen.dart`.
**Dependencies**: None. **Database Changes**: None (existing schema). **Security Impact**: None — screen already has its own access gating.
**Testing Required**: Manual end-to-end payroll run for at least one staff member, confirming a payslip is generated and visible to that staff member's `MyPayslipsScreen`.
**Acceptance Criteria**: An admin can create a salary structure, run payroll, and the affected staff member sees a payslip.
**Status**: **Not started**

### IMPL-09 — GAP-011: Student promotion UI wiring
**Module**: Academic Year | **Feature**: Student promotion entry point
**Current State**: `StudentPromotionScreen` fully built, unreferenced.
**Expected State**: Reachable from the admin dashboard or `AcademicYearManagementScreen`.
**Problem**: Year-end promotion cannot be performed.
**Implementation**: Add a navigation entry point; then a careful manual dry-run given zero automated test coverage of the promotion logic (which mutates every promoted student's class/academic-year fields in bulk — higher blast radius than IMPL-08 if something's wrong).
**Files Expected To Change**: `lib/presentation/dashboard/screens/admin_dashboard_screen.dart` or `lib/presentation/admin/screens/academic_year_management_screen.dart`.
**Dependencies**: None. **Database Changes**: None (existing schema); recommend testing against a dev/test environment first given the bulk-mutation nature of promotion.
**Security Impact**: None — screen already has its own access gating.
**Testing Required**: Manual dry-run in a non-production environment, verifying arrears creation and rollback behavior described in the repository's own logic before trusting it against production data.
**Acceptance Criteria**: An admin can promote a class of students to the next academic year, with arrears correctly created for any unpaid balances.
**Status**: **Not started**

### IMPL-10 — GAP-006: Storage rules cross-tenant scoping
**Module**: Security / Storage | **Feature**: `teacher_documents`, `leave_attachments` rules
**Current State (before)**: Both readable (and `leave_attachments` writable) by any authenticated user regardless of school.
**Expected State**: Both scoped by `belongsToSchool(schoolId)`.
**Problem**: Cross-tenant file exposure/write access.
**Implementation**: `teacher_documents` read now requires `isSuperAdmin() || belongsToSchool(schoolId) || request.auth.uid == teacherId` (the self-access fallback avoids depending on the schoolId claim being populated, addressing the exact concern the original relaxation comment raised). `leave_attachments` read and write now both require `isSuperAdmin() || belongsToSchool(schoolId)`, matching `firestore.rules`'s own scoping of the `leaves` collection. Neither `write` rule for `teacher_documents` needed a change — it was already correctly self-scoped.
**Files Changed**: `storage.rules`.
**Dependencies**: None encountered — see Testing note below on what remains unverified.
**Database Changes**: None (Storage, not Firestore). **Security Impact**: Closes GAP-006.
**Testing Required**: No Firebase project credentials or emulator were available in this session to run `firebase deploy --only storage` or exercise the rules against real auth tokens. Verified: brace/paren balance (structural sanity check), and that the new logic mirrors the already-correct `payslips` rule and the Firestore `leaves` collection's scoping. **Not verified**: an actual staff member with only self-access (no populated schoolId claim) can still read their own leave attachments in a live environment — this was the specific risk the original "relaxed" comment flagged, and the self-access `uid == teacherId` fallback on `teacher_documents` addresses it for that path, but `leave_attachments` has no equivalent self-access fallback (it relies on `belongsToSchool` alone). **Recommend deploying to a non-production Firebase project first and manually testing**: (1) a staff member uploading/viewing their own leave attachment, (2) an admin viewing a staff member's attachment in the same school, (3) any user from a different school being rejected on both paths.
**Acceptance Criteria**: Cross-tenant read/write blocked (verified by rule logic); same-school legitimate access unaffected (NOT live-verified — see above).
**Status**: **Done, pending live/deployed verification**

### IMPL-11 — GAP-014: Bill/Invoice numbering atomicity
**Module**: Finance / Bill Management | **Feature**: `getNextBillId()`
**Current State**: Plain max+1 query, collision-prone under concurrency.
**Expected State**: Transactional counter, matching the receipt-numbering pattern already proven correct elsewhere in the same codebase.
**Problem**: Duplicate bill IDs possible.
**Implementation**: Rewrite `getNextBillId()` (and the expense equivalent) to use a Firestore transaction against a counter document, following `term_fee_payment_repository.dart`'s existing pattern as the template.
**Files Expected To Change**: `lib/data/repositories/fee_repository.dart`, `lib/data/repositories/expense_repository.dart`.
**Dependencies**: None. **Database Changes**: New counter document(s) per school (additive).
**Security Impact**: None.
**Testing Required**: A concurrency test (fire two bill-creation calls near-simultaneously in a test environment) confirming no duplicate ID — this is exactly the test described in TESTING_STRATEGY.md item 7.
**Acceptance Criteria**: No duplicate bill IDs producible under concurrent creation, verified by test.
**Status**: **Not started**

### IMPL-12 — GAP-008: Bill deletion / ledger reversion atomicity
**Module**: Finance / Bill Management | **Feature**: `_deleteBill`
**Current State**: Non-atomic delete + ledger reversal; reversal failures silently swallowed, UI reports success regardless.
**Expected State**: Single transaction covering both; any failure surfaces to the admin and nothing is left in a partial state.
**Problem**: Data corruption risk (student balance can silently diverge from reality).
**Implementation**: Wrap the bill-delete and ledger-reversal writes in one `runTransaction` call; replace the swallowed `catch` with a surfaced error (rethrow or explicit failure UI state).
**Files Expected To Change**: `lib/presentation/finance/screens/bill_management_screen.dart`.
**Dependencies**: Should be designed together with GAP-018 (refunds), since both touch the same ledger-reversal logic — worth planning as one piece of work rather than two separate passes over the same code.
**Database Changes**: None (existing schema).
**Security Impact**: None directly, though data-integrity bugs of this kind can look like security bugs to an affected school.
**Testing Required**: The regression test described in TESTING_STRATEGY.md item 6 (force the reversal step to fail, assert full rollback) — write this test *before* the fix, confirm it fails against current code, then confirm it passes after.
**Acceptance Criteria**: A forced mid-operation failure leaves neither the bill deleted nor the ledger partially reverted; the admin sees an accurate error.
**Status**: **Not started**

---

## Backlog (P2/P3 — not detailed as full task cards; see `PRODUCTION_GAP_REGISTER.md` for the source finding on each)

Ordered roughly by the same priority logic, within their tier:

- GAP-015 (wire or retire `backend-authorization.js`) and GAP-016 (independent per-screen access gates) — both are larger architectural decisions, not quick tasks; recommend a dedicated design discussion before scoping either as an implementation task.
- GAP-017 (late fee calculation) and GAP-027 (percentage-based concessions) — depend on the GAP-007 fee-system-consolidation decision; sequence after that.
- GAP-007 itself (consolidate the two fee-structure systems) — the largest single piece of work in this register; needs its own dedicated planning pass (data migration strategy, screen-by-screen cutover plan) rather than a single task card.
- GAP-018 (refunds), GAP-019 (parent-initiated payment), GAP-010 (Razorpay) — a natural sequence: build Razorpay first, then parent payment UI, then refunds can cover both gateway and manual-payment reversal.
- GAP-020 (reconciliation) — sequence after GAP-010, since gateway vs. manual reconciliation needs differ.
- GAP-021/GAP-022 (pagination), GAP-023 (RFID rate limiting), GAP-024 (Windows-only build script), GAP-025 (node_modules in git), GAP-031 (crash reporting), GAP-032 (logging cleanup), GAP-033 (eslint config) — all independent, low-risk, can be picked up individually in any order as capacity allows.
- GAP-026 (staff-creation pattern consistency), GAP-028/GAP-029 (remaining scoping gaps), GAP-030 (dead code cleanup) — lowest urgency, good candidates for a cleanup sprint.
- GAP-034 (committed credential files) — flagged for your decision on credential rotation and whether to rewrite git history; not something to action unilaterally as an "implementation task."

## Testing Backlog

See `docs/TESTING_STRATEGY.md`'s full priority list — items 1–4 there (Firestore security-rules tests, idempotency test, cross-tenant authorization tests, RFID auth test) should ideally be written **before or alongside** IMPL-07 through IMPL-12 above, so each fix ships with a regression guard rather than relying on manual re-verification every time.
