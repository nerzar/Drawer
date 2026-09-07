# AGENT_BOARD — Drawer autonomous work queue

Blackboard между архитектором ChatGPT и coding agents.

**Владелец файла:** архитектор ChatGPT. Coding agents этот файл не редактируют и приоритеты сами не меняют.

## AUTONOMOUS WORKER PROTOCOL
A task is autonomous-ready only with `Status: READY`, eligible agent, Run ID, exact base/source, branch and task file. Fresh-fetch before every task. Claim through `docs/agent-claims/<RUN-ID>.md`; one Run ID = one branch; completed/claimed tasks are skipped.

### Critical Git ref hygiene
Read shared state from `refs/remotes/dev/wip/slots-parity`; shared docs push only to `HEAD:refs/heads/wip/slots-parity`. Never create local `dev/...` refs or use ambiguous `dev/wip/slots-parity`. Inspect worktrees/exact refs/unique commits before cleanup. Public `origin` is untouched.

### Publish-before-DONE invariant
Agent work is not considered durable/completed until claim, remote branch, report tip and exact Code SHA (when code changes exist) are re-fetched from private `dev`. Recover unpublished local work before starting another run.

## Protocol
1. `git fetch dev`; read current board, exact task and `REPORT_FORMAT.md`.
2. Claim; obey exact Base/Code SHA, scope, branch/worktree/session.
3. Preserve accepted user behavior unless user explicitly changes it.
4. Do not spend cycles on broad behavioral self-tests when the task says user manual acceptance is the gate.
5. Report/commit/push; verify remote + clean tree. Never self-promote.

## Repo tooling
RepoWise may be used only as supplementary navigation/indexing aid. Git refs/SHAs/files remain authoritative. Hindsight is optional and must not block work.

## Product contract — LOCKED
- Accepted production: `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`.
- Failed integrated candidate: `cd6dc00b3d58c6abea709687618ea3702432bc45` — **DO NOT PROMOTE**.
- Rejected monitor-pinning fix: `073a9e649bb85b4766acec33e49f975d5444a140` — **DO NOT USE**.
- `monitor: cursor` stays dynamic exactly as accepted production: managed window + active edge handle follow the live cursor monitor and Show/deploy resolves the current cursor monitor. No sticky/pinned bind-monitor behavior.

## User directive — stop test churn, restore behavior, user will verify
The user explicitly requested that agents stop spending time trying to prove the bug via self-tests and instead produce a behavior-preserving recovery candidate for manual testing on the real dual-monitor setup.

Accordingly, prior diagnostic-only READY tasks are superseded and must NOT be picked:
- `RUN-20260907-OPENCODE-MUSE13-MULTIMON-TRACE-PUBLISH-RECOVERY-05` — superseded;
- `RUN-20260907-AUTO-ANTIGRAVITY-MULTIMON-VM-CAPTURE-PREP-04` — superseded.

No new runtime-harness work is needed before the next user test.

## AUTONOMOUS QUEUE — ANTIGRAVITY
### Build conservative recovery candidate
- Status: `READY`
- Eligible: `ANTIGRAVITY`
- Preferred model: `Gemini 3.8 Flash (Medium)`
- Session: `NEW`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-MULTIMON-RECOVERY-CANDIDATE-06`
- Base: `cd6dc00b3d58c6abea709687618ea3702432bc45`
- Accepted behavior reference: `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`
- Branch: `fix/manual-recovery-revert-geometry-handles-antigravity`
- Task: `docs/agent-tasks/RUN-20260907-AUTO-ANTIGRAVITY-MULTIMON-RECOVERY-CANDIDATE-06.md`

Build a conservative manual-test candidate by removing the unaccepted geometry + handles refactor line from the failed candidate while retaining unrelated focus/settings-test work. No redesign. Required machine checks are only syntax validate x64/x86, diff-check, config untouched and lineage/scope audit. User manual test is the behavioral gate.

## AUTONOMOUS QUEUE — OPENCODE / MUSE 1.3 FREE
### Recovery rollback boundary map
- Status: `READY`
- Eligible: `OPENCODE-MUSE13`
- Required model: `Muse Spark 1.3 Contributor Free`
- Session: `NEW`
- Run ID: `RUN-20260907-OPENCODE-MUSE13-MULTIMON-RECOVERY-BOUNDARY-06`
- Failed candidate: `cd6dc00b3d58c6abea709687618ea3702432bc45`
- Accepted behavior reference: `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`
- Branch: `analysis/multimon-recovery-boundary-muse13`
- Task: `docs/agent-tasks/RUN-20260907-OPENCODE-MUSE13-MULTIMON-RECOVERY-BOUNDARY-06.md`

Map the exact geometry/handles rollback boundary and dependencies. Analysis only, no src/test edits, no broad tests. Flag only concrete conflicts that could remove unrelated focus/settings work.

## Acceptance debt — after user PASS
Unpromoted focus/focus-history/geometry/handles refactors remain acceptance debt. If the conservative recovery candidate passes the user's dual-monitor test, immediately consolidate/accept the safe subset, then run post-wave ref cleanup before any new A03S2/A03S3/A05 work.

## Branch/worktree debt
Post-wave cleanup task remains `WAITING_DEPENDENCY`: `RUN-20260907-AUTO-ANTIGRAVITY-POST-WAVE-REF-CLEANUP-02`.

## Architect gate
Wait for Antigravity recovery Code SHA and Muse rollback-boundary report. If Antigravity produces `READY_FOR_USER_RETEST` and Muse finds no rollback-boundary blocker, expose that exact Code SHA to the user immediately. No additional behavioral test/review cycle before the user's manual dual-monitor test.