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
Config: `config.ini` next to the executable, read at startup, never written by Drawer. Format: INI, UTF-16 LE (required for Cyrillic text in `name=` fields).

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
| Full test suite in VM | NOT RUN — requires 2 monitors |

---

## 5. VM

### Current test VM ("tetst")

| Property | Value |
|---|---|
| Host VirtualBox | 7.2.16 |
| Guest OS | Windows 11 (visual confirmation; exact build UNKNOWN — diag-result.txt not read back) |
| Architecture | x64 (UNKNOWN — not read from diag this session) |
| Monitor count | 1 (single monitor — insufficient for full test suite which requires 2) |
| Resolution | ~1536×786 (from screenshots) |
| DPI/scaling | UNKNOWN |
| Username | vboxuser, password 1211 |
| AHK in guest | NOT installed — not needed (compiled exe) |
| VBoxService | Running, Startup=Automatic (fixed this session) |

### File delivery

```powershell
VBoxManage guestcontrol "tetst" copyto --username vboxuser --password 1211 `
    "host\path\file.exe" "C:\Users\vboxuser\Desktop\file.exe"
```

Single-file syntax: `source dest-full-path` (not `--target-directory`).

For PS scripts with complex logic: write on host → `copyto` → run with `-ExecutionPolicy Bypass -File`.

### Keyboard simulation

```powershell
VBoxManage controlvm "tetst" keyboardputscancode <bytes>  # raw PS/2 Set-1 scancodes
VBoxManage controlvm "tetst" keyboardputstring "text"     # text input
```

Hotkeys confirmed working via this method. Modifier combo order: make Ctrl → make Alt → make Shift → make key → break key → break Shift → break Alt → break Ctrl.

### Known VM limitations

- **1 monitor only** — test harness requires 2 monitors (M2 left of M1); `run.ps1` will refuse to run.
- **No snapshot** created for this VM.
- **Stop-Process from guestcontrol fails** across Session 0→1 boundary. Use `taskkill /IM Drawer.exe /F` from an interactive PS session (keyboard simulation) to kill Drawer.
- **AHK single-instance mutex** lingers after force-kill; next launch shows "Could not close previous instance" dialog (press Нет to abort, then retry after a pause).
- `test/vm/run-in-vm.ps1` and `test/vm/new-vm.ps1` have **never been executed end-to-end** (require Windows ISO). Written against VBoxManage 7.2 help.

### Automation boundary

Automatable via VBoxManage: file copy, PS script execution, screenshot, keyboard input.  
Requires interactive session (keyboard sim): launching GUI apps, UAC elevation, killing Drawer, starting Drawer.  
Cannot automate: mouse clicks (no VBoxManage mouse API in use; would need SendInput from guest session).

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

**config.ini is the only settings storage.** Drawer never writes settings. All persistent configuration is in config.ini. This means there is no in-app settings UI — that is the *next planned feature*.

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

**NEXT PLANNED STAGE: Settings**

The app currently has no in-app settings UI. All configuration is done by editing `config.ini` manually. The next stage is to design and implement a Settings interface.

**The next Claude must NOT implement Settings immediately. Read the repo, propose architecture, get approval first.**

### What the next Claude should do

1. Read `PROJECT_STATE.md` (this file).
2. Verify actual repo state: `git log --oneline -5`, `git status`, check `src/drawer.ahk` for current version.
3. Read the existing docs in `docs/` — they contain briefs, requirements, and design decisions from prior sessions.
4. **Do NOT start implementing Settings automatically.**
5. Propose Settings architecture and UX first:
   - What can be configured in-app vs. stays in config.ini?
   - What is the UI paradigm (tray menu? Settings window? Wizard?)?
   - How does Settings UI interact with existing config.ini on disk?
   - How does Drawer reload config (restart vs. hot reload)?
6. Get explicit approval before writing any code.
7. After implementation: use the host test harness (`test/run.ps1`) and the VM for verification. The VM currently needs 2 monitors for the full suite — this may need to be addressed first if multi-monitor settings behavior must be tested.

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
