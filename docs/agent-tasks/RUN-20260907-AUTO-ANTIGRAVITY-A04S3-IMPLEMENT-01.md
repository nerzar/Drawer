# A04S3 — handle runtime synchronization and click seam

- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-A04S3-IMPLEMENT-01`
- Eligible: `ANTIGRAVITY`
- Preferred model: Gemini available in Antigravity; Claude allowed only if Gemini unavailable
- Session: `NEW`
- Dependency: A04S2 must be DONE with pushed Code SHA. Use that exact Code SHA as base; do not use report-tip SHA.
- Branch: `refactor/window-handles-runtime-sync`
- Worktree: `C:\Users\nerza\Projects\drawer-agent-worktrees\A04S3`

## Goal
Finish the handles extraction by moving the remaining live handle runtime synchronization/click behavior out of `src/drawer.ahk` into the existing production `WindowHandles.ahk` seam created by A04S1/A04S2, preserving behavior exactly.

Human meaning: the edge handle must continue to appear/disappear/update with its Drawer window and clicking it must restore/show the correct window without stealing focus or changing timing semantics.

## Scope
Start from the exact pushed A04S2 Code SHA. Inspect the accepted A04 analysis/report and actual A04S1/A04S2 code before editing. Move only the remaining handle-specific runtime ownership needed for:
- handle show/hide/update/synchronization with deployed window state;
- mapping handle GUI/HWND back to its owning Drawer window/slot where currently required;
- click dispatch behavior and existing asynchronous timing semantics;
- cleanup of handle runtime state when the owning window/slot is released/destroyed/reconciled.

Keep orchestration adapters in `drawer.ahk` only where they genuinely belong outside the handle module.

## Must preserve
- `WS_EX_NOACTIVATE` / no focus stealing;
- existing async click dispatch semantics (`SetTimer` or equivalent existing behavior), no synchronous behavioral rewrite;
- base/rest geometry ownership and no-jitter behavior from A04S1/A04S2;
- icon/resource ownership and cleanup semantics established by A04S2;
- permanent/dynamic slot authority unchanged;
- no changes to WindowFocus, WindowGeometry, Settings persistence, parking policy, animation, hotkey semantics, config format or UX;
- no generic event bus/DI/framework layer.

## Tests / gates
Add or extend production-direct narrow coverage for the runtime seam where deterministic: owner mapping, show/hide/update state transitions, cleanup/idempotence, and click dispatch contract. Avoid copied models/static source-shape assertions when direct production seam coverage is possible.

Run at minimum x64 `/Validate src/drawer.ahk`, targeted handle narrow tests, and cheap directly affected deterministic gates. If real GUI/runtime behavior cannot be fully exercised in the narrow harness, report the exact remaining runtime verification requirement instead of claiming it tested.

## Git / report
Follow current AGENT_BOARD, claim protocol, Critical Git ref hygiene and REPORT_FORMAT. One Run ID = one branch. Do not modify AGENT_BOARD or ARCHITECT_STATE. Production/test commit first and record its Code SHA separately from report-tip SHA. Push explicitly to `dev` `refs/heads/refactor/window-handles-runtime-sync`, verify remote contains Code SHA, leave clean tree, update claim DONE/BLOCKED.

Report: `docs/agent-reports/2026-09-07-antigravity-a04s3.md`.
