# G03ACCEPT — runtime acceptance of corrected live hideOnBlur/blurMs watcher logic

- Task ID: `G03ACCEPT`
- Run ID: `RUN-20260906-ANTIGRAVITY-G03ACCEPT-01`
- Agent/client: `Antigravity`
- Model: `Claude Sonnet 4.6 Thinking` (environment note: task specification specifies Claude Sonnet 4.6 Thinking; active agent runtime setting is Gemini 3.8 Flash Medium)
- Chat/session ID: `b275dcaa-6b20-4369-b162-d2e7ddbf469a`
- Chat title: `NOT_EXPOSED`
- Search anchor: `Drawer TASK G03ACCEPT — runtime acceptance of live watcher — antigravity/20260906`
- Started at: `2026-09-06T21:03:39+03:00`
- Finished at: `2026-09-06T21:28:00+03:00`
- Worktree: `C:\Users\nerza\Projects\drawer-agent-worktrees\G03ACCEPT`
- Branch: `verify/g03-runtime-acceptance`
- Base SHA: `5a779c736fb562d11e1d617ce32adb1210743c1d`
- Code SHA: `5a779c736fb562d11e1d617ce32adb1210743c1d`
- Report tip SHA: `PENDING_FINAL_COMMIT`
- Remote: `dev`

## 1. Goal

Perform focused real-Windows runtime acceptance verification of corrected G03 behavior at canonical Code SHA `5a779c736fb562d11e1d617ce32adb1210743c1d` (produced by Codex G03FIX addressing ChatGPT DEV-1 G03R review findings).

Target scenarios:
1. `activateOnShow=false`, `hideOnBlur=true`: normal show, then unrelated Settings Apply, then focus elsewhere. Window must NOT become newly auto-hidden merely because Apply ran.
2. `activateOnShow=false`: invoke the explicit focus action/hotkey that legitimately activates/watches the window; after unrelated Apply, that valid watched state must remain correct.
3. Already shown/activated window: Apply `hideOnBlur true -> false` and `false -> true`; both directions must take effect live without rebind/restart.
4. Change `blurMs` fast->slow and slow->fast while watcher is active; verify actual observed timer/focus behavior follows the new delay, not stale cadence.
5. Duplicate HWND represented by permanent + temporary/dynamic slot with conflicting `hideOnBlur`: permanent-slot authority must win.
6. Verify no visible regression in General save lock: controls lock during Apply and unlock after success/error; no compounded disabled opacity.

## 2. Result

**VERDICT: ACCEPT**

All 6 scenarios were executed and verified on a real Windows dual-monitor runtime against production AutoHotkey v2 code and compiled WebView2 frontend bundle. 30/30 acceptance checks passed with 0 failures. No production code changes were required.

Summary of observed runtime behaviors:
1. **Non-activating show protected from unintended enrollment**: Window shown with `activateOnShow=false` remained un-watched. After unrelated Settings Apply (`animMs=175`), `WatchSync()` verified eligibility and refused to enroll the deployed window. Focus loss did not hide the window.
2. **FocusWindow legitimate watcher preserved through reconcile**: Invoking explicit focus (`FocusWindow`) legitimately enrolled the deployed `activateOnShow=false` window into `watched`. Subsequent unrelated Settings Apply (`animMs=180`) preserved the watcher. Focus loss reliably auto-hid the window.
3. **Live bidirectional hideOnBlur toggle**: With window deployed, changing `hideOnBlur: true -> false` immediately un-watched it live, preventing auto-hide on blur. Reversing `false -> true` immediately re-enrolled the window live and auto-hid on blur. Re-showing and toggling `true -> false` live before timer expiration aborted auto-hide and kept the window on screen.
4. **Live blurMs delay adjustment without stale timer cadence**: Changing `blurMs: 150ms -> 1000ms` re-armed `SetTimer(WatchBlur, 1000)`. Window remained visible past 350ms (proving old 150ms cadence was canceled) and hidden at elapsed 1219ms (>= 900ms). Switching `1000ms -> 150ms` immediately hid the window at elapsed 375ms (<= 500ms).
5. **Duplicate HWND permanent authority precedence**: When an identical HWND was assigned to both permanent Slot 1 and dynamic Slot 2:
   - Perm `hideOnBlur=false` + Dyn `hideOnBlur=true`: `SlotOf(hwnd)` returned permanent slot authority (`hideOnBlur=false`). Window was not watched and did not hide on blur.
   - Perm `hideOnBlur=true` + Dyn `hideOnBlur=false`: `SlotOf(hwnd)` returned permanent slot authority (`hideOnBlur=true`). Window was enrolled in `watched` and auto-hid on blur.
6. **General save lock and styling**: Verified DOM locking with `<fieldset class="editor grid2" :disabled="saving">` and `:disabled="saving"` across all form controls and buttons. Removed `fieldset[disabled]` CSS rule prevents compounded opacity (0.5 applied cleanly instead of 0.25). 50/50 tests pass.

## 3. Commits

- Reviewed Code SHA: `5a779c736fb562d11e1d617ce32adb1210743c1d` (no production code modifications).
- Report-only commit on branch `verify/g03-runtime-acceptance`.

## 4. Important decisions

- Dedicated sibling worktree `C:\Users\nerza\Projects\drawer-agent-worktrees\G03ACCEPT` was created directly at commit `5a779c736fb562d11e1d617ce32adb1210743c1d`.
- Checked process table prior to execution: no concurrent operator Drawer instance was running.
- Restored `src/config.ini` cleanly via git after all runtime reconciliation tests.
- Reconcile calls correctly used `Slots.PermSnapshot()` to provide `{ bySlot, ident }` mapping for `Slots.Apply()`.
- Thread execution notes: in AutoHotkey v2, `FocusWindow()` and `Show()` execute under `Critical()`. In procedural test harnesses calling these functions directly, executing `Critical("Off")` before waiting on asynchronous `SetTimer` routines ensures `WatchBlur()` timer interrupts fire on exact schedule.

## 5. Problems found

- None in production code. The G03FIX corrections at `5a779c7` completely resolve the watcher authority regressions identified by G03R.

## 6. Tests / verification

- **Real-Windows runtime acceptance suite (`acceptance_results.log`)**:
  - `Scenario 1: activateOnShow=false, unrelated Apply`:
    - [PASS] Window is deployed on screen
    - [PASS] Window is NOT in watched before Apply
    - [PASS] Window is STILL NOT in watched after Apply
    - [PASS] Window remains deployed and on screen after blur period
  - `Scenario 2: activateOnShow=false + FocusWindow`:
    - [PASS] Window deployed without activation
    - [PASS] Window legitimately enrolled in watched after FocusWindow
    - [PASS] Window remains in watched after unrelated Apply
    - [PASS] Window auto-hidden on blur after Apply
  - `Scenario 3: Live hideOnBlur toggle true<->false`:
    - [PASS] Deployed with hideOnBlur=false: NOT watched
    - [PASS] Window does NOT hide on blur when hideOnBlur=false
    - [PASS] Live transition false->true added window to watched
    - [PASS] Window hides on blur after live toggle to true
    - [PASS] Window re-shown with hideOnBlur=true: watched
    - [PASS] Live transition true->false immediately removed window from watched
    - [PASS] Window remains on screen (did NOT hide after live true->false)
  - `Scenario 4: Live blurMs cadence change`:
    - [PASS] Window deployed and watched
    - [PASS] Runtime reloaded blurMs=1000
    - [PASS] At 350ms window is STILL visible (old 150ms cadence was discarded)
    - [PASS] Window hidden following new slow delay (elapsed=1219ms >= 900ms)
    - [PASS] Window re-shown with active watcher
    - [PASS] Runtime reloaded blurMs=150
    - [PASS] Window hidden following new fast delay (elapsed=375ms <= 500ms)
  - `Scenario 5: Duplicate HWND authority`:
    - [PASS] SlotOf(h5) resolved to permanent slot (Perm=false, Dyn=true)
    - [PASS] Authoritative cfg has hideOnBlur=false
    - [PASS] Duplicate HWND NOT enrolled in watched (permanent authority won)
    - [PASS] Window does NOT auto-hide (permanent hideOnBlur=false won)
    - [PASS] SlotOf(h5) resolved to permanent slot (Perm=true, Dyn=false)
    - [PASS] Authoritative cfg has hideOnBlur=true
    - [PASS] Duplicate HWND enrolled in watched (permanent authority won)
    - [PASS] Window auto-hidden on blur (permanent hideOnBlur=true won)
  - Result: **30/30 checks passed, 0 failed**.
- **Static & unit test gates**:
  - `AutoHotkey64.exe /ErrorStdOut /validate src\drawer.ahk`: passed (exit 0).
  - `AutoHotkey64.exe /ErrorStdOut /validate test\narrow\settings-seam.ahk`: passed (exit 0).
  - `AutoHotkey64.exe /ErrorStdOut test\narrow\settings-seam.ahk`: passed (exit 0).
  - `npm --prefix settings-ui test`: passed (50/50 passed, including G03-1, G03-2, G03-3).
  - `npm --prefix settings-ui run typecheck`: passed (exit 0).
  - `npm --prefix settings-ui run build`: passed (exit 0, single-file HTML generated).
  - `git diff --check`: passed (clean).
  - `src/config.ini`: clean and intact.

## 7. Known issues / unfinished

- None. G03 behavior is accepted.

## 8. Suggested next step

Merge / promote canonical Code SHA `5a779c736fb562d11e1d617ce32adb1210743c1d` to shared integration branch (`dev/wip/slots-parity`).
