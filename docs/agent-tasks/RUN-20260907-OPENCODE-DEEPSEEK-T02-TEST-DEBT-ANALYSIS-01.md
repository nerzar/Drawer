# T02A — narrow test debt / production-seam coverage audit

- Run ID: `RUN-20260907-OPENCODE-DEEPSEEK-T02-TEST-DEBT-ANALYSIS-01`
- Eligible: `OPENCODE-DEEPSEEK`
- Required model: `deepseek-v4-flash`
- Session: `NEW`
- Base/source rule: latest accepted shared production identity available when claimed; docs-only shared commits allowed. Do not analyze unaccepted feature branches as canonical.
- Branch: `analysis/test-debt-production-seams-deepseek`

## Goal
Audit Drawer narrow tests for duplicated/copy-model/source-shape assertions versus direct execution of production seams. Analysis only.

Inventory `test/narrow` and related deterministic tests. Classify tests as production-direct behavioral, integration/runtime, copied-model, static/source-shape, or obsolete/redundant. Pay special attention to Settings, WindowFocus, geometry and Slots authority. Identify places where copied logic could pass while production diverges.

Deliver a prioritized debt plan:
- KEEP tests with reason;
- REPLACE candidates only where equivalent production-callable seam exists or is planned;
- DELETE candidates only when demonstrably redundant after replacement;
- missing high-value regression cases;
- cheapest first implementation slice with exact files/tests;
- avoid broad test-framework rewrite.

No production/test changes in this run. Follow current AGENT_BOARD, claim/ref-hygiene protocol and REPORT_FORMAT. Report to `docs/agent-reports/2026-09-07-opencode-deepseek-t02-test-debt-analysis.md`, push report-only branch, update claim DONE/BLOCKED.