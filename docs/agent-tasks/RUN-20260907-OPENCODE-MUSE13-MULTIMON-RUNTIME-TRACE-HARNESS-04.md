# RUN-20260907-OPENCODE-MUSE13-MULTIMON-RUNTIME-TRACE-HARNESS-04

- Status: `READY`
- Eligible: `OPENCODE-MUSE13`
- Required model: `Muse Spark 1.3 Contributor Free`
- Session: `NEW`
- Base/Code SHA: `cd6dc00b3d58c6abea709687618ea3702432bc45`
- Accepted comparison: `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`
- Rejected semantic fix: `073a9e649bb85b4766acec33e49f975d5444a140`
- Branch: `diag/multimon-runtime-trace-harness-muse13`

## Goal
Build a bounded diagnostic/test harness that can capture the real dual-monitor runtime sequence behind the user's wrong animation origin / transient disappearing handle without changing Drawer production behavior.

## Product contract — immutable
For `monitor: cursor`, managed windows and handles follow the current cursor monitor. `Show()` and handle sync must resolve the live cursor monitor. Do not pin, suppress animation, recreate handles on monitor change, alter timing, or otherwise change existing behavior in this task.

## Evidence context
- Static reconciliation closed `5ed8b9a` as a live candidate defect: `26b1133` fixes its brace bug inside `cd6dc00`.
- Accepted `6bfa010` and failed candidate `cd6dc00` have statically equivalent geometry, Show staging, handle lifecycle and naked cursor resolve on the relevant paths.
- Antigravity's proposed destroy-on-monitor-change and cross-monitor slide suppression would change accepted behavior and are NOT authorized.
- Therefore the next useful artifact is runtime observability, not another speculative fix.

## Required
1. Fresh-fetch; verify exact SHAs and branch from `cd6dc00`.
2. Add only diagnostic/test tooling under `test/` (and docs if needed). Do NOT edit `src/` or production config/default behavior.
3. Reuse existing VM/runtime harness where practical. Instrument or wrap the scenario so one run can record, with timestamps/order:
   - cursor coordinates and resolved monitor immediately before handle sync / deploy trigger;
   - handle key/monitor/rect before and after cursor crosses monitors;
   - target monitor and computed `slide`, `hx/hy`, `sx/sy` for Show;
   - actual window rect before first move, after staging move, and after animation;
   - foreground/focus transition relevant to Show/Hide;
   - whether handle GUI exists/visible and its rect during migration.
4. The harness must be capable of running the same scenario against exact `6bfa010` and `cd6dc00` without modifying production source. If a small test-only adapter/seam is necessary, keep it isolated and explain why it does not alter shipping code.
5. Provide a deterministic operator recipe for the real two-monitor topology, including what constitutes PASS/FAIL for wrong-origin and handle disappearance.
6. Where feasible, run bounded checks that the harness itself parses/loads and that existing narrow tests still pass. Do not claim dual-monitor reproduction if the environment cannot genuinely execute it.
7. Add a negative source assertion that rejects `073a9e6`-style managed-monitor pinning, but do not use that assertion as proof of the unresolved runtime bug.
8. Report exact files changed, commands, limitations, and whether the artifact is `READY_FOR_RUNTIME_CAPTURE` or `BLOCKED`.

## Deliver
- Test/diagnostic Code SHA on `diag/multimon-runtime-trace-harness-muse13`.
- Report under `docs/agent-reports/`.
- Claim updated DONE/BLOCKED on shared board ref.
- Verdict `READY_FOR_RUNTIME_CAPTURE` only if the harness can capture accepted-vs-candidate runtime evidence without production behavior changes.

No production fix, no merge, no promotion, no candidate assembly.