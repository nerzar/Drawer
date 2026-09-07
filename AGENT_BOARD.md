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
- A02S2 broken implementation `c482ad3ae9c499ea32eb3c0cdd590e495a919e30` remains non-promotable. FIX is DONE at Code SHA `313b3af8b6377b2b66e07256f985b1663c5630ee`; acceptance/promotion pending.
- A03S1 DONE at Code SHA `700f033cc2700dcdbb6c9fbd387e2e44b8510ef8`; repo-only scope review clean; not accepted/promoted.
- A04S1/S2/S3 DONE in exact linear lineage through `4d1a3106c3e3f64f8caa5b26bceacf9fafdf5873`; repo-only scope review clean; line remains unaccepted/unpromoted pending stronger verification/review.
- T01 settings-seam determinism DONE at `34efdb62d8fb1dcaa55119f47794c3b269772e9c`; promotion pending.
- CODEX quota exhausted. DeepSeek and Claude OpenCode paid/limited runs are stopped after completed work.
- Muse Spark 1.3 Contributor Free passed architect read-only repo/Git/reasoning diagnostic and is approved for low-risk analysis/review work. Do not give it implementation/promotion authority yet.
- Branch/ref hygiene debt: remote `tmp/never` still exists; do not use as base and do not delete without local ref/worktree inspection.

## AUTONOMOUS QUEUE — ANTIGRAVITY

### A05A — Settings service / tray seam analysis
- Status: `READY`
- Eligible: `ANTIGRAVITY`
- Preferred model: `Gemini 3.8 Flash (Medium)`
- Session: `NEW`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-A05-ANALYSIS-01`
- Base/source rule: accepted shared production `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`; unaccepted A02/A03/A04 branches are context only, not production identity
- Branch: `analysis/a05-settings-tray-seam-antigravity`
- Task file: `docs/agent-tasks/RUN-20260907-AUTO-ANTIGRAVITY-A05-ANALYSIS-01.md`

After A05A DONE/BLOCKED, fresh-fetch and stop unless architect has published another Antigravity READY task. Do not implement A05 slices without a new architect task.

## AUTONOMOUS QUEUE — OPENCODE / MUSE 1.3 FREE

### T02A — narrow test debt / production-seam coverage audit
- Status: `READY`
- Eligible: `OPENCODE-MUSE13`
- Required model: `Muse Spark 1.3 Contributor Free`
- Session: `NEW`
- Run ID: `RUN-20260907-OPENCODE-MUSE13-T02-TEST-DEBT-ANALYSIS-01`
- Base/source rule: accepted shared production `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`; unaccepted feature lines are noncanonical context only
- Branch: `analysis/test-debt-production-seams-muse13`
- Task file: `docs/agent-tasks/RUN-20260907-OPENCODE-MUSE13-T02-TEST-DEBT-ANALYSIS-01.md`

Muse authority for this wave is analysis/report only. After T02A DONE/BLOCKED, fresh-fetch and STOP unless architect explicitly publishes another Muse READY task. Do not implement recommendations, accept, promote, merge, or clean refs.

## COMPLETED / STOPPED OPENCODE RUNS

- A03S1 — DONE, Code SHA `700f033cc2700dcdbb6c9fbd387e2e44b8510ef8`; DeepSeek stopped after completion.
- A02S2 FIX — DONE, Code SHA `313b3af8b6377b2b66e07256f985b1663c5630ee`; Claude 4.8 stopped after completion.

## WAITING / ARCHITECT GATES

- A03S2 waits for architect review/acceptance strategy and suitable implementation model budget.
- A03S3 waits for accepted A02S2 FIX lineage.
- A04 line waits for sufficient review/verification before acceptance/promotion.
- T01 promotion pending.
- A05 implementation waits for A05A analysis verdict and a new architect task.
- Muse implementation authority remains gated until its real T02 analysis output is reviewed.

## COMPLETED AUTONOMOUS RUNS — recent

- `RUN-20260907-OPENCODE-CLAUDE48-A02S2-FIX-01` — DONE, Code SHA `313b3af8b6377b2b66e07256f985b1663c5630ee`; acceptance pending.
- `RUN-20260906-AUTO-ANTIGRAVITY-A03S1-IMPLEMENT-01` — DONE by OpenCode DeepSeek, Code SHA `700f033cc2700dcdbb6c9fbd387e2e44b8510ef8`; acceptance pending.
- `RUN-20260907-AUTO-ANTIGRAVITY-A04S3-IMPLEMENT-01` — DONE, Code SHA `4d1a3106c3e3f64f8caa5b26bceacf9fafdf5873`; acceptance pending.
- `RUN-20260907-OPENCODE-DEEPSEEK-T01-SETTINGS-SEAM-01` — DONE, Code SHA `34efdb62d8fb1dcaa55119f47794c3b269772e9c`; promotion pending.
