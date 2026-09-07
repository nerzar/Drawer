# A04S1 — Pure Handle Geometry & Color Seam

- Task ID: `A04S1`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-A04S1-IMPLEMENT-01`
- Agent/client: `Antigravity`
- Model: `Gemini 3.8 Flash (Medium)`
- Chat/session ID: `9dc967be-9af2-4cb0-98ec-f8201c531b4f`
- Chat title: `Drawer A04S1 pure handle geometry and color seam`
- Search anchor: `Drawer A04S1 pure handle geometry color — Antigravity — 20260907`
- Started at: `2026-09-07T03:50:20+03:00`
- Finished at: `2026-09-07T03:51:50+03:00`
- Worktree: `C:\Users\nerza\Projects\drawer-agent-worktrees\A04S1`
- Branch: `refactor/window-handles-pure-seam`
- Base SHA: `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`
- Code SHA: `851f47566dd074538f412b9d258193dbde65195b`
- Report tip SHA: `PENDING_DOCS_COMMIT`
- Remote: `dev`

## 1. Goal

Extract deterministic handle color, layout, inward growth, and hover math into a dedicated production-callable `src/WindowHandles.ahk` seam without changing runtime behavior, GUI lifecycle, timers, click orchestration, icon ownership, handle state map, Settings integration, or full `HandlesSync`.

## 2. Result

1. **`src/WindowHandles.ahk` (NEW)**:
   - Extracted sizing and layout constants: `HANDLE_REST` (22), `HANDLE_NEAR` (28), `HANDLE_HOVER` (44), `HANDLE_LEN` (34), `HANDLE_GAP` (8), `HANDLE_ICON` (18), `HANDLE_ROUND` (6), `HANDLE_PERP` (130), `HANDLE_ALONG` (70), `HANDLE_ANIM` (140), `HANDLE_SLOW` (50), `HANDLE_FAST` (16), `HANDLE_SYNC` (4), `HANDLE_FG` ("D6DAE2").
   - Extracted pure functions:
     - `HandleLighten(hex, pct)`: pure channel math with 0..255 clamping and format validation.
     - `HandleBaseCalc(workArea, edge, idx, count, rest, len, gap)`: pure stack centering calculation for all 4 edges, supporting negative and asymmetric monitor coordinates.
     - `HandleGrownCalc(baseRect, edge, t, rest)`: pure inward expansion calculation where the external boundary remains pegged to work area.
     - `HandleTargetCalc(base, rect, edge, mx, my, rest, near, hover, perp, along)`: pure hover/approach zone detection, preserving the no-jitter invariant by measuring approach distance relative to `base` (rest position).

2. **`src/drawer.ahk` (MODIFIED)**:
   - Added `#Include WindowHandles.ahk`.
   - Delegated `HandleBase(mi, edge, idx, count)` to `HandleBaseCalc` using `MonitorGetWorkArea` facts.
   - Delegated `HandleGrown(b, edge, t)` to `HandleGrownCalc`.
   - Delegated `HandleTarget(hd, mx, my)` to `HandleTargetCalc`.
   - Removed redundant duplicate definition of `HandleLighten` in `drawer.ahk`.
   - All other handle orchestration, GUI creation, timers, clicks, and Settings repainting remain untouched.

3. **`test/narrow/window-handles-seam.ahk` (NEW)**:
   - 17/17 direct narrow assertions passed:
     - Color math: black + 10% -> 1A1A1A, 0% identity, 100% white FFFFFF, clamp on > 100%, ValueError on invalid string length.
     - Positioning: right, left (with 8px gap verification), bottom (centering with 3 tiles), top, invalid edge rejection.
     - Multi-monitor: negative monitor coordinate and asymmetric work area support.
     - Inward growth: right grows left, left grows right, bottom grows up, top grows down, external boundary constant.
     - Approach detection: inside rect -> hover (44), 1px outside rect -> hover, near zone -> near (28), outside -> rest (22), no-jitter distance measured to base.

4. **Invariants Preserved**:
   - `src/config.ini` was not touched.
   - GUI lifecycle, WinAPI styling, and click routing untouched.

## 3. Commits

- Production & test code commit: `851f47566dd074538f412b9d258193dbde65195b` on `refactor/window-handles-pure-seam`.
- Pushed to `refs/heads/refactor/window-handles-pure-seam` on `dev`.

## 4. Checks

- AutoHotkey v2 `/Validate`:
  - `src/drawer.ahk`: EXIT 0
  - `src/WindowHandles.ahk`: EXIT 0
  - `test/narrow/window-handles-seam.ahk`: EXIT 0
- Direct narrow test suite:
  - `test/narrow/window-handles-seam.ahk`: 17/17 PASS, exit 0.
- `src/config.ini`: intact and unmodified.
- Remote verification: `git ls-remote dev refs/heads/refactor/window-handles-pure-seam` confirmed `851f47566dd074538f412b9d258193dbde65195b`.

## 5. Suggested next step

- Architect review of `refactor/window-handles-pure-seam`.