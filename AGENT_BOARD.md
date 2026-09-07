# AGENT_BOARD — Drawer autonomous work queue

Blackboard между архитектором ChatGPT и coding agents.

**Владелец файла:** архитектор ChatGPT. Coding agents этот файл не редактируют и приоритеты сами не меняют.

## Critical Git ref hygiene
Read shared state from `refs/remotes/dev/wip/slots-parity`; shared docs push only to `HEAD:refs/heads/wip/slots-parity`. Never create local `dev/...` refs or use ambiguous `dev/wip/slots-parity`. Public `origin` stays untouched.

The shared docs branch may advance with docs-only commits. Do **not** treat its moving HEAD as the runtime Code SHA. Runtime work must name an explicit Code SHA; the accepted runtime baseline remains the SHA listed below until deliberately changed.

A number of historical remote `analysis/*`, `fix/*`, `refactor/*`, `diag/*`, `integration/*` branches still exist. They are **dormant evidence/history, not active task branches and not promotion candidates** unless a future task names one explicitly by full ref + Code SHA. Do not infer work from branch names.

## Source of truth / locked behavior
- Accepted production baseline: `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`.
- Dedicated manual-baseline branch: `recovery/known-good-6bfa010` -> exactly `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`.
- User manually re-verified exact baseline on real setup: edge handles follow cursor across monitors; managed windows follow the cursor-selected monitor as expected; Settings works.
- Failed integrated candidate `cd6dc00b3d58c6abea709687618ea3702432bc45`: rejected / do not use.
- Rejected monitor-pinning fix `073a9e649bb85b4766acec33e49f975d5444a140`: rejected / do not use.
- Rejected recovery candidate `71d67845467893f7dfe82267289cd7ea5dd95886`: rejected / do not use.
- Existing user-visible behavior is immutable unless the user explicitly requests a change.
- In particular `monitor: cursor` remains dynamic exactly as accepted production.

## Product contract draft
- `docs/PRODUCT_SPEC.md` exists on the shared docs branch as a **DRAFT** for user review.
- It is not yet an acceptance authority where it conflicts with the manually verified `6bfa010...` baseline or where it contains `USER REVIEW` markers.
- Do not implement from unresolved draft wording. Wait for owner edits/approval.

## Recovery policy
The night-wave is treated as suspect. Do not salvage arbitrary subsets by assumption.
Future code must start from the known-good baseline and be reintroduced one bounded, behavior-neutral unit at a time. Any slice that can affect runtime behavior must go to immediate user manual verification before another such slice is stacked on top.

## Completed maintenance
### Reset repository around known-good baseline and clean superseded refs
- Status: `DONE`
- Eligible: `ANTIGRAVITY`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-RESET-TO-KNOWN-GOOD-CLEANUP-01`
- Verdict: `CLEAN_BASELINE_READY`
- Baseline: `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`
- Baseline branch: `recovery/known-good-6bfa010`
- Final docs commit observed: `3d40a2cb069bbfc28e06346c243d0828ffca86a8`
- Result: 22 redundant/superseded local branches removed, one redundant remote branch removed, rejected RECOVERY-06 worktree removed, public `origin` untouched, known-good baseline preserved.
- Important unresolved local-state note: Antigravity reported an uncommitted user-generated `src/config.ini` modification in `drawer-settings-integration` and stashed it to obtain a clean tree. Do not drop/overwrite/auto-apply that stash. User should decide whether those manual-test settings need restoring.
- Documentation hygiene debt: claim/report still contain `Report tip SHA: PENDING_FINAL_COMMIT` even though final docs commit `3d40a2c...` exists. This is bookkeeping only; do not spend a scarce model run on it.
- Maintenance branch `maintenance/reset-known-good-cleanup-20260907` is completed evidence/history, not an active task branch.

## AUTONOMOUS QUEUE — OPENCODE / MUSE
No READY tasks. Muse remains disabled by user directive.

## AUTONOMOUS QUEUE — ANTIGRAVITY
No READY tasks. STOP after fresh fetch.

## Next gate
Do not reintroduce night-wave code yet. User plans to hand the failure context directly to Claude after model limits recover and wants an independent diagnosis rather than architect-led salvage. Until then, preserve `6bfa010...` as the only trusted runtime baseline. No cleanup, refactor, merge, promotion, or implementation tasks are READY.
