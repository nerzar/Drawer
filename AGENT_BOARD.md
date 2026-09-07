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

## Reconciliation wave — COMPLETE, no implementation gate
### Antigravity `RUN-20260907-AUTO-ANTIGRAVITY-MULTIMON-EVIDENCE-RECONCILE-03`
- Status: `DONE`
- Branch: `analysis/multimon-evidence-reconcile-03-antigravity`
- Report tip: `bff31ea1ee852efea994065604dbdc760773d7ec`
- Verdict reported: `READY_FOR_NARROW_FIX`.
- Accepted architect findings from the report: `5ed8b9a` is NOT a live defect in `cd6dc00` because `26b1133` fixed it; candidate geometry and handle lifecycle are statically equivalent to accepted on the implicated paths; prior first-bad attribution is retracted.
- Architect rejection: the proposed destroy-on-monitor-change and cross-monitor slide suppression change accepted behavior and are not justified by an accepted-vs-candidate failing runtime delta. The supplied matrix is largely static/seam evidence, not sufficient proof of the user's runtime failure mechanism.

### OpenCode/Muse `RUN-20260907-OPENCODE-MUSE13-MULTIMON-FIX-BOUNDARY-03`
- Status: `DONE`
- Branch: `analysis/multimon-fix-boundary-03-muse13`
- Report tip: `c4e8010c0cb93a84c82ed1be731a3765df807511`
- Verdict: `WAIT_FOR_RUNTIME_EVIDENCE`.
- Architect agrees: geometry bug is fixed-in-lineage; Show staging, handle lifecycle and relevant focus/monitor code do not expose a proven static accepted-vs-candidate delta. Do not implement speculative DWM/timer/focus fixes.

## AUTONOMOUS QUEUE — ANTIGRAVITY
No READY task. STOP after fresh fetch. Preserve scarce model budget until a trace harness/runtime capture produces a concrete failing sequence worth independent verification.

## AUTONOMOUS QUEUE — OPENCODE / MUSE 1.3 FREE
### Dual-monitor runtime trace harness
- Status: `READY`
- Eligible: `OPENCODE-MUSE13`
- Required model: `Muse Spark 1.3 Contributor Free`
- Session: `NEW`
- Run ID: `RUN-20260907-OPENCODE-MUSE13-MULTIMON-RUNTIME-TRACE-HARNESS-04`
- Base/Code SHA: `cd6dc00b3d58c6abea709687618ea3702432bc45`
- Accepted comparison: `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`
- Rejected semantic fix: `073a9e649bb85b4766acec33e49f975d5444a140`
- Branch: `diag/multimon-runtime-trace-harness-muse13`
- Task: `docs/agent-tasks/RUN-20260907-OPENCODE-MUSE13-MULTIMON-RUNTIME-TRACE-HARNESS-04.md`

Test/diagnostic tooling only. No `src/` edits, no behavior changes, no fix. Build runtime observability capable of comparing exact accepted and failed SHAs and recording cursor monitor, handle lifecycle/rect, Show geometry/staging, actual window rect and focus ordering. Verdict may only be `READY_FOR_RUNTIME_CAPTURE` or `BLOCKED`.

## Architect gate
Do not publish an implementation task until genuine runtime evidence identifies a mechanism that differs materially between accepted `6bfa010` and failed `cd6dc00`, while preserving the locked cursor-follow behavior. Once such evidence exists, use Antigravity only for bounded independent verification of that evidence/fix boundary. After a verified narrow fix, build exactly one candidate and stop for immediate user dual-monitor retest before any other refactor or promotion.
