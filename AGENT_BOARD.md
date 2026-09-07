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

## Current status — READY FOR USER DUAL-MONITOR RETEST
- Accepted production remains `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`.
- Failed candidate `cd6dc00b3d58c6abea709687618ea3702432bc45` remains **DO NOT PROMOTE**.
- Muse narrow multi-monitor FIX is `073a9e649bb85b4766acec33e49f975d5444a140`.
- Antigravity independently verified that exact FIX with verdict `ACCEPT_FOR_MANUAL_RETEST`.
- OpenCode/Muse preflight independently found no blocker and verdict `READY_FOR_MANUAL_RETEST_IF_VERIFY_PASSES`.
- Architect created `integration/manual-retest-20260907` pointing exactly at Code SHA `073a9e649bb85b4766acec33e49f975d5444a140`.
- No further refactoring is allowed before user dual-monitor retest. A03S2/A03S3/A05 remain frozen.

## AUTONOMOUS QUEUES
No current READY tasks for Antigravity or OPENCODE-MUSE13. Both workers STOP after fresh fetch until architect publishes a new task following the user's retest result.

## MANUAL RETEST CHECKPOINT
Candidate:
- Branch: `integration/manual-retest-20260907`
- Code SHA: `073a9e649bb85b4766acec33e49f975d5444a140`
- Base failed candidate: `cd6dc00b3d58c6abea709687618ea3702432bc45`

User should retest first and foremost:
1. On monitor 2, deploy the same slot/window that previously started animation from monitor 1; animation origin must now remain on monitor 2.
2. Move cursor between monitors while the window is managed/hidden; the handle must not jump/disappear solely because the cursor moved.
3. Click the handle after cursor movement; Show/deploy must use the same monitor as the managed slot/handle.
4. Recheck an internal edge between monitors: no slide across the neighboring workspace.
5. Quick smoke: basic handles + Settings lifecycle still work.

Any material failure blocks promotion and starts a targeted fix. If user PASSes this retest, architect may accept/promote this wave and publish the next implementation queue.
