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

## Current status — failed manual candidate, narrow fix under independent gate
- Accepted production remains `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`.
- Failed candidate `cd6dc00b3d58c6abea709687618ea3702432bc45` remains **DO NOT PROMOTE**.
- User manual failure: wrong-monitor deployment/animation on monitor 2 plus one transient disappearing edge handle.
- Independent Antigravity + Muse diagnoses converged on unstable `monitor: cursor` identity between `HandlesSync` and `Show`; earlier missing-braces monitor enumeration bug is already fixed by `26b1133`.
- Muse narrow FIX DONE at Code SHA `073a9e649bb85b4766acec33e49f975d5444a140`, branch `fix/manual-multimon-monitor-identity-muse13`, verdict `READY_FOR_INDEPENDENT_VERIFY`.
- Muse reports a managed-window monitor pin via stored geometry/config fingerprint; first/unmanaged cursor behavior preserved; new monitor-identity seam 24/24 x3 and negative control distinguishes failed candidate from fix. This is evidence only, not acceptance.
- A03S2/A03S3/A05 remain frozen until user dual-monitor PASS.

## AUTONOMOUS QUEUE — ANTIGRAVITY
### Independent verification of Muse multi-monitor FIX
- Status: `READY`
- Eligible: `ANTIGRAVITY`
- Preferred model: `Gemini 3.8 Flash (Medium)`
- Session: `NEW`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-MULTIMON-FIX-VERIFY-01`
- Accepted comparison: `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`
- Failed candidate base: `cd6dc00b3d58c6abea709687618ea3702432bc45`
- FIX Code SHA: `073a9e649bb85b4766acec33e49f975d5444a140`
- Source branch: `fix/manual-multimon-monitor-identity-muse13`
- Branch: `review/manual-multimon-fix-antigravity`
- Task: `docs/agent-tasks/RUN-20260907-AUTO-ANTIGRAVITY-MULTIMON-FIX-VERIFY-01.md`

Verification/report only. Do not self-fix, promote, merge, or assemble candidate. After DONE/BLOCKED, fresh-fetch and STOP unless architect publishes another explicit READY task.

## AUTONOMOUS QUEUE — OPENCODE / MUSE 1.3 FREE
### Manual retest preflight
- Status: `READY`
- Eligible: `OPENCODE-MUSE13`
- Required model: `Muse Spark 1.3 Contributor Free`
- Session: `NEW`
- Run ID: `RUN-20260907-OPENCODE-MUSE13-MULTIMON-RETEST-PREFLIGHT-01`
- Base/source: failed candidate `cd6dc00b3d58c6abea709687618ea3702432bc45`; Muse FIX `073a9e649bb85b4766acec33e49f975d5444a140`; accepted comparison `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`
- Branch: `analysis/multimon-retest-preflight-muse13`
- Task: `docs/agent-tasks/RUN-20260907-OPENCODE-MUSE13-MULTIMON-RETEST-PREFLIGHT-01.md`

Report-only preflight in parallel with Anti verification. Inspect exact code/diff; determine whether FIX can itself be the next manual candidate tip; prepare human dual-monitor retest checklist and diagnostics if failure persists. No production/test edits, no merge/promotion/candidate assembly. After DONE/BLOCKED, fresh-fetch and STOP unless architect publishes another explicit READY task.

## Next gate
If Antigravity returns `ACCEPT_FOR_MANUAL_RETEST` and OpenCode preflight finds no blocker, architect will publish one narrow candidate-assembly task using exact verified SHA(s), then stop for immediate user dual-monitor runtime retest. No A03S2/A03S3/A05 before user PASS.
