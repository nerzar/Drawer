# Slots parity — final factual report

Date: 2026-09-05
Workspace: `C:\Users\nerza\Projects\drawer-settings-integration`
Branch: `wip/slots-parity`

## Goal

Finish the Slots parity milestone from `af62f28` for manual acceptance, preserving the approved UI and existing conversion, dynamic overrides, focus and edge behavior. Fix the red WebView slice without an architecture refactor.

## Result

The source WebView slice passes 33/33: conversion in both directions, dynamic overrides and inherited values, no-op Apply, bind/release, live status, dirty-close, validation routing and OK persistence through the real bridge on a temporary config. The smoke also verifies PNG decoding in the UI.

Runnable build: `dist/Drawer-v0.1.2-beta/Drawer.exe`.
Archive: `dist/Drawer-v0.1.2-beta.zip`.
Build output is ignored by Git. The frontend and WebView2 loader were verified embedded. Source config and `docs/ARCHITECT_STATE.md` were not changed. No branch/worktree creation, merge, rebase or cherry-pick occurred.

## Commits

- `af62f28`: verified starting HEAD, initial tree clean.
- `fdacfe6`: functional fixes and targeted regression checks.
- This report is committed separately as `docs: record completed Slots parity milestone`; its commit is the final HEAD directly after `fdacfe6`.

## Root cause and important decisions

1. The native failure was access violation `0xC0000005` (exit `-1073741819`) when window discovery triggered PNG icon generation. GDI+ calls did not retain the DLL across startup, bitmap/stream operations and shutdown. Added `#DllLoad gdiplus.dll`. An isolated icon probe returned an empty URI before the change and a 502-character PNG URI with DLL retention. The slice then passed discovery/reentry and, after stale expectations were corrected, completed. Registration after Show was retained.
2. Restored `webHwnd := webAdapter.Hwnd` after Show for reopening the existing Settings window and dropping the same service registry entry on destruction. Vendored WebViewToo Show calls Gui.Show; its source does not support the old comment claiming a replacement HWND, so that claim was removed.
3. Whole-object JSON equality depended on key order. AHK Map order differs from frontend field construction; unchanged slots could therefore be sent as edits and retain old dynamic defaults as unintended overrides. Compare individual fields instead. A targeted test uses sorted AHK-style keys for both slot kinds.
4. WindowAppName called an undefined FileGetVersionInfo, silently falling back to the exe basename. Added cached FileDescription reading through Windows version resources and their language/codepage pairs. Verified `AutoHotkey 64-bit` from the interpreter and empty output for a missing file. Reference: https://learn.microsoft.com/en-us/windows/win32/api/winver/nf-winver-verqueryvaluew
5. Two smoke expectations still assumed dynamic slots had no width editor. They now wait for selected slot 5 and width 43. Bind/release completion markers are acknowledged sequentially; the prior trace missed one adjacent fire-and-forget marker.
6. Smoke now checks process exit code and captures AHK stderr. Previously a crash counted as successful process completion, followed by downstream checkpoint failures.

## Tests

- Source `webview-slice.ps1`: **33/33**, exit 0. Retained trace: `C:\Users\nerza\AppData\Local\Temp\drawer-webview-slice-d8d8078d\bridge.log`.
- `npm test --prefix settings-ui`: **25/25**.
- `npm run typecheck --prefix settings-ui`: passed.
- `npm run build --prefix settings-ui`: passed.
- AHK `/ErrorStdOut /validate src/drawer.ahk`: exit 0.
- `test/narrow/settings-seam.ahk`: **162 OK, 0 FAIL**, exit 0. Captured stdout uses legacy encoding; ASCII result prefixes were counted.
- Isolated GDI+ icon and FileDescription probes: passed as described above.
- `build/build.ps1 -SkipFrontend`: passed; exe 1,934,336 bytes; both embedded assets found.
- `git diff --check`: passed before functional commit.

The first launch was denied by the sandbox; an authorized retry did not reach the bridge before timeout. A subsequent baseline run reproduced native termination; the diagnostic run captured the access violation. No VM, full suite, picker suite or compiled runtime smoke was run.

## Known issues / unfinished

- Manual acceptance remains for real applications: focus returning to Settings after slot hide, retained edge during show/hide, and approved UI appearance. These behaviors were not visually verified.
- Mixed DPI / multi-monitor behavior and compiled runtime execution were not re-tested; the release was built and embedded assets checked.
- Existing limitations remain: focusHotkey changes require restart; Save is not transactional.
- No known blocker remains in the exercised Slots parity path.

## Manual acceptance

Launch the built Drawer.exe, bind a test application to a dynamic slot, open WebView Settings twice (one window should remain), convert the slot to permanent and Apply, then back to dynamic and Apply. With Settings focused, toggle the slot with Ctrl+Alt+N: Settings should stay visible, focus should return after hiding, and the edge should remain usable.
