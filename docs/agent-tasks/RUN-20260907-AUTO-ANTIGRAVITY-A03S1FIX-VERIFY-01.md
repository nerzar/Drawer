# A03S1 FIX independent verification

- Status: `READY`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-A03S1FIX-VERIFY-01`
- Eligible: `ANTIGRAVITY`
- Preferred model: `Gemini 3.8 Flash (Medium)`
- Session: `NEW`
- Base SHA: `700f033cc2700dcdbb6c9fbd387e2e44b8510ef8`
- Code SHA under verification: `90718c99de1609b40a7b7a8dbe314fbcb2d857dd`
- Source branch: `fix/a03s1-monitor-enumeration-muse13`
- Branch: `verify/a03s1fix-antigravity`

## Goal
Independently verify the Muse A03S1 multi-monitor adapter fix before acceptance/promotion. Verification/report only.

## Required checks
- Fresh fetch; verify exact Base -> Code lineage and changed-file scope.
- Inspect `ComputeGeom` adapter monitor enumeration and confirm the AHK v2 `Loop` body now includes both `MonitorGet(...)` and `monitors.Push(...)` for every monitor.
- Explicitly verify the blocker reproduced by Muse: the new adapter regression must fail on Base `700f033...` and pass on Code SHA `90718c99...`.
- Run bounded x64 and x86 `/Validate` for `src/drawer.ahk`, `src/WindowGeometry.ahk`, and `test/narrow/window-geometry-adapter-seam.ahk` where binaries are available.
- Run `test/narrow/window-geometry-seam.ahk` and the new adapter seam; record exact counts/exits.
- Check for duplicate declarations from `#Include` + stale copies.
- Review multi-monitor semantics for left/right/negative-coordinate layouts and ensure the fix is narrowly scoped to enumeration, not geometry policy drift.
- `git diff --check`; `src/config.ini` untouched.

## Verdict
Return `ACCEPT_CANDIDATE`, `NEEDS_FIX`, or `BLOCKED_REVIEW`.

## Constraints
Do not modify production/test code, accept, promote, merge, or clean unrelated refs. Follow current board claim/ref-hygiene protocol and REPORT_FORMAT. Report to `docs/agent-reports/2026-09-07-antigravity-a03s1fix-verify.md`, update claim DONE/BLOCKED, push and verify remote, leave clean tree.
