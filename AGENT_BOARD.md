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
- RepoWise is available in the Drawer environment and may be used as a supplementary repo-navigation/indexing aid.
- Git refs, exact SHAs, repository files, tests and runtime evidence remain authoritative.
- Hindsight is not a required dependency for any current task and must not block work.

## Current status — manual retest FAILED; product behavior locked
- Accepted production remains `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`.
- Integrated candidate `cd6dc00b3d58c6abea709687618ea3702432bc45` remains **DO NOT PROMOTE**.
- Monitor-pinning FIX `073a9e649bb85b4766acec33e49f975d5444a140` remains **REJECTED** because it changes required behavior.
- User-required contract is immutable unless user explicitly changes it: for `monitor: cursor`, managed windows and the active edge handle follow the current cursor monitor; Show/deploy uses that cursor monitor. No pinning to bind monitor.
- Real unresolved defects: wrong animation origin / cross-monitor staging and transient disappearing edge handle while cursor-follow remains dynamic.
- A03S2/A03S3/A05 and promotion remain frozen.

## Completed analysis wave
- `RUN-20260907-AUTO-ANTIGRAVITY-MULTIMON-RUNTIME-BISECT-02` — DONE, verdict `READY_FOR_FIX`. Report claims `5ed8b9a` for wrong-origin and `fae1850` for handle migration.
- `RUN-20260907-OPENCODE-MUSE13-CURSOR-CONTRACT-AUDIT-02` — DONE, verdict `NEEDS_RUNTIME_BISECT`. Static audit proves cursor-follow contract but conflicts with the Antigravity root-cause conclusion: it shows the `5ed8b9a` missing-braces geometry bug is fixed by `26b1133` inside the failed candidate and finds no remaining geometry semantic delta.

Because the two analyses do **not** converge, implementation is NOT authorized yet. Do not convert speculative DWM/timer explanations into code changes.

## AUTONOMOUS QUEUE — ANTIGRAVITY
### Runtime evidence reconciliation
- Status: `READY`
- Eligible: `ANTIGRAVITY`
- Preferred model: `Gemini 3.8 Flash (Medium)`
- Session: `NEW`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-MULTIMON-EVIDENCE-RECONCILE-03`
- Accepted baseline: `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`
- Failed candidate: `cd6dc00b3d58c6abea709687618ea3702432bc45`
- Rejected fix: `073a9e649bb85b4766acec33e49f975d5444a140`
- Branch: `analysis/multimon-evidence-reconcile-03-antigravity`
- Task: `docs/agent-tasks/RUN-20260907-AUTO-ANTIGRAVITY-MULTIMON-EVIDENCE-RECONCILE-03.md`

Analysis/report only. Produce an explicit per-commit runtime pass/fail matrix if dual-monitor runtime is genuinely available. If not, report `BLOCKED_RUNTIME_EVIDENCE`; do not call static reasoning a runtime bisection. Preserve cursor-follow.

## AUTONOMOUS QUEUE — OPENCODE / MUSE 1.3 FREE
### Fix-boundary reconciliation
- Status: `READY`
- Eligible: `OPENCODE-MUSE13`
- Required model: `Muse Spark 1.3 Contributor Free`
- Session: `NEW`
- Run ID: `RUN-20260907-OPENCODE-MUSE13-MULTIMON-FIX-BOUNDARY-03`
- Accepted baseline: `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`
- Failed candidate: `cd6dc00b3d58c6abea709687618ea3702432bc45`
- Rejected fix: `073a9e649bb85b4766acec33e49f975d5444a140`
- Branch: `analysis/multimon-fix-boundary-03-muse13`
- Task: `docs/agent-tasks/RUN-20260907-OPENCODE-MUSE13-MULTIMON-FIX-BOUNDARY-03.md`

Analysis/report only. Independently review both prior reports, flag unsupported claims, and define the smallest behavior-preserving fix boundary or explicitly wait for runtime evidence. No production/test edits.

## Architect gate
Wait for both reconciliation reports. Publish implementation only if evidence converges on a narrow mechanism that preserves accepted user behavior. Any proposed fix must have regression coverage that preserves managed cursor-follow and must not revive monitor pinning. After a verified narrow fix, build exactly one candidate and stop for immediate user dual-monitor retest before any other refactor or promotion.
