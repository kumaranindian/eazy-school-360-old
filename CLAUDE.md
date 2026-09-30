# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Eazy School 360 is a multi-tenant school management system: a Flutter app (mobile/tablet/web) backed by Firebase (Auth, Firestore, Storage, Cloud Functions, FCM). Each school is an isolated tenant; access is controlled by three roles — SUPER_ADMIN (system-wide), ADMIN (single school), STAFF (own data only). Core modules: teacher/staff management, leave & permission management, payroll, attendance (including RFID card-based attendance), and fee/finance management.

## Commands

### Flutter app

The app has four environment-specific entry points that must be selected explicitly with `-t`; there is no single default entry point for real use.

```bash
flutter pub get                                   # install dependencies

flutter run -t lib/main_dev.dart  -d chrome        # run against DEV Firebase project
flutter run -t lib/main_test.dart -d chrome        # run against TEST project
flutter run -t lib/main_uat.dart  -d chrome        # run against UAT project
flutter run -t lib/main_prod.dart -d chrome        # run against PROD project

flutter build web --release -t lib/main_prod.dart  # production web build

flutter analyze                                    # lint/static analysis
flutter test                                        # run all tests
flutter test test/finance/fee_payment_flow_test.dart # run a single test file
flutter test --plain-name "some test name"          # run a single test by name
```

`lib/main.dart` (no `-t`) and `npm start`/`npm run build` at the repo root are legacy/unconfigured — they use a placeholder Firebase project id. Always target one of `main_dev.dart` / `main_test.dart` / `main_uat.dart` / `main_prod.dart` explicitly.

`test/widget_test.dart` is annotated `@TestOn('browser')` and needs a browser test runner (e.g. `flutter test -d chrome`); plain `flutter test` skips it.

### Cloud Functions (`functions/`)

```bash
cd functions
npm run lint     # eslint .
npm run build    # tsc (compiles src/**/*.ts to lib/) + copies src/*.js into lib/src/
npm run serve    # build + firebase emulators:start --only functions
npm run shell    # build + firebase functions:shell
npm run deploy   # build + firebase deploy --only functions
npm run logs     # firebase functions:log
```

`npm run build`'s `xcopy` step is Windows-only; on macOS/Linux copy `functions/src/**/*.js` into `functions/lib/src/` manually (or with `cp -r`) before deploying if you're not on Windows.

### Firebase rules / indexes / project selection

```bash
firebase use <dev|test|uat|prod-alias>   # see .firebaserc for project ids/aliases
npm run deploy-rules      # node firebase/deploy-rules.js (validates + deploys firestore.rules)
npm run deploy-indexes    # node firebase/deploy-indexes.js
npm run validate-rules    # firebase firestore:rules:validate
npm run deploy-all        # rules + indexes + firebase deploy
```

## Architecture

### Layering

`lib/` follows a clean-architecture split:
- `presentation/` — screens/widgets, organized by feature (admin, staff, parent, attendance, leave, permission, finance, dashboard, auth...)
- `domain/entities/` — plain data entities shared across the app
- `data/repositories/` and `data/services/` — Firestore/Storage access, one repository per entity/feature
- `core/` — cross-cutting concerns: `providers/` (Riverpod), `routing/`, `security/` (RBAC + rules/index verification), `middleware/`, `theme/`, `constants/`, `utils/`

State management is Riverpod (`flutter_riverpod`); navigation is `go_router` via `lib/core/routing/app_router.dart`.

### Multi-environment setup

Four Firebase projects (dev/test/uat/prod, see `.firebaserc`) are selected at compile/run time, not at runtime via config:
- `lib/main_{dev,test,uat,prod}.dart` each call `EnvironmentConfig.setEnvironment(...)` then delegate to the shared `lib/main_common.dart`.
- `lib/config/environment_config.dart` maps the selected `Environment` enum to the right `lib/config/firebase_options_{dev,test,uat,prod}.dart` and to environment-specific flags (debug logging, analytics, crash reporting, API base URL).
- On startup (`main_common.dart`), the app calls `FirebaseRulesVerifier` / `FirebaseIndexesVerifier` (`lib/core/security/`) — this is *intended* as a guard against running against an out-of-date backend, but as of the production readiness audit (`docs/SECURITY_AUDIT.md`), the native rules-verification implementation is a stub that always succeeds after a fixed delay. Don't rely on it as a real check, and don't assume "the app started" means rules/indexes are actually current.

### RBAC (defense in depth)

Full design in `lib/core/security/rbac_documentation.md`. Three layers are *intended*, but the middle one is not actually wired in — see the production readiness audit (`docs/SECURITY_AUDIT.md`) for the full finding:
1. **UI (Flutter)**: `lib/core/security/role_policy.dart` is the single source of truth for what each role can see/do; `route_guard.dart` and `role_guard_service.dart` enforce it in navigation and widgets. UI-side checks are for UX only. In practice, `RouteGuard` only wraps the 4 top-level dashboard screens — the ~60 feature screens beneath them have no independent access check of their own.
2. **Backend (Cloud Functions)**: `functions/src/security/backend-authorization.js` is a complete, well-designed authorization class — **but as of this audit, no deployed Cloud Function actually calls it.** Every function instead reimplements its own inline role check. Don't assume calling a function means this class validated the request; check the function's own inline logic, and see `docs/SECURITY_AUDIT.md` / `docs/PRODUCTION_GAP_REGISTER.md` (GAP-015) before treating this class as active protection.
3. **Database**: `firestore.rules` (and `storage.rules` for file uploads) enforce tenant isolation and role-based read/write as the actual last line of defense. Two Storage paths (`teacher_documents`, `leave_attachments`) were found to be missing school-scoping — see GAP-006.

Tenant isolation convention: ADMIN/STAFF queries are always scoped by `schoolId` (and, for STAFF, additionally by the user's own id); only SUPER_ADMIN crosses tenants. Several Cloud Functions were found missing this check server-side and were fixed in the audit session (see `docs/CHANGELOG.md`) — when adding a new admin-scoped function, verify `callerData.schoolId === targetSchoolId` explicitly; don't assume the role check alone is sufficient.

### Cloud Functions structure — non-obvious entry point

`functions/package.json`'s `main` is `index.js`, which resolves to **`functions/index.js`** (repo-root-relative to `functions/`), *not* `functions/src/index.js`. This is the file Firebase actually deploys:
- It `require()`s most modules directly from `functions/src/*.js` (plain JS, no build step needed).
- It also `require()`s TypeScript-authored modules from **compiled output** in `functions/lib/` (e.g. `./lib/index`, `./lib/src/whatsapp-fee-reminders`) — so `npm run build` must run before deploying if any `.ts` file under `functions/src/` changed.
- `functions/src/index.js` and `functions/src/index.ts` exist but are **not** the deployed entry point; don't assume wiring a new export there exposes it — wire it into `functions/index.js` instead (and, for `.ts` modules, into `functions/src/index.ts` which compiles into `lib/index.js`).

The RFID attendance subsystem (`functions/src/rfid-attendance/`) is a self-contained Express app (`controllers/`, `middleware/`, `triggers/`, `utils/`) exported as a single HTTPS function (`exports.api`) with routes for device registration, RFID card mapping, and attendance marking, secured by a device-key middleware (`middleware/deviceAuth.js`) separate from the normal Firebase Auth-based RBAC.

Most functions are pinned to the `asia-south1` region via `.region('asia-south1')` — match this when adding new ones so they colocate with existing Firestore/Functions traffic.

### Firestore rules/indexes — two copies, only one is deployed

There are two sets of `firestore.rules` / `firestore.indexes.json`: one at the repo root, and one under `firebase/`. **`firebase.json` points at the `firebase/` copies**, and `firebase/deploy-rules.js` / `firebase/deploy-indexes.js` deploy from `firebase/`, not the repo root. The two copies have already diverged. When changing security rules or indexes, edit the files under `firebase/` — the root-level copies appear to be stale and are not what gets deployed.

### Security-sensitive files already in the repo

`service-account-key.json` and `users.json` at the repo root are tracked by git (not gitignored). Treat them as live credentials/PII, not placeholders — don't print their contents, don't copy patterns from them into new tracked files, and flag before making them more broadly reachable (e.g. bundling into a client build).

## Working on this codebase: production readiness audit workflow

This app went through a formal Production Readiness Audit — see **`docs/README.md`** for the full document index (`PROJECT_ANALYSIS.md`, `FEATURE_READINESS_MATRIX.md`, `PRODUCTION_GAP_REGISTER.md`, `SECURITY_AUDIT.md`, `DATABASE_AUDIT.md`, `END_TO_END_FLOW_AUDIT.md`, `PRODUCTION_CONFIGURATION_AUDIT.md`, `TESTING_STRATEGY.md`, `IMPLEMENTATION_PLAN.md`, `DEPLOYMENT_CHECKLIST.md`, `CHANGELOG.md`). These rules govern how future work on this codebase should proceed, whether or not you were the session that ran that audit.

**Project understanding.** Read the architecture (this file, `docs/PROJECT_ANALYSIS.md`) before changing code. Don't assume a screen existing means a feature is complete — this codebase has multiple fully-built, completely unreachable features (Payroll admin UI, Student Promotion, UPI settings) discovered only by tracing actual navigation, not by finding the file.

**Change discipline.** Do not make unrelated changes while implementing a specific task. If you notice something else wrong while working, note it (in the Gap Register or as a comment) rather than fixing it inline unless it's trivially safe and directly adjacent to the change you're already making.

**Backend protection.** Do not change backend (Cloud Functions) logic when the task is explicitly UI-only. A UI change should not need a matching backend change unless the task description says so.

**Database protection.** Do not change Firestore/Storage schema or data structure without documenting the impact in `docs/DATABASE_AUDIT.md` and noting it in `docs/CHANGELOG.md`. This includes adding new fields to existing collections — note it even if additive and non-breaking.

**Security.** Never weaken authentication, authorization, tenant isolation, or Firestore/Storage rules to make a feature work more easily. If a feature seems to require weakening a rule, that's a sign the feature's design needs rework, not the rule.

**Multi-tenancy.** Every school/tenant must remain isolated. Any new Cloud Function or repository query touching school-scoped data must verify `schoolId` server-side (Cloud Functions) or use the `schools/{schoolId}/...` nesting pattern (Firestore) — see the RBAC section above for the specific gap class this audit found and fixed.

**Production readiness.** Do not consider a feature complete until: UI works, business logic works, validation works, error handling works (failures are surfaced, not silently swallowed — see `docs/SECURITY_AUDIT.md`'s Data Integrity section for what "swallowed" looks like in this codebase), security is verified, responsive UI works, loading/empty/error states work, tests exist where appropriate, and documentation is updated. "The screen opens" is not the bar — see `docs/FEATURE_READINESS_MATRIX.md`'s legend for what each readiness column actually checks.

**Before implementation.** Read the relevant document(s) in `docs/` for the feature you're touching — at minimum its `FEATURE_READINESS_MATRIX.md` row and any Gap Register entries referencing it.

**After implementation.** Update `docs/FEATURE_READINESS_MATRIX.md` (the feature's row), `docs/PRODUCTION_GAP_REGISTER.md` (mark the relevant GAP status as Fixed, or add a new entry if you found something new), `docs/IMPLEMENTATION_PLAN.md` (mark the task Done), and `docs/CHANGELOG.md` (one entry, in the style already established there).

**Testing.** Run the appropriate tests after changes — `flutter analyze` / `flutter test` for Flutter changes, `node --check` (and `tsc --noEmit` if `.ts` files changed) for Cloud Functions changes at minimum, since `npm run lint` is currently broken (see `docs/PRODUCTION_CONFIGURATION_AUDIT.md`, GAP-033) and there is no Dart-equivalent syntax-only check. **Do not claim tests passed unless they were actually executed** — if your environment lacks the Flutter/Dart SDK (this has happened before in this repo's audit sessions), say so explicitly rather than asserting untested code compiles.

**No assumptions.** If a behavior, data flow, or feature's actual state cannot be verified from the codebase, mark it `UNKNOWN — REQUIRES VERIFICATION` (in docs, or in your response) rather than guessing. Several audit findings in this codebase exist specifically because earlier project documentation made confident claims ("90% complete," "implementation complete") that turned out not to match the code — don't repeat that pattern.

**Implementation mode.** When explicitly asked to implement a task (by Task ID from `IMPLEMENTATION_PLAN.md`, or "implement the next task"): read this file, read the relevant `docs/` documents, read the specific feature's existing implementation, understand dependencies, make the smallest safe change, don't rewrite unrelated code, preserve existing functionality, run appropriate tests, fix any regressions, then update documentation as described above and report exactly what changed. Do not implement multiple Gap Register items in one pass "while you're in there" — one task, tested, documented, then stop for the next instruction.
