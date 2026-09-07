# A04S2 — Handle GUI Lifecycle & Styling Seam

- Task ID: `A04S2`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-A04S2-IMPLEMENT-01`
- Agent/client: `Antigravity`
- Model: `Gemini 3.8 Flash (Medium)`
- Chat/session ID: `9dc967be-9af2-4cb0-98ec-f8201c531b4f`
- Chat title: `Drawer A04S2 handle GUI lifecycle and styling seam`
- Search anchor: `Drawer A04S2 handle GUI lifecycle styling — Antigravity — 20260907`
- Started at: `2026-09-07T04:09:05+03:00`
- Finished at: `2026-09-07T04:13:00+03:00`
- Worktree: `C:\Users\nerza\Projects\drawer-agent-worktrees\A04S2`
- Branch: `refactor/window-handles-gui-seam`
- Base SHA: `851f47566dd074538f412b9d258193dbde65195b` (A04S1 tip)
- Code SHA: `e862c4f7b71f0aced86dc2b19843b47b4b23a0f2`
- Report tip SHA: `PENDING_DOCS_COMMIT`
- Remote: `dev`

## 1. Goal

Extract handle GUI lifecycle (`HandleCreate`, `HandleDestroy`, `HandlesDestroyAll`), window icon copying (`HandleIcon`), styling and appearance calculations (`HandleRound`, `HandleFace`, `HandleFaceCalc`), and bulk repainting (`HandleRepaintAll`) from `src/drawer.ahk` into `src/WindowHandles.ahk`.

## 2. Result

1. **`src/WindowHandles.ahk` (MODIFIED)**:
   - Added pure helper `HandleFaceCalc(rect, edge, t, hasPic, rest, hover, icon)`: calculates visibility `on`, free space for text, text control position, icon position, discrete alpha step (`205 + Round(50 * Min(1, Max(0, k)) / 8) * 8`), and hot background status.
   - Added `HandleIcon(hwnd)`: queries `WM_GETICON`, fallback to `GetClassLongPtrW` (`GCLP_HICONSM`, `GCLP_HICON`), fallback to `shell32\ExtractIconExW`, returning a private handle copy via `CopyIcon` to preserve icon ownership invariants.
   - Added GUI lifecycle and styling functions:
     - `HandleCreate(n, k)`: creates borderless, non-activating tool window GUI (`WS_EX_NOACTIVATE`), adds picture and text controls, builds handle entry, positions and rounds window.
     - `HandleRound(hd)`: clips window corners via `WinSetRegion` with `HANDLE_ROUND` radius.
     - `HandleFace(hd, t)`: applies positioning, text visibility, background accent/hot color, and discrete transparency level.
     - `HandleRepaintAll()`: updates background color on all active handle GUIs upon Settings accent color changes.
     - `HandleDestroy(n)`: destroys GUI and cleans up handle record.
     - `HandlesDestroyAll()`: destroys all active handle GUIs and resets polling mode via `HandleTimer()`.

2. **`src/drawer.ahk` (MODIFIED)**:
   - Removed definitions of `HandleIcon`, `HandleCreate`, `HandleRound`, `HandleFace`, `HandleRepaintAll`, `HandleDestroy`, `HandlesDestroyAll` (delegating seamlessly to `WindowHandles.ahk` via existing `#Include WindowHandles.ahk`).
   - Retained orchestration: `HandlesSync`, `HandleTimer`, `HandleTick`, `HandleApply`, `HandleAim`, `HandleTarget`, and `HandleClick` (reserved for A04S3).
   - Retained literal call sites: `HandlesDestroyAll()` in `Cleanup(*)`, `HandleRepaintAll()` in `SettingsReconcileRuntime`.

3. **`test/narrow/window-handles-seam.ahk` (MODIFIED)**:
   - Added Section 6 & 7 assertions (total suite expanded from 17 to 24 tests):
     - `6a`: in rest state (`t=22`), `on=0`, `bgHot=false`, `alpha=205`.
     - `6b`: in rest state, icon position is calculated and text control is disabled (`txtPos=0`).
     - `6c`: right edge icon is pegged to outer border (`ix=2, iy=8`).
     - `6d`: in hover state (`t=44`), `on=1`, `bgHot=true`.
     - `6e`: in hover state, text label is positioned.
     - `6f`: slot number label appearance threshold is strictly `t >= 36` (`HANDLE_HOVER - 8`).
     - `6g`: intermediate transparency at `t=33` is discretely stepped to multiples of 8 (`alpha=229`).
     - `7a-7g`: confirmed presence and accessibility of `HandleCreate`, `HandleRound`, `HandleFace`, `HandleRepaintAll`, `HandleDestroy`, `HandlesDestroyAll`, `HandleIcon`.
   - All 24/24 assertions PASSED.

4. **Invariants Preserved**:
   - `src/config.ini` was completely untouched.
   - Compatibility with `test/narrow/settings-seam.ahk` (530+ checks passed with 0 exit code).

## 3. Commits

- Production & test code commit: `e862c4f7b71f0aced86dc2b19843b47b4b23a0f2` on `refactor/window-handles-gui-seam`.
- Pushed to `refs/heads/refactor/window-handles-gui-seam` on `dev`.

## 4. Checks

- AutoHotkey v2 `/Validate`:
  - `src/drawer.ahk`: EXIT 0
  - `src/WindowHandles.ahk`: EXIT 0
  - `test/narrow/window-handles-seam.ahk`: EXIT 0
- Direct narrow test suites:
  - `test/narrow/window-handles-seam.ahk`: 24/24 PASS, exit 0.
  - `test/narrow/settings-seam.ahk`: PASS, exit 0.
- `src/config.ini`: intact and unmodified (`git diff src/config.ini` empty).
- Remote verification: `git ls-remote dev refs/heads/refactor/window-handles-gui-seam` confirmed `e862c4f7b71f0aced86dc2b19843b47b4b23a0f2`.

## 5. Suggested next step

- A04S3 (timer, tick, click, and sync orchestration seam).
