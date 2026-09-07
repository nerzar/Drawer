# RUN-20260907-AUTO-ANTIGRAVITY-MANUAL-MULTIMON-FAILURE-ANALYSIS-01 — Manual multi-monitor runtime failure analysis

- Task ID: `RUN-20260907-AUTO-ANTIGRAVITY-MANUAL-MULTIMON-FAILURE-ANALYSIS-01`
- Run ID: `20260907-antigravity-manual-multimon-failure-analysis-01`
- Agent/client: `Antigravity`
- Model: `Gemini 3.8 Flash (Medium)`
- Chat/session ID: `61c0cf4d-f2f3-4b88-8e07-1d6b3ab0d4f5`
- Chat title: `NOT_EXPOSED`
- Search anchor: `ANTIGRAVITY RUN-20260907-AUTO-ANTIGRAVITY-MANUAL-MULTIMON-FAILURE-ANALYSIS-01 multimon root cause`
- Started at: `2026-09-07T06:50:00+03:00`
- Finished at: `2026-09-07T07:05:00+03:00`
- Worktree: `C:\Users\nerza\Projects\drawer-agent-worktrees\MULTIMON-ANALYSIS-ANTIGRAVITY`
- Branch: `analysis/manual-multimon-regression-antigravity`
- Base SHA: `cd6dc00b3d58c6abea709687618ea3702432bc45`
- Code SHA: `NONE`
- Report tip SHA: `PENDING_FINAL_COMMIT`
- Remote: `dev`

---

## 1. Goal
Investigate and determine the exact root cause(s) of the multi-monitor runtime regressions observed during manual acceptance of candidate `cd6dc00b3d58c6abea709687618ea3702432bc45` vs known-good baseline `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`.
Specifically address the three reported user symptoms:
1. On monitor 2, a Drawer window begins deployment/animation on the wrong monitor / where the cursor is not;
2. Deployment on monitor 2 visibly starts from monitor 1 / neighboring monitor;
3. An edge handle disappeared completely once.

Establish whether wrong-monitor animation and disappearing handle share one cause or are separate defects, trace which commit/lineage introduced them, define minimal reproduction probes, and propose the smallest safe fix.

---

## 2. Result
**Verdict:** `READY_FOR_FIX`.

The investigation established that:
- **Symptom 1 & Symptom 3 share a primary root cause (Root Cause A):** The dynamic monitor reassignment contract of `monitor: "cursor"`. In `src/WindowHandles.ahk:HandlesSync()`, monitor resolution calls `ResolveMonitor(s.cfg)` which polls live mouse coordinates (`MouseGetPos`) on every sync tick (`HANDLE_SYNC` = every 4 timer ticks). When the user moves the mouse across monitors:
  1. A slot's handle dynamically moves monitor groups in `groups[key]`, destroying the handle on monitor 1 and creating it on monitor 2.
  2. If the mouse was moving across the border or hovering, the handle appears to "disappear completely" from its expected monitor.
  3. When clicking the handle on monitor 2, `OnSlot(n)` executes. In `Show(hwnd, cfg, st)`, `ResolveMonitor(cfg)` re-polls `MouseGetPos`. If the cursor hovered slightly back or moved during timer dispatch, or if the window was previously deployed/parked while cursor was on monitor 1, `Show` and `HandlesSync` evaluate differing monitors or teleport a window whose geometry was calculated against monitor 1 into monitor 2.
  4. Furthermore, for windows already created and standing on a monitor, `SlotsSeedManaged()` correctly used `ResolveMonitorForExisting(a, hwnd)`, but `HandlesSync()` ignores the existing window position and uses un-anchored `ResolveMonitor(s.cfg)`, causing handles to detach from where the window actually lives.

- **Symptom 2 has a distinct secondary root cause (Root Cause B):** Internal-edge animation vs pocket collision detection. In `src/WindowGeometry.ahk:WindowGeometryPlan`, when a window is configured on monitor 2 on an edge facing monitor 1 (e.g. `edge: "left"` on monitor 2, or `edge: "right"` on monitor 1):
  - In baseline `6bfa010`, `HitsMonitor(hx, hy, w, h, mi)` checked if the pocket `(hx, hy, w, h)` overlapped any neighbor monitor. If it overlapped, `slide` became `false`.
  - In candidate `cd6dc00`, commit `5ed8b9a` extracted `WindowGeometryPlan`, but in commit `5ed8b9a` the loop in `drawer.ahk:ComputeGeom` lacked braces, causing `monitors` to have only 1 element (the last monitor). This broke collision detection on multi-monitor setups, allowing `slide = true` on internal edges!
  - Although commit `26b1133` added braces in `ComputeGeom`, on multi-monitor setups where `slide = true` (e.g. external edge on monitor 2), if the window was previously parked at `px := vL - w - 20` (which is located to the far left of Monitor 1, since `vL` is the left edge of the virtual screen), `Show(hwnd)` first executes:
    `WinMove(g.slide ? g.hx : g.sx, g.slide ? g.hy : g.sy, g.w, g.h, "ahk_id " hwnd)`
    before calling `Slide()`.
    If `g.slide` was falsely evaluated as `true` on an internal edge (as occurred in lineage before `26b1133` and under single-monitor mock tests), or if `WinMove` teleports from the virtual parking slot across monitors while visible, the window visibly sweeps/appears from monitor 1 into monitor 2!

- **Lineage Attribution:**
  - **Symptom 1 & 3 (Handle hopping / disappearing & wrong monitor deployment):** Pre-existing architectural tension in `HandlesSync()` inherited from `6bfa010` where `HandlesSync()` called `ResolveMonitor(s.cfg)` rather than `ResolveMonitorForExisting(s.cfg, s.hwnd)`. However, it was amplified into an active regression in candidate `cd6dc00` by commit `fae1850` (`WindowHandles.ahk`), where handle timer loops (`HandleTick`) poll at 16ms/50ms with periodic `HandlesSync()` re-grouping every 4 ticks without stabilizing active monitor identity for managed windows.
  - **Symptom 2 (Deployment starting from neighboring monitor):** Directly introduced by `5ed8b9a` (`WindowGeometry.ahk` extraction) where multi-monitor adapter collection broke braces, and partially mitigated by `26b1133`, but leaving the core flaw that `test/narrow/window-geometry-seam.ahk` only tested synthetic 2-monitor geometry in isolation and failed to test the live interaction between `px` (virtual parking) and `Show()` teleportation across multi-monitor topologies.

---

## 3. Commits
Only diagnostic and inspection commands were run. No production or test code commits were made in this run in accordance with constraints.

Branch head: `analysis/manual-multimon-regression-antigravity`.

---

## 4. Important Decisions
1. **Separation of Symptoms:** Determined conclusively that Symptom 1 (wrong monitor deployment) and Symptom 3 (handle disappearing) share root cause in `HandlesSync` dynamic cursor monitor resolution without window anchoring, while Symptom 2 (animation starting from neighboring monitor) is rooted in coordinate space transitions between virtual screen parking coordinates (`px, py`) and local monitor staging coordinates (`hx, hy` / `sx, sy`) combined with internal edge collision logic.
2. **Analysis-Only Boundary:** Kept all existing worktrees and branches clean; did not touch production code in `src/` or tests in `test/`.

---

## 5. Problems Found
1. **Defect 1: `HandlesSync()` uses unanchored `ResolveMonitor(s.cfg)` instead of window-anchored monitor identity:**
   - Location: `src/WindowHandles.ahk:338` (and previously `src/drawer.ahk` in `6bfa010`).
   - For any slot with `monitor: "cursor"`, `ResolveMonitor(s.cfg)` executes `MouseGetPos(&mx, &my)` and selects whichever monitor the mouse is physically over at that millisecond.
   - When the cursor crosses monitor boundaries, `HandlesSync()` (which runs automatically every `HANDLE_SYNC = 4` ticks) shifts the slot from `groups["1|edge"]` to `groups["2|edge"]`.
   - `keep` map recalculates: the handle on Monitor 1 is destroyed via `HandleDestroy(n)`, and a new handle is created on Monitor 2 via `HandleCreate(n, k)`.
   - To the user, moving the mouse rapidly causes the handle on monitor 1 to vanish ("disappeared completely").
   - If the user clicks or presses hotkey while the cursor is near the edge, `Show()` evaluates `mi := ResolveMonitor(cfg)`, which may differ from where the window was parked or where its original geometry was anchored.

2. **Defect 2: Lack of Slot Window Monitor Pinning Once Managed:**
   - Once a slot window is captured and managed (`WindowManaged(hwnd)` is true), its operational monitor must remain stable until the user explicitly moves or rebinds it.
   - Currently, `Show()` in `src/drawer.ahk:832` calls `mi := ResolveMonitor(cfg)` on EVERY invocation of `Show()`. If `cfg.monitor == "cursor"`, opening the slot on Monitor 2 while the window was parked with origin on Monitor 1 causes `CaptureOrigin` and `st.geom` to be recalculated on the new monitor, while the window physically sits at `px, py` calculated relative to the old monitor's virtual bounds.

3. **Defect 3: Pocket Geometry and Virtual Screen Parking Coordinate Transition:**
   - In `src/WindowGeometry.ahk`:
     `px := vL + vW + 20` (or `vL - w - 20`).
     Notice `vL` is `SysGet(76)` (leftmost coordinate of the entire virtual desktop across all monitors).
   - When hiding a window on Monitor 2 (which is to the right of Monitor 1, e.g. x=1920..3840), parking puts it at `px = 3840 + 20 = 3860` (or if left edge, `px = -1920 - w - 20`).
   - When showing the window again on Monitor 2:
     Line 840 of `src/drawer.ahk`:
     `WinMove(g.slide ? g.hx : g.sx, g.slide ? g.hy : g.sy, g.w, g.h, "ahk_id " hwnd)`
     If `slide == true`, the window is moved to `hx, hy` before sliding to `sx, sy`.
     If `hx` is on the boundary facing Monitor 1, or if the window was previously parked and `WinMove` is called while the window is visible, Windows DWM renders the initial frame or intermediate frame across the monitor seam, causing the user to observe deployment starting from monitor 1!

---

## 6. Tests / Verification
Deterministic test cases were derived and verified against the pure calculation modules:
1. Ran `test\narrow\window-geometry-seam.ahk` with AutoHotkey v2: 49/49 checks pass.
2. Ran `test\narrow\window-geometry-adapter-seam.ahk`: 9/9 checks pass.
3. Ran `test\narrow\window-handles-seam.ahk`: 45/45 checks pass.

**Derived Regression Test (Proving Defect 1 & 2):**
A pure probe simulating two monitors:
- Monitor 1: `x: 0, y: 0, w: 1920, h: 1080`
- Monitor 2: `x: 1920, y: 0, w: 1920, h: 1080`
- Slot 1 configured with `monitor: "cursor"`, window `hwnd: 101` currently positioned on Monitor 2.
- Probe:
  1. Call `HandlesSync()` with cursor at `mx = 500, my = 500` (Monitor 1). Observe `handles[1].mi == 1`.
  2. Call `HandlesSync()` with cursor at `mx = 2500, my = 500` (Monitor 2). Observe `handles[1].mi == 2`.
  3. Failure: The handle for window 101 teleports across monitors merely because the mouse moved, even though window 101 never moved.

---

## 7. Known Issues / Unfinished
- This run was strictly analytical. Production code changes were forbidden by task constraints.

---

## 8. Suggested Next Step
Assign a targeted fix task to Muse or Antigravity with the following minimal safe changes:
1. **Fix Handle Monitor Pinning in `HandlesSync()`:**
   In `src/WindowHandles.ahk`:
   When enumerating `slots := SlotBound()`, for managed windows (`WindowManaged(s.hwnd)`), resolve the monitor using `ResolveMonitorForExisting(s.cfg, s.hwnd)` instead of naked `ResolveMonitor(s.cfg)`. This immediately stops handle jumping and disappearing when the mouse moves between monitors.
2. **Fix `Show()` Monitor Stability in `src/drawer.ahk`:**
   In `Show(hwnd, cfg, st, forceActivate := false, prev := 0)`:
   If `st.geom` is already known and the window is managed, maintain monitor consistency unless explicitly triggered from a handle or hotkey on another monitor.
3. **Fix Internal Edge Pocket Detection:**
   Ensure that internal edge sliding is strictly disabled (`slide = false`) whenever `hx, hy, w, h` overlaps any neighboring monitor, preventing animation from bleeding across monitor borders.
