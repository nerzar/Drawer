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
- A02S1 accepted, runtime verified and promoted by P08.
- A02S2 is DONE by Antigravity at Code SHA `c482ad3ae9c499ea32eb3c0cdd590e495a919e30`; agent reports AHK validate pass, targeted narrow suites pass, `src/config.ini` untouched, remote branch verified. Architect acceptance/promotion is still pending.
- A03 analysis verdict `READY_TO_IMPLEMENT`; A03S1 remains reserved for OPENCODE-DEEPSEEK and must not depend on unaccepted A02S2.
- T01 DeepSeek settings-seam determinism is DONE at Code SHA `34efdb62d8fb1dcaa55119f47794c3b269772e9c`; architect repo-only diff review found no scope issue. Agent verification: settings seam 5 consecutive direct exits, 256/256 pass; focus seam 3 direct exits, 9/9 pass; drawer validate pass; config.ini untouched. Not promoted yet.
- DeepSeek A03S2 remains dependency-gated on A03S1 and must not be claimed early.
- CODEX quota exhausted.
- One READY task per scarce agent: Antigravity has A04A; DeepSeek has A03S1. Lower-priority work stays queued but not READY until architect advances it.

## AUTONOMOUS QUEUE — ANTIGRAVITY

### A02S2 — focus history + foreground state extraction
- Status: `DONE`
- Eligible: `ANTIGRAVITY`
- Run ID: `RUN-20260906-AUTO-ANTIGRAVITY-A02S2-IMPLEMENT-01`
- Base: `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`
- Branch: `refactor/window-focus-history-foreground`
- Code SHA: `c482ad3ae9c499ea32eb3c0cdd590e495a919e30`
- Task file: `docs/agent-tasks/RUN-20260906-AUTO-ANTIGRAVITY-A02S2-IMPLEMENT-01.md`
- Do not self-promote; architect review/acceptance remains pending.

### A04A — handles seam analysis
- Status: `READY`
- Eligible: `ANTIGRAVITY`
- Preferred model: `Gemini 3.8 Flash (Medium)`
- Session: `NEW`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-A04-ANALYSIS-01`
- Base/source rule: analyze accepted shared production `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`; docs-only higher shared commits do not change analyzed code
- Branch: `tmp/never`
- Task file: `docs/agent-tasks/RUN-20260907-AUTO-ANTIGRAVITY-A04-ANALYSIS-01.md`
- Analysis only. Do not implement A04 until architect publishes an implementation task.

After A04A DONE/BLOCKED, fresh-fetch and stop unless architect has published the next Antigravity READY task.

## AUTONOMOUS QUEUE — OPENCODE / DEEPSEEK

### 1. T01 — settings-seam determinism / timeout
- Status: `DONE`
- Eligible: `OPENCODE-DEEPSEEK`
- Run ID: `RUN-20260907-OPENCODE-DEEPSEEK-T01-SETTINGS-SEAM-01`
- Code SHA: `34efdb62d8fb1dcaa55119f47794c3b269772e9c`
- Report tip SHA: `0c184d0d10a6e1e75d6e4b6e5a56e712ed162412`
- Branch: `test/settings-seam-determinism`
- Architect repo-only review: no issue found; promotion still pending.

### 2. A03S1 — pure geometry plan seam
- Status: `READY`
- Eligible: `OPENCODE-DEEPSEEK`
- Required model: `deepseek-v4-flash`
- Session: `NEW`
- Run ID: `RUN-20260906-AUTO-ANTIGRAVITY-A03S1-IMPLEMENT-01`
- Base/source rule: accepted shared lineage at or above P08; must not depend on unaccepted A02S2
- Branch: `refactor/window-geometry-plan-seam`
- Task file: `docs/agent-tasks/RUN-20260906-AUTO-ANTIGRAVITY-A03S1-IMPLEMENT-01.md`
- Reserved for DeepSeek.

### 3. A05A — Settings service / tray seam analysis
- Status: `WAITING_QUEUE`
- Eligible: `OPENCODE-DEEPSEEK`
- Required model: `deepseek-v4-flash`
- Session: `NEW`
- Run ID: `RUN-20260907-OPENCODE-DEEPSEEK-A05-ANALYSIS-01`
- Base/source rule: accepted shared production `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`
- Branch: `analysis/a05-settings-tray-seam-deepseek`
- Task file: `docs/agent-tasks/RUN-20260907-OPENCODE-DEEPSEEK-A05-ANALYSIS-01.md`

### 4. T02A — narrow test debt / production-seam coverage audit
- Status: `WAITING_QUEUE`
- Eligible: `OPENCODE-DEEPSEEK`
- Required model: `deepseek-v4-flash`
- Session: `NEW`
- Run ID: `RUN-20260907-OPENCODE-DEEPSEEK-T02-TEST-DEBT-ANALYSIS-01`
- Base/source rule: latest accepted shared production identity when claimed; docs-only higher tip allowed
- Branch: `analysis/test-debt-production-seams-deepseek`
- Task file: `docs/agent-tasks/RUN-20260907-OPENCODE-DEEPSEEK-T02-TEST-DEBT-ANALYSIS-01.md`

### 5. A03S2 — monitor / origin selection seam
- Status: `WAITING_DEPENDENCY`
- Eligible: `OPENCODE-DEEPSEEK`
- Required model: `deepseek-v4-flash`
- Session: `NEW`
- Run ID: `RUN-20260907-OPENCODE-DEEPSEEK-A03S2-IMPLEMENT-01`
- Dependency: A03S1 DONE with pushed Code SHA
- Branch: `refactor/window-geometry-monitor-origin-seam`
- Task file: `docs/agent-tasks/RUN-20260907-OPENCODE-DEEPSEEK-A03S2-IMPLEMENT-01.md`

DeepSeek must fresh-fetch after A03S1 DONE/BLOCKED and stop unless architect has advanced another task to READY.

## COMPLETED AUTONOMOUS RUNS — recent

- `RUN-20260906-AUTO-ANTIGRAVITY-A02S2-IMPLEMENT-01` — DONE, Code SHA `c482ad3ae9c499ea32eb3c0cdd590e495a919e30`; acceptance pending.
- `RUN-20260907-OPENCODE-DEEPSEEK-T01-SETTINGS-SEAM-01` — DONE, Code SHA `34efdb62d8fb1dcaa55119f47794c3b269772e9c`; repo-only architect review clean.
- `RUN-20260906-AUTO-ANTIGRAVITY-P08-A02S1-PROMOTE-01` — DONE, shared production Code SHA `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`.
- `RUN-20260906-AUTO-CODEX-P07-G06-PROMOTE-CLEANUP-01` — DONE.
- `RUN-20260906-AUTO-ANTIGRAVITY-A02S1-ACCEPT-01` — DONE, ACCEPT.
- `RUN-20260906-AUTO-DEV1-A02S1-REVIEW-01` — DONE.
- `RUN-20260906-AUTO-CODEX-A02S1-01` — DONE, Code SHA `ac71581b98a58e51128a987d20d8b5b1952c1756`.
- `RUN-20260906-AUTO-CODEX-A03-ANALYSIS-01` — DONE, READY_TO_IMPLEMENT.

## NEXT AFTER THIS WAVE

Architect reviews A02S2/A03S1/DeepSeek outputs before promotion. T01 promotion is pending. A03S3 waits for accepted A02S2. A04/A05 implementation is not autonomous until architect explicitly publishes it.
