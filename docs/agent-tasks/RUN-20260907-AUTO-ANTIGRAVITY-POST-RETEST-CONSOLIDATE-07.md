# Post-retest consolidation of safe refactor subset

- Status: `WAITING_USER_PASS`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-POST-RETEST-CONSOLIDATE-07`
- Eligible: `ANTIGRAVITY`
- Preferred model: `Gemini 3.8 Flash (Medium)`
- Session: `NEW`
- Dependency: user manual dual-monitor PASS on recovery candidate from `RUN-20260907-AUTO-ANTIGRAVITY-MULTIMON-RECOVERY-CANDIDATE-06`.
- Base: exact recovery Code SHA from that PASS, to be pinned by architect before READY.
- Branch: `integration/post-retest-safe-consolidation-antigravity`

## Goal
After the user confirms the recovery candidate behaves correctly, consolidate only the safe, already-reviewed non-monitor subset that is worth keeping. Do not resurrect geometry/handles refactors that were rolled back for recovery unless the user explicitly asks to retry them later.

## Preserve
- user-visible behavior of the recovery candidate;
- focus/focus-history fixes only if already present in the passed candidate;
- settings-test determinism/test-only work only if it does not affect runtime behavior.

## Required
- produce a simple inventory: kept, abandoned, superseded branches/Code SHAs;
- create one clean integration tip from the passed recovery candidate;
- no new behavior, no new refactor, no monitor pinning;
- only `/Validate` x64/x86, `git diff --check`, config untouched, exact lineage audit.

## Deliver
One consolidation Code SHA and report with verdict `READY_FOR_BRANCH_CLEANUP` or `BLOCKED`.

No promotion to public origin. Do not start until architect changes status to READY after explicit user PASS.