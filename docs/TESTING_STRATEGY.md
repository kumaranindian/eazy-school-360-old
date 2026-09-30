# Eazy School 360 — Testing Strategy

Part of the Production Readiness Audit. See `docs/README.md` for the document index.

## Current State (as found)

| File | Test cases | What it actually tests | Hits real Firestore? |
|---|---|---|---|
| `test/finance/fee_payment_flow_test.dart` | 53 | Pure logic helpers mirroring the fee-payment screen (balance lookup by fee type, amount validation, update-map construction) — unit tests of extracted logic, not the screen itself. | No |
| `test/finance/bill_and_payment_test.dart` | 42 | Similar pattern — bill/payment domain logic in isolation. | No |
| `test/finance/financial_reports_screen_test.dart` | 21 | Report calculation logic. | No |
| `test/widget_test.dart` | 1 | The default Flutter-generated counter-app smoke test, referencing `MyApp` — **this class doesn't exist in `lib/main.dart`** (the real class is `EazySchool360App`), so this test would fail to compile/run as-is. It's also marked `@TestOn('browser')`, so a plain `flutter test` run skips it silently rather than failing loudly. |

**Total: 116 real test cases, all confined to the finance module's pure logic, zero coverage everywhere else.**

Confirmed absent:
- **No widget/component tests** for any screen (the one `widget_test.dart` that exists is broken/stale).
- **No integration tests** exercising a real Firestore emulator or real navigation flow.
- **No Firestore security-rules tests** (no `@firebase/rules-unit-testing` dependency in `functions/package.json` or root `package.json`, no `*.rules.test.*` files anywhere in the repo).
- **No CI configuration** of any kind (no `.github/workflows/`, no other CI config file found) — so even the 116 tests that do exist are never run automatically; they only run if a developer remembers to run `flutter test` locally.
- **No Cloud Functions tests** — `functions/package.json` lists `firebase-functions-test` as a devDependency, but no test files were found under `functions/` that use it.

## Required Tests by Priority (business-critical first)

### P0 — must exist before production, given what this audit found

1. **Firestore security-rules tests** for tenant isolation specifically: assert that a STAFF/ADMIN token from School A is rejected reading/writing School B's `students`, `leaves`, `leaveBalances`, `fee_structures`, `payment_transactions`, and the two Storage paths flagged in `SECURITY_AUDIT.md` (`teacher_documents`, `leave_attachments`). This is the single highest-value test suite this codebase doesn't have — it would have caught the Storage-rules gap this audit found by hand.
2. **Leave/permission balance idempotency test**: simulate a Cloud Functions trigger retry (call the same `onLeaveStatusChange`/`onPermissionStatusChange` handler twice with the same before/after snapshot) and assert the balance is mutated exactly once. This directly tests the fix applied this session.
3. **Cross-tenant Cloud Function authorization tests**: for each of `approveLeave`/`rejectLeave`/`approvePermission`/`rejectPermission`/`adjustLeaveBalance`/`adjustPermissionBalance`/`mapRfidToStaff`/`listRfidCards`/`unmapRfidCard`, assert an admin from School A gets `permission-denied` when passing School B's `schoolId`.
4. **RFID device registration authorization test**: assert `/register-device` rejects a request with no `Authorization` header, and rejects an admin token from the wrong school.

### P1 — critical business flows

5. Fee calculation correctness: the 53+42 existing finance unit tests are a reasonable start; extend to cover the **two parallel fee-structure systems** explicitly — a test that creates a fee structure via the v2 path and asserts it is (or, more likely, is *not*) visible to a screen reading the legacy path, to make the current inconsistency visible and trackable rather than silently discovered by users.
6. Bill deletion / ledger reversion atomicity: a test that forces the ledger-update step to fail after the bill-delete step succeeds, asserting the whole operation rolls back (this test would currently **fail**, since the code has no rollback — see `SECURITY_AUDIT.md`'s Data Integrity section — which is exactly why the test is valuable to write now, as a regression guard for whenever that bug is fixed).
7. Receipt/bill numbering under concurrency: a test that calls `getNextBillId()` (or the receipt-counter transaction) from two simulated concurrent requests and asserts no duplicate ID is produced — the Invoice/Receipt audit found the bill-ID scheme is a plain max+1 query, not a transaction, so this test would currently **fail** for bills (while the receipt-counter transaction should pass).
8. Attendance → parent-portal consistency: a test asserting that a student marked absent by an admin is visible as absent in the parent-facing attendance view, sourced from the same underlying record.

### P2 — important but not launch-blocking

9. Widget tests for the core CRUD screens per module (student, staff, fee structure) covering loading/empty/error states specifically, since those states were not systematically verified in this audit (see `docs/FEATURE_READINESS_MATRIX.md`).
10. WhatsApp notification send-path tests, at minimum asserting `sendPaymentNotification` goes through the Cloud-Function proxy and `sendFeeDueReminder`/`sendAdminDailySummary` — flagged as calling the Graph API directly from the client — don't leak the access token into any client-visible log or state.

### P3 — nice to have

11. PDF-generation smoke tests (bill/receipt rendering doesn't throw, branding elements present) — lower priority given `loadPdfUnicodeFont()` is already known to be a no-op stub, which is a known, documented limitation rather than something a test would newly reveal.

## Testing Infrastructure Gaps

- No CI: recommend adding a minimal workflow that runs `flutter test` and `functions: npm run build && node --check` on every push, even before expanding test coverage — this alone would have caught the `test/widget_test.dart` compile break and the `functions/package.json` `npm run lint` config gap (no `.eslintrc*` file exists despite `eslint` being a devDependency — confirmed this session; `npm run lint` currently fails outright with "ESLint couldn't find a configuration file").
- No Firestore emulator usage anywhere in the existing test setup — all 116 existing tests avoid Firestore entirely by testing extracted pure functions. This is a reasonable unit-testing choice but means there is currently zero automated coverage of the actual Firestore read/write paths, rules, or transactions that most of this audit's findings concern.
