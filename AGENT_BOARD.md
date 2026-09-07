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
- Antigravity diagnosis DONE, verdict `READY_FOR_FIX`; Muse independent diagnosis DONE, verdict `READY_FOR_FIX`.
- Both analyses agree the old `5ed8b9a` missing-braces monitor collection bug is already fixed by `26b1133`; remaining likely defect is unstable `monitor: cursor` identity between `HandlesSync` and `Show`.
- Antigravity budget has reset and is available again, but implementation and verification remain separated.

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

Implement only the smallest monitor-identity stabilization justified by both diagnoses, plus deterministic regression coverage. Preserve first/unmanaged cursor semantics and `26b1133`. Do not broaden into A03S2/A03S3/A05, merge or promote. After DONE/BLOCKED, fresh-fetch and STOP.

## AUTONOMOUS QUEUE — ANTIGRAVITY
### Reserved independent verification of Muse FIX
- Status: `WAITING_DEPENDENCY`
- Eligible: `ANTIGRAVITY`
- Preferred model: `Gemini 3.8 Flash (Medium)`
- Session: `NEW`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-MULTIMON-FIX-VERIFY-01`
- Dependency: Muse FIX above must be DONE with `READY_FOR_INDEPENDENT_VERIFY`; architect must pin exact FIX Code SHA and switch this task to READY.
- Branch: `review/manual-multimon-fix-antigravity`
- Task: `docs/agent-tasks/RUN-20260907-AUTO-ANTIGRAVITY-MULTIMON-FIX-VERIFY-01.md`

Anti must not start this while dependency is pending. Once activated, review/verification only: no self-fix, promotion or candidate assembly.

## Next gate
Architect inspects Muse Code SHA/report, activates Antigravity verification against that exact SHA, then—only on `ACCEPT_FOR_MANUAL_RETEST`—builds one candidate and stops for immediate user dual-monitor runtime retest. No A03S2/A03S3/A05 before that manual PASS.
