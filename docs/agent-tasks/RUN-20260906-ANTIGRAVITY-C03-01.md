# TASK C03 — partial/retryable/diagnostics correctness

- Run ID: `RUN-20260906-ANTIGRAVITY-C03-01`
- Executor: Antigravity
- Model: `Claude Sonnet 4.6 (Thinking)`
- Exact feature base: `dev/integration/slots-settings-wave4@e4136c577d52e2fbf0b57d65b8344809236d5985`
- Branch: `fix/settings-partial-retry-diagnostics`
- Worktree: `C:\Users\nerza\Projects\drawer-agent-worktrees\C03`
- Parallel with: P02 promotion by ChatGPT DEV-1

## Why parallel is safe
P02 only promotes the already accepted Wave 4 into `dev/wip/slots-parity` and synchronizes the integration checkout; it must not change product/runtime/frontend semantics. C03 starts directly from the exact accepted Wave 4 SHA and works in a separate sibling worktree/branch. Do not edit `AGENT_BOARD.md` or P02 task/report files.

## Goal
Fix Settings partial/retryable/diagnostics correctness end-to-end. Structured partial-save/reload/reconcile outcomes must reach the UI without false `Сохранено`, without losing retryable draft/field diagnostics, and without warnings disappearing after a no-op/reconcile path. Preserve one persistence path rather than adding a parallel save mechanism.

## Required investigation before edits
1. Trace the current Apply/save path from Vue draft -> bridge -> AHK/backend result -> reload/reconcile -> UI status/diagnostics.
2. Identify every place where a structured partial/retryable result is collapsed to boolean/success or overwritten by subsequent reload/no-op state.
3. Confirm existing wire/result contracts and tests before choosing the smallest fix.
4. If the actual contract is ambiguous and a product decision is required, stop `BLOCKED` rather than inventing behavior.

## Required behavior
- Full success may show `Сохранено` only when the persisted/reloaded canonical state confirms success.
- Partial/retryable save must remain visibly non-successful and expose the relevant warning/field diagnostics to the user.
- Retryable draft values must not be silently discarded by reload/reconcile.
- A subsequent no-op/reconcile must not erase an unresolved warning merely because no new write occurred.
- Successful retry should clear resolved diagnostics and converge draft/canonical state normally.
- Cancel/reload semantics must remain consistent with existing product behavior.
- Keep a single persistence path; do not add a second ad-hoc save endpoint or duplicate backend logic.

## Scope
Change only files actually needed in Settings save/result/reconcile/diagnostics path and targeted tests. Backend/AHK changes are allowed only when tracing proves the structured result is lost there.

Do not:
- redesign Slots/General UI;
- fix the known narrow `Использовать общие настройки` visual debt;
- change hotkey contract;
- change picker identity behavior from G02/A01FIX;
- take G03/F12 or unrelated backlog work;
- edit `AGENT_BOARD.md` / `docs/ARCHITECT_STATE.md`;
- merge/promote to wip.

## Verification
Add targeted regression coverage for at least:
1. full success;
2. partial/retryable result does not become false success;
3. retryable draft/field diagnostic survives reload/reconcile as intended;
4. unresolved warning survives no-op/reconcile;
5. successful retry clears resolved diagnostic and converges state.

Then run relevant gates:
- `AutoHotkey64.exe /validate src/drawer.ahk` if AHK touched;
- `AutoHotkey64.exe test/narrow/settings-seam.ahk` if bridge/backend/settings contract touched;
- `npm --prefix settings-ui test`;
- `npm --prefix settings-ui run typecheck`;
- `npm --prefix settings-ui run build`.

No VM/full suite unless the implementation reveals a concrete reason.

## Completion
Factual report per `docs/agent-reports/REPORT_FORMAT.md` -> commit -> push `dev/fix/settings-partial-retry-diagnostics` -> verify remote HEAD = local HEAD -> clean tree.

Report must explicitly state:
- root cause(s);
- exact structured result fields/contract preserved;
- how draft/canonical/diagnostics behave for partial, retry, no-op and eventual success;
- tests added and gate results;
- any overlap risk with Wave 4/P02.

If blocked, preserve safe state, report `BLOCKED`, push only safe work, and stop.