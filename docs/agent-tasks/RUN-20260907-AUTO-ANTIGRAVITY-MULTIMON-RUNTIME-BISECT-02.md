# Live multi-monitor regression bisection — preserve cursor-follow contract

- Status: `READY`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-MULTIMON-RUNTIME-BISECT-02`
- Eligible: `ANTIGRAVITY`
- Preferred model: `Gemini 3.8 Flash (Medium)`
- Session: `NEW`
- Accepted behavioral baseline: `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`
- Failed integrated candidate: `cd6dc00b3d58c6abea709687618ea3702432bc45`
- Rejected semantic FIX: `073a9e649bb85b4766acec33e49f975d5444a140` — DO NOT use as desired behavior; it incorrectly pins managed windows to a monitor.
- Branch: `analysis/multimon-runtime-bisect-02-antigravity`

## Product contract confirmed by user
For slots configured `monitor: cursor`, the historical/desired behavior is dynamic:
- moving the cursor to another monitor moves the active edge handle/kromka to that monitor;
- deploying the slot opens the bound window on the monitor under the cursor;
- this remains true after the window is already bound/managed.
Do NOT pin a managed slot/window to the monitor where it was bound. The Muse pinning change `073a9e6` violates product behavior and is rejected.

## Current user failures on rejected retest
- VS Code bound on monitor 2 stayed there; neither edge nor window followed cursor — confirmed semantic regression from `073a9e6`.
- Another bound app could open on monitor 2 while animation visibly started on monitor 1.
- VS Code bound on monitor 1 could deploy on monitor 2 with animation beginning on monitor 1.
- Previous failed candidate also had transient disappearing edge.

## Goal
Find the real regression(s) between accepted `6bfa010` and candidate `cd6dc00` while preserving the dynamic `monitor: cursor` contract. Prefer live dual-monitor reproduction/bisection using the project's existing VM/test infrastructure if available. Determine exact first bad commit(s) for wrong animation origin and disappearing edge. Explicitly separate intended monitor-follow behavior from bugs.

## Required
- Verify accepted `6bfa010` behavior/code contract first.
- Test/bisect the integrated sequence between `6bfa010` and `cd6dc00` at meaningful commits (focus, geometry, geometry fix, handles S1/S2/S3) on real/simulated dual-monitor runtime where possible.
- Capture monitor topology, cursor monitor, resolved mi, geometry `sx/sy/hx/hy/px/py/slide`, window position before Show, and handle group before/after sync.
- Check animation staging/visibility semantics: whether `WinMove(hx)` can render on neighbor even when final target monitor is correct.
- Check disappearing-handle path independently under dynamic cursor-follow; it is valid for handle to MOVE monitors, but not to vanish beyond a normal transition.
- Inspect integration conflict resolutions and extraction behavior for semantic drift.

## Deliver
Exact first bad commit/lineage per symptom, evidence from runtime or bounded probes, smallest fix preserving cursor-follow semantics, regression-test plan that distinguishes accepted behavior from both `cd6dc00` and rejected `073a9e6`, verdict `READY_FOR_FIX` or `BLOCKED_NEEDS_USER_RUNTIME`.

Analysis/report only. No production/test edits, no promotion. Report: `docs/agent-reports/2026-09-07-antigravity-multimon-runtime-bisect-02.md`.
