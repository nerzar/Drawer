# AGENT_BOARD — Drawer autonomous work queue

Blackboard между архитектором ChatGPT и coding agents.

**Владелец файла:** архитектор ChatGPT. Coding agents этот файл не редактируют и приоритеты сами не меняют.

## AUTONOMOUS WORKER PROTOCOL
A task is autonomous-ready only with `Status: READY`, eligible agent, Run ID, exact base/source, branch and task file. Fresh-fetch before every task. Claim through `docs/agent-claims/<RUN-ID>.md`; one Run ID = one branch; completed/claimed tasks are skipped.

### Critical Git ref hygiene
Read shared state from `refs/remotes/dev/wip/slots-parity`; shared docs push only to `HEAD:refs/heads/wip/slots-parity`. Never create local `dev/...` refs or use ambiguous `dev/wip/slots-parity`. Inspect worktrees/exact refs/unique commits before cleanup. Public `origin` is untouched.

### Publish-before-DONE invariant
Agent work is not durable/completed until claim, remote branch, report tip and exact Code SHA (when code/test changes exist) are re-fetched from private `dev`.

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

## User directive — stop agent churn; Gemini owns recovery
The user explicitly disabled Muse/OpenCode for now and requested clear Gemini/Antigravity tasks to eliminate the broken night-wave state. No parallel Muse analysis/review/recovery work is authorized until the user explicitly re-enables it.

Prior Muse READY/recovery/trace tasks are superseded and MUST NOT be picked.

## AUTONOMOUS QUEUE — OPENCODE / MUSE 1.3 FREE
No READY tasks. STOP after fresh fetch. Do not recover, analyze, review, test, or implement anything until user/architect explicitly re-enables Muse.

## AUTONOMOUS QUEUE — ANTIGRAVITY
### 1. Restore known-good monitor behavior and build manual-test candidate
- Status: `READY`
- Eligible: `ANTIGRAVITY`
- Preferred model: `Gemini 3.8 Flash (Medium)`
- Session: `NEW`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-MULTIMON-RECOVERY-CANDIDATE-06`
- Base: `cd6dc00b3d58c6abea709687618ea3702432bc45`
- Accepted behavior reference: `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`
- Branch: `fix/manual-recovery-revert-geometry-handles-antigravity`
- Task: `docs/agent-tasks/RUN-20260907-AUTO-ANTIGRAVITY-MULTIMON-RECOVERY-CANDIDATE-06.md`

This is the only current READY task. Goal: remove the unaccepted geometry + handles night refactor line from the failed candidate, preserve unrelated focus/settings-test work, restore monitor/handle behavior to accepted production on those paths, and output one Code SHA for immediate user manual test. No redesign. No monitor pinning. No broad behavioral test marathon. Required checks only: x64/x86 `/Validate`, `git diff --check`, config untouched, exact lineage/scope audit.

If revert conflicts make semantics ambiguous, STOP `BLOCKED` rather than invent behavior.

## WAITING AFTER USER RETEST
### 2. Consolidate the safe subset after explicit user PASS
- Status: `WAITING_USER_PASS`
- Eligible: `ANTIGRAVITY`
- Session: `NEW`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-POST-RETEST-CONSOLIDATE-07`
- Dependency: explicit user dual-monitor PASS on task 06 candidate.
- Task: `docs/agent-tasks/RUN-20260907-AUTO-ANTIGRAVITY-POST-RETEST-CONSOLIDATE-07.md`

Do not start until architect pins the passed recovery SHA and changes status to READY. This task keeps only the safe subset already present in the passed candidate and records abandoned/superseded night refs. It does not resurrect geometry/handles refactors.

### 3. Branch/worktree cleanup
- Status: `WAITING_DEPENDENCY`
- Eligible: `ANTIGRAVITY`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-POST-WAVE-REF-CLEANUP-02`
- Dependency: task 07 DONE with `READY_FOR_BRANCH_CLEANUP`.
- Task: `docs/agent-tasks/RUN-20260907-AUTO-ANTIGRAVITY-POST-WAVE-REF-CLEANUP-02.md`

Cleanup must preserve unique commits and report before/after ref counts. No mass deletion by pattern.

## Acceptance debt / abandoned night wave
The unpromoted focus/focus-history/geometry/handles lines are not automatically accepted just because code exists. Geometry/handles are being explicitly rolled back from the manual recovery candidate. Focus/focus-history may survive only if the user-tested recovery candidate proves stable. No new A03S2/A03S3/A05 refactor wave until recovery PASS, consolidation and ref cleanup complete.

## Architect gate
Wait for Gemini task 06 Code SHA. Expose that exact candidate to the user immediately for manual two-monitor testing. Do not insert another agent review/testing cycle before the user test. On PASS, activate task 07; on FAIL, give Gemini one narrow corrective task based on the user's concrete symptom. Muse stays disabled.