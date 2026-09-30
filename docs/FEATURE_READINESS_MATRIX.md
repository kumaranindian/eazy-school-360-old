# Eazy School 360 — Feature Readiness Matrix

Part of the Production Readiness Audit. See `docs/README.md` for the document index. Every row is backed by a specific finding in `PROJECT_ANALYSIS.md`, `SECURITY_AUDIT.md`, `DATABASE_AUDIT.md`, or `END_TO_END_FLOW_AUDIT.md` — this table is a summary view, not a fresh source of claims.

**Columns**: UI = screen exists and is reachable from the live app · Backend = business logic exists and is correct · DB = Firestore structure/scoping is correct · Validation = input/business-rule validation present · Security = tenant/role scoping verified · Error Handling = failures are surfaced, not swallowed · Tests = automated coverage exists · Prod Ready = Y/N/Partial, per the rule that a feature is not "Ready" just because its happy path works.

Legend: ✅ Yes/Good · ⚠️ Partial/Weak · ❌ No/Missing/Broken · 🚫 N/A (feature doesn't exist) · ❓ Unknown — requires verification

## Core

| ID | Feature | UI | Backend | DB | Validation | Security | Error Handling | Tests | Prod Ready | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| CORE-01 | Authentication (email/password login) | ✅ | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | ❌ | **Partial** | Works; password logging removed this session; startup "security gate" (`FirebaseRulesVerifier`) is still a non-functional stub presented as real. |
| CORE-02 | School setup (self-signup) | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ | ❌ | **Partial** | Provisioning itself (Auth user + school/admin/user/membership docs) is solid. |
| CORE-03 | School activation (post-signup approval) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | **Ready** (pending compiler verification) | Fixed (IMPL-07): Super Admin dashboard now has a real Pending Approval list with a working Activate button. See Gap Register GAP-001. |
| CORE-04 | Branch management | ❓ | ❓ | ❓ | ❓ | ❓ | ❓ | ❌ | **Unknown** | No dedicated multi-branch-per-school feature was found; a "school" appears to be the top-level tenant unit with no sub-branch concept. Not exhaustively searched — mark unknown rather than assume absent. |
| CORE-05 | User management (staff/teacher accounts) | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | ⚠️ | ❌ | **Partial** | CRUD works; `createAdmin()`/`createFinanceAdmin()` and bulk upload still use an older temp-password pattern inconsistent with the newer reset-email pattern. |
| CORE-06 | Role management (assigning ADMIN/STAFF/etc.) | ⚠️ | ⚠️ | ✅ | ⚠️ | ✅ (fixed) | ⚠️ | ❌ | **Partial** | `setUserClaims` privilege-escalation hole fixed this session. Role-string casing inconsistency (`ADMIN`/`admin`/`TENANT_ADMIN`/`tenant_admin`) is a standing maintenance risk. |
| CORE-07 | Permissions (RBAC enforcement) | ⚠️ | ❌ | ✅ | ⚠️ | ⚠️ | ⚠️ | ❌ | **Partial** | Backend `backend-authorization.js` never actually called by any function; only 4 top-level screens have a real access gate; ~60 feature screens have none. |
| CORE-08 | Tenant management (Super Admin: view/manage all schools) | ⚠️ | ✅ | ✅ | 🚫 | ✅ | ✅ | ❌ | **Partial** (activation fixed) | Fixed (IMPL-07): real platform stats, a working Pending Approval + Activate flow, and a browsable All Schools list. Still missing: a UI for `deactivateSchool` (backend exists, not wired to any button), and "Global Staff"/"Reports"/"Settings" tabs remain "Coming Soon" stubs — out of scope for GAP-001, which was specifically about activation. |
| CORE-09 | Settings (school-level) | ✅ | ✅ | ✅ | ⚠️ | ✅ | ❓ | ❌ | **Partial** | `school_settings_screen.dart` works, correctly scoped, but calls Firestore directly rather than through a repository. |

## Student Management

| ID | Feature | UI | Backend | DB | Validation | Security | Error Handling | Tests | Prod Ready | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| STU-01 | Student registration (Create) | ✅ | ✅ | ✅ | ❓ | ✅ | ❓ | ❌ | **Partial** | `createStudent` exists, correctly scoped. Field-level validation depth not exhaustively checked. |
| STU-02 | Student profile (Read/Update) | ✅ | ✅ | ✅ | ❓ | ✅ | ❓ | ❌ | **Partial** | `updateStudent` exists and works. |
| STU-03 | Student delete | ✅ | ✅ | ✅ | 🚫 | ✅ | ❓ | ❌ | **Partial** | Correct soft-delete (`status: INACTIVE`), scoped. Dedicated `DeleteStudentScreen` also reachable. |
| STU-04 | Parent/guardian details on student | ✅ | ✅ | ✅ | ❓ | ✅ | ❓ | ❌ | **Partial** | Stored as fields on the student record, not a separate entity; parent account creation from these fields is unconfirmed (see PAR-01). |
| STU-05 | Class / Section | ⚠️ | ⚠️ | ⚠️ | ❓ | ✅ | ❓ | ❌ | **Partial** | Appears to be free-text/derived fields, not a managed entity with its own CRUD; a `classes` collection exists in rules but its actual use is unconfirmed. |
| STU-06 | Academic year linkage | ✅ | ✅ | ✅ | ❓ | ✅ | ❓ | ❌ | **Partial** | `academicYearCode` field present on the student entity. |
| STU-07 | Student status (active/inactive/etc.) | ✅ | ✅ | ✅ | ✅ | ✅ | ❓ | ❌ | **Ready** | `StudentStatus` enum implemented and enforced via soft-delete. |
| STU-08 | Search | ✅ | ✅ | ⚠️ | ❓ | ✅ | ❓ | ❌ | **Partial** | `searchStudents` exists. |
| STU-09 | Filter / Sort | ❓ | ❓ | ❓ | ❓ | ✅ | ❓ | ❌ | **Unknown** | Not exhaustively verified this pass. |
| STU-10 | Pagination | ❌ | ❌ | ❌ | 🚫 | ✅ | 🚫 | ❌ | **Not Ready** | Main student list `.snapshots()` queries have **no `.limit()`** — unbounded fetch of the entire roster on every open. See Database Audit. |
| STU-11 | Student history | ❓ | ❓ | ❓ | 🚫 | ❓ | ❓ | ❌ | **Unknown** | Not exhaustively verified this pass. |

## Teacher Management

| ID | Feature | UI | Backend | DB | Validation | Security | Error Handling | Tests | Prod Ready | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| TCH-01 | Teacher registration/profile | ✅ | ✅ | ⚠️ | ❓ | ⚠️ | ❓ | ❌ | **Partial** | Works; `teachers` collection may exist both as a flat top-level collection and nested under `schools/{schoolId}` — potential duplication, unconfirmed (see Database Audit). |
| TCH-02 | Teacher single-doc lookup scoping | 🚫 | ❌ | ❌ | 🚫 | ❌ | 🚫 | ❌ | **Not Ready** | `getTeacherById` has no `schoolId` filter in the query itself — relies solely on Firestore rules. Not fixed this session. |
| TCH-03 | Class Teacher assignment | ✅ | ✅ | ✅ | ❓ | ✅ | ❓ | ❌ | **Partial** | `ClassTeacherAssignmentScreen` confirmed reachable from the live admin dashboard. |
| TCH-04 | Teacher attendance | ✅ | ✅ | ✅ | ✅ | ✅ (fixed) | ⚠️ | ❌ | **Partial** | Real RFID-based pipeline; device-registration auth bypass fixed this session; no rate-limiting on attendance marking. |
| TCH-05 | Teacher portal access (own students/ledgers/payslips/leave) | ✅ | ✅ | ✅ | ⚠️ | ✅ | ⚠️ | ❌ | **Partial** | Reachable and correctly scoped; payslips has nothing to display since Payroll admin side is broken (see FIN-06). |

## Fee Management

| ID | Feature | UI | Backend | DB | Validation | Security | Error Handling | Tests | Prod Ready | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| FEE-01 | Fee structure (creation/config) | ✅ | ✅ | ⚠️ | ❓ | ✅ | ❓ | ⚠️ | **Not Ready** | **Two parallel, both-live systems** (legacy + v2) read by different screens for the same student — the single largest data-consistency risk in the app. |
| FEE-02 | Fee categories | ✅ | ✅ | ✅ | ❓ | ✅ | ❓ | ❌ | **Partial** | `fee_category_repository.dart` exists and is used. |
| FEE-03 | Fee schedules / due dates | ✅ | ✅ | ✅ | ❓ | ✅ | ❓ | ❌ | **Partial** | `dueDate` tracked per term/fee item. |
| FEE-04 | Student fee assignment | ✅ | ✅ | ⚠️ | ❓ | ✅ | ❓ | ❌ | **Partial** | Works via v2 (`assign_fee_structure_screen.dart`); inherits the two-system risk from FEE-01. |
| FEE-05 | Discounts / Concessions | ✅ | ⚠️ | ✅ | ❓ | ✅ | ❓ | ❌ | **Partial** | Implemented as a flat currency amount (`totalConcession`), not percentage-based despite category metadata suggesting more granularity was intended. |
| FEE-06 | Late fees | ⚠️ | ❌ | ✅ | 🚫 | ✅ | 🚫 | ❌ | **Broken** | Full `LateFeeRule`/`LateFeeType` schema exists but is **never calculated** — `lateFeeApplied` is only ever carried forward unchanged; no UI to enter it manually either. |
| FEE-07 | Fee calculations (balance/outstanding) | ✅ | ⚠️ | ⚠️ | ⚠️ | ✅ | ⚠️ | ✅ (partial) | **Partial** | 116 unit tests exist for parts of this logic (finance module only); non-transactional bill numbering is a real risk under concurrency. |

## Invoice / Bill Management

| ID | Feature | UI | Backend | DB | Validation | Security | Error Handling | Tests | Prod Ready | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| INV-01 | Invoice/Bill generation | ✅ | ⚠️ | ✅ | ❓ | ✅ | ⚠️ | ⚠️ | **Partial** | No formal "Invoice" entity — "Bill" is generated on-demand as a PDF, no persisted status lifecycle. |
| INV-02 | Invoice/Bill numbering | ✅ | ❌ | ✅ | 🚫 | ✅ | 🚫 | ❌ | **Not Ready** | Plain max+1 query, not a transaction — duplicate IDs possible under concurrent creation. Contrast with receipt numbering (RCP-02), which is done correctly. |
| INV-03 | Invoice/Bill status (draft/issued/paid/cancelled) | ❌ | ❌ | ❌ | 🚫 | 🚫 | 🚫 | ❌ | **Missing** | Only a soft-delete boolean exists; no formal status field/lifecycle. |
| INV-04 | Invoice/Bill cancellation | ✅ | ❌ | ⚠️ | 🚫 | ✅ | ❌ | ⚠️ (test would fail) | **Not Ready** | Deletion and ledger-reversal are non-atomic; reversal failures are silently swallowed while the UI reports success. |
| INV-05 | Invoice/Bill history | ✅ | ✅ | ✅ | 🚫 | ✅ | ❓ | ❌ | **Partial** | Viewable via Bill Management screen, filterable by date range. |
| INV-06 | Invoice/Bill PDF | ✅ | ✅ | 🚫 | 🚫 | 🚫 | ❓ | ❌ | **Partial** | Branded two-copy A5 PDF works; Unicode font loading is a no-op stub, so non-Latin glyphs won't render correctly. |

## Payment Management

| ID | Feature | UI | Backend | DB | Validation | Security | Error Handling | Tests | Prod Ready | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| PAY-01 | Cash payment recording | ✅ | ✅ | ✅ | ✅ | ✅ | ❓ | ✅ (partial) | **Partial** | Works, tracked via `PaymentMode` enum. |
| PAY-02 | UPI payment recording (manual entry) | ✅ | ✅ | ✅ | ✅ | ✅ | ❓ | ✅ (partial) | **Partial** | Recorded as a payment method; distinct from a live UPI *gateway* (see PAY-03). |
| PAY-03 | Online payment (Razorpay gateway) | ❌ | ❌ | 🚫 | 🚫 | 🚫 | 🚫 | ❌ | **Broken / Missing** | **No backend Cloud Function exists at all** for order creation or signature verification — not merely "unwired," genuinely absent. No SDK dependency in `pubspec.yaml`. |
| PAY-04 | Partial payment | ✅ | ✅ | ⚠️ | ✅ | ✅ | ❓ | ❌ | **Partial** | Works via `multi_allocation_payment_dialog.dart`. |
| PAY-05 | Advance payment | ❌ | ❌ | 🚫 | 🚫 | 🚫 | 🚫 | ❌ | **Missing (by design)** | Explicitly blocked by validation (`amt > balanceAmount` rejected) — a product decision needed, not a bug. |
| PAY-06 | Payment allocation (multi-category, single transaction) | ✅ | ✅ | ✅ | ✅ | ✅ | ❓ | ❌ | **Partial** | `recordMultiTermPayment` implemented and used. |
| PAY-07 | Refunds | ❌ | ❌ | 🚫 | 🚫 | 🚫 | 🚫 | ❌ | **Missing** | Zero occurrences of "refund" anywhere in `lib/`. |
| PAY-08 | Payment reconciliation | ❌ | ❌ | 🚫 | 🚫 | 🚫 | 🚫 | ❌ | **Missing** | Only two UI warning strings telling the admin to reconcile manually — no reconciliation tool exists. |

## Receipt Management

| ID | Feature | UI | Backend | DB | Validation | Security | Error Handling | Tests | Prod Ready | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| RCP-01 | Receipt generation | ✅ | ✅ | ✅ | ✅ | ✅ | ❓ | ❌ | **Ready** | Confirmed working end to end. |
| RCP-02 | Receipt numbering | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | **Ready** | Correctly transactional (`receiptCounter` doc in a Firestore transaction), collision-safe — the *correct* pattern the bill-numbering logic should have followed. |
| RCP-03 | Receipt PDF | ✅ | ✅ | 🚫 | 🚫 | 🚫 | ❓ | ❌ | **Partial** | Works; same Unicode-font caveat as bill PDFs. |
| RCP-04 | Receipt history | ✅ | ✅ | ✅ | 🚫 | ✅ | ❓ | ❌ | **Partial** | Viewable in student ledger detail. |
| RCP-05 | Receipt re-print | ⚠️ | ✅ | ✅ | 🚫 | ✅ | ❓ | ❌ | **Partial** | Possible via Bill Management screen only, not from the student ledger/history screen directly. |
| RCP-06 | Receipt verification (lookup by number) | ❌ | ❌ | 🚫 | 🚫 | 🚫 | 🚫 | ❌ | **Missing** | No search-by-receipt-number capability found anywhere. |

## Attendance

| ID | Feature | UI | Backend | DB | Validation | Security | Error Handling | Tests | Prod Ready | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| ATT-01 | Student attendance (daily marking) | ✅ | ✅ | ✅ | ❓ | ✅ | ❓ | ❌ | **Partial** | Screen/repository exist. |
| ATT-02 | Teacher/staff attendance (RFID-based) | ✅ | ✅ | ✅ | ✅ | ✅ (fixed) | ⚠️ | ❌ | **Partial** | Real, working pipeline; registration auth bypass fixed this session; no duplicate-scan throttling. |
| ATT-03 | Daily attendance report | ✅ | ✅ | ✅ | 🚫 | ✅ | ❓ | ❌ | **Partial** | Staff side confirmed via the daily finalizer job. |
| ATT-04 | Monthly attendance report | ❓ | ❓ | ❓ | 🚫 | ❓ | ❓ | ❌ | **Unknown** | No dedicated student-attendance report screen was found; whether monthly aggregation exists is unconfirmed — needs direct verification. |
| ATT-05 | Attendance visible in Parent Portal | ✅ | ❓ | ❓ | 🚫 | ❓ | ❓ | ❌ | **Unknown** | Screen exists (`student_attendance_view_screen.dart`); whether it reads the same records the admin marks is unconfirmed. |

## Entry / Exit

| ID | Feature | UI | Backend | DB | Validation | Security | Error Handling | Tests | Prod Ready | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| ENT-01 | Student entry/exit, parent pickup, gate pass | 🚫 | 🚫 | 🚫 | 🚫 | 🚫 | 🚫 | 🚫 | **Missing — does not exist** | Confirmed via repo-wide search; this is new-feature work if required, not a fix. |

## Parent Portal

| ID | Feature | UI | Backend | DB | Validation | Security | Error Handling | Tests | Prod Ready | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| PAR-01 | Parent account creation | ❓ | ❓ | ❓ | ❓ | ❓ | ❓ | ❌ | **Unknown** | No code path found that provisions a parent's login from a student's parent fields; dashboard/login for parents exists and is reachable, but exactly how a parent first gets credentials is unconfirmed. |
| PAR-02 | Student info / attendance / leave (parent view) | ✅ | ✅ | ❓ | 🚫 | ❓ | ❓ | ❌ | **Partial** | Screens exist and appear non-stub; not line-by-line re-verified this pass. |
| PAR-03 | Fees / payment (parent-initiated) | ❌ | ❌ | 🚫 | 🚫 | 🚫 | 🚫 | ❌ | **Missing** | No parent-facing payment screen found — fee payment is admin/finance-recorded only. |
| PAR-04 | Receipts (parent view) | ❌ | ❌ | 🚫 | 🚫 | 🚫 | 🚫 | ❌ | **Missing** | Consequence of PAR-03 — no in-app receipt view for a parent was found. |
| PAR-05 | In-app notifications (parent) | ❓ | ❓ | ❓ | 🚫 | ❓ | ❓ | ❌ | **Unknown** | Not found in the parent screens directory scan; may exist elsewhere or may rely entirely on WhatsApp. |

## Teacher Portal

(See Teacher Management, TCH-01 through TCH-05, above — this audit treats them as one module rather than duplicating rows.)

## Finance

| ID | Feature | UI | Backend | DB | Validation | Security | Error Handling | Tests | Prod Ready | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| FIN-01 | Finance role / dashboard | ✅ | ⚠️ | ✅ | 🚫 | ❓ | ❓ | ❌ | **Partial** | `finance_dashboard_screen.dart` exists; exact FINANCE-vs-ADMIN permission boundary unconfirmed. |
| FIN-02 | Collections view | ✅ | ✅ | ✅ | 🚫 | ✅ | ❓ | ❌ | **Partial** | Reachable via finance dashboard. |
| FIN-03 | Outstanding fees | ✅ | ✅ | ⚠️ | 🚫 | ✅ | ❓ | ❌ | **Partial** | Inherits the two-fee-system consistency risk. |
| FIN-04 | Revenue tracking | ✅ | ✅ | ⚠️ | 🚫 | ✅ | ❓ | ❌ | **Partial** | Same. |
| FIN-05 | Expenses | ✅ | ✅ | ✅ | ❓ | ✅ | ❓ | ❌ | **Partial** | `expense_repository.dart`/`expense_entry_screen.dart` exist; shares the non-transactional ID-generation pattern with bills. |
| FIN-06 | Payroll | ❌ | ✅ | ✅ | ✅ | ✅ | ❓ | ❌ | **Broken** | Admin nav routes to a "Coming Soon" stub instead of the real, correctly-built `PayrollManagementScreen`. Feature is one navigation wire away from working. |
| FIN-07 | Financial reports | ✅ | ✅ | ✅ | 🚫 | ✅ | ❓ | ✅ (partial, 21 cases) | **Partial** | Only report screen in the app; reachable and has some test coverage. |
| FIN-08 | Reconciliation | ❌ | ❌ | 🚫 | 🚫 | 🚫 | 🚫 | ❌ | **Missing** | Same finding as PAY-08. |

## Admin Dashboard

| ID | Feature | UI | Backend | DB | Validation | Security | Error Handling | Tests | Prod Ready | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| DASH-01 | Admin dashboard KPIs | ✅ | ✅ | ✅ | 🚫 | ✅ | ❓ | ❌ | **Partial** | Live and functional (`presentation/dashboard/`, not the dead `dashboards/` folder). |
| DASH-02 | Super Admin dashboard | ⚠️ | ✅ | ✅ | 🚫 | ✅ | ✅ | ❌ | **Partial** (core blocker fixed) | Fixed (IMPL-07): real platform stats (replacing "156 Schools"/"2,847 Users"/"99.9% Uptime"), working "Add School" button (now jumps to the real Schools tab), and a functional Pending Approval + Activate flow. "Global Staff"/"Reports"/"Settings" nav destinations remain "Coming Soon" — not part of the GAP-001 blocker. |
| DASH-03 | Staff/Parent/Finance dashboards | ✅ | ✅ | ✅ | 🚫 | ✅ | ❓ | ❌ | **Partial** | All confirmed live and reachable. |
| DASH-04 | Dead duplicate dashboard folder | 🚫 | 🚫 | 🚫 | 🚫 | 🚫 | 🚫 | 🚫 | **Dead code, no user impact** | `lib/presentation/dashboards/` (with "s") is unreferenced from the live app — cleanup item, not a functional gap. |

## Notifications

| ID | Feature | UI | Backend | DB | Validation | Security | Error Handling | Tests | Prod Ready | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| NOT-01 | In-app notifications | ❓ | ❓ | ❓ | 🚫 | ❓ | ❓ | ❌ | **Unknown** | Not confirmed to exist as a distinct in-app feed; not exhaustively searched. |
| NOT-02 | Push notifications (FCM) | ❓ | ❓ | 🚫 | 🚫 | ❓ | ❓ | ❌ | **Unknown** | `firebase_messaging` is a dependency; actual topic/token wiring not verified this pass. |
| NOT-03 | Email notifications | ❌ | ❌ | 🚫 | 🚫 | 🚫 | 🚫 | ❌ | **Not found** | No email-sending integration found (beyond Firebase Auth's own password-reset emails). |
| NOT-04 | WhatsApp notifications | ✅ | ⚠️ | ✅ | ✅ | ⚠️ | ⚠️ | ❌ | **Partial** | Real integration; one of three send paths correctly proxies through a Cloud Function, two call Meta's API directly from the client (CORS risk on web, client-side token exposure). Requires external Meta Business account setup outside the app. |

## Reports

| ID | Feature | UI | Backend | DB | Validation | Security | Error Handling | Tests | Prod Ready | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| REP-01 | Financial reports | ✅ | ✅ | ✅ | 🚫 | ✅ | ❓ | ✅ (partial) | **Partial** | The only dedicated report screen found in the entire app. |
| REP-02 | Attendance reports (student, monthly) | ❓ | ❓ | ❓ | 🚫 | ❓ | ❓ | ❌ | **Unknown** | See ATT-04. |
| REP-03 | Any other report type (staff, admissions, etc.) | ❌ | 🚫 | 🚫 | 🚫 | 🚫 | 🚫 | ❌ | **Not found** | Repo-wide search for "report"-named screens found exactly one file. |

## Settings

| ID | Feature | UI | Backend | DB | Validation | Security | Error Handling | Tests | Prod Ready | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| SET-01 | School settings (branding/info) | ✅ | ✅ | ✅ | ⚠️ | ✅ | ❓ | ❌ | **Partial** | Correctly scoped despite bypassing the repository layer. |
| SET-02 | WhatsApp settings | ✅ | ✅ | ✅ | ⚠️ | ✅ | ❓ | ❌ | **Partial** | Reachable, functional, correctly scoped. |
| SET-03 | UPI settings | ❌ | ✅ | ✅ | ❓ | ✅ | 🚫 | ❌ | **Dead code** | `UPISettingsScreen` exists and looks complete but is unreferenced from any live navigation path — same class of gap as Payroll and Student Promotion. |

## RFID Attendance Subsystem

| ID | Feature | UI | Backend | DB | Validation | Security | Error Handling | Tests | Prod Ready | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| RFID-01 | Device registration | ✅ | ✅ (fixed) | ✅ | ✅ | ✅ (fixed) | ❓ | ❌ | **Partial** | Was a full authentication bypass; now requires an authenticated school admin. |
| RFID-02 | Card mapping (staff/student) | ✅ | ✅ (fixed) | ✅ | ✅ | ✅ (fixed) | ❓ | ❌ | **Partial** | Cross-tenant scoping gap closed this session. |
| RFID-03 | Attendance marking (swipe) | 🚫 (hardware-driven) | ⚠️ | ✅ | ⚠️ | ✅ | ❓ | ❌ | **Partial** | No rate-limiting/duplicate-scan protection (deliberately removed per code comment). |
| RFID-04 | Device key storage | 🚫 | ✅ (fixed) | ✅ | 🚫 | ✅ (fixed) | 🚫 | ❌ | **Ready** | Now hashed + constant-time compared, with legacy fallback. |

## Academic Year / Promotion

| ID | Feature | UI | Backend | DB | Validation | Security | Error Handling | Tests | Prod Ready | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| ACY-01 | Academic year management | ✅ | ✅ | ✅ | ✅ | ✅ | ❓ | ❌ | **Ready** | Confirmed reachable and correctly built. |
| ACY-02 | Fiscal year management | ✅ | ✅ | ✅ | ✅ | ✅ | ❓ | ❌ | **Ready** | Same repository, same verdict. |
| ACY-03 | Student promotion (year-end) | ❌ | ✅ | ✅ | ✅ | ✅ | ❓ | ❌ | **Broken** | Fully implemented, completely unreferenced from any live screen — the doc claim of "90% complete, wired in" is overstated for this specific piece. |
| ACY-04 | Arrears tracking | ⚠️ | ✅ | ✅ | ❓ | ✅ | ❓ | ❌ | **Partial** | Data model/rules exist (`arrears` collection); UI surfacing not independently re-verified this pass. |

## Leave & Permission Management

| ID | Feature | UI | Backend | DB | Validation | Security | Error Handling | Tests | Prod Ready | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| LV-01 | Apply leave/permission (staff) | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ | ❌ | **Ready** | Confirmed self-scoping by construction; two duplicate screens exist for each (leave and permission), a maintenance risk, not a functional one. |
| LV-02 | Approve/reject leave/permission (admin) | ✅ | ✅ | ✅ | ✅ | ✅ (fixed) | ⚠️ | ❌ | **Ready** | Live path confirmed architecturally sound; cross-tenant gap in the parallel callable-API path fixed this session. |
| LV-03 | Balance calculation, idempotency | 🚫 | ✅ (fixed) | ✅ | ✅ | ✅ | ✅ (fixed) | ❌ | **Ready** | Idempotency guard added this session; this is now one of the more solid modules in the app. |
| LV-04 | Cancellation flow | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ | ❌ | **Ready** (leave) / **Unknown** (permission UI per historical project docs, not re-verified) | See `CODEBASE_ANALYSIS.md` §8 for the historical bug-fix trail on this feature. |

## Cross-Cutting: RBAC / Security

See `docs/SECURITY_AUDIT.md` for the full PASS/WARNING/FAIL breakdown — not duplicated here as matrix rows since it doesn't map cleanly to a single "feature."

## Summary Counts (by row, not by weighted importance)

Counting the 68 rows above (excluding the two purely cross-reference rows): **Ready: 8 · Partial: 40 · Broken: 8 · Missing: 9 · Unknown: 10 · N/A/Dead: 3** (some rows carry two tags, e.g. "Broken" + counted once under its primary tag). This count is a rough indicator, not a precision metric — see `docs/PRODUCTION_GAP_REGISTER.md` for severity-ranked, actionable items, which is the more useful document for prioritization than this raw tally.
