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
**Current State (before)**: `super_admin_dashboard_screen.dart` showed hardcoded fake stats; "Add School" was `onTap: () {}`; no path to call `activateSchool`.
**Expected State**: A real "Pending Schools" list with a working Activate action, backed by the already-implemented `SchoolManagementRepository`.
**Problem**: Blocked all new-tenant onboarding — the highest-priority functional gap in the app.
**Implementation**:
- Dashboard home (`_buildDashboardHome`): replaced the hardcoded banner chips and 4 stat cards with `ref.watch(platformStatsProvider)`, handled via `.when(data/loading/error)` — real totals, active/pending school counts, staff/admin breakdown.
- Replaced the fake `_buildRecentSchools`/`_buildSchoolItem` (four hardcoded school names) with a real "Pending School Approvals" section driven by `ref.watch(pendingSchoolsProvider)`, showing up to 5 pending schools with an **Activate** button on each.
- New `_activateSchool(School school)` method: confirmation dialog → `schoolManagementRepositoryProvider.activateSchool(schoolId, session.uid)` → invalidates `platformStatsProvider` to refresh counts → success/error snackbar. `pendingSchoolsProvider` is a `StreamProvider`, so the activated school disappears from the pending list automatically once the Firestore write commits, with no manual refresh needed.
- New `_buildSchoolsManagementTab`: wired to the "Schools" nav item (`_selectedIndex == 1`, both desktop side-nav and mobile bottom-nav), showing the full pending-approval list (not just 5) plus a browsable "All Schools" list via `ref.watch(allSchoolsProvider(false))`.
- "Add School" quick-action button now navigates to the Schools tab instead of doing nothing (`onTap: () {}` → `() => setState(() => _selectedIndex = 1)`). Note: this does not let a super admin *create* a school from scratch — that capability doesn't exist and wasn't part of GAP-001 (new schools are created via the existing self-signup flow, which already works; the gap was specifically that they couldn't be activated afterward).
**Files Changed**: `lib/presentation/dashboard/screens/super_admin_dashboard_screen.dart` (imports added: `package:intl/intl.dart`, `school_management_repository.dart`, `domain/entities/school.dart`).
**Dependencies**: None — backend logic (`SchoolManagementRepository.activateSchool`/`getPendingSchools`/`getAllSchools`/`getPlatformStats`) already existed and required no changes.
**Database Changes**: None.
**Security Impact**: None negative; purely additive UI wiring to existing, already-correct backend logic. `activateSchool`'s own Firestore writes (school doc + admin user docs + membership docs) were not modified.
**Deliberately NOT included in this task** (kept the change scoped to the GAP-001 blocker specifically): a UI for `deactivateSchool` (the "All Schools" list is browse-only, no status badge or deactivate button — the `School` entity's `.status` field was found not to reliably reflect the `isActive` boolean the repository actually queries on, and building a correct status display would have required either a per-row extra Firestore read or a fix to the entity's field mapping, both bigger than this task's scope); the "Global Staff"/"Reports"/"Settings" nav destinations remain "Coming Soon" stubs.
**Testing Required**: No Dart/Flutter toolchain was available in this session to run `flutter analyze`/`flutter test`. Verified instead: brace/paren balance (structural check), a full manual read-through of every changed section against the provider signatures in `school_management_repository.dart` (`platformStatsProvider` is `FutureProvider<PlatformStats>`, `pendingSchoolsProvider`/`allSchoolsProvider(bool)` are `StreamProvider`s returning `List<School>`, `School.schoolName`/`.email`/`.createdAt`/`.schoolId` all confirmed to exist on the entity), and confirmed `package:intl/intl.dart` + `DateFormat.yMMMd()` matches the import pattern already used elsewhere in this codebase. **Not verified**: actual compilation, and the full manual end-to-end flow below.
**Acceptance Criteria**: A newly-signed-up school can be activated through the app with no manual Firestore edit required. **Recommend running this exact manual test before trusting the fix**: sign up a new school → confirm it appears in the Super Admin's Pending Approval list (both the dashboard-home preview and the full Schools tab) → click Activate → confirm the snackbar shows success and the school disappears from the pending list → confirm that school's admin can then log in successfully.
**Status**: **Done, pending compiler and live verification**

### IMPL-08 — GAP-009: Payroll admin UI wiring
**Module**: Finance / Payroll | **Feature**: Admin payroll management entry point
**Current State (before)**: Dashboard nav routed to `_buildComingSoonScreen('Payroll Management')`.
**Expected State**: Routes to the real, already-built `PayrollManagementScreen`.
**Problem**: Entire payroll feature was inert despite correct backend code.
**Implementation**: Added `import '../../admin/screens/payroll_management_screen.dart';` and changed the `payroll_management` nav case from `_buildComingSoonScreen('Payroll Management')` to `const PayrollManagementScreen()`.
**Files Changed**: `lib/presentation/dashboard/screens/admin_dashboard_screen.dart`.
**Dependencies**: None. **Database Changes**: None (existing schema). **Security Impact**: None — screen already has its own access gating.
**Testing Required**: No Dart/Flutter toolchain available this session. Verified: the import path and class name match `payroll_management_screen.dart`'s actual location and its `const PayrollManagementScreen({super.key})` constructor signature; brace/paren structural balance across the whole file. **Not verified**: an actual end-to-end payroll run. **Recommend**: create a salary structure, run payroll for at least one staff member, and confirm a payslip appears in that staff member's `MyPayslipsScreen`, before trusting this in production.
**Acceptance Criteria**: An admin can create a salary structure, run payroll, and the affected staff member sees a payslip. **Not live-verified.**
**Status**: **Done, pending compiler and live verification**

### IMPL-09 — GAP-011: Student promotion UI wiring
**Module**: Academic Year | **Feature**: Student promotion entry point
**Current State (before)**: `StudentPromotionScreen` fully built, but its `student-promotion` nav case routed to `_buildComingSoonScreen('Student Promotion')`, unreferenced.
**Expected State**: Reachable from the admin dashboard.
**Problem**: Year-end promotion could not be performed.
**Implementation**: Added `import '../../admin/screens/student_promotion_screen.dart';` and changed the `student-promotion` nav case to `const StudentPromotionScreen()`.
**Files Changed**: `lib/presentation/dashboard/screens/admin_dashboard_screen.dart`.
**Dependencies**: None. **Database Changes**: None (existing schema).
**Security Impact**: None — screen already has its own access gating.
**Testing Required**: No Dart/Flutter toolchain available. Verified: import path/class name/constructor match; structural balance. **Not verified**: a real promotion run — this is the highest-blast-radius fix in this batch, since `StudentPromotionScreen` mutates every promoted student's class/academic-year fields in bulk with zero automated test coverage of that logic. **Strongly recommend a manual dry-run in a non-production environment** (verify arrears creation and rollback behavior described in `StudentPromotionService`) before running this against real production data.
**Acceptance Criteria**: An admin can promote a class of students to the next academic year, with arrears correctly created for any unpaid balances. **Not live-verified — treat this specific fix as higher-risk than the others in this batch.**
**Status**: **Done (navigation wired), pending compiler verification and a required manual dry-run before production use**

### IMPL-13 — GAP-035: Student leave approval UI wiring (new finding)
**Module**: Leave / Student Portal | **Feature**: Admin approval of parent-initiated student leave requests
**Current State (before)**: `StudentLeaveApprovalScreen`'s nav case routed to `_buildComingSoonScreen('Student Leave Approval')`; the screen itself *also* displayed its own internal "Coming Soon" banner above a fully-built implementation.
**Expected State**: Reachable from the admin dashboard, with no contradictory "Coming Soon" messaging on a screen that actually works.
**Problem**: Admins could not approve/reject student leave requests at all, despite the underlying implementation (tabbed pending/all requests, real Riverpod providers, proper loading/error/empty states) being complete.
**Implementation**: Added `import '../../admin/screens/student_leave_approval_screen.dart';` and changed the `student_leave_approval` nav case to `const StudentLeaveApprovalScreen()`. Separately, removed the internal "Coming Soon" banner `Container` from `student_leave_approval_screen.dart`'s `build()` method (and the now-unnecessary extra `Expanded`/`Container` wrapper it was nested in), since displaying it would have been actively confusing once the screen was reachable through normal navigation.
**Files Changed**: `lib/presentation/dashboard/screens/admin_dashboard_screen.dart`, `lib/presentation/admin/screens/student_leave_approval_screen.dart`.
**Dependencies**: None. **Database Changes**: None. **Security Impact**: None — screen already gated the same way as its siblings (checks `session`/`session.schoolId` at the top of `build()`).
**Testing Required**: No Dart/Flutter toolchain available. Verified: import/class/constructor match; the removed banner block's braces were fully self-contained (confirmed via brace/paren balance on both files) so no structural damage from its removal; `pendingStudentLeavesProvider`/`schoolStudentLeavesProvider` (the providers this screen watches) were not modified. **Not verified**: an actual end-to-end approve/reject flow for a real student leave request.
**Acceptance Criteria**: An admin can view pending student leave requests and approve/reject them from the live app, with no "Coming Soon" messaging.
**Status**: **Done, pending compiler and live verification**

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
**Current State (before)**: Plain max+1 query, collision-prone under concurrency, duplicated identically in both `fee_repository.dart` and `expense_repository.dart` (both point at the same `schools/{schoolId}/bills` collection, confirmed by reading both `_billsCollection` methods).
**Expected State**: Transactional counter, matching the receipt-numbering pattern already proven correct in `term_fee_payment_repository.dart`.
**Problem**: Duplicate bill IDs were possible under concurrent bill creation.
**Implementation**: Rewrote `getNextBillId()` in both repositories identically. Each call: (1) queries the current max `billId` as a seed value — done *outside* the transaction, since Firestore transactions can't run a `.where()`/`.orderBy()` query; (2) opens a transaction that reads `financeSettings/billCounter`, uses the counter's stored value if the doc exists, otherwise falls back to the pre-computed seed; (3) writes `seed_or_counter + 1` back to the counter doc via `transaction.set(..., SetOptions(merge: true))` and returns that value. The seeding step is race-safe despite running outside the transaction: if two calls race on the very first use (when the counter doc doesn't exist yet), Firestore's automatic transaction retry-on-conflict means only one of them actually creates the counter doc — the other's transaction detects the conflict, retries, and on retry sees the counter already exists, incrementing from it instead of re-seeding.
**Files Changed**: `lib/data/repositories/fee_repository.dart`, `lib/data/repositories/expense_repository.dart`. Call sites (`fee_collection_screen.dart`, `expense_entry_screen.dart`) needed no changes — the method's signature and return type (`Future<int>`) are unchanged.
**Dependencies**: None. **Database Changes**: New document `schools/{schoolId}/financeSettings/billCounter` per school, created lazily on first use (additive; confirmed the `financeSettings` collection already has Firestore rules permitting read/write for `isTenantAdmin()`/`isAdmin()`/`isFinance()` roles within their own school, so no rules change was needed).
**Security Impact**: None.
**Testing Required**: No Dart/Flutter toolchain available this session. Verified: brace/paren structural balance on both files; the transaction's `transaction.get()` call happens before its `transaction.set()` call (Firestore's read-before-write requirement); the seed-query and counter-document logic is identical in both repositories, matching the fact that they share one underlying collection and were previously identical buggy implementations; call sites confirmed unchanged (`await repo.getNextBillId(schoolId)` still type-checks against the same signature). **Not verified**: the concurrency test described in `TESTING_STRATEGY.md` item 7 (fire two bill-creation calls near-simultaneously against a real Firestore emulator and confirm no duplicate ID) — recommend running this, along with a check that a school with pre-existing bills gets its counter correctly seeded above its current max rather than restarting at 1, before trusting this fix in production.
**Acceptance Criteria**: No duplicate bill IDs producible under concurrent creation, and existing bills' IDs are never collided with. **Not live-verified.**
**Status**: **Done, pending compiler and live/emulator verification**

### IMPL-12 — GAP-008: Bill deletion / ledger reversion atomicity
**Module**: Finance / Bill Management | **Feature**: `_deleteBill`
**Current State (before)**: Non-atomic delete + ledger reversal; reversal failures silently swallowed, UI reported success regardless.
**Expected State**: Single transaction covering both; any failure surfaces to the admin and nothing is left in a partial state.
**Problem**: Data corruption risk (student balance could silently diverge from reality).
**Implementation**: Rewrote `_deleteBill` entirely around `FirebaseFirestore.instance.runTransaction(...)`. Firestore transactions can only `.get()` a known `DocumentReference`, not run a `.where()` query, so the three lookups that originally used queries to *find* which document to update (`student_fee_details` by `stuId`+`academicYear`; the ad-hoc ledger by `studentId`+`category`) now run first, outside the transaction, resolving to plain `DocumentReference`s (or `null` if nothing matched) — matching Firestore's own recommended pattern for this exact situation. The transaction itself then does all its `transaction.get()` reads first (bill doc not re-read since we don't need its prior value; `student_fee_details` ref, single ledger ref, and each component-fallback ledger ref, all conditionally), then all writes (bill soft-delete, `student_fee_details` update, ledger update(s)) — preserving every original branch (ad-hoc studentFeeItems vs termFeePayments vs expense bills; single-ledger-by-id vs ad-hoc-ledger-by-category vs component-loop fallback) exactly, just restructured into transaction-legal read-then-write order. The outer `catch` no longer swallows: a transaction failure now shows `'Failed to delete bill; nothing was changed: $e'` instead of a false "reverted" success message. Also removed ~15 `print()` debug statements that were interleaved through the original logic (not extra scope — the lines containing them were being rewritten regardless as part of restructuring into the transaction).
**Files Changed**: `lib/presentation/finance/screens/bill_management_screen.dart` (one method, `_deleteBill`, ~290 lines before → ~265 after).
**Dependencies**: None for this fix. GAP-018 (refunds) still isn't designed — deferred, since building a correct atomic reversal here didn't require also designing refunds, and doing both at once would have widened this task's scope.
**Database Changes**: None (existing schema; the transaction reads/writes the same fields the original code did).
**Security Impact**: None directly.
**Testing Required**: No Dart/Flutter toolchain was available in this session. Verified: brace/paren structural balance; a full line-by-line re-read of the new method confirming every original branch and field name is preserved; that `Transaction.get()`/`transaction.update()` calls follow Firestore's read-before-write rule (all `.get()` calls happen before any `.update()` call inside the transaction closure); and that the bare (non-generic) `DocumentReference`/`DocumentSnapshot` typing used throughout matches this file's existing convention (no `.withConverter()` used anywhere else in it either). **Not verified**: actual compilation, and the regression test described in `TESTING_STRATEGY.md` item 6 (force the reversal step to fail mid-transaction and confirm a real Firestore emulator shows full rollback) — recommend writing and running that test before trusting this fix in production, since transaction semantics are exactly the kind of thing that should be verified against a real Firestore instance, not just read by eye.
**Acceptance Criteria**: A forced mid-operation failure leaves neither the bill deleted nor any ledger partially reverted; the admin sees an accurate error. **Not live-verified.**
**Status**: **Done, pending compiler and live/emulator verification**

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
