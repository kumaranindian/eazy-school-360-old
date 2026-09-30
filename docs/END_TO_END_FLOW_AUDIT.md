# Eazy School 360 — End-to-End Flow Audit

Part of the Production Readiness Audit. See `docs/README.md` for the document index. Each flow below is traced through actual screens/repositories/Cloud Functions read during this audit, not assumed from screen names.

## Entry / Exit (Gate Pass / Parent Pickup)

**Does not exist.** A repo-wide case-insensitive search for "entry", "exit", "pickup", "gatepass", "gate_pass" across `lib/` and `functions/` returned no matches related to a student gate-entry/exit or authorized-pickup feature. Do not confuse this with RFID **attendance** swipe-in/out, which is a different, existing feature (clock-in/out for staff, processed by `functions/src/attendance/attendanceProcessor.ts`) — it records attendance timestamps, not a gate pass or pickup-authorization workflow. If this feature is expected for production, it needs to be designed and built from nothing; there is no partial implementation to extend.

## 1. Student Onboarding: School → Class → Student → Parent → Student Assignment

**Current behavior (traced):**
- School creation happens via self-service signup (`auth_repository.dart`), creating the school doc, admin doc, `users/{uid}`, and membership doc — correctly scoped. The resulting school has `isActive: false`.
- **Blocker**: there is no reachable UI to set `isActive: true` (see `docs/PROJECT_ANALYSIS.md` / `SECURITY_AUDIT.md` — the Super Admin dashboard is largely a mockup with a no-op "Add School" button and no working `activateSchool` call site). A school created today cannot proceed past this point through the app itself.
- Class/section: no dedicated "class management" screen was found; class/section values appear to be free-text/derived fields on the student record itself (`className`, inferred from `StudentRepository.getClasses()` deriving the class list by scanning students, rather than reading from a maintained `classes` reference collection) rather than a managed entity with its own CRUD. A `classes/{classId}` collection does exist in the Firestore rules, but whether it's actually populated/used is **UNKNOWN — REQUIRES VERIFICATION**.
- Student registration: `StudentRepository.createStudent`/`updateStudent`/`deleteStudent` (soft delete via `status`) are implemented and correctly scoped, reachable via `StudentManagementScreen` (finance dashboard) and `StudentDirectoryScreen` (admin dashboard).
- Parent/guardian: stored as fields on the student record (`parentName`, presumably `parentPhone`/`parentEmail` alongside it — not a separate `Parent` entity/collection). No student-onboarding step was found that automatically provisions a parent's login account from these fields.
- Parent account provisioning: **UNKNOWN — REQUIRES VERIFICATION exactly how.** A `ParentDashboardScreen` exists and is reachable from the live login flow (`enhanced_login_screen.dart`, `splash_screen.dart`), confirming parent login as a concept works, but no code path was found in `auth_repository.dart` or `student_repository.dart` that creates a parent's Firebase Auth account or `users/{uid}` document as part of student registration. Whoever picks this up next should trace exactly how a parent first gets credentials before assuming this flow is complete.

**Gaps/bugs found:** the school-activation blocker (P0, see Gap Register); class/section as unmanaged free text rather than a first-class entity (minor, P2/P3); parent-account provisioning mechanism unconfirmed (needs verification before calling this flow complete).

## 2. Fee Setup → Bill/Invoice → Payment → Receipt

**Current behavior (traced):**
- There is no formal "Invoice" entity — the app uses "Bill" (revenue receipts + expense vouchers), generated as on-demand PDFs via `bill_management_screen.dart`, not as a persisted document with a status lifecycle (no draft/issued/paid/cancelled field — only `isDeleted` soft-delete flags).
- Fee structure creation happens through the **v2** system (`assign_fee_structure_screen.dart`, `fee_structure_v2_repository.dart`) — actively developed and used for new assignments.
- **The legacy fee system (`fee_repository.dart`) remains simultaneously live**, read by `student_directory_screen.dart`, `fee_collection_screen.dart`, `upload_sheet_screen.dart`, `student_fee_management_screen.dart`, `student_management_screen.dart`, and the admin dashboard's own summary widgets. A student's fee state can therefore differ depending on which screen an admin happens to open — this is the single biggest data-consistency risk in the fee module, confirmed across two independent audit passes now.
- Bill numbering (`getNextBillId()` in `fee_repository.dart`/`expense_repository.dart`) is a plain max-existing-value+1 query, **not** a Firestore transaction — concurrent bill creation can produce duplicate IDs. Contrast with the **receipt** numbering (`term_fee_payment_repository.dart`), which correctly uses a transactional counter and is collision-safe.
- Payment recording supports cash/UPI/card/cheque/bank-transfer (tracked via a `PaymentMode`/`TermPaymentMode` enum — two parallel enums, mirroring the two parallel fee systems).
- Receipt generation: a branded PDF is produced (`fee_payment_screen.dart` → `PdfBranding`), and the payment record with its receipt number is stored and viewable in the student's ledger history. **No receipt-number search/lookup/verification** exists anywhere (confirmed by a repo-wide grep for a receipt-number query pattern returning nothing) — a receipt can be viewed by browsing a student's history, not by looking it up directly.

**Gaps/bugs found:** two-fee-system inconsistency risk (P0/P1, affects data correctness for every paying family); non-transactional bill numbering (P1, real duplicate-ID risk under concurrent use); no receipt verification/lookup (P2); bill deletion doesn't atomically reverse the ledger and swallows reversion errors while still telling the admin it succeeded (P0/P1 — see Security Audit's Data Integrity section, this affects revenue bills specifically per this pass's confirmation).

## 3. Partial Payment: Bill → Partial Payment → Outstanding Balance → Remaining Payment → Final Receipt

**Current behavior (traced):**
- `multi_allocation_payment_dialog.dart` supports recording an amount less than the full `balanceAmount` against a fee item, and can allocate a single payment across multiple fee categories/terms in one submission (`recordMultiTermPayment`).
- **Advance payment is explicitly blocked by validation** — allocation rows reject any amount greater than the existing `balanceAmount` (`amt > e.balanceAmount + 0.01` is rejected), so a parent cannot pre-pay before a due amount exists in the system. If advance payment is a required capability for production, this is a deliberate gap, not a bug to "fix" quietly — it needs a product decision on whether advance payment should be allowed at all.
- **Refunds do not exist anywhere** — a repo-wide search for "refund" (case-insensitive) across all of `lib/` returned zero matches. There is no code path to reverse or partially reverse a recorded payment other than the non-atomic bill-deletion flow noted above.

**Gaps/bugs found:** advance payment unsupported (needs a product decision — Missing, not Broken); refunds entirely absent (Missing — if required for production, this is new-feature work, not a fix); outstanding-balance recalculation correctness under concurrent partial payments to the same student was not independently stress-tested in this pass (**UNKNOWN — REQUIRES VERIFICATION**, flagged given the non-transactional pattern already found elsewhere in the same file family).

## 4. Attendance: Student → Daily Marking → Monthly Report → Parent Portal

**Current behavior (traced, partial — some detail not independently re-verified this pass due to a research-agent failure; combined with prior-session findings):**
- Staff/teacher attendance has a real, working pipeline: RFID swipe → `processRfidSwipe` (Cloud Function) → daily `staffAttendance` records → a daily finalizer (`combined-daily-jobs.js`) marks absent/leave/permission/holiday and computes loss-of-pay. This pipeline is confirmed live and, as of this session, requires authenticated device registration.
- Student attendance: `student_attendance_screen.dart` (admin) and `student_attendance_repository.dart` exist for daily marking. Whether a **monthly aggregate/report** exists specifically for student attendance (as opposed to staff attendance's daily finalizer) is **UNKNOWN — REQUIRES VERIFICATION** — the only dedicated "report" screen found repo-wide is `financial_reports_screen.dart`; no `student_attendance_report_screen.dart` or equivalent was found, suggesting monthly student-attendance reporting may not exist as a distinct screen, though it's possible monthly data is derivable from the daily records without a dedicated aggregation step. This needs direct verification before being marked complete or missing.
- Parent portal: `student_attendance_view_screen.dart` exists under `lib/presentation/parent/` — whether it reads from the *same* records the admin marks, or a separately-maintained summary, was not independently re-confirmed this pass (**UNKNOWN — REQUIRES VERIFICATION**).

**Gaps/bugs found:** monthly student-attendance reporting existence unconfirmed; parent-portal data-source consistency unconfirmed. Both should be verified directly (open the two screens, read the actual query in each) before the attendance module is marked production-ready in the Feature Readiness Matrix.

## 5. Parent Journey: Login → Student → Fees → Payment → Receipt → Attendance → Notifications

**Current behavior (traced):**
- Login: parents use the same Firebase Auth email/password flow as staff/admin (`enhanced_login_screen.dart`); role-based redirect sends a `PARENT`-role user to `ParentDashboardScreen`. How the parent's account is first created is unconfirmed (see Flow 1 above).
- Student info / attendance / leave history: `lib/presentation/parent/screens/` has `apply_student_leave_screen.dart`, `student_attendance_view_screen.dart`, `student_leave_history_screen.dart` — all appear to be real, non-stub implementations (not independently re-read line-by-line this pass).
- Fees / payment / receipt from the parent's own view: **no dedicated parent-facing fee/payment screen was found** in `lib/presentation/parent/` during this audit's directory scan — fee payment appears to be an admin/finance-side-only action (recorded on behalf of a parent, e.g. cash paid at the school office), not something a parent does themselves in-app. If online self-service payment by parents is a production requirement, this is effectively the same gap as Razorpay not being wired up — there's no payment entry point for a parent to use even once a gateway exists.
- Notifications: in-app notification screen for parents was not found in the `lib/presentation/parent/` directory listing; WhatsApp notifications (fee-due reminders, payment confirmations) are sent server-side to the parent's phone number rather than surfaced in-app.

**Gaps/bugs found:** no parent-initiated payment flow exists at all (Missing — significant, since this is typically a core parent-portal expectation); in-app parent notifications not found (Missing or UNKNOWN — REQUIRES VERIFICATION, a dedicated notifications screen may exist elsewhere and wasn't caught by this pass's directory scan).

## 6. Teacher Journey: Login → Assigned Classes → Students → Attendance → (Entry/Exit N/A)

**Current behavior (traced):**
- `ClassTeacherAssignmentScreen` is reachable from the live admin dashboard, confirming class-teacher assignment (an admin designates which teacher owns which class) exists and is wired in.
- `lib/presentation/staff/` has `class_teacher_leave_screen.dart`, `staff_student_ledger_screen.dart` (a class teacher's view of their own students' fee ledgers), `my_payslips_screen.dart` (reachable, correctly scoped, but see Flow 8 / Payroll below for why it has nothing to display), `staff_profile_screen.dart`.
- A teacher's day-to-day capability appears to center on: viewing their assigned students' fee ledgers, applying for their own leave/permission, and viewing their own payslips (once payroll is fixed). A dedicated "mark student attendance as the class teacher" screen distinct from the admin's `student_attendance_screen.dart` was not confirmed to exist separately — **UNKNOWN — REQUIRES VERIFICATION** whether teachers use the same admin screen (if their role permits) or have no attendance-marking capability of their own.
- Entry/Exit: N/A, confirmed not to exist as a feature at all (see top of this document).

**Gaps/bugs found:** teacher-side student-attendance-marking capability unconfirmed — verify directly before assuming teachers can or cannot mark attendance.

## 7. Finance Journey: Login → Dashboard → Collections → Payment → Receipt → Reconciliation

**Current behavior (traced):**
- A distinct `finance_dashboard_screen.dart` exists (separate from the admin dashboard), and `manage_finance_users_screen.dart` suggests a FINANCE role distinct from ADMIN — the precise permission boundary between the two roles was not independently re-derived in this pass (**UNKNOWN — REQUIRES VERIFICATION**; `docs/SECURITY_AUDIT.md`'s RBAC section notes the same gap).
- Collections/payment recording: the finance dashboard reaches `StudentManagementScreen` and, presumably, the same bill/payment screens used by admin (not independently re-traced this pass).
- **Reconciliation does not exist as a feature.** The only occurrences of the word "reconcile" in the entire `lib/` tree are two UI warning strings in `assign_fee_structure_screen.dart` that tell the *admin* they will need to "reconcile any [paid amounts] manually" when reassigning a fee structure to an already-billed student — i.e., the app explicitly tells the user to do reconciliation themselves outside the system, rather than providing a reconciliation tool or report.

**Gaps/bugs found:** no reconciliation feature exists (Missing — if this is a production requirement, it's new-feature work); FINANCE vs ADMIN role boundary unconfirmed (verify directly, since an under-scoped FINANCE role could either be too permissive or too restrictive without dedicated review).

## Cross-Flow Observations

- The single most consequential cross-cutting finding across every flow above is the **two parallel fee-structure systems** — it surfaces in Flow 1 (student-to-fee assignment), Flow 2 (bill generation), and Flow 3 (partial payment), because which system a given screen reads from determines what data a user sees for the same student.
- The **Super Admin activation blocker** (Flow 1) is a hard stop for any *new* tenant, independent of how well every other flow works — worth treating as the single highest-priority item across the whole audit, ahead of even the security findings, because it blocks the product's basic sales/onboarding motion.
- Several flows (Parent payment, Teacher attendance-marking, Finance reconciliation, monthly student-attendance reporting) turned out to be either **entirely absent** or **unconfirmed** rather than "partially implemented" — this audit could not always distinguish "not built" from "built somewhere this pass didn't look," and those specific items are flagged as UNKNOWN rather than guessed at either way.
