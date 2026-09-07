# AGENT_BOARD — Drawer autonomous work queue

Blackboard между архитектором ChatGPT и coding agents.

**Владелец файла:** архитектор ChatGPT. Coding agents этот файл не редактируют и приоритеты сами не меняют.

## Critical Git ref hygiene
Read shared state from `refs/remotes/dev/wip/slots-parity`; shared docs push only to `HEAD:refs/heads/wip/slots-parity`. Never create local `dev/...` refs or use ambiguous `dev/wip/slots-parity`. Public `origin` stays untouched.

## Source of truth / locked behavior
- Accepted production baseline: `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`.
- Dedicated manual-baseline branch: `recovery/known-good-6bfa010` -> exactly `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`.
- User manually re-verified exact baseline on real setup: edge handles follow cursor across monitors; managed windows follow the cursor-selected monitor as expected; Settings works.
- Failed integrated candidate `cd6dc00b3d58c6abea709687618ea3702432bc45`: rejected / do not use.
- Rejected monitor-pinning fix `073a9e649bb85b4766acec33e49f975d5444a140`: rejected / do not use.
- Rejected recovery candidate `71d67845467893f7dfe82267289cd7ea5dd95886`: rejected / do not use.
- Existing user-visible behavior is immutable unless the user explicitly requests a change.
- In particular `monitor: cursor` remains dynamic exactly as accepted production.

## Recovery policy
The night-wave is treated as suspect. Do not salvage arbitrary subsets by assumption.
Future code must start from the known-good baseline and be reintroduced one bounded, behavior-neutral unit at a time. Any slice that can affect runtime behavior must go to immediate user manual verification before another such slice is stacked on top.

## AUTONOMOUS QUEUE — OPENCODE / MUSE
No READY tasks. Muse remains disabled by user directive.

## AUTONOMOUS QUEUE — ANTIGRAVITY
### Reset repository around known-good baseline and clean superseded refs
- Status: `READY`
- Eligible: `ANTIGRAVITY`
- Preferred model: `Gemini 3.8 Flash (Medium)`
- Session: `NEW`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-RESET-TO-KNOWN-GOOD-CLEANUP-01`
- Baseline: `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`
- Baseline branch: `recovery/known-good-6bfa010`
- Branch: `maintenance/reset-known-good-cleanup-20260907`
- Task: `docs/agent-tasks/RUN-20260907-AUTO-ANTIGRAVITY-RESET-TO-KNOWN-GOOD-CLEANUP-01.md`

Maintenance only. No `src/`, `test/`, config or behavior changes. Safely reduce branch/worktree debt, preserve unique commits, keep known-good baseline intact, and leave one clean starting ref for future development.

## Next gate
After cleanup, architect will choose exactly one small behavior-neutral slice to reintroduce from the known-good baseline. No multi-slice integration and no new refactor wave. Any runtime-affecting slice is followed immediately by user manual verification before continuing.