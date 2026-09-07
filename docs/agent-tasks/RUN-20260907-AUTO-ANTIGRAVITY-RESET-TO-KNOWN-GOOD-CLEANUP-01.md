# Reset development state around known-good baseline and clean superseded refs

- Status: `READY`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-RESET-TO-KNOWN-GOOD-CLEANUP-01`
- Eligible: `ANTIGRAVITY`
- Preferred model: `Gemini 3.8 Flash (Medium)`
- Session: `NEW`
- Baseline: `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`
- Baseline branch: `recovery/known-good-6bfa010`
- Branch: `maintenance/reset-known-good-cleanup-20260907`

## User-confirmed baseline behavior
The user manually verified exact `6bfa010` on the real setup:
- edge handles follow the cursor across monitors;
- windows follow the cursor/selected monitor as expected;
- Settings works.

Treat this behavior as immutable unless the user explicitly requests a change.

## Goal
Reduce repository chaos without changing product code. Establish a clean post-night-wave development state around the known-good baseline and safely remove only clearly superseded temporary refs/worktrees.

## Required
1. Fresh fetch and inventory all local/remote branches/worktrees related to the failed night wave, including failed candidate, rejected pinning fix, rejected recovery candidate, analysis/review/diag branches, and recovery refs.
2. Preserve every unique commit that is not already reachable from a durable report/archive ref. If in doubt, keep the ref and report it.
3. Delete only refs/worktrees that are provably redundant/superseded and have no unique unpreserved commits.
4. Keep `recovery/known-good-6bfa010` intact.
5. Do NOT modify `src/`, `test/`, config, product behavior, or accepted baseline.
6. Produce a before/after branch/worktree count and a mapping of deleted vs preserved refs with reasons.
7. Create/retain a clean development starting ref at exact baseline for future one-slice-at-a-time work; do not add code to it.

## Deliver
- report: `docs/agent-reports/2026-09-07-antigravity-reset-known-good-cleanup.md`;
- verdict `CLEAN_BASELINE_READY` or `BLOCKED`;
- exact clean starting branch/ref for the next development slice;
- before/after counts and ref hygiene evidence.

No code changes. No promotion of any night-wave code. No new refactors. Stop after completion.