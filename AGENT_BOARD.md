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
- G03, G05/G05FIX, G06 accepted + runtime verified + promoted.
- A02S1 accepted, runtime verified and promoted by P08.
- A02S2 implementation `c482ad3ae9c499ea32eb3c0cdd590e495a919e30` is `NEEDS_FIX`; OpenCode Claude 4.8 owns the fix run. Do not promote broken SHA.
- A04 analysis DONE. A04S1 `851f47566dd074538f412b9d258193dbde65195b`, A04S2 `e862c4f7b71f0aced86dc2b19843b47b4b23a0f2`, and A04S3 `4d1a3106c3e3f64f8caa5b26bceacf9fafdf5873` are DONE in exact linear lineage. A04S3 repo-only scope review: one commit, only `src/WindowHandles.ahk`, `src/drawer.ahk`, `test/narrow/window-handles-seam.ahk`; reported validate + 39/39 handle seam + settings/focus seams pass. Entire A04 line remains unaccepted/unpromoted pending stronger verification/review.
- A03S1 remains owned by OpenCode DeepSeek until its current run finishes; no new OpenCode work afterward due current model limit.
- T01 DeepSeek settings-seam determinism DONE at `34efdb62d8fb1dcaa55119f47794c3b269772e9c`; promotion pending.
- CODEX quota exhausted. Do not spend Codex.
- Current resource policy: Antigravity is the only worker eligible for new autonomous tasks. OpenCode Claude 4.8 may finish its already-claimed A02S2 FIX only; do not queue it another run. DeepSeek may finish A03S1 only; do not queue another run.

## AUTONOMOUS QUEUE — ANTIGRAVITY

### A05A — Settings service / tray seam analysis
- Status: `READY`
- Eligible: `ANTIGRAVITY`
- Preferred model: `Gemini 3.8 Flash (Medium)`
- Session: `NEW`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-A05-ANALYSIS-01`
- Base/source rule: accepted shared production `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`; unaccepted A02/A04 branches are context only, not production identity
- Branch: `analysis/a05-settings-tray-seam-antigravity`
- Task file: `docs/agent-tasks/RUN-20260907-AUTO-ANTIGRAVITY-A05-ANALYSIS-01.md`

After A05A DONE/BLOCKED, fresh-fetch and stop unless architect has published another Antigravity READY task. Do not implement A05 slices without a new architect task.

## OPENCODE — FINISH CURRENT RUNS ONLY

### A03S1 — pure geometry plan seam
- Status: `CLAIMED/RUNNING`
- Eligible: `OPENCODE-DEEPSEEK`
- Run ID: `RUN-20260906-AUTO-ANTIGRAVITY-A03S1-IMPLEMENT-01`
- Base: `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`
- Branch: `refactor/window-geometry-plan-seam`
- Claim: `docs/agent-claims/RUN-20260906-AUTO-ANTIGRAVITY-A03S1-IMPLEMENT-01.md`
- Task file: `docs/agent-tasks/RUN-20260906-AUTO-ANTIGRAVITY-A03S1-IMPLEMENT-01.md`
- After completion: STOP; model budget exhausted.

### A02S2 FIX — promotion blockers
- Status: `CLAIMED/RUNNING`
- Eligible: `OPENCODE-CLAUDE48`
- Required model: `agentrouter/claude-opus-4-8`
- Run ID: `RUN-20260907-OPENCODE-CLAUDE48-A02S2-FIX-01`
- Base: `c482ad3ae9c499ea32eb3c0cdd590e495a919e30`
- Branch: `fix/a02s2-focus-history-blockers`
- Claim: `docs/agent-claims/RUN-20260907-OPENCODE-CLAUDE48-A02S2-FIX-01.md`
- Task file: `docs/agent-tasks/RUN-20260907-OPENCODE-CLAUDE48-A02S2-FIX-01.md`
- After completion: STOP; no second Claude task.

## WAITING / ARCHITECT GATES

- A03S2 waits for architect review of A03S1 and renewed model budget.
- A03S3 waits for accepted A02S2.
- A04 line waits for sufficient review/verification before acceptance/promotion.
- T01 promotion pending.
- A05 implementation waits for A05A analysis verdict and a new architect-published task.
- T02 test-debt audit waits; no scarce worker spent while A05 architecture is higher value.

## COMPLETED AUTONOMOUS RUNS — recent

- `RUN-20260907-AUTO-ANTIGRAVITY-A04S3-IMPLEMENT-01` — DONE, Code SHA `4d1a3106c3e3f64f8caa5b26bceacf9fafdf5873`; repo-only scope review clean, acceptance pending.
- `RUN-20260907-AUTO-ANTIGRAVITY-A04S2-IMPLEMENT-01` — DONE, Code SHA `e862c4f7b71f0aced86dc2b19843b47b4b23a0f2`; acceptance pending.
- `RUN-20260907-AUTO-ANTIGRAVITY-A04S1-IMPLEMENT-01` — DONE, Code SHA `851f47566dd074538f412b9d258193dbde65195b`; acceptance pending.
- `RUN-20260907-AUTO-ANTIGRAVITY-A04-ANALYSIS-01` — DONE, `READY_TO_IMPLEMENT`.
- `RUN-20260906-AUTO-ANTIGRAVITY-A02S2-IMPLEMENT-01` — DONE, Code SHA `c482ad3ae9c499ea32eb3c0cdd590e495a919e30`; independent review `NEEDS_FIX`, no promotion.
- `RUN-20260907-OPENCODE-DEEPSEEK-T01-SETTINGS-SEAM-01` — DONE, Code SHA `34efdb62d8fb1dcaa55119f47794c3b269772e9c`; repo-only architect review clean.
- `RUN-20260906-AUTO-ANTIGRAVITY-P08-A02S1-PROMOTE-01` — DONE, shared production Code SHA `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`.
