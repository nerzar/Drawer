# A03S2 — monitor / origin selection seam

- Run ID: `RUN-20260907-OPENCODE-DEEPSEEK-A03S2-IMPLEMENT-01`
- Eligible: `OPENCODE-DEEPSEEK`
- Required model: `deepseek-v4-flash`
- Session: `NEW`
- Dependency: A03S1 must be DONE with a pushed Code SHA. If not, do not claim; wait.
- Base/source rule: base exactly on the pushed A03S1 Code SHA from `RUN-20260906-AUTO-ANTIGRAVITY-A03S1-IMPLEMENT-01`; do not base on report-tip SHA and do not depend on unaccepted A02S2.
- Branch: `refactor/window-geometry-monitor-origin-seam`
- Worktree: `C:\Users\nerza\Projects\drawer-agent-worktrees\A03S2-DEEPSEEK`

## Goal
Implement the second A03 slice from the accepted A03 analysis: extract monitor/origin selection policy into the production geometry seam while preserving behavior exactly.

## Scope
Expected files only unless a directly necessary narrow-test adjustment is justified:
- `src/WindowGeometry.ahk`
- `src/drawer.ahk`
- `test/narrow/window-geometry-seam.ahk`
- optionally reduce obsolete copied/source-shape assertions in `test/narrow/settings-seam.ahk` only when equivalent direct production-policy coverage replaces them.

Implement/shape production-callable policy equivalent to:
- monitor-at-point selection with primary fallback;
- greatest-overlap monitor selection for an existing rectangle, ties retaining first monitor;
- origin preservation/fallback plan for partially visible vs fully off-screen rectangles;
- keep live Win32 wrappers (`ResolveMonitor`, `ResolveMonitorForExisting`, `CaptureOrigin`) behavior/signatures compatible unless the smallest adapter change is required.

## Behavior invariants
Preserve exactly:
- explicit connected numeric monitor wins;
- disconnected numeric monitor falls back to cursor, then primary;
- invalid non-numeric/non-`cursor` monitor value retains current error behavior;
- cursor outside all monitor rectangles falls back to primary;
- existing `monitor=cursor` window uses greatest full-monitor rectangle overlap; ties retain first monitor;
- partially visible original rectangle is preserved exactly, including negative coordinates;
- fully off-screen original rectangle falls back to 80% target work-area size inset 10%;
- full monitor rectangles and work areas must not be conflated;
- no changes to slot authority, focus/watch state, handles, Settings persistence, parking policy, animation or product behavior.

## Tests
Add direct tests against production policy for at least: explicit monitor/fallback, cursor gaps, overlap winner + tie, partial visibility, fully off-screen fallback, negative origins, asymmetric work areas. Retain existing real-window behavior suites unchanged unless task scope genuinely requires an adapter fix.

Run targeted AHK validation and narrow geometry seam tests. Run any additional cheap directly affected seam gate that is available. Do not spend time on unrelated full-suite failures; report them factually if encountered.

## Git / output
Follow current `AGENT_BOARD.md`, `REPORT_FORMAT.md`, claim protocol and Critical Git ref hygiene. One Run ID = one branch. Never create local `dev/...` branches. Do not modify `AGENT_BOARD.md` or `docs/ARCHITECT_STATE.md`. Production/test commit first and record its `Code SHA`; report-tip SHA is metadata only. Push explicitly to `dev` branch `refs/heads/refactor/window-geometry-monitor-origin-seam`, verify remote contains Code SHA, leave clean tree, update claim DONE/BLOCKED.

Report: `docs/agent-reports/2026-09-07-opencode-deepseek-a03s2.md`.
