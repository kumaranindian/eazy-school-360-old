# Eazy School 360 — Deployment Checklist

Part of the Production Readiness Audit. See `docs/README.md` for the document index. This checklist reflects what this audit actually found — it is not a generic template. A pre-existing `DEPLOYMENT_CHECKLIST.md` at the repo root predates this audit and may contain additional environment-specific steps (Firebase console clicks, DNS, etc.) not re-verified here; treat this document as the production-readiness gate, and the root-level one as the operational how-to once that gate is passed.

## Do not deploy to production until:

### Blockers (P0 from the Gap Register)
- [ ] GAP-001: Super Admin can activate a newly-signed-up school through the app (currently impossible — **this alone should block launch**, since it breaks new-customer onboarding entirely).
- [ ] GAP-006: Storage rules for `teacher_documents` and `leave_attachments` are scoped by school (currently cross-tenant readable/writable).
- [ ] GAP-007: A decision has been made and communicated on the two parallel fee-structure systems — at minimum, staff must be told which one is authoritative to avoid entering data that silently doesn't appear elsewhere.
- [ ] GAP-008: Bill deletion either has its atomicity fixed, or staff are explicitly warned that deleting a bill requires manually verifying the student's ledger afterward.
- [x] GAP-002, GAP-003, GAP-004, GAP-005: RFID device-registration bypass, commented-out-auth functions, `setUserClaims` privilege escalation, cross-tenant scoping on 9 Cloud Functions — all fixed this session.
- [x] GAP-012: Leave/permission trigger idempotency — fixed this session.

### Critical (P1) — strongly recommended before launch, not strictly blocking
- [ ] GAP-009: Payroll is reachable (currently a "Coming Soon" stub) — or payroll is explicitly out of scope for launch and stakeholders know it.
- [ ] GAP-010: Razorpay/online payment either works or is explicitly descoped from the launch — currently advertised in the data model but non-functional.
- [ ] GAP-011: Student promotion is reachable — or year-end promotion is planned to be done manually for the first cycle.
- [ ] GAP-013 verified compiler-clean: `flutter analyze` and `flutter test` have been run against the password-logging fix (this audit's environment had no Dart toolchain to verify it directly — see `CLAUDE.md`).
- [ ] GAP-014: Bill numbering collision risk understood by whoever's approving launch, even if not yet fixed.

### Security sign-off
- [ ] `docs/SECURITY_AUDIT.md` reviewed in full; every FAIL row either fixed or explicitly accepted as a known risk by whoever owns that decision.
- [ ] GAP-034: `service-account-key.json` rotated (treat as compromised regardless of whether it's removed from future commits — it's already in git history).
- [ ] Firestore rules deployed from `firebase/firestore.rules` specifically (not the stale root-level copy) — confirm via `firebase firestore:rules:get` against the target project after deploy.
- [ ] Storage rules deployed and the GAP-006 fix (if applied) verified against a real cross-tenant test, not just a code read.

### Environment configuration
- [ ] Confirm the correct entry point is used for the build: `flutter build web --release -t lib/main_prod.dart` — **never** the bare `lib/main.dart` (placeholder project ID) or a dev/test/uat entry point.
- [ ] Confirm `firebase use eazy-school-360` (the prod alias) is active before any `firebase deploy` command.
- [ ] Confirm Cloud Functions were built (`npm run build` in `functions/`) with the `xcopy` step actually run (or its cross-platform equivalent) before `firebase deploy --only functions` — see GAP-024. A stale `functions/lib/` silently ships old logic for the modules routed through it (notably WhatsApp reminders).
- [ ] Confirm all 134 composite indexes in `firebase/firestore.indexes.json` are deployed to the production project specifically, not just dev/test/uat (`npm run deploy-indexes` against the correct `firebase use` target).

### Observability
- [ ] GAP-031: Some form of crash reporting exists, or the team has explicitly accepted launching without it (currently `EnvironmentConfig.enableCrashReporting` is a flag with nothing behind it).
- [ ] A process exists for someone to actually look at Cloud Functions logs (`firebase functions:log`) periodically, given there's no alerting/crash-reporting to push issues to anyone.

### Testing
- [ ] The 116 existing finance unit tests pass (`flutter test test/finance/`).
- [ ] At minimum, the P0 tests described in `docs/TESTING_STRATEGY.md` (Firestore security-rules tests for tenant isolation, the idempotency test, cross-tenant authorization tests, RFID auth test) exist and pass — none of these exist today.
- [ ] Every core business flow in `docs/END_TO_END_FLOW_AUDIT.md` has been manually exercised at least once against a near-production-scale dataset (not just a handful of test records), given the unbounded-query findings in `docs/DATABASE_AUDIT.md`.

### Repository hygiene (non-blocking, but do before the team scales)
- [ ] GAP-025: `node_modules/` removed from git tracking.
- [ ] GAP-033: `functions/`'s ESLint config restored so `npm run lint` actually runs.

## What this checklist deliberately does not cover

This audit did not change any production Firebase configuration, did not run a live deploy, and did not test against a populated dev/test/uat environment (no such environment was reachable from this audit's tooling). Every checkbox above should be independently re-verified by whoever performs the actual deployment, not treated as already confirmed by this document's existence.
