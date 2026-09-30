# Eazy School 360 — Project Analysis

Part of the Production Readiness Audit. See `docs/README.md` for the full document index. This document is built entirely from direct inspection of the current codebase (this session and the two prior audit passes recorded in `CODEBASE_ANALYSIS.md`), not from the project's own historical docs, which are treated as unverified claims where referenced.

## Project Overview

Eazy School 360 is a multi-tenant school management system: a Flutter application (targeting at least Web; no `android/` or `ios/` platform directories exist in this checkout, so mobile build readiness is **UNKNOWN — REQUIRES VERIFICATION**) backed by Firebase (Auth, Firestore, Storage, Cloud Functions, Cloud Messaging). Each school is a tenant identified by a `schoolId`; roles are SUPER_ADMIN (platform-wide), ADMIN/TENANT_ADMIN (single school), STAFF (own data within a school), plus a FINANCE role variant referenced in places (`manage_finance_users_screen.dart`) whose exact permission boundary vs. ADMIN is **UNKNOWN — REQUIRES VERIFICATION**.

## Technology Stack

- **Frontend**: Flutter, Dart SDK `>=3.0.0 <4.0.0`. State management: `flutter_riverpod ^2.3.7`. Navigation: `go_router ^17.0.0` is a dependency but is **not actually used at runtime** — see Application Entry Points below.
- **Firebase client packages**: `firebase_core ^4.2.1`, `firebase_auth ^6.1.2`, `cloud_firestore ^6.1.0`, `cloud_functions ^6.2.0`, `firebase_storage ^13.0.4`, `firebase_messaging ^16.0.4`.
- **No crash-reporting or analytics package** (`firebase_crashlytics`, `firebase_analytics`, Sentry, etc.) is present in `pubspec.yaml`. Observability is limited to `print()`/`debugPrint()` console output and a largely-unused `lib/core/utils/app_logger.dart`.
- **Backend**: Firebase Cloud Functions, Node 20, mixed JavaScript (majority) and TypeScript (`functions/src/attendance/attendanceProcessor.ts`, `functions/src/leave/leaveValidator.ts`, compiled via `tsc` into `functions/lib/`). Functions API: `firebase-functions` v1 (legacy) syntax throughout, region pinned to `asia-south1`.
- **PDF/reporting**: `pdf`, `printing`, `syncfusion_flutter_pdfviewer`, `syncfusion_flutter_charts`, `syncfusion_flutter_calendar`.
- **Payments**: no payment-gateway SDK (e.g. `razorpay_flutter`) is present in `pubspec.yaml` — consistent with the earlier finding that Razorpay has no working integration.

## Architecture

Clean-architecture-style layering under `lib/`:
- `presentation/` — screens and widgets, grouped by feature area (admin, attendance, auth, dashboard, dashboards, finance, leave, parent, permission, staff, shared, widgets).
- `domain/entities/` — plain data models mirroring Firestore documents.
- `data/repositories/`, `data/services/` — Firestore/Storage access, one repository per feature area.
- `core/` — cross-cutting: `providers/` (Riverpod), `routing/`, `security/`, `middleware/`, `theme/`, `constants/`, `utils/`.

**This layering is not consistently honored.** At least 27 presentation-layer files call `FirebaseFirestore.instance` directly rather than going through a repository (confirmed in the prior review; `whatsapp_settings_screen.dart` and `school_settings_screen.dart` are two re-confirmed examples in this pass).

## Folder Structure (top level, application-relevant)

```
lib/
  main.dart, main_dev.dart, main_test.dart, main_uat.dart, main_prod.dart, main_common.dart
  config/            — environment + Firebase options per env
  core/               — providers, routing (dead), security, middleware, theme, constants, utils
  domain/entities/    — 36 data models
  data/repositories/  — 31 repositories
  data/services/      — cross-cutting services (leave balance, membership, id generation, etc.)
  presentation/       — screens, by feature (see CODEBASE_ANALYSIS.md §3.1 for the full inventory)
functions/
  index.js            — the REAL deployed Cloud Functions entry point
  src/                — function source (JS + TS)
  lib/                — TypeScript build output (git-tracked)
firebase/
  firestore.rules, firestore.indexes.json  — the REAL deployed rules/indexes (firebase.json points here)
  deploy-rules.js, deploy-indexes.js, set-custom-claims.js, fix-claims-cli.js
firestore.rules, firestore.indexes.json    — STALE root-level duplicates, already diverged from firebase/, not deployed
docs/                 — this audit's documents, plus ~60 pre-existing implementation/history docs (see README)
test/                 — see docs/TESTING_STRATEGY.md
scripts/              — one-off Node maintenance/migration scripts, run manually, not part of the app
```

## Application Entry Points

Four environment-specific Dart entry points, each selecting a Firebase project via `EnvironmentConfig.setEnvironment(...)` before delegating to the shared `main_common.dart`:
- `lib/main_dev.dart` → `eazyschool-360-dev`
- `lib/main_test.dart` → `eazyschool-360-test`
- `lib/main_uat.dart` → `eazyschool-360-uat`
- `lib/main_prod.dart` → `eazy-school-360`

`lib/main.dart` (no environment argument) is a fifth, legacy/unconfigured entry point using a literal placeholder Firebase project id (`'your-firebase-project-id'`) — not a real entry point, should not be used or built from.

**Navigation**: despite `go_router` being present as a dependency and a full router configuration existing (`lib/core/routing/app_router.dart`, `lib/presentation/dashboards/` screens), the app actually runs on a plain `MaterialApp` with manual `Navigator.push`/`pushReplacement` calls scattered through `lib/presentation/auth/screens/*` and each dashboard screen. The `go_router` configuration and everything it routes to is dead code.

## Authentication Architecture

- Firebase Authentication (email/password) via `lib/core/providers/auth_provider.dart` (a Riverpod `StateNotifier`).
- Sign-up (`lib/data/repositories/auth_repository.dart`) creates: a Firebase Auth user, a `schools/{schoolId}` document, a per-school admin sub-document, a `users/{uid}` document, and a membership document — scoped correctly to the new `schoolId`. New schools are created with `isActive: false`, intended to require Super Admin approval before use (see Authorization / RBAC below for why this currently has no resolution path).
- A "School Chooser" screen (`lib/presentation/auth/screens/school_chooser_screen.dart`) supports one user having memberships in multiple schools.
- Staff/teacher account creation uses either a random-password-plus-reset-email pattern (newer, staff-creation path) or an older temp-password pattern (still used by `createAdmin()`/`createFinanceAdmin()` in `staff_management_repository.dart` and bulk staff upload) — the two patterns coexist.
- `lib/core/security/firebase_rules_verifier.dart` / `firebase_indexes_verifier.dart` are called at app startup and can, per their contract, block the app from starting if Firestore rules/indexes look stale — but the rules-verification implementation is a stub that always returns success after a fixed delay, so this "security gate" is currently decorative, not a real control.

## Authorization / RBAC

Three intended layers (see `lib/core/security/rbac_documentation.md`, the project's own design doc):
1. **Flutter UI**: `lib/core/security/role_policy.dart` (permission definitions), `route_guard.dart` / `role_guard_service.dart` (enforcement). In practice, the `RouteGuard` widget wraps only the four top-level dashboard screens; none of the ~60 feature screens reachable from them re-check access on entry.
2. **Backend**: `functions/src/security/backend-authorization.js` is a fully-implemented, well-designed authorization class — but as of this audit, **no deployed Cloud Function calls it**. Each function instead reimplements its own inline role check, several of which had (and, per the fixes applied earlier this session, now no longer have) missing cross-tenant `schoolId` verification.
3. **Database**: `firebase/firestore.rules` is the actual last line of defense, and is fairly thorough — see `docs/DATABASE_AUDIT.md` for a structural review.

Roles observed in code: `SUPER_ADMIN`, `ADMIN` (also referred to as `TENANT_ADMIN`/`tenant_admin` in places — inconsistent casing/naming is itself a minor risk, since every inline role check has to enumerate all the historical spellings), `STAFF`, and a `FINANCE` variant whose full scope is **UNKNOWN — REQUIRES VERIFICATION**.

## Multi-Tenant Architecture

Primary isolation model: Firestore documents live under `schools/{schoolId}/...` subcollections, which structurally prevents cross-tenant queries by construction. Two known exceptions store data in flat top-level collections filtered by a `schoolId` field instead (`leave_types`, `teachers`), and single-document lookups against those two collections were found to skip the `schoolId` filter entirely, relying solely on Firestore rules for isolation (`leave_type_repository.dart:40-54`, `teacher_repository.dart:63-77`).

Several Cloud Functions previously lacked server-side verification that an admin's own `schoolId` matched the `schoolId` they were operating on; this has been fixed for `approveLeave`/`rejectLeave`/`approvePermission`/`rejectPermission`/`adjustLeaveBalance`/`adjustPermissionBalance` and the RFID admin callables (`mapRfidToStaff`/`listRfidCards`/`unmapRfidCard`) as of this session. See `docs/SECURITY_AUDIT.md` for the full list of what was and wasn't fixed.

## Data Architecture

See `docs/DATABASE_AUDIT.md` for collection structure, indexes, and audit-field conventions.

## External Integrations

| Integration | Status |
|---|---|
| WhatsApp Business Platform (Meta Graph API) | Real, working integration for one send path (`sendPaymentNotification`, proxied through a Cloud Function); two other send paths (`sendFeeDueReminder`, `sendAdminDailySummary`) call the Graph API directly from the Flutter client, risking CORS failure on web and client-side exposure of the WhatsApp access token. Requires the school to independently obtain Meta Business API credentials — no in-app onboarding for that. |
| Razorpay | **Not integrated.** No Cloud Function for order creation or payment verification exists anywhere in `functions/index.js`; no SDK dependency in `pubspec.yaml`; no payment dialog references it. The data model (`PaymentGateway.RAZORPAY` enum, `payment_transaction_repository.dart`) exists but nothing populates or exercises it. |
| Firebase Cloud Messaging | Dependency present (`firebase_messaging`); actual push-notification wiring (topic subscriptions, notification-tap handling) not verified in this pass — **UNKNOWN — REQUIRES VERIFICATION**. |
| RFID hardware (ESP32-class devices) | Real HTTPS API (`functions/src/rfid-attendance/`) for device registration, card mapping, and attendance marking. Device registration now requires an authenticated school admin (fixed this session); previously had no authentication at all. |

## Environment Configuration

Four Firebase projects (`eazyschool-360-dev`, `eazyschool-360-test`, `eazyschool-360-uat`, `eazy-school-360`), selected via `.firebaserc` aliases and the `Environment` enum in `lib/config/environment_config.dart`. See `docs/PRODUCTION_CONFIGURATION_AUDIT.md` for build/release configuration detail.

## Deployment Architecture

- Hosting: Firebase Hosting, serving `build/web` (per `firebase.json`).
- Functions: deployed via `firebase deploy --only functions` from `functions/`; the build step (`tsc` + a Windows-only `xcopy` to copy plain `.js` sources into the `lib/` output tree) is fragile on non-Windows contributors — see `CLAUDE.md`.
- Firestore rules/indexes: deployed via `npm run deploy-rules` / `npm run deploy-indexes` (custom Node scripts under `firebase/`, not the bare `firebase deploy --only firestore` command), from the `firebase/` copies specifically.
- No CI/CD pipeline exists in this repository (no `.github/workflows/`, no other CI config found) — every deploy is a manual, local operation.

## Existing Testing Strategy

See `docs/TESTING_STRATEGY.md` for the full breakdown. Summary: a handful of finance-domain unit/widget tests exist (`test/finance/`); no security-rules tests, no integration tests, no CI to run any of it automatically.

## Known Technical Debt

- Two parallel, both-live fee-structure systems (legacy `fee_repository.dart` vs. `fee_structure_v2_repository.dart`) read by different screens for the same underlying student/school data.
- Two parallel dashboard folders (`presentation/dashboard/` live, `presentation/dashboards/` dead).
- Duplicate, independently-maintained "apply leave" / "request permission" screens.
- A dead, unused reimplementation of leave/permission approval (`LeaveApprovalService`, `PermissionApprovalService`) that writes directly to Firestore in a way current security rules block, and would double-process balances alongside the live Cloud Function triggers if it were ever wired up.
- `functions/src/security/backend-authorization.js` — a complete, unused authorization module, now documented in-code as inactive so it isn't mistaken for real protection.
- ~60 pre-existing Markdown documents in `docs/` (plus ~35 more at the repo root) recording the project's development history, several of which make completeness claims that this audit found to be overstated (see `docs/END_TO_END_FLOW_AUDIT.md` and `CODEBASE_ANALYSIS.md` §10 for specific contradictions already identified).

## Existing Risks

Summarized here; full detail in `docs/PRODUCTION_GAP_REGISTER.md` and `docs/SECURITY_AUDIT.md`.

- **Onboarding is structurally broken**: a newly self-signed-up school cannot be activated by any reachable UI (Super Admin dashboard is materially a mockup — see Gap Register P0 items).
- **Payroll and Student Promotion** have complete backend implementations but zero UI reachability — not "incomplete," but literally unusable today.
- **Razorpay** does not exist as a working feature despite being referenced in the data model and historical docs.
- Several of the security issues found in the first audit pass have been fixed this session (unauthenticated RFID device registration, two Cloud Functions with authentication commented out, a privilege-escalation path in `setUserClaims`, missing cross-tenant checks, missing trigger idempotency, credential logging) — see `docs/SECURITY_AUDIT.md` for current status of each.
