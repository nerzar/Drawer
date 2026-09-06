# TASK A01FIX — manual acceptance hotkey + Reset-to-General fixes

**Status:** READY
**Run ID:** `RUN-20260906-ANTIGRAVITY-A01FIX-01`
**Executor:** Antigravity
**Model:** Gemini 3.8 Flash High
**Base:** current `dev/wip/slots-parity`
**Branch:** `fix/a01-hotkey-reset-general`
**Worktree:** `C:\Users\nerza\Projects\drawer-agent-worktrees\A01FIX`

Read `AGENT_BOARD.md` and `docs/agent-reports/REPORT_FORMAT.md` first. This task record is the architect-approved A01 correction task. Do not integrate G02 or take C03/G03.

## BUG 1 — hotkey cycle breaks

Manual A01 reproduction:
1. Slot 1 starts with `Ctrl+Alt+1` and it works.
2. Change to `Ctrl+Z`, Apply. `Ctrl+Z` works.
3. Settings shows: `Parameter #1 of Integer.Call requires a Number, but received an empty string.`
4. Change hotkey back to `Ctrl+Alt+1`, Apply.
5. `Ctrl+Alt+1` no longer works.

Expected contract: `A -> B -> A` must work. After every successful Apply only the currently configured show/hide hotkey is active; a previously unregistered hotkey must be registerable again. No `Integer.Call(empty string)` error.

Find the actual root cause across parsing/normalization, save/apply, unregister/register and rollback/error paths. Do not hide the exception in frontend and do not special-case Ctrl+Alt+1. Add regression coverage for the complete `A -> B -> A` lifecycle and the empty-string failure.

## BUG 2 — Reset-to-General functional bug + action-bar layout

Manual A01 observations:
- top action bar does not fit at the real settings window width; `Освободить слот`, `Сбросить к General`, `Сделать постоянным...` are cramped/overlap;
- `Сбросить к General` does not work;
- separate `Сбросить слот` does work.

First establish the actual semantics in code. Reset-to-General must remove the selected slot's individual overrides and restore inheritance from General without releasing the slot or destroying its identity.

Fix the functional path and the layout. Do not merely squeeze three long buttons. Prefer placing this per-slot override action near the override settings/indicator rather than in the crowded top action bar. A clearer label such as `Использовать общие настройки` is acceptable only if it matches the real semantics. Keep Release and Permanent/Dynamic actions obvious. No full SlotsView redesign.

## Scope

Change only what is necessary in slot settings frontend/bridge/styles, corresponding AHK/backend hotkey/reset path if root cause is there, and targeted tests. Preserve the product hotkey contract: one configurable show/hide hotkey per slot. Do not change unrelated General/animation behavior.

## Verification

Required:
- regression for `Ctrl+Alt+1 -> Ctrl+Z -> Ctrl+Alt+1`;
- current hotkey works after every Apply and previous one is inactive;
- no `Integer.Call(empty string)`;
- Reset-to-General regression;
- `npm --prefix settings-ui test`;
- `npm --prefix settings-ui run typecheck`;
- `npm --prefix settings-ui run build`;
- if AHK/backend touched: AHK validate + settings-seam.

VM/full suite are not required.

Before completion: factual report -> commit -> push `dev/fix/a01-hotkey-reset-general` -> verify remote HEAD == local HEAD -> clean tree.

Report must explicitly state: root cause of `Integer.Call(empty string)`; why `Ctrl+Alt+1` failed to register again; root cause of Reset-to-General; regression coverage added.