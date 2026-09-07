# A03S1 FIX — ComputeGeom monitor enumeration blocker

- Status: `READY`
- Run ID: `RUN-20260907-OPENCODE-MUSE13-A03S1-FIX-01`
- Eligible: `OPENCODE-MUSE13`
- Required model: `Muse Spark 1.3 Contributor Free`
- Session: `NEW`
- Base: `700f033cc2700dcdbb6c9fbd387e2e44b8510ef8`
- Branch: `fix/a03s1-monitor-enumeration-muse13`
- Review input: `docs/agent-reports/2026-09-07-opencode-muse13-a03s1-review.md`

## Goal
Fix only blocker B1 found by the independent A03S1 review: `ComputeGeom` must push every monitor returned by `MonitorGetCount()` into the monitor array before calling the pure geometry plan. Preserve all other A03S1 behavior.

## Required scope
- Correct the AHK v2 loop body so `MonitorGet(...)` and `monitors.Push(...)` execute for every monitor.
- Do not redesign geometry policy, wrapper signatures, parking behavior, edge logic, or module ownership.
- Do not touch unrelated production files.
- Add the smallest regression coverage that would fail for the broken one-monitor-array adapter shape. Prefer production-direct behavior if feasible without GUI/VM dependence; if the AHK built-ins prevent deterministic direct adapter testing, add the narrowest structural regression pin and explicitly document that limitation rather than inventing a fake behavioral test.

## Verification
- Compare exact Base -> fix diff and keep scope minimal.
- Run bounded `/Validate` x64 and x86 for `src/drawer.ahk` and `src/WindowGeometry.ahk`.
- Run `test/narrow/window-geometry-seam.ahk` with bounded timeout and record exact count/exit.
- Explicitly inspect for duplicate declarations between `src/drawer.ahk` and `src/WindowGeometry.ahk`.
- `git diff --check`; `src/config.ini` untouched.

## Completion
- Report Code SHA and report-tip SHA separately.
- Report to `docs/agent-reports/2026-09-07-opencode-muse13-a03s1-fix.md`.
- Update claim `DONE`/`BLOCKED`, explicit push, verify remote, clean tree.
- Do not accept/promote/merge.
- After DONE, fresh-fetch current board and continue to the next READY `OPENCODE-MUSE13` task in board order.
