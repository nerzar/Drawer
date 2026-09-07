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
3. Verify repository facts independently; do not trust prior reports as proof.
4. Run bounded targeted gates; report/commit/push; verify remote + clean tree.
5. Never self-accept/promote or broaden scope. On blocker/conflict/data-loss risk: report `BLOCKED`, stop.

## Current status — manual retest FAILED; previous fix hypothesis rejected
- Accepted production remains `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`.
- Integrated candidate `cd6dc00b3d58c6abea709687618ea3702432bc45` remains **DO NOT PROMOTE**.
- Muse monitor-pinning FIX `073a9e649bb85b4766acec33e49f975d5444a140` is **REJECTED** despite automated verification because it changes intended product behavior.
- User explicitly confirmed historical/required contract for `monitor: cursor`: even after binding, moving cursor to another monitor moves the active edge handle there and deployment must occur on that cursor monitor. A managed window is NOT pinned to its bind monitor.
- The rejected fix caused exactly the wrong behavior: bound VS Code/Storm stayed on original monitor, handle no longer followed cursor, and deployment/animation remained wrong. Therefore previous diagnosis "cursor monitor instability is the bug" was incorrect as a product conclusion.
- Accepted code itself proves dynamic behavior: `Show()` resolves `mi := ResolveMonitor(cfg)` on every deploy. Preserve that contract.
- Real unresolved bug: candidate lineage causes wrong animation origin / cross-monitor staging and transient handle disappearance while dynamic cursor-follow must remain intact.
- A03S2/A03S3/A05 and promotion remain frozen.

## AUTONOMOUS QUEUE — ANTIGRAVITY
### Live/runtime bisection of real regression
- Status: `READY`
- Eligible: `ANTIGRAVITY`
- Preferred model: `Gemini 3.8 Flash (Medium)`
- Session: `NEW`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-MULTIMON-RUNTIME-BISECT-02`
- Accepted baseline: `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`
- Failed candidate: `cd6dc00b3d58c6abea709687618ea3702432bc45`
- Rejected semantic fix: `073a9e649bb85b4766acec33e49f975d5444a140`
- Branch: `analysis/multimon-runtime-bisect-02-antigravity`
- Task: `docs/agent-tasks/RUN-20260907-AUTO-ANTIGRAVITY-MULTIMON-RUNTIME-BISECT-02.md`

Analysis only. Prefer actual dual-monitor VM/runtime bisection. Identify first bad commit for wrong animation origin and disappearing edge while preserving cursor-follow semantics.

## AUTONOMOUS QUEUE — OPENCODE / MUSE 1.3 FREE
### Cursor-follow contract / semantic-drift audit
- Status: `READY`
- Eligible: `OPENCODE-MUSE13`
- Required model: `Muse Spark 1.3 Contributor Free`
- Session: `NEW`
- Run ID: `RUN-20260907-OPENCODE-MUSE13-CURSOR-CONTRACT-AUDIT-02`
- Accepted baseline: `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`
- Failed candidate: `cd6dc00b3d58c6abea709687618ea3702432bc45`
- Rejected fix: `073a9e649bb85b4766acec33e49f975d5444a140`
- Branch: `analysis/cursor-contract-audit-02-muse13`
- Task: `docs/agent-tasks/RUN-20260907-OPENCODE-MUSE13-CURSOR-CONTRACT-AUDIT-02.md`

Analysis only. Prove accepted cursor-follow contract and identify semantic drift/animation staging changes across the candidate lineage. Do not implement another fix yet.

## Architect gate
Wait for both analyses. Compare runtime bisection with static semantic audit. Then publish one narrow FIX that preserves dynamic cursor-follow and specifically addresses wrong animation origin/handle disappearance. The next regression tests must fail both bad candidate `cd6dc00` and rejected pinning fix `073a9e6` for distinct reasons while passing accepted behavior. Rebuild one candidate and request immediate user dual-monitor retest before any other refactor or promotion.
