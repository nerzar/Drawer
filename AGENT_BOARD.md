# AGENT_BOARD — Drawer autonomous work queue

Blackboard между архитектором ChatGPT и coding agents.

**Владелец файла:** архитектор ChatGPT. Coding agents этот файл не редактируют и приоритеты сами не меняют.

## AUTONOMOUS WORKER PROTOCOL
A task is autonomous-ready only with `Status: READY`, eligible agent, Run ID, exact base/source, branch and task file. Fresh-fetch before every task. Claim through `docs/agent-claims/<RUN-ID>.md`; one Run ID = one branch; completed/claimed tasks are skipped.

### Critical Git ref hygiene
Read shared state from `refs/remotes/dev/wip/slots-parity`; shared docs push only to `HEAD:refs/heads/wip/slots-parity`. Never create local `dev/...` refs or use ambiguous `dev/wip/slots-parity`. Inspect worktrees/exact refs/unique commits before cleanup. Public `origin` is untouched.

## Protocol
1. `git fetch dev`; read current board, exact task and `REPORT_FORMAT.md`.
2. Claim; obey exact Base/Code SHA, scope, branch/worktree/session.
3. Verify repository facts independently; do not trust prior reports as proof.
4. Run bounded targeted gates; report/commit/push; verify remote + clean tree.
5. Never self-accept/promote or broaden scope. On blocker/conflict/data-loss risk: report `BLOCKED`, stop.

## Current status — MANUAL CANDIDATE FAILED
- Accepted production remains `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`.
- Failed candidate: `cd6dc00b3d58c6abea709687618ea3702432bc45`, branch `integration/manual-candidate-20260907`. **DO NOT PROMOTE.**
- User manual PASS: basic handles; Settings lifecycle.
- User manual FAIL: monitor-2 deployment visibly starts/animates from monitor 1 / neighboring monitor; target/cursor monitor and deployment origin disagree; an edge handle disappeared completely once; multi-monitor behavior materially regressed.
- Green narrow/validate gates did not predict this runtime failure. New refactors A03S2/A03S3/A05 remain frozen.
- Antigravity diagnosis DONE, verdict `READY_FOR_FIX`; Antigravity remains intentionally STOPPED to preserve budget.
- Muse independent diagnosis DONE, verdict `READY_FOR_FIX`.
- Both independent analyses agree the earlier `5ed8b9a` missing-braces monitor collection bug was real but is already fixed by `26b1133`. Both independently identify the remaining likely runtime defect as unstable `monitor: cursor` identity between `HandlesSync` and `Show`, which can regroup/destroy handles and deploy a managed window against a different monitor after incidental cursor movement.

## AUTONOMOUS QUEUE — ANTIGRAVITY
No current READY tasks. STOP after fresh fetch. Do not spend remaining Antigravity budget unless architect/user explicitly reopens it.

## AUTONOMOUS QUEUE — OPENCODE / MUSE 1.3 FREE
### Narrow FIX — managed-window monitor identity
- Status: `READY`
- Eligible: `OPENCODE-MUSE13`
- Required model: `Muse Spark 1.3 Contributor Free`
- Session: `NEW`
- Run ID: `RUN-20260907-OPENCODE-MUSE13-MANUAL-MULTIMON-FIX-01`
- Base: `cd6dc00b3d58c6abea709687618ea3702432bc45`
- Source branch: `integration/manual-candidate-20260907`
- Branch: `fix/manual-multimon-monitor-identity-muse13`
- Task: `docs/agent-tasks/RUN-20260907-OPENCODE-MUSE13-MANUAL-MULTIMON-FIX-01.md`

Implement only the smallest monitor-identity stabilization justified by both diagnoses, plus deterministic regression coverage. Preserve first/unmanaged cursor semantics and `26b1133`. Do not broaden into A03S2/A03S3/A05, merge or promote.

After DONE/BLOCKED, fresh-fetch and STOP. There is intentionally no automatic follow-on READY task: architect must inspect Code SHA/report before assigning verification.

## Architect gate
Review Muse FIX code/report. If evidence is sufficient, publish a separate verification/review task in a NEW session (prefer non-scarce Muse fresh session if Antigravity budget remains protected), then rebuild one candidate. Stop for early user dual-monitor runtime re-test before any further refactoring or promotion.
