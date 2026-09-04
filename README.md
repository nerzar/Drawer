# Drawer — setup

Reference for `config.ini`. For what Drawer is and how to start, see
`README.md` (the short one, also on the project page).

## Run

1. Extract `Drawer-v0.1.2-beta` anywhere.
2. Run `Drawer.exe`.

A tray notification shows the version and how many hotkeys registered.
Fewer than expected means another program already holds some of them.
Launching again replaces the running instance — no need to exit first.

`Drawer.exe` is self-contained; AutoHotkey is not required. Windows 10/11.
If `config.ini` is missing next to the exe, Drawer says so and stops
rather than starting half-configured.

## Hotkeys

| Hotkey | Action |
|---|---|
| `Ctrl+Alt+1…9` | show / hide the slot |
| `Ctrl+Alt+Shift+1…9` | bind the active window to the slot |
| `Ctrl+Alt+0` | clear all dynamic slots, windows return home |
| `Ctrl+Alt+Shift+0` | exit, windows return home |
| `focusHotkey` | optional per-slot hotkey that only restores focus |

## Slots

All nine slots are **dynamic** out of the box: empty until you press
`Ctrl+Alt+Shift+N`. That binds the *exact window* that was active, not
the application — one Chrome window out of five. Rebinding an occupied
slot sends the old window home. Dynamic bindings are forgotten on exit.

A slot becomes **permanent** by adding a `[slotN]` section with `exe=`.
It finds its application by process name on every press, so it survives
restarting that application, and `Ctrl+Alt+Shift+N` refuses to overwrite
it. With several windows of one application it takes the largest.

## config.ini

Plain text next to `Drawer.exe`, read at startup. Settings writes only
keys changed through Apply/OK; closing Settings, Cancel and application
exit do not save anything. Every option is documented inline in the file.

| Setting | Where | Meaning |
|---|---|---|
| `exe`, `cls` | `[slotN]` | makes the slot permanent |
| `monitor` | any slot section | `1`, `2`, … or `cursor` |
| `edge` | any slot section | `left`, `right`, `top`, `bottom` |
| `width` | any slot section | percent of the screen the drawer takes |
| `activateOnShow` | any slot section | take focus when sliding in |
| `hideOnBlur` | any slot section | hide again when focus leaves |
| `focusHotkey` | `[slotN]` | hotkey that focuses without toggling |
| defaults | `[dynamic]` | applies to every dynamic slot |
| overrides | `[dynamicSlotN]` | settings for one dynamic slot |
| `handles` | `[general]` | edge handles, on by default |
| `animMs`, `animSteps`, `blurMs` | `[general]` | animation and focus polling |

Two traps: a `;` comment must sit on its own line — trailing comments
become part of the value; and the file is UTF-16, so keep that encoding
if your editor asks.

Settings is available from the tray menu. General edits dynamic defaults;
Slots can edit permanent bindings and convert slots between permanent and
dynamic. The file remains the only persistent settings store.

## Edge handles

Each parked window leaves a small tile with its application icon at its
edge of the monitor. Move the pointer close and it grows and shows the
slot number; click it and the slot slides in — the same thing the hotkey
does. The deployed slot has no tile, its neighbours keep theirs, so you
can switch between parked windows with the mouse alone.

Set `handles=false` in `[general]` to turn this off entirely.

## Known limitations

- Killing the process instead of exiting with `Ctrl+Alt+Shift+0` leaves
  parked windows off-screen. Restart Drawer, bind them again and exit
  properly, or move them back with another tool.
- Mashing a hotkey queues the presses: after ~24 rapid presses the window
  keeps moving for about six seconds.
- When the chosen edge faces a second monitor, the slot appears and
  disappears instantly — animating there would show the window on the
  neighbouring screen.
- A fullscreen window that is itself always-on-top covers the handles.
- Only one dynamic slot cannot be cleared on its own — clear all, or
  close the window and the slot frees itself.
- Managed windows stay in Alt+Tab and on the taskbar. Handles do not.
- No autostart.
- Display scaling other than 100% and monitor layouts other than
  side-by-side are untested.

## Development

`src/drawer.ahk` runs directly under [AutoHotkey v2](https://www.autohotkey.com/);
`build/build.ps1` compiles the exe with [Ahk2Exe](https://github.com/AutoHotkey/Ahk2Exe/releases).
`test/` is the test bench — see `test/README.md`. Design notes and the
requirement history live in `docs/`, in Russian.
