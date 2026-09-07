# Narrow FIX — stabilize monitor identity in failed manual candidate

- Status: `READY`
- Run ID: `RUN-20260907-OPENCODE-MUSE13-MANUAL-MULTIMON-FIX-01`
- Eligible: `OPENCODE-MUSE13`
- Required model: `Muse Spark 1.3 Contributor Free`
- Session: `NEW`
- Base: failed candidate Code SHA `cd6dc00b3d58c6abea709687618ea3702432bc45`
- Source branch: `integration/manual-candidate-20260907`
- Branch: `fix/manual-multimon-monitor-identity-muse13`

## Evidence
Independent Antigravity and Muse analyses converge on the residual runtime defect after `26b1133`: `monitor: "cursor"` is re-resolved independently by live cursor sampling in both handle sync and show/deploy paths. A managed window/handle can therefore change monitor identity merely because the cursor moved between sync and activation, causing wrong-monitor deployment origin and transient handle destruction/recreation. Both analyses also agree the earlier `5ed8b9a` missing-braces geometry defect was real but is already fixed in candidate by `26b1133`; do not regress that fix.

Reports:
- `docs/agent-reports/2026-09-07-antigravity-manual-multimon-failure-analysis.md`
- `docs/agent-reports/2026-09-07-opencode-muse13-manual-multimon-analysis.md`

## Goal
Implement the smallest safe production fix that stabilizes monitor identity for an already managed/bound window while preserving intended first-bind / explicit cursor-monitor behavior. Prevent handle hopping/disappearance and wrong-monitor Show/deploy caused only by incidental cursor motion.

## Required behavior
- A bound, managed window must not migrate monitor assignment solely because the mouse crosses to another monitor.
- `HandlesSync` must anchor monitor resolution to the managed window/current stable geometry when available, rather than naked live `ResolveMonitor(s.cfg)` for every tick.
- `Show` must use a monitor identity consistent with the managed window/slot state; do not independently re-sample the cursor in a way that disagrees with the handle/runtime state.
- Preserve intentional monitor selection for first capture/bind and any existing explicit rebind/move contract. Do not invent a new UX.
- Preserve `26b1133` multi-monitor collection braces and internal-edge collision behavior.
- Do not change Settings behavior, focus contracts, config format, hotkeys or unrelated refactors.

## Regression coverage
Add narrow regression coverage that fails on `cd6dc00` and passes with the fix. At minimum cover:
1. managed window physically/geom anchored on monitor 2 + `monitor: cursor`; moving simulated cursor to monitor 1 does NOT regroup/destroy its handle to monitor 1;
2. Show/deploy for that managed window keeps monitor 2 despite cursor drift between sync and activation;
3. first/unmanaged cursor-based resolution still follows cursor as before;
4. internal-edge geometry still disables slide when pocket overlaps neighboring monitor;
5. existing focus/settings/handles/geometry seams remain green.

If current architecture makes a pure deterministic test impossible without broad production changes, add the smallest injectable/helper seam needed, but do not redesign the subsystem.

## Gates
- `/Validate` x64/x86 for `src/drawer.ahk`, `src/WindowHandles.ahk`, `src/WindowGeometry.ahk` and any touched module.
- relevant narrow seams including new monitor-identity regression; repeat flaky/timer-sensitive seam at least 3x.
- `git diff --check` clean; `src/config.ini` untouched.

## Deliver
- exact root cause addressed and contract chosen;
- Code SHA;
- checks/results;
- report `docs/agent-reports/2026-09-07-opencode-muse13-manual-multimon-fix.md`;
- verdict `READY_FOR_INDEPENDENT_VERIFY` or `BLOCKED`.

## Constraints
This is a narrow fix, not acceptance/promotion. Do not start A03S2/A03S3/A05, do not merge/promote candidate, do not clean foreign refs/worktrees. After DONE/BLOCKED, fresh-fetch and STOP unless architect has published another explicit READY task.
