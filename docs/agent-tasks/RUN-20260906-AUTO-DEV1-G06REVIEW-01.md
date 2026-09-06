# G06R — independent GitHub-native review

- Status: `READY`
- Eligible: `DEV1`
- Run ID: `RUN-20260906-AUTO-DEV1-G06REVIEW-01`
- Base: G06 Code SHA `5e9c717f23ee4503c0850a9be5d406892d49bed9`
- Branch: `review/g06-navigation-accessibility`
- Task file: `docs/agent-tasks/RUN-20260906-AUTO-DEV1-G06REVIEW-01.md`
- Worktree: `N/A — GitHub-native repo-only review`

## Goal
Independently review G06 against the completed G06A findings and accepted G03/G05 behavior. Do not implement fixes.

Review selected-slot persistence and field-error routing, lifecycle safety without KeepAlive, Sidebar/nav semantics, General label/aria/save-lock preservation, Footer focus/live-region behavior, picker naming/help semantics, focus-visible CSS and contrast, list/detail scrolling, narrow-layout risks, test quality, and unrelated scope changes.

Output report with findings by severity and verdict `ACCEPT`, `ACCEPT_WITH_RUNTIME_CHECK`, `NEEDS_FIX`, or `BLOCKED`. Use autonomous claim protocol. Report-only branch, no production edits, no self-promotion.