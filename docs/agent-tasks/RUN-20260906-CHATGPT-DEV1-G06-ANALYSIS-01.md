# TASK G06A — repo-only navigation/accessibility/polish analysis

- Run ID: `RUN-20260906-CHATGPT-DEV1-G06-ANALYSIS-01`
- Executor: ChatGPT DEV-1
- Model: GPT-5.6 Sol
- Source branch: `dev/wip/slots-parity`
- Reference candidate: latest accepted/integrated settings lineage visible in repo
- Output branch: `dev/analysis/g06-navigation-accessibility`

## Goal
Prepare a code-grounded implementation plan for G06 without touching production code. Focus on selected-slot persistence between tabs, scrollbar/list behavior, keyboard/accessibility issues, remaining labels/select/contrast problems, and About follow-up.

## Required investigation
Using GitHub/repository reads only:
- trace selected slot state across tabs/routes and identify why selection may reset;
- inspect Slots list/detail layout and scrolling ownership, including narrow viewport behavior;
- inspect keyboard navigation/focusability/labels for interactive controls in Settings;
- identify obvious contrast/disabled/select/label issues that can be fixed without redesign;
- inspect About for remaining temporary/mock/internal artifacts;
- identify exact likely production files/functions/components and collision risks with G03/C03/G05;
- separate proven code facts from UX recommendations;
- produce a prioritized regression-test matrix and manual acceptance checklist.

## Output
Create `docs/agent-reports/2026-09-06-chatgpt-dev1-g06-analysis.md` with:
- findings ranked P0/P1/P2;
- exact file/function/component references;
- minimal proposed implementation scope;
- conflicts/overlaps with G03/G05;
- test matrix;
- recommendation `READY_TO_IMPLEMENT`, `NEEDS_ARCH_DECISION`, or `BLOCKED`.

Do not edit `AGENT_BOARD.md`, `docs/ARCHITECT_STATE.md`, or production/runtime/frontend source files. This is intentionally repo-only: no local worktree/runtime/tests required.

## Completion
Create/use `dev/analysis/g06-navigation-accessibility`, commit/push the report through GitHub, verify remote branch/ref. Final response: Run ID, DONE/BLOCKED, branch, final SHA, recommendation, top findings.