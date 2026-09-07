# AGENT_BOARD — Drawer autonomous work queue

Blackboard между архитектором ChatGPT и coding agents.

**Владелец файла:** архитектор ChatGPT. Coding agents этот файл не редактируют и приоритеты сами не меняют.

## AUTONOMOUS WORKER PROTOCOL

Coding agents may self-pick work only when a task explicitly contains all of:
- `Status: READY`
- `Eligible: <agent types>`
- `Run ID`
- exact `Base` / source rule
- output `Branch`
- task file path

If any field is missing, the task is NOT autonomous-ready.

### Critical Git ref hygiene

`dev` is the private remote name, not a local branch namespace.

- Shared remote branch for reads: `refs/remotes/dev/wip/slots-parity`; remote push destination: `refs/heads/wip/slots-parity`.
- Never create a local branch beginning with a remote-name prefix such as `dev/...`.
- If local `refs/heads/dev/wip/slots-parity` exists, inspect `git worktree list --porcelain` and unique commits. Delete only when unreferenced by worktrees and containing no unique commits; otherwise report `BLOCKED` with exact holding worktree path/ref/unique-commit status.
- Never use ambiguous `dev/wip/slots-parity` revision shorthand and never run `git push dev dev/wip/slots-parity`.
- Before destructive branch/worktree cleanup inspect `git worktree list --porcelain` first, then fully-qualified refs. Stale registrations are cleanup debt, not proof a branch exists.

Before starting an autonomous task, claim it via `docs/agent-claims/<RUN-ID>.md` on the shared branch after fresh fetch. Existing claim by another agent means skip it. One Run ID = one working branch; no extra analysis/review/verify/tmp branches unless the task requires them.

Claim must record Run ID, agent/client, actual model, timestamp, observed shared SHA, branch and `CLAIMED`; completion updates it to `DONE` with Code SHA/report tip/checks. `BLOCKED` stops autonomous pickup until architect action.

Claim/docs shared pushes must base from `refs/remotes/dev/wip/slots-parity`, use non-ambiguous local names, and push explicitly to `HEAD:refs/heads/wip/slots-parity`. On non-fast-forward fetch/recreate or rebase safely and re-check claims.

Autonomous workers never self-accept arbitrary feature code, change architecture/priority, or delete other agents' branches unless a task explicitly delegates promotion/cleanup.

## Общий протокол

1. `git fetch dev`.
2. Read current `AGENT_BOARD.md` from `refs/remotes/dev/wip/slots-parity` or exact SHA.
3. Read `docs/agent-reports/REPORT_FORMAT.md`.
4. Pick only a `READY` task explicitly eligible for your agent type.
5. Verify worktree/branch/base/status and ref hygiene.
6. Coding tasks use sibling worktrees under `C:\Users\nerza\Projects\drawer-agent-worktrees\<task-id>`.
7. Do not reset/clean/discard foreign work; public `origin` stays untouched.
8. Stay inside scope and run targeted gates.
9. Report, commit, explicit push to private `dev`, verify remote, clean tree.
10. `docs/ARCHITECT_STATE.md` is architect-owned.
11. Architectural identity = `Code SHA`; report-tip SHA is metadata only.

On blocker/conflict/product ambiguity/data-loss risk: preserve safe state, push factual `BLOCKED`, stop.

## Текущий статус

- Shared accepted production identity remains `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`; higher shared commits are docs/tasks/claims/reports only unless explicitly promoted.
- G03, G05/G05FIX, G06 accepted + runtime verified + promoted. A02S1 accepted, runtime verified and promoted by P08.
- A02S2 FIX DONE at `313b3af8b6377b2b66e07256f985b1663c5630ee`; acceptance/promotion pending.
- A03S1 DONE at `700f033cc2700dcdbb6c9fbd387e2e44b8510ef8`; independent pre-promotion review is the active Muse gate.
- A04S1/S2/S3 DONE in exact linear lineage through `4d1a3106c3e3f64f8caa5b26bceacf9fafdf5873`; independent S1/S2/S3 reviews remain mandatory before acceptance/promotion.
- T01 settings-seam determinism DONE at `34efdb62d8fb1dcaa55119f47794c3b269772e9c`; promotion pending.
- T02A Muse audit DONE, verdict `NEEDS_PREREQUISITE`: accepted settings-seam is largely copied/static coverage and hangs at accepted production; T01 plus mandatory `/Validate` extraction gate are prerequisites for trustworthy settings refactors.
- A05A analysis DONE, report tip `2aa6eab70a209495ceecef47cac4a8829f3f3250`, verdict `READY_TO_IMPLEMENT`. Proposed A05S1 is a large SettingsService extraction; do not start it yet because T01/settings-seam prerequisite is unresolved and the A02S2 duplicate-declaration failure class requires the new independent pre-promotion gate.
- CODEX quota exhausted. DeepSeek and Claude limited OpenCode runs stopped. Muse Spark 1.3 Contributor Free is approved for analysis/review only, not implementation/promotion authority yet.
- Branch/worktree clutter is active maintenance debt; cleanup is now the Antigravity task.

## AUTONOMOUS QUEUE — ANTIGRAVITY

### Ref/worktree cleanup
- Status: `READY`
- Eligible: `ANTIGRAVITY`
- Preferred model: `Gemini 3.8 Flash (Medium)`
- Session: `NEW`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-REF-CLEANUP-01`
- Base/source rule: fresh current `refs/remotes/dev/wip/slots-parity`; repository-hygiene only
- Branch: `maintenance/ref-cleanup-20260907`
- Task file: `docs/agent-tasks/RUN-20260907-AUTO-ANTIGRAVITY-REF-CLEANUP-01.md`

After cleanup DONE/BLOCKED, fresh-fetch and stop unless architect has published another Antigravity READY task. Preserve all refs needed by pending A02/A03/A04/T01 acceptance/review and active Muse review work.

### A05A — Settings service / tray seam analysis
- Status: `DONE`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-A05-ANALYSIS-01`
- Report tip: `2aa6eab70a209495ceecef47cac4a8829f3f3250`
- Verdict: `READY_TO_IMPLEMENT`
- Branch: `analysis/a05-settings-tray-seam-antigravity`
- A05 implementation remains architect-gated pending T01/settings verification strategy.

## AUTONOMOUS QUEUE — OPENCODE / MUSE 1.3 FREE

### T02A — narrow test debt audit
- Status: `DONE`
- Run ID: `RUN-20260907-OPENCODE-MUSE13-T02-TEST-DEBT-ANALYSIS-01`
- Verdict: `NEEDS_PREREQUISITE`
- Report branch: `analysis/test-debt-production-seams-muse13`
- Report: `docs/agent-reports/2026-09-07-opencode-muse13-t02-test-debt-analysis.md`

### A03S1 independent review
- Status: `READY`
- Eligible: `OPENCODE-MUSE13`
- Required model: `Muse Spark 1.3 Contributor Free`
- Session: `NEW`
- Run ID: `RUN-20260907-OPENCODE-MUSE13-A03S1-REVIEW-01`
- Base: `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`
- Code SHA: `700f033cc2700dcdbb6c9fbd387e2e44b8510ef8`
- Branch: `review/a03s1-muse13`
- Task file: `docs/agent-tasks/RUN-20260907-OPENCODE-MUSE13-A03S1-REVIEW-01.md`

### A04S1 independent review
- Status: `WAITING_QUEUE`
- Run ID: `RUN-20260907-OPENCODE-MUSE13-A04S1-REVIEW-01`
- Base: `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`
- Code SHA: `851f47566dd074538f412b9d258193dbde65195b`
- Branch: `review/a04s1-muse13`
- Task file: `docs/agent-tasks/RUN-20260907-OPENCODE-MUSE13-A04S1-REVIEW-01.md`

### A04S2 independent review
- Status: `WAITING_QUEUE`
- Run ID: `RUN-20260907-OPENCODE-MUSE13-A04S2-REVIEW-01`
- Base: `851f47566dd074538f412b9d258193dbde65195b`
- Code SHA: `e862c4f7b71f0aced86dc2b19843b47b4b23a0f2`
- Branch: `review/a04s2-muse13`
- Task file: `docs/agent-tasks/RUN-20260907-OPENCODE-MUSE13-A04S2-REVIEW-01.md`

### A04S3 independent review
- Status: `WAITING_QUEUE`
- Run ID: `RUN-20260907-OPENCODE-MUSE13-A04S3-REVIEW-01`
- Base: `e862c4f7b71f0aced86dc2b19843b47b4b23a0f2`
- Code SHA: `4d1a3106c3e3f64f8caa5b26bceacf9fafdf5873`
- Branch: `review/a04s3-muse13`
- Task file: `docs/agent-tasks/RUN-20260907-OPENCODE-MUSE13-A04S3-REVIEW-01.md`

Muse authority remains review/analysis only. Advance one review to READY at a time. Do not implement fixes, accept/promote/merge, or clean refs.

## WAITING / ARCHITECT GATES

- A03S2 waits for A03S1 independent review and architect acceptance strategy.
- A03S3 waits for accepted A02S2 FIX lineage.
- A04 cannot be accepted/promoted until S1/S2/S3 independent review gates are complete.
- T01 promotion pending; T02 identifies it as prerequisite for trustworthy settings-seam execution.
- A05S1 implementation waits for T01/settings-seam prerequisite resolution and a new architect implementation task.
