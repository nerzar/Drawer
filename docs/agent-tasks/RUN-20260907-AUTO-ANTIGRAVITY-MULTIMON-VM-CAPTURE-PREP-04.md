# Dual-monitor runtime capture prep / execution

- Status: `READY`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-MULTIMON-VM-CAPTURE-PREP-04`
- Eligible: `ANTIGRAVITY`
- Preferred model: `Gemini 3.8 Flash (Medium)`
- Session: `NEW`
- Accepted baseline: `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`
- Failed candidate: `cd6dc00b3d58c6abea709687618ea3702432bc45`
- Rejected semantic fix: `073a9e649bb85b4766acec33e49f975d5444a140`
- Branch: `diag/multimon-vm-runtime-capture-antigravity`

## Goal
Use the existing Drawer VM/test infrastructure to produce genuine dual-monitor runtime evidence comparing the exact accepted and failed SHAs, without changing product behavior. If the environment can execute the capture now, do so; otherwise leave a fully runnable bounded capture procedure/harness and report the exact blocker.

## Required
- Fresh fetch; read board/task/report format and inspect existing `test/vm`, `run-in-vm.ps1`, dual-monitor setup notes, prior VM artifacts and current runtime tooling.
- Verify whether a two-monitor Windows VM or equivalent runtime is actually available. Do not call static reasoning a runtime result.
- Reproduce the user contract: `monitor: cursor` must dynamically follow the live cursor monitor.
- Run the same scenario on accepted `6bfa010` and failed `cd6dc00`: bind/manage a window, move cursor across monitors while hidden/managed, observe handle move/lifecycle, deploy from monitor 2/internal edge, and capture animation/staging origin.
- Capture exact topology/coordinates, cursor monitor, handle rect/lifecycle, Show/Hide/Toggle timing, computed geometry, actual window rects and focus sequence where the tooling allows.
- If Muse's trace harness branch appears during this run, you may consume it only after verifying its exact Code SHA and scope; do not wait indefinitely for it.
- Test/diagnostic changes only. No `src/` behavior changes and no product fix.

## Deliver
Report `docs/agent-reports/2026-09-07-antigravity-multimon-vm-runtime-capture.md` with one verdict:
- `RUNTIME_DELTA_PROVEN` — only with a concrete accepted-vs-failed behavioral/log delta and exact reproduction;
- `READY_FOR_RUNTIME_CAPTURE` — harness/procedure is ready but execution requires user/VM action;
- `BLOCKED_RUNTIME_ENV` — environment cannot provide the evidence, with exact blocker.

Include commands, topology, artifacts/paths, per-SHA result table, and any first-bad boundary justified by actual runtime evidence. No fix/promotion/merge. After DONE/BLOCKED, fresh-fetch and stop unless architect publishes another READY task.
