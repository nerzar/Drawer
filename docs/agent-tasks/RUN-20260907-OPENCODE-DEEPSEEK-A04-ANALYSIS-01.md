# A04A — handles seam analysis

- Run ID: `RUN-20260907-OPENCODE-DEEPSEEK-A04-ANALYSIS-01`
- Eligible: `OPENCODE-DEEPSEEK`
- Required model: `deepseek-v4-flash`
- Session: `NEW`
- Base/source rule: analyze accepted shared production identity `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`; later docs-only shared commits do not change analyzed code.
- Branch: `analysis/a04-handles-seam-deepseek`

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

Do not redesign product UX and do not implement code. Follow current AGENT_BOARD, claim/ref-hygiene protocol and REPORT_FORMAT. Report to `docs/agent-reports/2026-09-07-opencode-deepseek-a04-analysis.md`, push report-only branch, update claim DONE/BLOCKED.