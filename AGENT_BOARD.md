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

- Shared accepted production identity remains `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`; current wave is NOT promoted yet.
- Integration/manual candidate is assembled at Code SHA `cd6dc00b3d58c6abea709687618ea3702432bc45` on `integration/manual-candidate-20260907`; verdict `READY_FOR_MANUAL_ACCEPTANCE`.
- Candidate contains independently reviewed/verified T01 settings-test determinism, corrected focus-history extraction, corrected multi-monitor geometry extraction, and reviewed handles S1/S2/S3 extraction.
- Candidate gates at tip: drawer + WindowFocus + WindowGeometry + WindowHandles `/Validate` x64/x86 EXIT 0; focus seam 30/30; geometry seam 55/55; geometry adapter 9/9; handles seam 50/50 x3; settings seam 256/256 x3; `git diff --check` clean; `src/config.ini` untouched.
- A05A Settings analysis DONE, verdict `READY_TO_IMPLEMENT`, but implementation remains intentionally gated until this manual checkpoint passes.
- T02A audit DONE; its T01 prerequisite is included in the manual candidate.
- Ref/worktree cleanup DONE.

## AUTONOMOUS QUEUES

No current READY tasks for Antigravity or OPENCODE-MUSE13. Current refactor wave is intentionally paused for user manual acceptance.

Agents must STOP after fresh fetch until architect publishes another READY task. Do not start A03S2/A03S3/A05 or promotion autonomously.

## MANUAL ACCEPTANCE CHECKPOINT

Candidate:
- Branch: `integration/manual-candidate-20260907`
- Code SHA: `cd6dc00b3d58c6abea709687618ea3702432bc45`
- Report: `docs/agent-reports/2026-09-07-antigravity-manual-candidate-assemble.md`
- Status: `READY_FOR_MANUAL_ACCEPTANCE`

User-visible checks before promotion:
1. Handles: edge handles appear; hover expansion is smooth; click deploys/slides the correct window.
2. Focus: blur-hide returns focus to the previous foreground window; when Settings is previous, focus returns to Settings.
3. Multi-monitor: internal-edge slots park off-screen correctly and do not animate across the neighboring monitor workspace.
4. Settings: open Settings, change a visible setting such as accent/edge, Save, and confirm handles/runtime update and Settings reload remains healthy.

Any material failure blocks promotion and starts a targeted fix cycle. If manual acceptance passes, architect may promote this candidate and publish the next implementation wave.
