# G03ACCEPT — runtime acceptance of corrected live hideOnBlur/blurMs watcher logic

- Run ID: `RUN-20260906-ANTIGRAVITY-G03ACCEPT-01`
- Executor: Antigravity
- Model: Claude Sonnet 4.6 Thinking
- Canonical corrected G03 Code SHA: `5a779c736fb562d11e1d617ce32adb1210743c1d`
- Prior review: G03R found watcher-authority regressions; Codex G03FIX reports them fixed
- Output branch: `verify/g03-runtime-acceptance`

## Goal
Perform a focused real-Windows/runtime acceptance of corrected G03 behavior at Code SHA `5a779c736fb562d11e1d617ce32adb1210743c1d`. This is verification first, not implementation. Do not change production code unless a reproducible runtime bug is found.

## Required manual/runtime scenarios
1. `activateOnShow=false`, `hideOnBlur=true`: normal show, then unrelated Settings Apply, then focus elsewhere. Window must NOT become newly auto-hidden merely because Apply ran.
2. `activateOnShow=false`: invoke the explicit focus action/hotkey that legitimately activates/watches the window; after unrelated Apply, that valid watched state must remain correct.
3. Already shown/activated window: Apply `hideOnBlur true -> false` and `false -> true`; both directions must take effect live without rebind/restart.
4. Change `blurMs` fast->slow and slow->fast while watcher is active; verify actual observed timer/focus behavior follows the new delay, not stale cadence.
5. Duplicate HWND represented by permanent + temporary/dynamic slot with conflicting hideOnBlur if safely reproducible: permanent-slot authority must win. If reproducing this state safely is impractical, document exactly why and rely on code/seam evidence for that one scenario.
6. Verify no visible regression in General save lock: controls lock during Apply and unlock after success/error.

## Constraints
- Use a dedicated sibling worktree based exactly on corrected Code SHA.
- Do not disturb another running Drawer instance without first checking processes/worktrees. If operator-owned instance would be disrupted, stop it only if task can do so safely and restore state; otherwise BLOCK the specific runtime scenario, not the whole task if remaining checks can run.
- Do not modify `src/config.ini` except through normal Settings behavior needed for the scenario; restore test values afterwards.
- No broad refactor, no UX changes.

## If all scenarios pass
Create a report-only branch `verify/g03-runtime-acceptance` with verdict `ACCEPT` or `ACCEPT_WITH_LIMITATION` and exact scenarios/results. No production code commit.

## If a runtime bug appears
Reproduce minimally, capture exact steps/result, then either make the smallest scoped fix on a separate code commit in this same branch if unambiguous, or stop `BLOCKED` if architectural/product choice is required. Run relevant AHK/settings tests after any code change.

## Completion
Report per REPORT_FORMAT using corrected Code SHA as review identity and separate Report tip SHA. Push/verify remote. Final: Run ID, DONE/BLOCKED, branch, reviewed/final Code SHA, report tip SHA, verdict, checks/scenarios.