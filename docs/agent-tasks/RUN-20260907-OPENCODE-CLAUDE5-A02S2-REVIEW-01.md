# A02S2R — independent deep review of focus-history / foreground extraction

- Run ID: `RUN-20260907-OPENCODE-CLAUDE5-A02S2-REVIEW-01`
- Eligible: `OPENCODE-CLAUDE5`
- Required model: `Claude 5` (use the exact Claude 5 model exposed by OpenCode; record actual model ID in claim/report)
- Session: `NEW`
- Reviewed Code SHA: `c482ad3ae9c499ea32eb3c0cdd590e495a919e30`
- Source branch: `refactor/window-focus-history-foreground`
- Output branch: `review/a02s2-claude5`
- Base for report-only branch: current shared docs tip from `refs/remotes/dev/wip/slots-parity`; review the exact Code SHA above, not report-tip metadata.

## Goal
Perform a high-confidence independent architectural/code review of A02S2 before architect acceptance/promotion. This is intentionally assigned to a strong reasoning model. Review only; do not implement fixes or self-promote.

## Review questions
1. Prove behavior preservation for focus history and foreground state across show/hide, blur, explicit FocusWindow enrollment, permanent/dynamic slot authority, duplicate HWND handling, reload/reconcile, destroyed windows, and activation failure paths.
2. Check initialization/lifetime/order hazards: module globals, callbacks/timers, startup state, stale HWNDs, reentrancy, state surviving config reload, and any hidden dependency on old `drawer.ahk` globals.
3. Check extraction boundary quality: `WindowFocus.ahk` owns focus/watch/history policy without absorbing geometry, parking, Settings persistence, Slots authority, handles, animation, or unrelated runtime orchestration.
4. Inspect every changed production call site at Code SHA and compare against parent/base behavior. Look specifically for semantic changes hidden by adapter reshaping, argument ordering, default values, truthiness, Map/object aliasing, and mutation order.
5. Evaluate tests: which assertions execute production code directly, what meaningful paths remain uncovered, and whether any copied/static model could allow production divergence.
6. Assess interaction with already-promoted A02S1 and future A03S3. Flag coupling that would make the next geometry extraction unsafe.
7. Verify scope/config hygiene and identify any unrelated changes.

## Evidence / output
Use repository diff/history and task/report evidence. Do not claim Windows runtime execution unless actually performed by this OpenCode environment. If cheap local AHK validation/narrow tests are available, run them; otherwise classify runtime confidence explicitly.

Create `docs/agent-reports/2026-09-07-opencode-claude5-a02s2-review.md` with findings ordered by severity and exact file/function references. Verdict must be one of:
- `ACCEPT`
- `ACCEPT_WITH_RUNTIME_CHECK`
- `NEEDS_FIX`
- `BLOCKED`

If `NEEDS_FIX`, give the smallest concrete fix scope but do not modify production code.

Follow current AGENT_BOARD autonomous claim/ref-hygiene protocol and REPORT_FORMAT. One Run ID = one report-only branch. Push explicitly to `dev` `refs/heads/review/a02s2-claude5`, verify remote, update claim DONE/BLOCKED. Never edit AGENT_BOARD or ARCHITECT_STATE.