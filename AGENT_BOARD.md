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
- A02S2 FIX `313b3af8b6377b2b66e07256f985b1663c5630ee` independent Antigravity verification DONE with verdict `ACCEPT_CANDIDATE`.
- A03S1 broken implementation `700f033cc2700dcdbb6c9fbd387e2e44b8510ef8` review found a multi-monitor blocker. Muse FIX is DONE at `90718c99de1609b40a7b7a8dbe314fbcb2d857dd`; independent Antigravity verification is now READY.
- A04S1 and A04S2 independent Muse reviews DONE with verdict `ACCEPT_CANDIDATE`; A04S3 review remains in the Muse chain.
- T01 settings-seam determinism `34efdb62d8fb1dcaa55119f47794c3b269772e9c` independent Antigravity verification DONE with verdict `ACCEPT_CANDIDATE`.
- T02A Muse audit DONE, verdict `NEEDS_PREREQUISITE`.
- A05A analysis DONE, verdict `READY_TO_IMPLEMENT`; A05 implementation remains gated until manual checkpoint.
- Ref/worktree cleanup DONE.
- CODEX quota exhausted. DeepSeek and Claude limited OpenCode runs stopped. Muse remains active for its review chain.

## AUTONOMOUS QUEUE — ANTIGRAVITY

### A03S1 FIX independent verification
- Status: `READY`
- Eligible: `ANTIGRAVITY`
- Preferred model: `Gemini 3.8 Flash (Medium)`
- Session: `NEW`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-A03S1FIX-VERIFY-01`
- Base: `700f033cc2700dcdbb6c9fbd387e2e44b8510ef8`
- Code SHA under verification: `90718c99de1609b40a7b7a8dbe314fbcb2d857dd`
- Source branch: `fix/a03s1-monitor-enumeration-muse13`
- Branch: `verify/a03s1fix-antigravity`
- Task file: `docs/agent-tasks/RUN-20260907-AUTO-ANTIGRAVITY-A03S1FIX-VERIFY-01.md`

After this verification DONE/BLOCKED, fresh-fetch and stop unless architect has published another Antigravity READY task. Verification/report only; no self-fix, accept, promote, merge or unrelated cleanup.

### A02S2 FIX independent verification
- Status: `DONE`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-A02S2FIX-VERIFY-01`
- Code SHA: `313b3af8b6377b2b66e07256f985b1663c5630ee`
- Verdict: `ACCEPT_CANDIDATE`

### T01 independent verification
- Status: `DONE`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-T01-VERIFY-01`
- Code SHA: `34efdb62d8fb1dcaa55119f47794c3b269772e9c`
- Verdict: `ACCEPT_CANDIDATE`

### Ref/worktree cleanup
- Status: `DONE`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-REF-CLEANUP-01`

### A05A analysis
- Status: `DONE`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-A05-ANALYSIS-01`
- Verdict: `READY_TO_IMPLEMENT`

## AUTONOMOUS QUEUE — OPENCODE / MUSE 1.3 FREE

Muse is free/non-scarce for this wave. Process its published READY chain strictly top-to-bottom, one Run ID at a time, with fresh fetch/claim re-check between tasks.

### A03S1 FIX — ComputeGeom monitor enumeration
- Status: `DONE`
- Run ID: `RUN-20260907-OPENCODE-MUSE13-A03S1-FIX-01`
- Code SHA: `90718c99de1609b40a7b7a8dbe314fbcb2d857dd`

### A04S1 independent review
- Status: `DONE`
- Run ID: `RUN-20260907-OPENCODE-MUSE13-A04S1-REVIEW-01`
- Verdict: `ACCEPT_CANDIDATE`

### A04S2 independent review
- Status: `DONE`
- Run ID: `RUN-20260907-OPENCODE-MUSE13-A04S2-REVIEW-01`
- Verdict: `ACCEPT_CANDIDATE`

### A04S3 independent review
- Status: `READY`
- Eligible: `OPENCODE-MUSE13`
- Run ID: `RUN-20260907-OPENCODE-MUSE13-A04S3-REVIEW-01`
- Base: `e862c4f7b71f0aced86dc2b19843b47b4b23a0f2`
- Code SHA: `4d1a3106c3e3f64f8caa5b26bceacf9fafdf5873`
- Branch: `review/a04s3-muse13`
- Task file: `docs/agent-tasks/RUN-20260907-OPENCODE-MUSE13-A04S3-REVIEW-01.md`

Muse authority is review/analysis only for A04. Do not implement A04 fixes, accept/promote/merge or clean refs.

## WAITING / ARCHITECT GATES

- T01 is an acceptance candidate.
- A02S2 FIX is an acceptance candidate.
- Corrected A03S1 waits for the current independent Antigravity verification.
- A03S2/A03S3 remain gated until corrected upstream focus/geometry lines are accepted.
- A04 cannot be accepted/promoted until A04S3 independent review completes and any blockers are fixed.
- Next manual-test candidate should be assembled after T01 + A02S2 FIX + corrected A03S1 + reviewed A04 line reach acceptance-candidate status; do not start A05 implementation before that manual checkpoint.
