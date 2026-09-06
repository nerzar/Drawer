# A02S1ACCEPT — live Windows acceptance for watcher seam

- Run ID: `RUN-20260906-AUTO-ANTIGRAVITY-A02S1-ACCEPT-01`
- Eligible: `ANTIGRAVITY`
- Preferred model: `Gemini 3.8 Flash`; use Claude reserve only if Gemini cannot complete the runtime checks
- Session: `NEW`
- Base / tested Code SHA: `ac71581b98a58e51128a987d20d8b5b1952c1756`
- Source branch: `refactor/window-focus-watch-seam`
- Output branch: `verify/a02s1-window-focus-watch-seam`

## Goal
Live-verify that A02S1 watcher extraction preserved the already accepted G03 behavior on real Windows/WebView/AHK runtime. No feature implementation in this run.

## Acceptance focus
1. `activateOnShow=false` normal show does not become watched merely after unrelated Settings Apply.
2. Explicit FocusWindow/slot focus legitimately enrolls watcher even with `activateOnShow=false`, and reconcile preserves it while hideOnBlur remains enabled.
3. Duplicate HWND permanent + temporary/dynamic representation obeys permanent-slot authority for hideOnBlur.
4. Live `hideOnBlur true->false` removes watcher; `false->true` does not invent watcher authority for a merely deployed non-activated window.
5. `blurMs` change re-arms polling as expected; no stale timer behavior.
6. Stale/dead/not-deployed watcher cleanup remains correct and one watcher becoming ineligible does not disturb another valid watcher.
7. Normal slot show/hide/focus behavior and Settings Apply still function after extraction.

## Checks
Run relevant AHK validate, `test/narrow/window-focus-seam.ahk`, settings seam if practical, and the focused real-window acceptance available in this environment. Preserve `src/config.ini` exactly.

## Output
Create factual report with verdict `ACCEPT`, `NEEDS_FIX`, or `BLOCKED`, exact tested Code SHA, live cases/pass count, and any runtime anomalies. Follow current claim/ref-hygiene protocol. Do not edit production code; if a defect is found, report it rather than patching in this run.
