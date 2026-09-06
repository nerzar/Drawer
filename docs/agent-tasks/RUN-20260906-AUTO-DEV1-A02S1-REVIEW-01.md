# A02S1R — independent review of watcher policy/state seam

- Run ID: `RUN-20260906-AUTO-DEV1-A02S1-REVIEW-01`
- Eligible: `DEV1`
- Base / reviewed Code SHA: `ac71581b98a58e51128a987d20d8b5b1952c1756`
- Source branch: `refactor/window-focus-watch-seam`
- Output branch: `review/a02s1-window-focus-watch-seam`

## Goal
Independently review A02S1 extraction for behavior preservation and seam quality. Repo/GitHub-only; do not implement fixes.

Review specifically:
1. Verify watcher membership/policy extraction preserves accepted G03 behavior, including activateOnShow=false, explicit FocusWindow enrollment, duplicate HWND permanent-first authority, stale/deployed filtering, timer start/stop/re-arm, and unrelated Apply behavior.
2. Check ownership boundaries: WindowFocus.ahk should own watcher policy/state without accidentally absorbing geometry, parking, slot authority, Settings persistence, tray, or unrelated behavior.
3. Inspect adapters/call sites in drawer.ahk for ordering changes, duplicated state, hidden globals, lifetime/init hazards, or circular coupling.
4. Evaluate new production-direct narrow tests and identify remaining copied-model/static checks that could mask divergence.
5. Investigate the reported settings-seam direct-run timeout from the diff/code perspective; classify as likely pre-existing harness behavior vs regression where evidence allows, without claiming runtime execution.
6. Verify scope and unrelated changes.

## Output
Create `docs/agent-reports/2026-09-06-chatgpt-dev1-a02s1-review.md` with findings by severity, exact file/function references, and verdict `ACCEPT`, `ACCEPT_WITH_RUNTIME_CHECK`, `NEEDS_FIX`, or `BLOCKED`. No production edits.

Follow current AGENT_BOARD autonomous claim/ref-hygiene protocol. One Run ID = one branch. Push report-only output branch explicitly and update claim to DONE/BLOCKED.
