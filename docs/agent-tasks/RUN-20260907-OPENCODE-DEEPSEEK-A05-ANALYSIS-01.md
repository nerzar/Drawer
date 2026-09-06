# A05A — Settings service / tray seam analysis

- Run ID: `RUN-20260907-OPENCODE-DEEPSEEK-A05-ANALYSIS-01`
- Eligible: `OPENCODE-DEEPSEEK`
- Required model: `deepseek-v4-flash`
- Session: `NEW`
- Base/source rule: analyze accepted shared production identity `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`; later docs-only shared commits do not change analyzed code.
- Branch: `analysis/a05-settings-tray-seam-deepseek`

## Goal
Analyze the remaining Settings service/tray/runtime orchestration seam after G03/G05/G06 and A02S1. Analysis only; no implementation.

Map Settings window/service lifecycle, WebView bridge entry points, config reload/reconcile orchestration, tray commands/state, service-window registration, hotkey rebind/runtime notifications, and dependencies on Slots/focus/geometry/handles. Separate persistence/bridge responsibilities from runtime application and tray/UI lifecycle.

Deliver:
- call/state map and current ownership problems;
- smallest safe module boundary/boundaries (do not create generic DI/framework layers);
- ordered implementation slices and prerequisites;
- invariants from accepted Settings behavior that must remain exact;
- direct seam tests worth adding and copied/static tests worth retiring only after equivalent production coverage exists;
- exact first-slice scope;
- verdict `READY_TO_IMPLEMENT`, `NEEDS_PREREQUISITE`, or `BLOCKED`.

Do not redesign Settings UX and do not change code. Follow current AGENT_BOARD, claim/ref-hygiene protocol and REPORT_FORMAT. Report to `docs/agent-reports/2026-09-07-opencode-deepseek-a05-analysis.md`, push report-only branch, update claim DONE/BLOCKED.