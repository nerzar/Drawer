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
- Before destructive branch/worktree cleanup inspect `git worktree list --porcelain`, exact refs and unique commits.
- Never use ambiguous `dev/wip/slots-parity` revision shorthand and never run `git push dev dev/wip/slots-parity`.

Before starting an autonomous task, claim it via `docs/agent-claims/<RUN-ID>.md` on the shared branch after fresh fetch. Existing claim by another agent means skip it. One Run ID = one working branch.

Claim must record Run ID, agent/client, actual model, timestamp, observed shared SHA, branch and `CLAIMED`; completion updates it to `DONE` with Code SHA/report tip/checks. `BLOCKED` stops autonomous pickup until architect action.

Claim/docs shared pushes must base from `refs/remotes/dev/wip/slots-parity` and push explicitly to `HEAD:refs/heads/wip/slots-parity`. On non-fast-forward fetch/rebase safely and re-check claims.

Autonomous workers never self-accept arbitrary feature code, change architecture/priority, or delete other agents' branches unless a task explicitly delegates it.

## Общий протокол

1. `git fetch dev`.
2. Read current `AGENT_BOARD.md` from `refs/remotes/dev/wip/slots-parity`.
3. Read `docs/agent-reports/REPORT_FORMAT.md`.
4. Pick only a `READY` task explicitly eligible for your agent type.
5. Verify worktree/branch/base/status and ref hygiene.
6. Coding tasks use sibling worktrees under `C:\Users\nerza\Projects\drawer-agent-worktrees\<task-id>`.
7. Do not reset/clean/discard foreign work; public `origin` stays untouched.
8. Stay inside scope and run targeted gates.
9. Report, commit, explicit push to private `dev`, verify remote, clean tree.
10. Architectural identity = `Code SHA`; report-tip SHA is metadata only.

On blocker/conflict/product ambiguity/data-loss risk: preserve safe state, push factual `BLOCKED`, stop.

## Текущий статус

- Shared accepted production identity remains `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`; nothing below is promoted yet.
- T01 settings-seam determinism `34efdb62d8fb1dcaa55119f47794c3b269772e9c`: independent Antigravity verification DONE, verdict `ACCEPT_CANDIDATE`.
- A02S2 focus-history line: broken implementation `c482ad3ae9c499ea32eb3c0cdd590e495a919e30` + FIX `313b3af8b6377b2b66e07256f985b1663c5630ee`; independent Antigravity verification DONE, verdict `ACCEPT_CANDIDATE`.
- A03S1 geometry line: implementation `700f033cc2700dcdbb6c9fbd387e2e44b8510ef8` had a multi-monitor blocker; Muse FIX `90718c99de1609b40a7b7a8dbe314fbcb2d857dd`; independent Antigravity verification DONE, verdict `ACCEPT_CANDIDATE`.
- A04 handles line: S1 `851f47566dd074538f412b9d258193dbde65195b`, S2 `e862c4f7b71f0aced86dc2b19843b47b4b23a0f2`, S3 `4d1a3106c3e3f64f8caa5b26bceacf9fafdf5873`; Muse independent reviews for S1/S2/S3 all DONE with verdict `ACCEPT_CANDIDATE`.
- T02A test-debt audit DONE, verdict `NEEDS_PREREQUISITE`; its prerequisite T01 is now an acceptance candidate.
- A05A Settings analysis DONE, verdict `READY_TO_IMPLEMENT`, but implementation remains intentionally gated until manual acceptance of the current refactor wave.
- Ref/worktree cleanup DONE.
- CODEX quota exhausted. DeepSeek/Claude limited OpenCode runs stopped. Muse completed its current review chain.

## AUTONOMOUS QUEUE — ANTIGRAVITY

### Manual acceptance candidate assembly
- Status: `READY`
- Eligible: `ANTIGRAVITY`
- Preferred model: `Gemini 3.8 Flash (Medium)`
- Session: `NEW`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-MANUAL-CANDIDATE-ASSEMBLE-01`
- Base: `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`
- Branch: `integration/manual-candidate-20260907`
- Task file: `docs/agent-tasks/RUN-20260907-AUTO-ANTIGRAVITY-MANUAL-CANDIDATE-ASSEMBLE-01.md`

Assemble T01 + corrected A02S2 + corrected A03S1 + reviewed A04 line into ONE integration branch for user manual testing. This is not acceptance/promotion. Stop on semantic conflict; mechanical conflict resolutions must be documented. After publishing candidate/report/claim, STOP.

## AUTONOMOUS QUEUE — OPENCODE / MUSE 1.3 FREE

No current READY tasks. Current wave complete.

Completed this wave:
- T02A audit — DONE (`NEEDS_PREREQUISITE`).
- A03S1 independent review — DONE (`NEEDS_FIX`).
- A03S1 blocker FIX — DONE, Code SHA `90718c99de1609b40a7b7a8dbe314fbcb2d857dd`.
- A04S1 review — DONE (`ACCEPT_CANDIDATE`).
- A04S2 review — DONE (`ACCEPT_CANDIDATE`).
- A04S3 review — DONE (`ACCEPT_CANDIDATE`).

Muse has no implementation/promotion authority beyond completed explicit tasks. Stop until architect publishes another READY task.

## MANUAL CHECKPOINT / NEXT WAVE GATES

- Current priority is a user-testable integration candidate, not more refactoring.
- Do not start A03S2, A03S3 or A05 implementation before manual checkpoint unless architect explicitly changes this gate.
- If manual candidate is `READY_FOR_MANUAL_ACCEPTANCE`, architect/user performs visible runtime acceptance: focus return, two-monitor/internal-edge geometry and parking, handle hover/click/sync, Settings open/save/reload.
- Any material manual failure blocks promotion and starts a targeted fix cycle.
- If manual acceptance passes, architect may promote the accepted wave and then publish the next implementation queue.
