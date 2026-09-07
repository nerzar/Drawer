# A05A — Settings service / tray seam analysis

- Status: `READY`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-A05-ANALYSIS-01`
- Eligible: `ANTIGRAVITY`
- Preferred model: `Gemini 3.8 Flash (Medium)`
- Session: `NEW`
- Base/source rule: analyze accepted shared production identity `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`; later docs/tasks/claims/reports and unaccepted A02/A04 branches do not change analyzed production code.
- Branch: `analysis/a05-settings-tray-seam-antigravity`

## Goal
Analyze the remaining Settings service/tray/runtime orchestration seam after G03/G05/G06 and accepted A02S1. Analysis only; no implementation or promotion.

Map Settings window/service lifecycle, WebView bridge entry points, config reload/reconcile orchestration, tray commands/state, service-window registration, hotkey rebind/runtime notifications, and dependencies on Slots/focus/geometry/handles. Separate persistence/bridge responsibilities from runtime application and tray/UI lifecycle.

## Deliver
- call/state map and current ownership problems;
- smallest safe module boundary/boundaries; do not introduce generic DI/framework layers;
- ordered implementation slices and prerequisites;
- invariants from accepted Settings behavior that must remain exact;
- direct production-seam tests worth adding and copied/static tests worth retiring only after equivalent production coverage exists;
- exact first implementation slice scope;
- verdict `READY_TO_IMPLEMENT`, `NEEDS_PREREQUISITE`, or `BLOCKED`.

## Constraints
- Read current `AGENT_BOARD.md` and `docs/agent-reports/REPORT_FORMAT.md` after fresh fetch and claim this Run ID before work.
- Do not base conclusions on unaccepted A02S2/A04 code as if it were production. You may note those lines only as future dependency context.
- Do not redesign Settings UX and do not change production/test code.
- Preserve Critical Git ref hygiene. One Run ID = one branch.
- Report to `docs/agent-reports/2026-09-07-antigravity-a05-analysis.md`, push report-only branch, update claim `DONE`/`BLOCKED`, verify remote, clean tree.
- Do not self-implement the resulting slices and do not self-promote.
