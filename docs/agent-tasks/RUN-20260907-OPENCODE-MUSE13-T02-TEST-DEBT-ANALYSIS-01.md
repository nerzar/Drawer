# T02A — narrow test debt / production-seam coverage audit

- Status: `READY`
- Run ID: `RUN-20260907-OPENCODE-MUSE13-T02-TEST-DEBT-ANALYSIS-01`
- Eligible: `OPENCODE-MUSE13`
- Required model: `Muse Spark 1.3 Contributor Free`
- Session: `NEW`
- Base/source rule: analyze accepted shared production identity `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`; docs-only shared commits may be read for context. Do not treat unaccepted A02/A03/A04 branches as canonical production. You may inspect their tests/reports only to identify already-planned coverage and avoid duplicate recommendations, clearly labeling them unaccepted.
- Branch: `analysis/test-debt-production-seams-muse13`

## Goal
Audit Drawer narrow tests for duplicated/copy-model/source-shape assertions versus direct execution of production seams. Analysis only.

Inventory `test/narrow` and related deterministic tests. Classify tests as production-direct behavioral, integration/runtime, copied-model, static/source-shape, or obsolete/redundant. Pay special attention to Settings, WindowFocus, geometry and Slots authority. Identify places where copied logic could pass while production diverges.

## Deliver
- concise inventory/classification of relevant tests;
- prioritized KEEP list with reasons;
- REPLACE candidates only where an equivalent production-callable seam exists or is concretely planned;
- DELETE candidates only when demonstrably redundant after replacement;
- missing high-value regression cases;
- places where copied/static tests can give false confidence while production differs;
- cheapest first implementation slice with exact files/tests and prerequisites;
- verdict `READY_TO_IMPLEMENT`, `NEEDS_PREREQUISITE`, or `BLOCKED`.

## Constraints
- Fresh `git fetch dev`; read current `AGENT_BOARD.md` from `refs/remotes/dev/wip/slots-parity` and `docs/agent-reports/REPORT_FORMAT.md` before claiming.
- Claim this exact Run ID on shared branch using Critical Git ref hygiene.
- Analysis/report only. Do not modify production code or tests and do not run long GUI/VM suites.
- Verify claims against repository facts; do not merely repeat prior reports.
- Avoid broad test-framework redesign.
- One Run ID = one report-only branch.
- Report to `docs/agent-reports/2026-09-07-opencode-muse13-t02-test-debt-analysis.md`.
- On completion push report branch, update claim `DONE`/`BLOCKED` on shared branch, verify remote and clean tree.
- Do not self-implement recommendations and do not self-promote.
