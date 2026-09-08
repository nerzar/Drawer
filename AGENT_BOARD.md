# AGENT_BOARD — Drawer autonomous work queue

Blackboard между архитектором ChatGPT и coding agents.

**Владелец файла:** архитектор ChatGPT. Coding agents этот файл не редактируют и приоритеты сами не меняют.

## Critical Git ref hygiene
Read shared state from `refs/remotes/dev/wip/slots-parity`; shared docs push only to `HEAD:refs/heads/wip/slots-parity`. Never create local `dev/...` refs or use ambiguous `dev/wip/slots-parity`. Public `origin` stays untouched.

The shared docs branch may advance with docs-only commits. Do **not** treat its moving HEAD as the runtime Code SHA. Runtime work must name an explicit Code SHA.

Historical remote `analysis/*`, `fix/*`, `refactor/*`, `diag/*`, `integration/*` branches are dormant evidence/history, not active task branches or promotion candidates unless a future task names one explicitly by full ref + Code SHA. Do not infer work from branch names.

## Source of truth / product contract
- `docs/PRODUCT_SPEC.md` plus explicit owner decisions define desired Drawer behavior.
- `master` is the current most stable working version, but **not an oracle of correctness** and may contain known or unknown bugs.
- If desired behavior is missing, ambiguous, or conflicts with current implementation/history, stop and ask the owner rather than choosing a product behavior independently.
- `recovery/known-good-6bfa010` preserves historical recovery baseline `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`; it is evidence/fallback, not the current product contract.
- Rejected candidates `cd6dc00b3d58c6abea709687618ea3702432bc45`, `073a9e649bb85b4766acec33e49f975d5444a140`, and `71d67845467893f7dfe82267289cd7ea5dd95886` remain rejected / do not promote.
- `monitor: cursor` remains dynamic. Explicit monitor pinning is allowed only when selected by the user.
- Visual reference screenshots are still pending; do not infer unspecified visual styling. Ask the owner if a visual reference becomes necessary.

## Working policy after recovery wave
- Do not reintroduce the failed night-wave wholesale.
- Develop/fix in small reviewable units and keep Git simple and clean.
- Runtime-sensitive behavior (real windows, focus, animation, edge handles, multi-monitor) should go to short owner manual verification when that is faster/more reliable than additional agent test loops.
- Do not start chains of extra refactors, cross-agent reviews, or tests without a concrete reason.
- After a failed manual check, localize the observed regression and make the smallest justified correction before stacking further changes.

## Completed maintenance
### Reset repository around known-good baseline and clean superseded refs
- Status: `DONE`
- Eligible: `ANTIGRAVITY`
- Verdict: `CLEAN_BASELINE_READY`
- Historical baseline: `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`
- Baseline branch: `recovery/known-good-6bfa010`
- Result: 22 redundant/superseded local branches removed, one redundant remote branch removed, rejected RECOVERY-06 worktree removed, public `origin` untouched, baseline preserved.
- Important unresolved local-state note: Antigravity reported an uncommitted user-generated `src/config.ini` modification in `drawer-settings-integration` and stashed it to obtain a clean tree. Do not drop/overwrite/auto-apply that stash. User decides whether those manual-test settings need restoring.
- Maintenance branch `maintenance/reset-known-good-cleanup-20260907` is completed evidence/history, not an active task branch.

## AUTONOMOUS QUEUE — OPENCODE / MUSE
No READY tasks. Muse is available 24/7; its previous pause was temporary and is not a model-availability restriction.

## AUTONOMOUS QUEUE — ANTIGRAVITY
No READY tasks.

## Current gate
No autonomous implementation task is justified yet. The project has just moved to a clean architect-session + durable-memory workflow, and the next known technical topic is the adjacent-monitor appearance/animation problem. Keep agents idle until that problem is researched/decomposed into a bounded task or the owner explicitly chooses another implementation slice.

Before creating the next runtime task, read current `docs/architect/ARCHITECT_BOOTSTRAP.md`, `docs/architect/PROJECT_STATE.md`, `docs/architect/ORCHESTRATION_RULES.md`, and `docs/PRODUCT_SPEC.md`; do not reconstruct product intent from historical task/report files.
