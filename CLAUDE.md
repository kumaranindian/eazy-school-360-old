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
- On startup (`main_common.dart`), the app calls `FirebaseRulesVerifier` / `FirebaseIndexesVerifier` (`lib/core/security/`) and refuses to start if deployed Firestore rules/indexes look stale — a deliberate guard against running against an out-of-date backend.

### RBAC (defense in depth)

Full design in `lib/core/security/rbac_documentation.md`. Three layers, all of which must be kept in sync when changing permissions:
1. **UI (Flutter)**: `lib/core/security/role_policy.dart` is the single source of truth for what each role can see/do; `route_guard.dart` and `role_guard_service.dart` enforce it in navigation and widgets. UI-side checks are for UX only.
2. **Backend (Cloud Functions)**: `functions/src/security/backend-authorization.js` validates every callable/HTTP function request against role + tenant scope and logs violations. This is the authoritative check.
3. **Database**: `firestore.rules` enforces tenant isolation and role-based read/write at the Firestore level as a last line of defense.

Tenant isolation convention: ADMIN/STAFF queries are always scoped by `schoolId` (and, for STAFF, additionally by the user's own id); only SUPER_ADMIN crosses tenants.

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
