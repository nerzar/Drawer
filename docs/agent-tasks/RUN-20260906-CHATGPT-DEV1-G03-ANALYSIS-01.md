# TASK G03A — repo-only design/test plan for live hideOnBlur/blurMs + save lock

- Run ID: `RUN-20260906-CHATGPT-DEV1-G03-ANALYSIS-01`
- Executor: ChatGPT DEV-1 (browser/GitHub-native)
- Model: GPT-5.6 Sol
- Source branch: `dev/wip/slots-parity`
- Reference accepted candidate: `dev/integration/slots-settings-wave4@e4136c5`
- Output branch: `dev/analysis/g03-live-settings`

## Why this task exists
DEV-1 has GitHub repository access but no access to the operator's local Windows checkout. This task is deliberately repo-only and must not require local worktrees, runtime execution, AHK validation, npm execution, or synchronization of `C:\Users\nerza\...`.

## Goal
Prepare the next implementation task G03 by doing a code-grounded analysis of the current Wave 4 implementation for:
1. `hideOnBlur` changes after Apply actually affecting an already shown/managed window;
2. `blurMs` changes not leaving a stale timer/old delay active;
3. General settings inputs being protected from concurrent edits while Save/Apply is in flight.

Do not implement the production fix in this run. Produce a precise implementation map and regression-test plan that another local/runtime-capable agent can execute with minimal rediscovery.

## Required investigation
Using repository/GitHub reads only:
- trace General settings draft -> bridge/request -> AHK/backend persistence/reconcile -> runtime slot/window behavior;
- locate where `hideOnBlur` and `blurMs` are read/cached and where blur timers are created/cancelled;
- determine whether Apply updates the live runtime object/state used by already managed/shown windows or only persistence/config;
- locate Save/Apply pending state in Settings UI and identify which General inputs/actions remain editable during the request;
- identify the smallest likely production files/functions for G03 and likely collision points with C03;
- inspect existing tests and state exactly which regression cases can be unit/seam-tested and which require a real Windows runtime check.

## Output
Create `docs/agent-reports/2026-09-06-chatgpt-dev1-g03-analysis.md` containing:
- factual current behavior/code path with file/function references;
- root-cause hypotheses ranked by confidence, clearly separating proven code facts from hypotheses;
- minimal proposed implementation scope;
- explicit overlap/conflict risk with C03;
- concrete regression-test matrix;
- manual runtime verification checklist for the implementation agent;
- recommendation: `READY_TO_IMPLEMENT`, `NEEDS_ARCH_DECISION`, or `BLOCKED`, with reasons.

Do not edit `AGENT_BOARD.md` or `docs/ARCHITECT_STATE.md`. Do not change product/runtime/frontend source files in this analysis run.

## GitHub-native completion
Because this agent has no local filesystem access, normal local-worktree/clean-tree/test requirements are intentionally waived for this Run ID. Use GitHub repository operations only. Create/use `dev/analysis/g03-live-settings`, commit/push the report there, and verify the remote branch/ref through GitHub. No local tests are expected.

Final response: Run ID, DONE/BLOCKED, branch, final SHA, recommendation, and the 3–5 most important findings.