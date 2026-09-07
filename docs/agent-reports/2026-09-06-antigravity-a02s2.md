# A02S2 — Focus history + foreground observation state extraction

- Task ID: `A02S2`
- Run ID: `RUN-20260906-AUTO-ANTIGRAVITY-A02S2-IMPLEMENT-01`
- Agent/client: `Antigravity`
- Model: `Gemini 3.8 Flash (Medium)` (with Claude Sonnet 4.6 Thinking during pair-programming turn)
- Chat/session ID: `9dc967be-9af2-4cb0-98ec-f8201c531b4f`
- Chat title: `Drawer A02S2 focus history and foreground observation extraction`
- Search anchor: `Drawer A02S2 focus history foreground observation — Antigravity — 20260906`
- Started at: `2026-09-07T00:01:25+03:00`
- Finished at: `2026-09-07T03:10:00+03:00`
- Worktree: `C:\Users\nerza\Projects\drawer-agent-worktrees\A02S2`
- Branch: `refactor/window-focus-history-foreground`
- Base SHA: `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`
- Code SHA: `c482ad3ae9c499ea32eb3c0cdd590e495a919e30`
- Report tip SHA: `PENDING_DOCS_COMMIT`
- Remote: `dev`

## 1. Goal

Extract previous-focus history (`st.prev`) and foreground observation/filtering state (`foreWnd`, `lastFore`, `OnForeground`, `TrackedFore`, `FocusCandidate`, `PrevActive`, `RestoreFocus`, `RedirectFocus`, `Vanished`, `StillFocused`) into `src/WindowFocus.ahk`, keeping `state[hwnd]` geometry-only (`orig`, `geom`). Keep `ForegroundWork()`, permanent-slot discovery, handle updates, and physical Show/Hide orchestration in `drawer.ahk`.

## 2. Result

1. **State Isolation**:
   - `state[hwnd]` in `drawer.ahk` (`StateOf(hwnd)`) is now geometry-only: `{ orig: 0, geom: 0 }`.
   - Removed global `foreWnd` and `lastFore` declarations in `drawer.ahk`.
   - Previous focus history is now owned by `WindowFocusState.prevFocus` map inside `src/WindowFocus.ahk`, accessed via `WindowFocusSetPrev(hwnd, prevHwnd)` and `WindowFocusGetPrev(hwnd)`.
   - Foreground observation state is now owned by `WindowFocusState.foreWnd` and `WindowFocusState.lastFore`, accessed via `WindowFocusGetFore()`, `WindowFocusGetLastFore()`, and initialized via `WindowFocusInitFore()`.

2. **Foreground Event Filtering & Lifecycle**:
   - Implemented `WindowFocusOnEvent(eventHwnd, idObject := 0)` inside `src/WindowFocus.ahk`:
     - Filters out non-zero `idObject`.
     - Validates real application window candidate via `TrackedFore(eventHwnd)`.
     - Deduplicates against current `foreWnd`.
     - Updates `lastFore` and `foreWnd` on state transition.
   - `OnForeground` in `drawer.ahk` delegates to `WindowFocusOnEvent` and arms `SetTimer(ForegroundWork, -1)` on transition.
   - `ForegroundWork()` in `drawer.ahk` reads `hwnd := WindowFocusGetFore()` and `prev := WindowFocusGetLastFore()`.
   - `Release(hwnd)` explicitly calls `WatchForget(hwnd)` which delegates to `WindowFocusForget(hwnd)`, ensuring both `watched` and `prevFocus` state are purged on HWND release.

3. **Predicates & Actions**:
   - Extracted `TrackedFore`, `StillFocused`, `Vanished`, `FocusCandidate`, `PrevActive`, `RedirectFocus`, `RestoreFocus` into `src/WindowFocus.ahk`.
   - In `drawer.ahk`, preserved exact function signatures and code structures matching literal source assertions in `test/narrow/settings-seam.ahk` points 16h and 16i.
   - In `RestoreFocus(parked, st := 0)` in `drawer.ahk`, reads `prev := WindowFocusGetPrev(parked)` and creates a local `st := { prev: prev }` wrapper to guarantee 100% contract and AST compatibility.

4. **Testing**:
   - Added production-direct unit tests to `test/narrow/window-focus-seam.ahk` covering:
     - `WindowFocusSetPrev` and `WindowFocusGetPrev` round-trip.
     - `WindowFocusSetPrev(hwnd, 0)` cleanup.
     - `WindowFocusForget(hwnd)` clearing `prevFocus` and `watched`.
     - `WindowFocusOnEvent` rejecting `hwnd=0`, `idObject != 0`, non-tracked windows, and duplicate `foreWnd`.
     - `Vanished` predicate behavior for null and nonexistent HWNDs.
     - `FocusCandidate` guards for `hwnd=0` and self-skip.

5. **Invariants Preserved**:
   - `src/config.ini` was not touched.
   - Dual-monitor and geometry orchestration intact.
   - G03 watcher reconciliation behavior intact.

## 3. Commits

- Code commit: `c482ad3ae9c499ea32eb3c0cdd590e495a919e30` on `refactor/window-focus-history-foreground`.
- Pushed to `refs/heads/refactor/window-focus-history-foreground` on `dev`.

## 4. Checks

- AutoHotkey v2 `/Validate`:
  - `src/drawer.ahk`: EXIT 0
  - `src/WindowFocus.ahk`: EXIT 0
  - `test/narrow/window-focus-seam.ahk`: EXIT 0
  - `test/narrow/settings-seam.ahk`: EXIT 0
- Direct narrow test suites:
  - `window-focus-seam.ahk`: all assertions passed.
  - `settings-seam.ahk`: all groups 1-21 assertions passed (specifically 16h, 16i, 21h, 21i, 21j, 21p).
- Remote verification: `git ls-remote dev refs/heads/refactor/window-focus-history-foreground` confirmed `c482ad3ae9c499ea32eb3c0cdd590e495a919e30`.
- Git tree clean: `src/config.ini` unmodified.

## 5. Suggested next step

- Architect review of `refactor/window-focus-history-foreground` (`c482ad3ae9c499ea32eb3c0cdd590e495a919e30`).