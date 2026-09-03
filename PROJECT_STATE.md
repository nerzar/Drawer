# PROJECT_STATE — Drawer

*Handoff document for the next session. Verified against repo at commit 046b92c on 2026-09-03.*

---

## 1. PROJECT

**What it is:** Drawer is a Windows tray utility (AutoHotkey v2, compiled to .exe) that parks application windows off-screen into numbered slots and deploys them on demand via hotkeys or by clicking edge handles on the screen border.

| Field | Value |
|---|---|
| Version | `0.1.2-beta` (line 10 of `src/drawer.ahk`) |
| Tag | `v0.1.2-beta` |
| Current commit | `046b92c` — docs: add project state handoff |
| Branch | `master` |
| Remote | `origin` → `https://github.com/nerzar/Drawer` |
| Working tree | Clean locally; 1 commit ahead of origin/master (this file, not pushed). Untracked: `test/vm-transfer/` — VM scratch scripts, intentionally uncommitted. |

---

## 2. ARCHITECTURE

Single source file: `src/drawer.ahk` (1 307 lines, AHK v2).  
Build: `build/build.ps1` compiles with Ahk2Exe → `dist/Drawer-vX.Y.Z-tag/Drawer.exe`.  
Config: `config.ini` next to the executable, read at startup by `LoadConfig()`. Since S2 the Settings window also writes it — but only on Apply/OK, only the keys the user changed, key by key via `IniWrite`, never regenerating the file. `LoadConfig()` is idempotent (it resets `apps` and `dynamicSlots` on entry) so it can be re-run to apply changes. Format: INI, UTF-16 LE (required for Cyrillic text in `name=` fields).

### Slot types

**Permanent slot** (`[slot1]`…`[slot9]` in config.ini): identified by `exe=` process name. Drawer finds the window by searching running processes; the found HWND is remembered (`managed` map) until Drawer restarts. Permanent slots survive `Ctrl+Alt+0` clear.

**Dynamic slot**: any of slots 1–9 not occupied by a permanent slot. `Ctrl+Alt+Shift+N` binds the *current foreground HWND* (not the application) to slot N. The binding is a concrete window handle. Cleared by `Ctrl+Alt+0` or exit.

**Per-slot dynamic overrides** (`[dynamicSlot1]`…): override geometry/behavior defaults for a specific dynamic slot number.

### Parking / deploying

`Hide`: WinMove offscreen (far negative coordinates). Window remains in taskbar.  
`Show`: WinMove back to saved geometry (`state[hwnd].orig`), then `WinActivate` if `activateOnShow=true`.  
`Release`: move back to original position, forget state. Used on exit and Ctrl+Alt+0.

Animation: incremental WinMove over `animSteps` steps in `animMs` ms. Internal monitor edges skip animation (no space to animate into) — this is a confirmed limitation, accepted by design.

### Handles ("Кромка")

Small rectangular tiles appearing at the screen edge for each parked window. Contain the window's icon (extracted via WM_GETICON → class → exe). Grow on cursor approach (22 → 28 → 44 px), click deploys the slot. Stacked by slot number, centered on the edge.

Polling: slow tick (50 ms) checks cursor proximity; fast tick (16 ms) runs during hover. Full rebuild every 4 slow ticks.

Handles belong to Drawer (Gui windows), not to the parked application.

### Focus management

`SetWinEventHook(WINEVENT_SYSTEM_FOREGROUND)` monitors active window changes. If a parked window receives focus (e.g. via Alt+Tab or taskbar click), Drawer deploys it automatically. Transient system windows (taskbar, Alt+Tab switcher, Progman) are filtered out to avoid false triggers.

`hideOnBlur`: when a deployed window loses focus to a *real* application window, Drawer parks it back (checked every `blurMs` ms).

`lastFore` tracks the window that was active before the current one — used to redirect focus when a parked window gets activated by the OS (not by the user).

### Hotkeys

Registered via AHK keyboard hook (`$` prefix) to avoid conflicts with RegisterHotKey:

| Hotkey | Action |
|---|---|
| Ctrl+Alt+1…9 | Toggle slot N: permanent slot → find window by exe, show/park it (silent if app not running); dynamic slot → show/park bound window; empty dynamic slot → silent no-op |
| Ctrl+Alt+Shift+1…9 | Bind current foreground window to dynamic slot N, notify |
| Ctrl+Alt+0 | Clear all dynamic slots (release windows to original positions) |
| Ctrl+Alt+Shift+0 | Exit, release all slots |
| `focusHotkey` (per slot) | Immediate focus/deploy of permanent slot |

At startup, the count of successfully registered hotkeys is shown in the startup notification.

### Notifications

`TrayTip` with deduplication: same title+text cannot appear again within 4 seconds. This prevents notification floods on rapid hotkey presses.

### Tray

Default AHK tray icon. Right-click menu: standard AHK menu (includes Exit). No custom tray menu items currently.

### Key data structures

```
apps[]          permanent slot configs (from config.ini)
managed[]       perm slot index → current HWND
state[]         hwnd → { orig: {x,y,w,h}, geom: computed park geometry }
watched[]       hwnd → slot config, for hideOnBlur tracking
permSlots[]     slot number → apps[] index
dynSlots[]      slot number → hwnd
handles[]       slot number → handle Gui window
notified[]      dedup map for TrayTip
```

---

## 3. CURRENT FUNCTIONALITY

All items below are in `src/drawer.ahk`. "Tested" means covered by the test harness (host or VM). "UNKNOWN" means not formally verified by automated test.

| Feature | Status |
|---|---|
| 9 slots | Implemented, tested (geom/behav suites) |
| Permanent slot binding by exe= | Implemented, tested |
| Dynamic HWND binding (Ctrl+Alt+Shift+N) | Implemented, tested (behav suite) |
| Ctrl+Alt+N toggle | Implemented, tested |
| Ctrl+Alt+0 clear dynamic | Implemented, tested |
| Ctrl+Alt+Shift+0 exit | Implemented, tested |
| Hide/show animation | Implemented, tested (geom) |
| Handles: appear, grow, click | Implemented, tested (kromka suite) |
| Handle icon extraction | Implemented, tested on real apps |
| Handle stack ordering | Implemented, tested |
| All 4 edges (left/right/top/bottom) | Implemented, tested (kromka suite) |
| Multi-monitor geometry | Implemented, tested (geom suite on 2-monitor host) |
| activateOnShow | Implemented, tested (behav) |
| hideOnBlur | Implemented, tested (behav) |
| Alt+Tab auto-deploy | Implemented, tested (behav) |
| Taskbar click auto-deploy | Implemented, behavior identical to Alt+Tab via same hook |
| Startup notification with hotkey count | Implemented, visually confirmed in VM |
| Notification deduplication | Implemented, tested (quiet suite) |
| Focus redirect for vanished windows | Implemented, tested (behav) |
| config.ini: all options | Implemented, partially tested |
| `handles=false` suppresses all handles | Implemented, tested (off suite) |
| handles+hideOnBlur interaction | Implemented, tested (extra suite) |
| handles on exit | Implemented, tested (extra suite) |
| handles on rebind | Implemented, tested (extra suite) |
| focusHotkey per permanent slot | Implemented, UNKNOWN (no explicit test) |
| `[dynamicSlotN]` overrides | Implemented, UNKNOWN |
| Permanent slot can't be overwritten | Implemented (guard in BindSlot) |
| No stranded windows on exit | Tested by strand.ahk after each suite |
| Settings window, opens from tray | Implemented (S1), tested — tray menu item "Settings", single instance |
| Settings: General editable (S2) | Implemented, tested in VM — `[general]` handles/animMs/animSteps/blurMs and `[dynamic]` width/monitor/edge/activateOnShow/hideOnBlur. Slots and About stay read-only |
| Settings: writes only changed keys | Implemented, tested — compares against the live values, so a key absent from the file and left alone is never written; `[slotN]` and `[dynamicSlotN]` are never written |
| Settings: verify-after-write | Implemented, tested — every written key is read back and compared; on mismatch the window shows the error and the runtime is not touched |
| Settings shows General and Slots from existing config.ini | Implemented — General reads `animMs`, `animSteps`, `blurMs`, `handles`; Slots lists `[dynamic]` plus slots 1–9 with every field, and marks where each value came from (`[general]` / `[slotN]` / `[dynamic]` / default) |
| Settings never writes unless asked | Implemented, tested — file unchanged after open, after Cancel, after closing with unsaved edits, and after app exit |
| Settings is a service window | Implemented, tested — excluded from dynamic binding, from handles and from focus tracking (`PickActive`, `TrackedFore`, `FocusCandidate`, `StillFocused`, `FindWindow`) through one `IsServiceWindow()` helper; focusing it does not trigger `hideOnBlur` |
| Settings: live «Состояние» column (S3) | Implemented, verified manually in VM — dynamic slot shows Empty/Parked/Shown, permanent slot shows Parked/Shown and «приложение не запущено» when the app isn't running, closing the bound window clears the status, bind is rejected while Settings is focused, second Settings window is not created, `hideOnBlur` unaffected, and the live tick does not mark the form dirty. See §4 for why the automated suite doesn't cover this yet |

---

## 4. TESTING

### Test harness

Entry point: `test/run.ps1`. Finds AHK v2, runs `/validate` on source, checks monitor layout (2 monitors, M2 left of M1 required), kills any existing Drawer, runs driver scripts, collects `ok`/`БАГ` lines, checks for stranded windows via `strand.ahk`.

Exit code 0 = all green. Logs in `%TEMP%\drawer-test\<suite>\`.

### Suites

| Suite | Driver | Checks |
|---|---|---|
| geom | geom.ahk | Window geometry per monitor×edge combination |
| behav | behav.ahk | Bind, toggle, hideOnBlur, activateOnShow, Alt+Tab, rapid hotkeys, clear, exit |
| invar | invar.ahk | Window never appears on neighbor monitor mid-animation |
| quiet | quiet.ahk | Exactly the expected notifications, no duplicates |
| kromka | kromka.ahk | Handle appearance, growth, slot number, click, stack, all edges+monitors |
| extra | extra.ahk | Handle+hideOnBlur, rebind, exit interactions |
| off | off.ahk | `handles=false`: no handles, rest works normally |
| apps | apps.ahk | VS Code, Telegram, Chrome (requires them installed) |
| browser | browser.ahk | Chrome full cycle |

### Last known results (host)

From `test/vm/README.md` (describes formal run on host):
- `extra`: 11/11, 0 failures
- `quiet`: 7/7, 0 failures
- No windows stranded outside monitors
- Exit code: 0

Full suite (geom, behav, invar, kromka) run history: UNKNOWN exact dates/counts, but all suites were passing as of the bcd6e1c commit (which added extra/quiet fixes and the test stand description).

### VM smoke test (this session, 2026-09-03)

Environment: VirtualBox 7.2.16, Windows 11 guest ("tetst"), single monitor, user `vboxuser`.

| Check | Result |
|---|---|
| Drawer.exe launches without AHK interpreter | PASS — binary is self-contained |
| Tray icon appears | PASS — confirmed visually in hidden-icons overflow |
| Startup notification (version + hotkey count) | PASS — `Drawer.exe` window handle appeared at launch (notification shown) |
| Hotkeys register | PASS — user manually verified in VM |
| Ctrl+Alt+Shift+N binds window | PASS — user confirmed |
| Ctrl+Alt+N toggles slot | PASS — user confirmed |
| No install required | PASS — ran directly from Desktop with config.ini |
| Single-instance enforcement | OBSERVED — AHK dialog appears if previous instance not cleanly exited; pressing Нет (No) cancels new instance |
| Handles in VM | NOT TESTED |
| Full test suite in VM | Superseded — see "VM regression" below; the stand now has two monitors |

### VM regression (2026-09-03, dual monitor)

The first run on a stand that matches what the harness was written for: VM `tetst`, two monitors at **1920×1080**, **M2 left of M1**, `layout.ahk` → ГОДИТСЯ, so no `-Force`. Narrow run of the five suites the earlier single-monitor stand had contaminated. 19:45:24 → 19:51:01.

| Suite | Checks | Passed | Failed |
|---|---|---|---|
| kromka | 82 | 69 | 13 |
| slots | 21 | 21 | 0 |
| life | 23 | 21 | 2 |
| load | 22 | 18 | 4 |
| restart | 30 | 29 | 1 |
| **total** | **178** | **158** | **20** |

`kromka` completed **without the driver crash** for the first time — 82 checks, the same count the host run produces. The crash (`Integer has no property "y"`) was a harness defect in `test/drivers/kromka.ahk`, since fixed there: a missing handle now yields a normal FAIL instead of aborting the suite. No stranded windows after the run.

**The second monitor did not drop out during the run.** Checked afterwards on suspicion. `VBox.log` recorded no display event in the run window — its last write predates the run by 24 minutes, and VirtualBox does log screen enable/disable, resize and guest-screen-count changes. Independently, three suites contain coordinates that are only computable with monitor 2 present: `x=-1920 (L2=-1920)` in `kromka`, and `x=-2900` in `life` and `restart` — the parked position of a monitor-2 left-edge slot, −1920 − 960 − 20. `restart` runs last, so this covers the end of the run. Worth knowing for future reports: `layout.ahk` runs **only at the start** of a run and `strand.ahk` does not report monitors, so end-of-run layout evidence has to come from the suite artifacts.

**Classification of the 20 failures**

- **19 — the known Z-order / timing risk (§7), not a new regression.** All of them are one symptom: a slot deploys itself, therefore has no handle (a deployed slot never does), and dependent checks cascade. The mechanism is documented: closing or hiding a deployed window hands foreground to the next parked slot in Z-order. The affected slot number changes between runs (6 → 3), which is the signature of a race, and the same code is clean on the 2×1920×1080 host. The guest has 2 CPUs and no GPU acceleration, so timing-sensitive checks race far more often here. How much is the known limitation and how much is VM slowness was not separated further — that needs more runs than were authorised.
- **1 — environment.** `restart`: the permanent slot did not find Paint's window after restarting the application (`x=-999999`, the driver's not-found sentinel). Paint in this guest is the Store app `Microsoft.Paint`, reached through an execution alias; the harness was written against classic `mspaint.exe`.

**None of this touches S2.** No suite in this run opens Settings, `IsServiceWindow()` returns false on its first line while the window is closed, and `LoadConfig()` runs once at startup.

`src/config.ini` before and after the run: `086978fc…905`, 9472 bytes — **unchanged**.

### S3 live status: manual verification (2026-09-04)

The automated `setstat` driver (bench `main`, added this session) did not complete: its test-only hotkey (`^!+F12`/`^!+F11`, wired into the build only for this suite — Settings has no hotkey of its own by design, Р16) never triggered `SettingsShow()`/a status dump, across four VM attempts, while in the same runs the real slot hotkeys (`^!+2`, `^!2`, `^!+3`, `^!+4`) fired correctly. `SettingsOpen()` itself never threw — confirmed by patching `Notify()` to a file for that run, same trick as the `quiet` suite. Root cause not confirmed; leading hypothesis is something specific to F11/F12 in this environment, since swapping the modifier count and lengthening the wait made no difference. **This is a gap in the test driver, not in S3** — nothing on the real code path (tray menu → `SettingsShow()`) is implicated, and two of the four attempts were also lost to the owner having re-synced files to the VM after editing them, not a code issue.

The owner then verified S3 by hand in the VM (`tetst`, two monitors, 1920×955, opened via the real tray menu): with dynamic and permanent slots already Parked/Shown before Settings opened, the live column read correctly — dynamic Empty/Parked/Shown, permanent Parked/Shown, empty slots «пусто». The rest of the required checks (bind rejected while Settings is focused, closing the bound window clears status rather than showing a stale one, `hideOnBlur` unaffected by Settings holding focus, no second Settings window, the live tick not marking the form dirty) were also checked by hand and passed. **S3 behavior is confirmed working — by manual verification, not the automated suite.** `src/config.ini` unchanged across the whole session: `086978fc…08d905`, 9472 bytes, same mtime.

The driver (`test/drivers/setstat.ahk`) and its `run.ps1` wiring (suite `setstat`) are left in the repo for whoever picks up the F11/F12 question — likely fix is swapping the test-only hotkeys for a letter combo (e.g. `^!+S`/`^!+D`) instead of function keys.

### Testing policy

Adopted 2026-09-03, after three full `run.ps1` passes on the main PC seized its desktop for hours and consumed most of a session budget.

- **Main PC: short smoke and manual UI checks only** — launch the app, open a window, take a screenshot.
- **Long or bulk GUI/regression runs: VM only** (`tetst`, §5). The VM is the primary bench.
- **`test/run.ps1` is not to be run on the main PC without the owner's explicit permission**, granted per run.
- **Repeat comparison runs** — the same suites against pristine HEAD, to tell a regression from a flake — **only when a failure is reproducible and relevant.** One suspicious failure is not by itself a reason to spend another pass.
- For a change that does not touch geometry, focus or handles, no suite run at all: `/validate` plus one targeted driver is enough.
- Pick suites with `-Only`; `-Suites safe` is 12 suites and about 20 minutes.

---

## 5. VM

The VM is the primary test bench (see Testing policy in §4). State below verified 2026-09-03.

### Current test VM ("tetst")

| Property | Value |
|---|---|
| Host VirtualBox | 7.2.16 |
| Guest Additions | 7.2.16, RunLevel 3 |
| Guest OS | Windows 11 x64 |
| RAM / CPU | 4096 MB / 2 |
| Monitor count | 1 |
| Resolution | 1920×955 (work area 1920×907) |
| Username | vboxuser, password 1211 |
| AHK in guest | **v2.0.27 installed** |
| AHK path | `C:\Users\vboxuser\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe` |
| Snapshot | **`base-ahk-v2`** — online snapshot; restoring returns a logged-in desktop with no boot and no login |
| Staging dir | `C:\drawer-vm` (empty in the base snapshot) |
| VBoxService | Running, Startup=Automatic |

The AHK path above is the **first** location `test/run.ps1` probes, so `-Ahk` never has to be passed. Installed with `winget install AutoHotkey.AutoHotkey` through `guestcontrol` — worked on the first attempt.

### guestcontrol runs in interactive Session 1

Measured, not assumed. An AHK script started through `guestcontrol` reported `SessionId = 1`, listed 9 real guest desktop windows (explorer, mspaint, terminals), moved the mouse to the coordinates it asked for, and created and then saw its own GUI window.

**GUI automation through guestcontrol therefore works.** The earlier "Session 0→1 boundary" note applied only to `Stop-Process`, not to GUI work in general.

### Verified in the VM

| Check | Result |
|---|---|
| Drawer.exe launches without AHK interpreter | PASS (earlier session) |
| Tray icon, startup notification, hotkeys | PASS (earlier session) |
| AHK v2 runs scripts in guest | PASS — `/validate` 0, script exit 0 |
| A driver actually drives Drawer in the guest | PASS — S1 settings driver, **35/35, 0 failures** |
| config.ini untouched by a driver run | PASS — SHA unchanged |
| Handles in VM | NOT TESTED |

### File delivery and command execution

```powershell
VBoxManage guestcontrol "tetst" copyto --username vboxuser --password 1211 `
    "host\path\file.ps1" "C:\drawer-vm\file.ps1"
```

Single-file syntax: `source dest-full-path` (not `--target-directory`).

Four rules, each of which cost a failed call before it was learned:

- **`copyto` does not overwrite, and `--force` is not accepted here.** Delete first (`guestcontrol ... rm <path>`), then copy.
- **Nested quotes do not survive `guestcontrol run` arguments.** Put any non-trivial logic in a `.ps1` on the host, copy it in, and run it with `-NoProfile -ExecutionPolicy Bypass -File`.
- **Guest-side PowerShell scripts must be ASCII-only.** Windows PowerShell 5.1 in the guest reads a `.ps1` without a BOM as ANSI; Cyrillic becomes mojibake and breaks the parser mid-file. `.ahk` files are unaffected — AHK v2 assumes UTF-8.
- **Stop processes with `taskkill`, not `Stop-Process`.** `Stop-Process` through guestcontrol does not terminate them.

### Keyboard simulation

Rarely needed now that guestcontrol reaches Session 1, but still available:

```powershell
VBoxManage controlvm "tetst" keyboardputscancode <bytes>  # raw PS/2 Set-1 scancodes
VBoxManage controlvm "tetst" keyboardputstring "text"     # text input
```

Modifier combo order: make Ctrl → make Alt → make Shift → make key → break key → break Shift → break Alt → break Ctrl.

### Known VM limitations

- **AHK single-instance mutex** lingers after a force-kill; the next launch shows "Could not close previous instance" (press Нет to abort, then retry after a pause).
- `test/vm/new-vm.ps1` has never been executed end-to-end (requires a Windows ISO). Written against VBoxManage 7.2 help.

### Not done yet

- **Second monitor — DONE.** `monitorcount=2`, both screens 1920×1080, M2 left of M1 (M1 `0,0..1920,1080`, M2 `-1920,3..0,1083`), work areas 1920×1032. `layout.ahk` returns ГОДИТСЯ, so `-Force` is no longer needed.
- **`test/vm/run-in-vm.ps1` NOT adapted to `tetst`.** It still hardcodes VM name `drawer-test`, user `tester/tester`, AHK at `C:\drawer-test\ahk\AutoHotkey64.exe`, and a two-monitor screen layout. Never executed end-to-end.
- **Regression in the VM — partly done.** A twelve-suite `safe` run and a five-suite narrow run have both been executed there; see "VM regression" in §4 for the results. `apps` and `browser` have never run in the VM: they need real VS Code, Telegram and Chrome, which the guest does not have and cannot install (no `winget`).

---

## 6. KNOWN LIMITATIONS

### CONFIRMED LIMITATIONS

**Internal monitor edges animate instantly** (no smooth slide-in/out). When a slot is assigned to an internal edge (the edge between two monitors), there is no empty off-screen space to animate through. The window appears/disappears without animation. This is by design — the alternative would be to animate across the neighbor monitor, which is worse.

**Handles steal screen edge real estate.** Each parked window's handle tab (22 px wide at rest) covers the last 22 px of the work area at its edge. Applications that respect the work area won't use this strip; those that don't may overlap the handle.

**Fullscreen/AlwaysOnTop windows can overlap handles.** A window covering the entire screen hides the handles behind it. No workaround.

**Rapid hotkey queue.** Pressing Ctrl+Alt+N many times quickly queues up toggles. All commands execute in order; no commands are lost, but the visual feedback (notifications) may pile up. Dedup prevents notification floods but the underlying hide/show still runs.

**Drawer killed with parked windows leaves them off-screen.** If Drawer.exe is terminated (not via Ctrl+Alt+Shift+0), parked windows remain in their off-screen position. They are still accessible via taskbar and will restore correctly if Drawer is restarted.

**config.ini encoding is UTF-16 LE.** If edited with a tool that saves as UTF-8 (without BOM), AHK v2's `IniRead` will fail to read Cyrillic text in `name=` fields. The file's comments document this.

### UNCONFIRMED RISKS

*Not reproduced or not fully characterized — do not treat as confirmed bugs.*

**Multi-monitor DPI mismatch.** Not tested with mixed DPI monitors (e.g. 100% + 150%). Geometry calculations use physical pixels; DPI differences may cause incorrect parking positions.

**Multiple windows of the same exe for permanent slots.** `FindWindow` uses exe name and optionally window class. If two windows of the same application exist, the one picked may not be the expected one. Not formally tested.

**hideOnBlur + activateOnShow=false.** If a slot is configured with `hideOnBlur=true` and `activateOnShow=false`, the window is shown but not activated. When the user then activates another window, hideOnBlur fires and parks the slot immediately, before the user interacted with it. Behavior not explicitly tested.

---

## 7. KNOWN RISKS / OPEN ISSUES

### WatchBlur race (CLOSED)

Fixed in commits `413b4f9` and `96572e8`. Two distinct races: (a) manual slot switch while WatchBlur timer was running → crash; (b) WatchBlur animation playing over already-shown window → visual artifact. Both fixed.

### Duplicate TrayTip (CLOSED)

Fixed in `f1f9e89`. AHK queues TrayTip calls; rapid empty-slot presses flooded the notification queue. Fixed with per-text dedup (4 s window).

### VM guestcontrol process isolation (OPEN / KNOWN)

Stop-Process and similar WMI-based process control from guestcontrol (Session 0) does not terminate Drawer processes in the interactive session (Session 1). Workaround: use keyboard simulation to open an interactive PS and run `taskkill /IM Drawer.exe /F` from there.  
**Not a Drawer bug.** No action needed in Drawer code.

### Full VM automated test (OPEN / INFRASTRUCTURE)

`test/vm/run-in-vm.ps1` has never run end-to-end. The VM ("tetst") has only 1 monitor. Full automated test needs: a new VM created with `new-vm.ps1` + ISO, 2 monitors configured, snapshot created.  
**Does not block development.** Host test harness is the primary validation path.

---

## 8. IMPORTANT DESIGN DECISIONS

**Dynamic slot = specific HWND, not the application.** `Ctrl+Alt+Shift+N` binds the *window* at that moment. If the user closes and reopens the application, the slot is empty. This is intentional — the user chose that specific window.

**Handles are Drawer's own Gui windows, not overlays on the application.** They are WS_POPUP windows created by Drawer at computed edge positions. The application has no knowledge of them.

**No drag for handles.** Handles click to deploy but cannot be dragged to reorder. No plan to change this.

**Internal-edge animation limitation is accepted.** The code detects internal edges and skips the slide animation. This was documented and accepted; do not "fix" it by animating across the neighbor monitor.

**config.ini is the only settings storage.** All persistent configuration lives in config.ini; Drawer does not write it today. The old decision that a settings UI would never be built (Р6 in `docs/03-решения.md`) is **cancelled** — see Р18 in the same file. The settings window is a shell over config.ini, not a second store: it writes individual keys, never regenerates the file, saves nothing on exit or on Cancel, and verifies every write by reading it back. S1 (read-only Settings) and S2 (General editable) are implemented. S3–S5 — per-slot settings, permanent slot editing, slot type changes — are not.

**Hotkeys 1–9 are fixed and non-configurable.** Only `focusHotkey` for permanent slots is configurable. The main slot hotkeys (Ctrl+Alt+N, Ctrl+Alt+Shift+N, etc.) are not exposed for remapping. Changing them requires code + recompile.

**`#SingleInstance Force`** is used. If an old instance was force-killed, the new instance shows an AHK dialog asking whether to wait. Pressing Нет aborts the new instance. This is native AHK behavior — do not "fix" by removing `#SingleInstance`; without it, multiple instances would register conflicting hotkeys silently.

**Hotkeys use keyboard hook (`$` prefix), not RegisterHotKey.** This avoids hotkey conflicts with other applications that use RegisterHotKey for the same combination, and works even when Drawer is not the foreground application.

**Binary-only public release.** The GitHub release contains only `Drawer.exe` + `config.ini` (example). Source code is not in the release archive. The source repo (`nerzar/Drawer`) is public but contains no release artifacts (they are in `dist/`, which is `.gitignore`d).

**Do not revert** the WatchBlur race fixes (413b4f9, 96572e8). They are non-obvious guard conditions that prevent real crashes.

---

## 9. RELEASE / GITHUB

| Field | Value |
|---|---|
| Public release | v0.1.2-beta |
| GitHub repo | https://github.com/nerzar/Drawer |
| Release archive | `Drawer-v0.1.2-beta.zip` (759 KB, uploaded this session) |
| Archive contents | `Drawer.exe` + `config.ini` (example/template) |
| Source in release | No |
| Branches | `master` only |
| Main branch | `master` |
| Release notes | Written in English, lists known limitations |

**What must NOT be changed without explicit approval:**
- No push to remote
- No new tags
- No new GitHub releases
- No changes to Drawer functionality, UI, hotkeys, handles, or geometry
- No refactoring

---

## 10. NEXT STEP

**S1 and S2 are complete.** The tray menu opens a single Settings window with three tabs. General is editable and writes `[general]` and `[dynamic]`; Slots and About remain read-only. Verified in the VM by a targeted driver: 34/34, 0 failures. Design decision is Р18 in `docs/03-решения.md`.

Two things were found and fixed on the way, both worth knowing:

- **`LoadConfig()` was not idempotent.** `apps.Push()` appended, so a second call duplicated every permanent slot (measured: 2 → 4 → 6 → 8), and `dynamicSlots` kept sections already deleted from the file. It now resets both on entry. Without this, "write → LoadConfig → apply" silently corrupts state.
- **`base` is a reserved property name in AHK v2** (`obj.base` is the prototype); assigning a string to it throws `ObjSetBase`. The form's snapshot field is called `snap`. Same class of trap as `log` and `exp` in the test drivers.

**S3 (live status column) is complete**, 2026-09-04. The Slots list shows a live "Состояние" column (`пусто` / `окно: <title>` / `выдвинут` / `припаркован` / `приложение не запущено`), polled only while the Slots tab is visible, timer stopped when Settings closes. Verified by hand in the VM — see §4 for why the automated `setstat` suite doesn't cover it yet (test-harness issue, not an S3 defect).

Per-slot overrides via `[dynamicSlotN]` — behind an explicit "свои настройки" checkbox that creates and deletes the section — were originally scoped together with S3 in this doc but were **not** part of the 2026-09-04 session. Still pending.

**NEXT PLANNED STAGE:** the `[dynamicSlotN]` overrides above, then permanent-slot editing / exe picker / Dynamic↔Permanent type changes (referred to as "S4" in the session that shipped the live column).

### Deferred, with the reason

**P2 — rebuilding `permSlots` and remapping `managed` after a config reload — is NOT implemented, and S2 does not need it.** `permSlots[slot] = index into apps` and `managed[index] = hwnd` stay correct as long as the set and order of `[slotN]` sections is unchanged, and S2 never writes those sections.

The one reproducible way to break it needs an external edit: open Settings, add or remove a `[slotN]` in config.ini by hand, then press Apply. `LoadConfig` rebuilds `apps` with shifted indices while `permSlots` and `managed` keep the old ones, so a slot hotkey can move the right window with the wrong geometry, or the wrong window. No stranded windows; restarting Drawer clears it. The fix is about seven lines and belongs to S4, where `[slotN]` becomes writable and the hazard turns into an everyday one.

### Rules that still apply

1. **Testing.** Heavy GUI and regression runs go in the VM (`tetst`, §5). The main PC is for short smoke and manual UI checks only, and `test/run.ps1` is not to be run there without explicit permission. Full policy in §4.
2. **No GitHub operations yet.** No push, no tags, no releases. Commits only when asked.
3. **The invariants from Р18 are not negotiable**: `config.ini` is the single source of truth, writes are per-key, the file is never regenerated, nothing is saved on exit or on Cancel, and every write is verified by reading it back. They exist because the predecessor's settings GUI silently lost changes (О5 in `docs/06-почему-не-wtq.md`).
4. **General means defaults for dynamic slots**, not global defaults. A permanent slot with its own `width` is not affected by the General value, because `LoadConfig` gives `[slotN]` its own literal defaults rather than inheriting from `[dynamic]`. The UI says so in plain words. Changing that inheritance would break existing configs and needs its own decision.

### What the next Claude should do

1. Read this file, then verify the actual repo state: `git log --oneline -5`, `git status`, the `VERSION` line in `src/drawer.ahk`.
2. Read the Settings block at the end of `src/drawer.ahk` — it carries its own design notes — and Р18 in `docs/03-решения.md`.
3. Propose the S3 change before writing code, and get approval.
4. Verify in the VM, not on the main PC.

---

## 11. HANDOFF NOTES

**WHAT THE NEXT CLAUDE SHOULD KNOW**

1. **Source is one file:** `src/drawer.ahk` (1 307 lines). Read it. Do not assume architecture from documentation alone.

2. **config.ini is UTF-16 LE.** Any tool that edits it must preserve this encoding. The in-app Settings feature must handle this correctly.

3. **Dynamic slot = HWND, not app.** This is load-bearing. Many natural "improvements" would break this invariant.

4. **AHK name collision rules apply.** Variable names `log`, `exp`, `gc` etc. clash with AHK built-ins. Always check before introducing new identifiers.

5. **SendLevel(1) required in test drivers.** Without it, AHK hotkeys in Drawer don't fire from test scripts. This was a painful lesson.

6. **Test harness requires 2 monitors, M2 left of M1.** The layout check in `test/layout.ahk` will refuse to run on any other configuration. Do not remove this check.

7. **The VM ("tetst") has only 1 monitor.** The formal test suite cannot run there. Either add a second monitor to the VM or use the host.

8. **Stop-Process from guestcontrol does not kill Session 1 processes.** Use keyboard simulation to run `taskkill` from an interactive PS session inside the VM.

9. **Force-killing Drawer leaves parked windows off-screen.** Always exit via `Ctrl+Alt+Shift+0` in production; in tests, the strand checker (`strand.ahk`) catches this.

10. **The AHK single-instance dialog appears after force-kill.** Wait for the mutex to clear (a few seconds), then retry.

11. **`handles` feature is recent (bcd6e1c).** The kromka/extra/off suites cover it. If touching handle code, run those suites first.

12. **Internal monitor edges animate instantly by design.** Do not "fix" this; it is documented and accepted.

13. **Notification dedup is 4 seconds per text+title.** The `quiet` suite verifies exact notification counts. If adding new notifications, update that suite.

14. **GitHub: binary-only release.** Source stays out of release archives. The repo is public but `dist/` is gitignored.

15. **The next planned feature is Settings** — not more hotkeys, not more slot types, not more animation options. Focus there.
