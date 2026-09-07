# AGENT_BOARD — Drawer autonomous work queue

Blackboard между архитектором ChatGPT и coding agents.

**Владелец файла:** архитектор ChatGPT. Coding agents этот файл не редактируют и приоритеты сами не меняют.

## EMERGENCY FREEZE
All autonomous work is PAUSED after repeated regressions in the night-wave recovery attempts.

- No READY tasks for Antigravity.
- No READY tasks for OpenCode/Muse.
- No implementation, analysis, cleanup, consolidation, acceptance or promotion until the user manually verifies the exact accepted production baseline again.

## Critical Git ref hygiene
Read shared state from `refs/remotes/dev/wip/slots-parity`; shared docs push only to `HEAD:refs/heads/wip/slots-parity`. Never create local `dev/...` refs or use ambiguous `dev/wip/slots-parity`. Public `origin` stays untouched.

## Source of truth / locked behavior
- Accepted production baseline: `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`.
- Dedicated manual-baseline branch created by architect: `recovery/known-good-6bfa010` -> exactly `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`.
- Failed integrated candidate `cd6dc00b3d58c6abea709687618ea3702432bc45`: rejected / do not use.
- Rejected monitor-pinning fix `073a9e649bb85b4766acec33e49f975d5444a140`: rejected / do not use.
- Recovery candidate `71d67845467893f7dfe82267289cd7ea5dd95886`: rejected after user test; do not use.
- Existing user-visible behavior is immutable unless the user explicitly requests a change.
- In particular `monitor: cursor` remains dynamic exactly as accepted production.

## User manual baseline gate
The next and only allowed action is the user's manual test of exact SHA `6bfa010...` from branch `recovery/known-good-6bfa010`.

If this exact baseline behaves correctly:
1. architect will treat all later night-wave code as suspect;
2. no salvage-by-subset will be assumed safe;
3. changes will be reintroduced only one bounded behavior-neutral unit at a time, each followed immediately by user manual verification where runtime behavior could change;
4. acceptance/consolidation and branch cleanup will happen only after a stable tested line exists.

If exact `6bfa010` itself does NOT match the user's expected behavior, stop and reconcile which earlier accepted SHA/behavior is actually the true baseline before any coding.

## AUTONOMOUS QUEUE — ANTIGRAVITY
No READY tasks. STOP after fresh fetch.

## AUTONOMOUS QUEUE — OPENCODE / MUSE
No READY tasks. STOP after fresh fetch.

## Deferred debt
All prior acceptance debt, consolidation tasks, branch/worktree cleanup and new refactors remain deferred until the manual baseline gate is resolved.
