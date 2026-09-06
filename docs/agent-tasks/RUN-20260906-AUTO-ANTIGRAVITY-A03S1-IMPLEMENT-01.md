# A03S1 — pure geometry plan seam

- Run ID: `RUN-20260906-AUTO-ANTIGRAVITY-A03S1-IMPLEMENT-01`
- Eligible: `ANTIGRAVITY`, `OPENCODE-DEEPSEEK`
- Preferred model: `Claude` if available; Gemini 3.8 Flash or `deepseek-v4-flash` allowed
- Session: `NEW`
- Claim race rule: first valid claim on the shared branch owns this Run ID and output branch; any other eligible worker must skip immediately after fresh fetch.
- Base source rule: current accepted shared lineage after P08; must contain shared production SHA `886e68663a0f487f3ad00c248a4aed87e02861c7` and accepted A02S1 `ac71581b98a58e51128a987d20d8b5b1952c1756` as ancestors. This slice must not depend on unaccepted A02S2.
- Analysis input: `analysis/a03-parking-geometry-seam` report `2026-09-06-codex-a03-analysis.md`
- Output branch: `refactor/window-geometry-plan-seam`

## Goal
Implement only A03S1 from the completed A03 analysis: extract deterministic rectangle/geometry planning into a production-callable `src/WindowGeometry.ahk` seam without changing placement behavior.

## Required scope
- Add pure helpers equivalent to the analysis recommendation: rectangle intersection/hit helpers and `WindowGeometryPlan(...)`.
- Keep `ComputeGeom(cfg, mi)` as a live compatibility wrapper that gathers MonitorGet/SysGet facts then calls the pure policy.
- Preserve exact behavior: 5–100 clamp, integer truncation, work-area sizing, full-monitor collision, virtual-screen parking 20px beyond bounds, negative coordinates, internal-edge `slide=false`, all four edges.
- Do not move geometry state ownership, Show/Hide, Slots identity, focus/watcher, handles, Settings or tray in this slice.

## Tests
Add `test/narrow/window-geometry-seam.ahk` calling production policy directly. Cover all four edges, clamp/truncation, negative coordinates, gaps, vertical/horizontal internal edges, external edges, work-area/taskbar differences and parking beyond virtual bounds. Run AHK validate + new seam + relevant existing narrow checks with bounded timeout. Preserve `src/config.ini`.

## Completion
Report separate Code SHA/report tip SHA, explicit push, verify remote, clean tree, update claim DONE/BLOCKED. Do not self-promote.
