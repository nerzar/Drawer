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

- Shared production identity after P08: `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`; higher shared commits may be docs/tasks/claims/reports.
- G03, G05/G05FIX, G06 accepted + runtime verified + promoted.
- A02S1 accepted, runtime verified and promoted by P08. P08 validate + window-focus seam 9/9 passed; `config.ini` untouched.
- A02S2 focus-history/foreground extraction is currently claimed by Antigravity from accepted P08 lineage.
- A03 analysis verdict `READY_TO_IMPLEMENT`; A03S1 is independent of unaccepted A02S2 and remains the single queued READY task for Antigravity.
- **CODEX quota exhausted. No new `Eligible: CODEX` work until operator reports reset.**
- Antigravity has only a small remaining model budget. Do not invent additional work beyond the deliberate final wave without architect review.

## AUTONOMOUS QUEUE — ANTIGRAVITY priority order

### 1. P08 — promote accepted A02S1
- Status: `DONE`
- Eligible: `ANTIGRAVITY`
- Model used: `Gemini 3.8 Flash`
- Run ID: `RUN-20260906-AUTO-ANTIGRAVITY-P08-A02S1-PROMOTE-01`
- Code SHA: `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`
- Verdict: `ACCEPT`
- Task file: `docs/agent-tasks/RUN-20260906-AUTO-ANTIGRAVITY-P08-A02S1-PROMOTE-01.md`

### 2. A02S2 — focus history + foreground state extraction
- Status: `CLAIMED/RUNNING`
- Eligible: `ANTIGRAVITY`
- Model: `Gemini 3.8 Flash`
- Session: `NEW`
- Run ID: `RUN-20260906-AUTO-ANTIGRAVITY-A02S2-IMPLEMENT-01`
- Base: accepted P08 Code SHA `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`
- Branch: `refactor/window-focus-history-foreground`
- Task file: `docs/agent-tasks/RUN-20260906-AUTO-ANTIGRAVITY-A02S2-IMPLEMENT-01.md`

### 3. A03S1 — pure geometry plan seam
- Status: `READY`
- Eligible: `ANTIGRAVITY`
- Preferred model: `Claude` if available; Gemini allowed
- Session: `NEW`
- Run ID: `RUN-20260906-AUTO-ANTIGRAVITY-A03S1-IMPLEMENT-01`
- Base/source rule: accepted shared lineage at or above P08 `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`; must not depend on unaccepted A02S2
- Branch: `refactor/window-geometry-plan-seam`
- Task file: `docs/agent-tasks/RUN-20260906-AUTO-ANTIGRAVITY-A03S1-IMPLEMENT-01.md`

After A03S1, Antigravity must idle unless architect publishes more work.

## COMPLETED AUTONOMOUS RUNS — recent

- `RUN-20260906-AUTO-ANTIGRAVITY-P08-A02S1-PROMOTE-01` — DONE, shared production Code SHA `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`.
- `RUN-20260906-AUTO-CODEX-P07-G06-PROMOTE-CLEANUP-01` — DONE, prior shared production Code SHA `886e68663a0f487f3ad00c248a4aed87e02861c7`.
- `RUN-20260906-AUTO-ANTIGRAVITY-A02S1-ACCEPT-01` — DONE, `ACCEPT`.
- `RUN-20260906-AUTO-DEV1-A02S1-REVIEW-01` — DONE, `ACCEPT_WITH_RUNTIME_CHECK`.
- `RUN-20260906-AUTO-ANTIGRAVITY-G06ACCEPT-01` — DONE, `ACCEPT`.
- `RUN-20260906-AUTO-CODEX-A02S1-01` — DONE, Code SHA `ac71581b98a58e51128a987d20d8b5b1952c1756`.
- `RUN-20260906-AUTO-CODEX-A03-ANALYSIS-01` — DONE, `READY_TO_IMPLEMENT`.

## NEXT AFTER THIS WAVE

- Review/accept A02S2 and A03S1 before promotion.
- A03S2 monitor/origin selection can follow A03S1; A03S3 waits until accepted A02S2 removes focus `prev` from shared geometry state.
- Then A04 handles seam, A05 Settings/tray seams, test debt and release gates.
