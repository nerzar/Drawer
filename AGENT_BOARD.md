# AGENT_BOARD — Drawer autonomous work queue

Blackboard между архитектором ChatGPT и coding agents.

**Владелец файла:** архитектор ChatGPT. Coding agents этот файл не редактируют и приоритеты сами не меняют.

## AUTONOMOUS WORKER PROTOCOL
Coding agents may self-pick work only when a task explicitly contains `Status: READY`, eligible agent, Run ID, exact base/source rule, branch and task path. Claim through `docs/agent-claims/<RUN-ID>.md` after fresh fetch. One Run ID = one branch. Completed/claimed work is not picked twice.

### Critical Git ref hygiene
`dev` is the private remote. Read shared board from `refs/remotes/dev/wip/slots-parity`; push shared docs explicitly to `HEAD:refs/heads/wip/slots-parity`. Never create local `dev/...` branches or use ambiguous `dev/wip/slots-parity`. Inspect worktrees/exact refs/unique commits before destructive cleanup.

## Общий протокол
1. `git fetch dev`.
2. Read board from `refs/remotes/dev/wip/slots-parity`.
3. Read `docs/agent-reports/REPORT_FORMAT.md` and exact task.
4. Claim, obey Base/Code SHA, scope, worktree and ref hygiene.
5. Run targeted gates; report/commit/push/verify remote and clean tree.
6. Never self-accept/promote or change architecture/priority without explicit task.
7. On blocker/conflict/data-loss risk: preserve state, report `BLOCKED`, stop.

## Current status / manual checkpoint FAILED

- Accepted production remains `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`.
- Candidate `cd6dc00b3d58c6abea709687618ea3702432bc45` on `integration/manual-candidate-20260907` is **REJECTED FOR PROMOTION pending fix** after user manual acceptance.
- Manual PASS: basic handles behavior; Settings lifecycle.
- Manual MATERIAL FAIL: on monitor 2 deployment starts/animates on the wrong monitor / from monitor 1; cursor/target monitor does not match visible deployment origin; an edge handle disappeared completely once; multi-monitor behavior is materially worse than accepted production.
- Automated gates were green but did not predict this runtime regression. Do not use them alone as promotion evidence for this wave.
- T01, focus FIX, geometry FIX and handles reviews remain useful evidence, but their combined candidate is not accepted.
- A05 implementation and all next-wave refactors remain gated until this regression is fixed and manually re-tested.

## AUTONOMOUS QUEUE — ANTIGRAVITY

### Diagnose failed manual multi-monitor behavior
- Status: `READY`
- Eligible: `ANTIGRAVITY`
- Preferred model: `Gemini 3.8 Flash (Medium)`
- Session: `NEW`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-MANUAL-MULTIMON-FAILURE-ANALYSIS-01`
- Base/source: failed candidate `cd6dc00b3d58c6abea709687618ea3702432bc45`; compare against accepted production `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`
- Branch: `analysis/manual-multimon-regression-antigravity`
- Task: `docs/agent-tasks/RUN-20260907-AUTO-ANTIGRAVITY-MANUAL-MULTIMON-FAILURE-ANALYSIS-01.md`

Analysis only. Identify exact root cause/first bad lineage and smallest safe fix/test. Do not modify production or promote.

## AUTONOMOUS QUEUE — OPENCODE / MUSE 1.3 FREE
No current READY task. Hold Muse for independent review/fix verification after Antigravity localizes the regression.

## Next gate
After Antigravity analysis: architect publishes a narrow FIX task, preferably to Muse if the fix is small and well-localized, followed by independent verification and a rebuilt manual candidate. User re-tests multi-monitor behavior before any promotion.
