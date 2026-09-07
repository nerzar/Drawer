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
- Antigravity diagnosis is DONE with verdict `READY_FOR_FIX`; report: `docs/agent-reports/2026-09-07-antigravity-manual-multimon-failure-analysis.md`.
- Antigravity is now intentionally STOPPED to preserve remaining model budget. Publish no new Antigravity READY task until architect/user explicitly reopens it.

## AUTONOMOUS QUEUE — ANTIGRAVITY
No current READY tasks. STOP after fresh fetch.

## AUTONOMOUS QUEUE — OPENCODE / MUSE 1.3 FREE
### Independent diagnosis B
- Status: `READY`
- Eligible: `OPENCODE-MUSE13`
- Required model: `Muse Spark 1.3 Contributor Free`
- Session: `NEW`
- Run ID: `RUN-20260907-OPENCODE-MUSE13-MANUAL-MULTIMON-INDEPENDENT-ANALYSIS-01`
- Base/source: failed candidate `cd6dc00b3d58c6abea709687618ea3702432bc45`; compare accepted `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`
- Branch: `analysis/manual-multimon-regression-muse13`
- Task: `docs/agent-tasks/RUN-20260907-OPENCODE-MUSE13-MANUAL-MULTIMON-INDEPENDENT-ANALYSIS-01.md`

Muse must form and record its own hypothesis/evidence BEFORE reading Antigravity's failure-analysis report. After its independent evidence is fixed in the report draft, it may compare with Antigravity's report and explicitly state agreements/disagreements.

Analysis/report only. No production/test edits, no fix, no promotion, no candidate rebuild. After claim/report/push is DONE, fresh-fetch and STOP. There is intentionally no follow-on READY task tonight.

## Architect gate
Next architect turn compares both diagnoses and publishes one narrow FIX task plus separate verification. Any fix must add evidence covering the observed runtime monitor-origin/handle-loss failure, not merely preserve current pure seams. Rebuild one candidate and perform early user dual-monitor re-test before any further refactoring.
