# A04A — handles seam analysis

- Status: `READY`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-A04-ANALYSIS-01`
- Eligible: `ANTIGRAVITY`
- Preferred model: `Gemini 3.8 Flash (Medium)`; do not switch to newly reappeared models unless explicitly reassigned by architect
- Session: `NEW`
- Base/source rule: analyze accepted shared production identity `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`; later docs-only shared commits do not change analyzed code.
- Branch: `tmp/never`

## Goal
Prepare the smallest safe A04 extraction plan for Drawer handle GUI/runtime behavior. Analysis only; no production/test implementation.

Map handle state, creation/destruction, synchronization, animation, click/focus behavior, Settings/runtime interactions, monitor/geometry dependencies, and all call sites currently in `src/drawer.ahk` or adjacent modules. Identify pure policy vs Win32/AHK side effects and exact ownership boundary for a future `WindowHandles.ahk` (or better justified name).

Deliver:
- current state/call graph;
- coupling/dependencies on Slots, WindowFocus, geometry, Settings and service windows;
- smallest implementation slices with explicit ordering/dependencies;
- behavior invariants and regression risks;
- proposed production-direct narrow tests;
- exact recommended file/symbol scope for first implementation slice;
- verdict `READY_TO_IMPLEMENT`, `NEEDS_PREREQUISITE`, or `BLOCKED`.

Do not redesign product UX and do not implement code. Follow current AGENT_BOARD, claim/ref-hygiene protocol and REPORT_FORMAT. Report to `docs/agent-reports/2026-09-07-antigravity-a04-analysis.md`, push report-only branch, update claim DONE/BLOCKED.

Note: branch `tmp/never` was pre-created by architect from the shared branch and is intentionally assigned to this Run ID so it is not an orphan ref. Do not create an additional analysis branch.