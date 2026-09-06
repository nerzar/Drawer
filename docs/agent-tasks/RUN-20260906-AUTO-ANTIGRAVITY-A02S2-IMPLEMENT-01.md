# A02S2 — focus history + foreground state extraction

- Run ID: `RUN-20260906-AUTO-ANTIGRAVITY-A02S2-IMPLEMENT-01`
- Eligible: `ANTIGRAVITY`
- Preferred model: `Claude` if Gemini budget is low; otherwise Gemini 3.8 Flash is allowed
- Session: `NEW`
- Base source rule: use the current `refs/remotes/dev/wip/slots-parity` only after it contains accepted A02S1 Code SHA `ac71581b98a58e51128a987d20d8b5b1952c1756` and shared production SHA `886e68663a0f487f3ad00c248a4aed87e02861c7` as ancestors. If not, do not claim this task yet.
- Output branch: `refactor/window-focus-history-foreground`

## Goal
Complete the second A02 slice described by the accepted A02 analysis: move previous-focus history and foreground observation/filtering state into `src/WindowFocus.ahk` while keeping geometry, Slots registry, handles, Settings persistence and tray ownership out of A02.

## Required scope
- Remove A02 `prev` ownership from shared geometry state so `state[hwnd]` becomes geometry-only (`orig/geom`) where safe.
- Move previous-focus history into WindowFocus-owned state/API.
- Move `foreWnd` / `lastFore` observation state and foreground filtering/dedup policy into WindowFocus-owned state/API.
- Keep `ForegroundWork()`, permanent-slot discovery, geometry seeding, handle updates, and physical Show/Hide orchestration in `drawer.ahk`.
- Ensure `Release(hwnd)`/cleanup forget focus history/watch state so HWND reuse cannot inherit stale state.
- Preserve all accepted G03 watcher invariants and A02S1 behavior.

## Verification
Add/extend production-direct narrow tests for focus history, foreground acceptance/dedup/filtering, release/forget behavior, and existing watcher invariants. Run AHK validate, window-focus seam, relevant settings seam with bounded timeout, and any focused real-window checks practical on this host. Preserve `src/config.ini`.

## Completion
Report separate Code SHA and report tip SHA, push explicit output ref, verify remote, clean tree, update claim DONE/BLOCKED. Do not self-promote.
