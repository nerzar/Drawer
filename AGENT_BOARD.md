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
3. Verify repository facts independently; do not trust prior reports or indexes as proof.
4. Run bounded targeted gates; report/commit/push; verify remote + clean tree.
5. Never self-accept/promote or broaden scope. On blocker/conflict/data-loss risk: report `BLOCKED`, stop.

## Repo tooling
- RepoWise may be used only as supplementary navigation/indexing aid.
- Git refs, exact SHAs, repository files, tests and genuine runtime evidence remain authoritative.
- Hindsight is not a required dependency and must not block current work.

## Product contract — locked
- Accepted production remains `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`.
- Failed integrated candidate `cd6dc00b3d58c6abea709687618ea3702432bc45` remains **DO NOT PROMOTE**.
- Monitor-pinning fix `073a9e649bb85b4766acec33e49f975d5444a140` remains **REJECTED**.
- For `monitor: cursor`, managed windows and the active edge handle follow the live cursor monitor; Show/deploy resolves the live cursor monitor. No pinning/sticky bind monitor unless the user explicitly changes this behavior.
- Unresolved user-visible defects: wrong animation origin / cross-monitor staging and one transient disappearing edge handle.
- A03S2/A03S3/A05 and promotion remain frozen.

## Evidence status
- Reconciliation reports are complete but do not justify a behavior-preserving implementation yet.
- Architect published Muse trace-harness task `RUN-20260907-OPENCODE-MUSE13-MULTIMON-RUNTIME-TRACE-HARNESS-04`, but after fresh Git inspection there is currently **no claim, no report, and no remote `diag/multimon-runtime-trace-harness-muse13` branch** visible on `dev` for that Run ID. If the agent completed work locally, it must be recovered/published rather than silently redone or lost.
- No implementation task is authorized until accepted-vs-failed runtime evidence exists.

## AUTONOMOUS QUEUE — OPENCODE / MUSE 1.3 FREE
### Recover/publish runtime trace harness
- Status: `READY`
- Eligible: `OPENCODE-MUSE13`
- Required model: `Muse Spark 1.3 Contributor Free`
- Session: `CONTINUE_IF_LOCAL_STATE_EXISTS_ELSE_NEW`
- Run ID: `RUN-20260907-OPENCODE-MUSE13-MULTIMON-TRACE-PUBLISH-RECOVERY-05`
- Base/Code SHA: `cd6dc00b3d58c6abea709687618ea3702432bc45`
- Accepted comparison: `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`
- Branch: `diag/multimon-runtime-trace-harness-muse13`
- Task: `docs/agent-tasks/RUN-20260907-OPENCODE-MUSE13-MULTIMON-TRACE-PUBLISH-RECOVERY-05.md`

First inspect local worktrees/branches for completed task-04 work. Recover and publish it if present; otherwise execute the trace-harness task now. Test/diagnostic only, no `src/` behavior changes. After DONE/BLOCKED, fresh-fetch and stop unless a new explicit READY task exists.

## AUTONOMOUS QUEUE — ANTIGRAVITY
### Dual-monitor VM runtime capture
- Status: `READY`
- Eligible: `ANTIGRAVITY`
- Preferred model: `Gemini 3.8 Flash (Medium)`
- Session: `NEW`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-MULTIMON-VM-CAPTURE-PREP-04`
- Accepted baseline: `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`
- Failed candidate: `cd6dc00b3d58c6abea709687618ea3702432bc45`
- Branch: `diag/multimon-vm-runtime-capture-antigravity`
- Task: `docs/agent-tasks/RUN-20260907-AUTO-ANTIGRAVITY-MULTIMON-VM-CAPTURE-PREP-04.md`

Use existing `test/vm`/dual-monitor infrastructure to obtain genuine accepted-vs-failed runtime evidence if possible. If execution is impossible, leave a bounded runnable capture procedure and exact blocker. Test/diagnostic changes only; no product fix.

## Architect gate
Wait for both diagnostic outputs. Publish a narrow implementation only if runtime evidence identifies a concrete accepted-vs-failed mechanism while preserving the locked cursor-follow behavior. Then independent verify, build exactly one candidate, and stop for immediate user dual-monitor retest before any other refactor or promotion.
