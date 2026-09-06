# A02S1 — watcher policy/state extraction

- Status: `READY`
- Eligible: `CODEX`
- Run ID: `RUN-20260906-AUTO-CODEX-A02S1-01`
- Base: `dev/wip/slots-parity` production identity `9162d157a3f6b3155519ed6248605b0f432ff832`; if shared tip has advanced only by docs/claims, rebase task work on latest shared tip while preserving production base identity
- Branch: `refactor/window-focus-watch-seam`
- Task file: `docs/agent-tasks/RUN-20260906-AUTO-CODEX-A02S1-01.md`
- Worktree: `C:\Users\nerza\Projects\drawer-agent-worktrees\A02S1`

## Goal
Implement the first safe A02 slice from `docs/agent-reports/2026-09-06-chatgpt-dev1-a02-analysis.md`: extract watcher policy/state from `src/drawer.ahk` into a focused `src/WindowFocus.ahk` seam without moving Show/Hide geometry/parking ownership.

Required invariants: preserve accepted G03 watcher behavior exactly, including non-activating Show not auto-enrolled, FocusWindow legitimate watcher preservation, permanent-slot authority for duplicate HWND, and live hideOnBlur/blurMs reconcile. Prefer production-callable policy helpers and replace/strengthen model/source-shape tests where practical. Do not take A03 geometry, A04 handles, A05 Settings/tray ownership.

Run AHK validate + relevant narrow seams. Frontend gates only if frontend is touched (should not be necessary). `src/config.ini` untouched.

Use autonomous claim protocol from AGENT_BOARD. Do not self-promote. Report Code SHA separately from report tip SHA.