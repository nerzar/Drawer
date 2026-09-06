# A03A — parking / geometry seam analysis

- Run ID: `RUN-20260906-AUTO-CODEX-A03-ANALYSIS-01`
- Eligible: `CODEX`
- Base: shared production identity `9162d157a3f6b3155519ed6248605b0f432ff832` plus docs-only shared commits; analyze accepted production lineage only, do not depend on unaccepted A02S1
- Output branch: `analysis/a03-parking-geometry-seam`

## Goal
Prepare the next architecture slice for parking/geometry ownership without changing production code. Identify the smallest behavior-preserving extraction that can follow A02.

## Analyze
1. Map current ownership/call graph for geometry calculation, parking/off-screen placement, monitor selection, saved/restored rects and any slot/runtime coupling.
2. Identify globals/state and Win32 dependencies that prevent narrow testing.
3. Separate pure geometry policy from live monitor/window adapters.
4. Identify behavior invariants already covered by tests and important missing seams, especially multi-monitor edges, negative coordinates, taskbar/work-area differences, stale/off-screen rects and permanent/dynamic slot behavior.
5. Propose A03 implementation slices small enough for independent review; list exact files/functions expected per slice.
6. Flag overlap/dependency with A02S1/A02S2 and state what must wait for accepted A02 lineage versus what is independent.
7. Do not redesign behavior or broaden into handles/Settings/tray.

## Output
Create `docs/agent-reports/2026-09-06-codex-a03-analysis.md` with current map, risks, recommended slices, test strategy, and verdict `READY_TO_IMPLEMENT` or `NEEDS_DECISION`. No production edits.

Follow current AGENT_BOARD autonomous claim/ref-hygiene protocol. One Run ID = one branch. Push report-only output branch explicitly and update claim to DONE/BLOCKED.
