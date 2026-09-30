# Eazy School 360 — Security Audit

Part of the Production Readiness Audit. See `docs/README.md` for the document index. Every finding here is grounded in a specific file/line read during this session (this pass, plus the two prior deep-review passes recorded in `CODEBASE_ANALYSIS.md`). Six of the FAIL items below were fixed in code during this same session (see the "Fix status" column) — they're kept in this audit as FAIL-then-fixed rather than removed, so the record shows what was found and what changed.

Classification: **PASS** (verified correct), **WARNING** (works but has a real weakness), **FAIL** (verified broken/missing), **UNKNOWN — REQUIRES VERIFICATION** (not confirmed from the code).

## Authentication

| Control | Status | Evidence |
|---|---|---|
| Firebase Auth email/password sign-in | PASS | `lib/core/providers/auth_provider.dart` — standard `signInWithEmailAndPassword` flow, credential/session handling looks correct. |
| Password not logged | **FAIL → FIXED** | Raw password and its length were printed to console on every sign-in (`auth_provider.dart:113-115`, pre-fix). Removed this session. |
| Generated temp-passwords not logged | **FAIL → FIXED** | `staff_management_repository.dart:931,957`, `teacher_repository.dart:218` printed generated passwords in plaintext. Removed this session. |
| Startup "security gate" (rules/index verification) is real | **FAIL** — not fixed | `lib/core/security/firebase_rules_verifier.dart`'s native verification is a stub (`await Future.delayed(500ms)` then unconditional success) presented to the app as a real check that can block startup. Not fixed this session — needs a product decision (build a real check, or remove the false "app refuses to start" framing) rather than a quick patch. |
| Password-reset-based account activation | WARNING | Implemented for the newer staff-creation path; `createAdmin()`/`createFinanceAdmin()` and bulk upload still use an older temp-password-export pattern per project docs (`USER_ACTIVATION_IMPLEMENTATION.md`) — not independently re-verified this session. |

## Authorization / RBAC

| Control | Status | Evidence |
|---|---|---|
| Centralized backend authorization actually enforced | **FAIL** — not fixed (documented as inactive) | `functions/src/security/backend-authorization.js` implements a complete role/tenant-check class, but no deployed function calls it. Every function reimplements its own inline check instead. Now has an in-code warning comment so it isn't mistaken for active protection; not wired in, since doing so safely for every function would be a larger change than a quick fix. |
| Flutter route-level access control | **FAIL** — not fixed | `lib/core/routing/app_router.dart`'s `RouteGuard`/`AppRoutes` are part of the dead `go_router` stack (app runs on plain `MaterialApp`). The *live* `RouteGuard` widget (`lib/core/security/route_guard.dart`) wraps only the 4 top-level dashboard screens; none of the ~60 feature screens beneath them independently re-check access. |
| Cross-tenant scoping on admin Cloud Functions | **FAIL → FIXED** (for the functions found) | `approveLeave`/`rejectLeave`/`approvePermission`/`rejectPermission`/`adjustLeaveBalance`/`adjustPermissionBalance` (`functions/src/leave-permission-management.js`) and `mapRfidToStaff`/`listRfidCards`/`unmapRfidCard` (`functions/src/student-phone-update.js`) checked the caller's admin role but not that the caller's own `schoolId` matched the target `schoolId`. Fixed via a shared `assertAdminSchoolAccess` helper. **Not exhaustively re-audited beyond these specific functions** — other functions not covered by the original bug hunt could have the same gap; treat this as fixed-where-found, not proven-comprehensive. |
| `setUserClaims` privilege escalation | **FAIL → FIXED** | Any authenticated user could set an arbitrary uid's custom claims to a client-supplied object (`functions/index.js`, pre-fix) — a direct path to self-granting `SUPER_ADMIN`. Now restricted to `SUPER_ADMIN` callers, with claims re-derived server-side from the target user's own Firestore document rather than trusted from the request. Confirmed unused by any Flutter caller, so nothing broke. |
| Role-string consistency | WARNING | Role checks across the codebase enumerate multiple historical spellings (`'ADMIN'`, `'admin'`, `'TENANT_ADMIN'`, `'tenant_admin'`, `'SUPER_ADMIN'`, `'super_admin'`) rather than normalizing to one canonical value — not a bypass by itself, but a maintenance hazard: a new function that misses one spelling in its check list silently under- or over-grants access. |
| Staff-facing callables self-scope correctly | PASS | `applyLeave`/`applyPermission`/`cancelLeave` derive the staff identity from `context.auth.uid` and look it up under `schools/{schoolId}/staff/{uid}` — structurally cannot act on a school the caller doesn't belong to, verified by tracing the lookup path. |

## Tenant Isolation

| Control | Status | Evidence |
|---|---|---|
| Firestore subcollection isolation (primary model) | PASS | Most collections live under `schools/{schoolId}/...`, structurally preventing cross-tenant reads/writes regardless of query logic. |
| Flat top-level collections with field-based scoping | WARNING | `leave_types` and `teachers` are stored as flat collections filtered by a `schoolId` field rather than nested under `schools/{schoolId}`; isolation for these two depends entirely on every query remembering the filter. |
| Single-document lookups on the two flat collections | **FAIL** — not fixed | `leave_type_repository.dart:40-54` (`getLeaveTypeById`) and `teacher_repository.dart:63-77` (`getTeacherById`) fetch by document ID alone, with no `schoolId` check in the query — isolation for these two calls relies solely on Firestore rules. Not fixed this session (lower severity, not on the original priority list; flagged here for the gap register). |
| `LeaveTypeRepository.isNameUnique` scoping | **FAIL** — not fixed, but unused | Queries `leave_types` across **all** schools with no `schoolId` filter (`leave_type_repository.dart:176-194`). Confirmed unused/dead today; a live trap if ever wired up. |
| RFID device registration | **FAIL → FIXED** | `/register-device` (the `rfidApi` HTTPS Express route) required no credentials at all — any caller who knew a `schoolId` could self-register a device and receive a valid, permanent device key. Now requires a Firebase ID token from an admin of the target school (or a super admin), via new middleware `functions/src/rfid-attendance/middleware/adminAuth.js`. |
| RFID device key storage/comparison | **FAIL → FIXED** | Device keys were stored in Firestore in plaintext and compared with `!==` (a timing side-channel, and a cleartext-credential-at-rest issue — any read access to the `devices` collection, e.g. a backup export, would leak live credentials). Now stored only as a SHA-256 hash, compared with `crypto.timingSafeEqual`; a legacy fallback exists for devices registered before this fix. |
| Two data-mutation Cloud Functions with authentication commented out | **FAIL → FIXED** | `standardizeAcademicYears` (`functions/src/data-cleanup.js`) and `updateAllStudentPhoneNumbers` (`functions/src/student-phone-update.js`) shipped with their auth checks fully commented out ("temporarily disabled for migration/testing purposes"), allowing any caller to trigger bulk data mutation across an arbitrary school. Both now require admin auth scoped to the target school. |
| Firestore rules block direct client writes to balance-sensitive collections | PASS | `firebase/firestore.rules`: `leaveBalances` and `monthlyPermissionUsage` both have `allow write: if false` — backend-only, confirmed to actually be enforced against the live approval screens (see Payment/Data Integrity section). |

## Data Integrity

| Control | Status | Evidence |
|---|---|---|
| Leave/permission status-change trigger idempotency | **FAIL → FIXED** | The deployed `onLeaveStatusChange`/`onPermissionStatusChange` triggers (`functions/src/leave-management.js`) had no guard against Cloud Functions' at-least-once retry delivery — a retried invocation would double-apply the same balance mutation. Fixed by porting the `processedAt`-guard pattern (already present, but unused, in `atomic-leave-approval.js`/`atomic-permission-approval.js`) into the live triggers, set inside the same transaction as the balance write. |
| Live leave/permission approval architecture is consistent | PASS | Traced end to end: the reachable admin screens (`leave_approval_screen.dart`, `permission_approval_screen.dart`) update only the document's `status` field via `LeaveApplicationRepository`/`PermissionRequestRepository`; the balance math is left entirely to the (now-idempotent) Cloud Function trigger. This matches what Firestore rules enforce and is architecturally sound. |
| Dead parallel client-side balance-mutation code | WARNING — documented, not deleted | `lib/data/services/leave_approval_service.dart` / `permission_approval_service.dart` implement a different, direct-client-write version of approval logic that Firestore rules currently block. Unreferenced from any screen today. If ever wired up without removing the Cloud Function triggers, every approval would double-process. Now carries an in-code warning; not deleted since removing dead code wasn't in scope. |
| Bill deletion / ledger reversion atomicity | **FAIL** — not fixed | `bill_management_screen.dart:1781-2066`: deletion and its ledger-balance reversion are separate, non-transactional writes; a reversion failure is caught and logged with `print()` only, while the UI still reports success to the admin. Not touched this session (part of the broader fee-system consolidation work, out of scope for a security-only fix pass). |
| Broken exports removed | **FIXED** | `dailyAttendanceFinalizer` and `revertStudentPhoneNumbers` were exported in `functions/index.js` from source that didn't actually define them (referencing `undefined`). Removed. |
| `previewPhoneNumberUpdate` runtime bug | **FIXED** | Used `.docs.take(10)`, not a real JS `Array` method — threw on every invocation. Changed to `.slice(0, 10)`. |

## API / Function Security

| Control | Status | Evidence |
|---|---|---|
| RFID attendance-marking rate limiting / duplicate-scan protection | **FAIL** — not fixed | `functions/src/rfid-attendance/controllers/attendanceController.js` has duplicate-scan protection deliberately removed per its own code comment, and no rate limiting. Combined with the (now-fixed) device-registration bypass, this was a compounding risk; the registration bypass is closed, but a legitimately-registered rogue/compromised device could still flood-write attendance records. |
| Input validation on RFID HTTP routes | WARNING | No format/length validation on `rfidTag`/`schoolId` before using them directly as Firestore document IDs. Not a known exploit path today (document-ID injection in Firestore is limited), but not validated either. |
| Firebase Functions v1 vs v2 API consistency | PASS | Confirmed consistent v1 usage throughout; no mixed-API risk found. |

## Secret Management

| Control | Status | Evidence |
|---|---|---|
| Committed credential files | **FAIL** — not fixed, flagged only | `service-account-key.json` and `users.json` at the repo root are tracked by git, not gitignored (confirmed via `git ls-files`). Treat as live credentials/PII already in git history; rotating/removing them is a repo-hygiene decision for you to make, not something changed silently in an audit pass. |
| Hardcoded API keys/secrets in application source | UNKNOWN — REQUIRES VERIFICATION | A repo-wide scan for common key patterns (Firebase `AIzaSy...`, Twilio `AC...`, Stripe-style `sk_live`/`sk_test`) is part of `docs/PRODUCTION_CONFIGURATION_AUDIT.md`; not yet finalized as of this document's writing — see that document for the result once available. |
| WhatsApp access token handling | **WARNING** | Credentials are stored per-school in Firestore (not hardcoded in source, which is good), but two of three WhatsApp send paths (`sendFeeDueReminder`, `sendAdminDailySummary` in `lib/core/services/whatsapp_service.dart`) call Meta's Graph API directly from the Flutter client rather than proxying through a Cloud Function — this ships the access token to the client at send time. The third path (`sendPaymentNotification`) correctly proxies through a Cloud Function. |

## Logging

| Control | Status | Evidence |
|---|---|---|
| Production logging discipline | **FAIL** — largely not fixed | 686 `print()` call sites found across 51 Flutter files in the original review, essentially none gated by `kDebugMode`; a dedicated `app_logger.dart` exists but is used in only 2 places. Only the password-revealing subset was removed this session; the broader over-logging pattern remains. |
| RFID request logging verbosity | WARNING — not fixed | `functions/src/rfid-attendance/utils/logger.js` logs full request bodies (`schoolId`, `deviceId`, `uid`) on every API call with no log-level gating — a cost and PII-exposure-via-log-access concern, not fixed this session. |
| Audit trail for security violations | UNKNOWN — REQUIRES VERIFICATION | `backend-authorization.js` includes a `logSecurityViolation` method that would write to a `securityAuditLogs` collection, but since that class is never called (see above), this audit trail does not currently capture anything. No alternative audit-logging mechanism was found for authorization failures. |

## Storage Rules (new finding, not covered by prior audit passes)

`storage.rules` was not examined in either of the two earlier Cloud Functions/Flutter review passes — this is the first audit to read it.

| Control | Status | Evidence |
|---|---|---|
| `school_logos/{schoolId}/{fileName}` — public read | PASS (by design) | `allow read: if true` — appropriate for public branding assets displayed to unauthenticated users (e.g. a public sign-up page); write correctly scoped to super admin or the school's own tenant admin. |
| `user_avatars/{userId}` — public read | PASS (by design) | Same reasoning as school logos; write correctly scoped to super admin or the user themself. |
| `teacher_documents/{schoolId}/{teacherId}/{fileName}` — read scoping | **FAIL** — not fixed | `allow read: if isSignedIn();` — **any authenticated user from any school** can read any teacher's documents from any other school. The rule's own comment says this was deliberately "relaxed... since custom claims may not be present for staff users in this environment," with no `belongsToSchool` check ever restored. Depending on what's actually uploaded here (ID proofs, certificates, personal documents are the typical use case for a "teacher documents" bucket), this is a real cross-tenant privacy/security exposure, not a theoretical one. |
| `leave_attachments/{schoolId}/{leaveId}/{fileName}` — read AND write scoping | **FAIL** — not fixed | `allow read: if isSignedIn(); allow write: if isSignedIn();` — any authenticated user from any school can both read and **write** into any other school's leave-attachment folder. The rule comment acknowledges this relies on `leaveId` being "unguessable" as its only protection — security-through-obscurity, not a real control, and it's a Firestore-generated ID that's likely predictable/enumerable in sequence or via the corresponding Firestore document. This is the more severe of the two storage findings since it permits cross-tenant writes, not just reads. |

These two findings were not part of the original priority-fix list (which focused on Cloud Functions and Firestore) and are **not fixed** as of this audit. Recommend adding both to the Gap Register at P0/P1 severity pending confirmation of what file types are actually stored in each path — see `docs/PRODUCTION_GAP_REGISTER.md`.

## Payment Security

| Control | Status | Evidence |
|---|---|---|
| Razorpay signature verification | **N/A — feature does not exist** | No Cloud Function for Razorpay order creation or payment-signature verification is exported anywhere in `functions/index.js`. Nothing to audit because nothing is implemented. |
| Cash/manual payment recording authorization | UNKNOWN — REQUIRES VERIFICATION | Not independently re-verified this pass whether payment-recording screens correctly restrict to admin/finance roles server-side vs. relying on UI-only gating; flagged for the Gap Register. |

## Overall Security Posture Summary

- **6 of the original 8 highest-severity findings from the first audit pass are fixed** in code this session (RFID auth bypass, two commented-out-auth functions, `setUserClaims` privilege escalation, missing cross-tenant checks on 9 functions, missing trigger idempotency, credential logging).
- **A new class of finding surfaced by this audit pass, not previously examined**: Cloud Storage rules (`storage.rules`) have two cross-tenant gaps — `teacher_documents` is readable by any authenticated user regardless of school, and `leave_attachments` is both readable and **writable** by any authenticated user regardless of school. Neither is fixed as of this document.
- **Not fixed, by design** (need a product/architecture decision, not a quick patch): the decorative backend-authorization layer, the decorative `FirebaseRulesVerifier` startup gate, the lack of independent access gates on ~60 Flutter screens, the non-atomic bill-deletion/ledger-reversion bug, the two flat-collection Firestore scoping gaps, the two Storage-rules scoping gaps above, committed credential files.
- **No exhaustive re-scan for additional instances of the same bug classes** (e.g., other functions with the same missing-schoolId-check pattern, or other Storage paths with the same scoping gap, beyond the ones this and the original bug hunt happened to find) has been performed. Treat the fixes as fixing what was found, not as proof the codebase is now free of this class of issue.
