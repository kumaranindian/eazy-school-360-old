# Eazy School 360 — Production Configuration Audit

Part of the Production Readiness Audit. See `docs/README.md` for the document index. No production configuration was changed while producing this document.

## Firebase Projects (Environment Separation)

| Environment | Project ID | Config source |
|---|---|---|
| DEV | `eazyschool-360-dev` | `lib/config/firebase_options_dev.dart`, entry point `lib/main_dev.dart` |
| TEST | `eazyschool-360-test` | `firebase_options_test.dart`, `main_test.dart` |
| UAT | `eazyschool-360-uat` | `firebase_options_uat.dart`, `main_uat.dart` |
| PRODUCTION | `eazy-school-360` | `firebase_options_prod.dart`, `main_prod.dart` |

Environment selection happens at build/run time via the `-t` flag choosing an entry point (`flutter run -t lib/main_prod.dart`), not via a runtime environment variable — see `CLAUDE.md` for the exact commands. `.firebaserc` maps all four as CLI aliases plus a `default` (dev). **Separation is real** (four genuinely distinct Firebase projects, not one project with environment flags) — this is a sound setup.

`lib/main.dart` (no environment suffix) is a fifth, unconfigured entry point with a literal placeholder project ID string — confirmed not a real environment, should never be built or deployed from.

## Firestore

- Rules and indexes: **deployed from `firebase/firestore.rules` / `firebase/firestore.indexes.json`** (per `firebase.json`), not the stale, already-diverged root-level copies of the same filenames. This divergence is a standing operational risk — anyone editing the root copies by habit or muscle memory silently changes nothing in production. See `CLAUDE.md`.
- Deploy path: custom Node scripts (`firebase/deploy-rules.js`, `firebase/deploy-indexes.js`) wrap the Firebase CLI with extra validation/versioning — not the bare `firebase deploy --only firestore` command. `npm run deploy-all` chains rules + indexes + a full `firebase deploy`.
- 134 composite indexes defined (see `docs/DATABASE_AUDIT.md`).

## Firebase Auth

Email/password provider, custom claims (`role`, `schoolId`, `isActive`, `superAdmin`/`admin`/`staff` boolean flags) synced from each user's Firestore document via `onUserDocumentWrite` and related Cloud Functions triggers. No other auth provider (Google/phone/SSO) was found in use.

## Storage

Single `storage.rules` file, not environment-specific (same rules apply across dev/test/uat/prod by virtue of each Firebase project having its own Storage bucket but sharing this one rules file in source control). See `docs/SECURITY_AUDIT.md` for the two cross-tenant scoping gaps found in this file (`teacher_documents`, `leave_attachments`).

## Cloud Functions

- Runtime: Node 20 (`functions/package.json` `engines.node`), region `asia-south1` throughout.
- Build: `tsc` (compiles `.ts` sources) plus a Windows-only `xcopy` step (copies plain `.js` sources into the build output tree) — see `CLAUDE.md` for the non-Windows workaround. This is a real deployment-process fragility: a contributor who runs `npm run build` on macOS/Linux without manually replicating the `xcopy` step will silently ship stale JS-sourced functions.
- `npm run lint` is **currently broken**: `eslint` is a listed devDependency but **no `.eslintrc*` configuration file exists** anywhere in `functions/`, so running lint fails immediately with "ESLint couldn't find a configuration file" rather than reporting on the code. Confirmed by direct invocation this session.

## Environment Variables / Secrets

- No `.env`-based configuration was found in the Flutter app (config is compiled-in via the `firebase_options_*.dart` files, standard for Flutter+Firebase).
- `.gitignore` excludes `.env`, `.env.local`, `.env.development`, `.env.test`, `.env.production` — but **`service-account-key.json` and `users.json` at the repo root are tracked by git anyway**, un-excluded by `.gitignore` and already committed to history (confirmed via `git ls-files`). Treat both as compromised/public credentials from a security standpoint regardless of whether they're removed going forward — git history retains them either way unless history is rewritten, which is a separate, higher-risk operation to weigh deliberately.
- No hardcoded third-party API-key-shaped strings (Firebase `AIzaSy...`, Twilio-style `AC[0-9a-f]{32}`, Stripe-style `sk_live`/`sk_test`) were found outside the expected `firebase_options_*.dart` files, which is normal — Firebase Web/client API keys are not secrets by design and are meant to be embedded in client code; their protection comes from Firestore/Storage security rules, not key secrecy.

## Repository Hygiene (new finding, affects deployment and clone/CI cost)

**`node_modules/` is committed to git.** `.gitignore` has no entry for `node_modules` anywhere, and `git ls-files` confirms **44,828 tracked files** under `node_modules/` and `functions/node_modules/` combined — the entire installed dependency tree for both the root `package.json` and `functions/package.json` is checked into source control. This is not a security issue by itself, but it is a significant production-configuration problem:
- Every clone of this repository downloads the full dependency tree unnecessarily, on top of `npm install` re-downloading it again for anyone who runs that command.
- Dependency updates become enormous, unreviewable diffs.
- If any dependency ever ships a vulnerability disclosure requiring a version bump, the fix is buried in tens of thousands of changed lines rather than a one-line `package.json` version bump.
- No CI exists to catch this pattern going forward (see `docs/TESTING_STRATEGY.md`).

**Recommend**: add `node_modules/` to `.gitignore` and remove it from version control (`git rm -r --cached node_modules functions/node_modules`) as a housekeeping task — this is a repository-hygiene fix, not a feature change, and carries low risk, but is explicitly **not done in this audit pass** per the "do not modify during the audit" instruction.

## App Identifiers / Platform Builds

- **No `android/` or `ios/` platform directories exist in this checkout.** This repository, as checked out, only supports building for Web (`flutter build web`, `flutter run -d chrome`) — there is no Android `applicationId`, no iOS `bundleId`, no platform-specific signing/release configuration to audit, because the platform projects themselves don't exist here. **UNKNOWN — REQUIRES VERIFICATION**: whether mobile builds are out of scope for this product entirely, or whether the `android/`/`ios/` directories exist in a different checkout/branch and simply aren't present in this one (they can be regenerated via `flutter create .` if intended, but that would need review of what it produces before committing).
- `web/index.html`/`web/manifest.json` exist; no placeholder text (`TODO`, `your-`, `example.com`) was found in `index.html`.

## Logging / Analytics / Crash Reporting

- **No crash-reporting or analytics package** (`firebase_crashlytics`, `firebase_analytics`, Sentry, or equivalent) is listed in `pubspec.yaml`. In production, a crash or unhandled exception in the field would be invisible to the team unless a user reports it manually — there is no automated visibility into runtime failures.
- Logging is `print()`/`debugPrint()` throughout (686 call sites across 51 files per the earlier bug-hunt pass), not gated by `kDebugMode`, meaning verbose debug output ships to production console output on every build. A dedicated `lib/core/utils/app_logger.dart` exists but is used in only 2 places.
- `EnvironmentConfig.enableCrashReporting` (`lib/config/environment_config.dart`) returns `true` for production and UAT — but since no crash-reporting package is actually integrated, this flag currently has nothing to turn on; it's a placeholder for a feature that was never wired up.

## Release Configuration

- `debugShowCheckedModeBanner` is correctly suppressed based on environment (`!EnvironmentConfig.isProduction`) in the real entry points.
- No obfuscation/build-mode-specific configuration was found beyond Flutter's own defaults for `flutter build web --release`.

## Summary of Configuration Risks

1. **No crash reporting/analytics** — production issues are invisible unless self-reported.
2. **`node_modules` committed to git** — repo hygiene, clone-time, and update-review cost.
3. **Committed credential files** (`service-account-key.json`, `users.json`) — treat as compromised.
4. **`npm run lint` is broken** — the linting step in `functions/package.json` cannot actually run.
5. **Cloud Functions build process is Windows-specific** — fragile for any non-Windows contributor.
6. **No CI** — none of the above would be caught automatically before a deploy.
7. Mobile platform build readiness (Android/iOS) is unconfirmed — the platform directories don't exist in this checkout.
