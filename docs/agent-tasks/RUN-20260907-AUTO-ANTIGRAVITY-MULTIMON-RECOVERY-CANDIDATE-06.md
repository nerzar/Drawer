# Build behavior-preserving recovery candidate for user manual test

- Status: `READY`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-MULTIMON-RECOVERY-CANDIDATE-06`
- Eligible: `ANTIGRAVITY`
- Preferred model: `Gemini 3.8 Flash (Medium)`
- Session: `NEW`
- Base: failed integrated candidate `cd6dc00b3d58c6abea709687618ea3702432bc45`
- Accepted behavior reference: `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`
- Branch: `fix/manual-recovery-revert-geometry-handles-antigravity`

## User direction
Stop spending cycles trying to prove the runtime bug with self-tests. Build a candidate that restores the known-good user behavior; the user will manually verify it on the real dual-monitor setup.

## Locked product behavior
Do not change user-visible semantics. In particular `monitor: cursor` must remain dynamic exactly as accepted production: managed window + active edge handle follow the live cursor monitor, and Show/deploy resolves the current cursor monitor. No monitor pinning/sticky bind monitor.

## Recovery strategy
Create the smallest conservative recovery from `cd6dc00` by removing the unaccepted geometry + handles refactor line from the candidate while keeping unrelated accepted-intent focus/settings-test work intact.

Target rollback lineage from candidate, in reverse dependency order:
- handles runtime sync / GUI / pure extraction commits (`fae1850`, `6e5a71c`, `815e0e9` in integrated lineage);
- geometry monitor-brace fix + geometry extraction (`26b1133`, `5ed8b9a`).

The resulting production behavior for geometry/handles must match accepted `6bfa010` on those paths. Do not reimplement or redesign the subsystem. Prefer clean git reverts/cherry-pick reconstruction over hand-editing when that preserves lineage clearly.

Retain unrelated focus-history/focus extraction fixes and test-only Settings determinism already in the candidate unless a direct conflict forces architect review.

## Verification boundary
Do NOT spend time on broad behavioral seam suites. User is the runtime acceptance gate.
Only required machine checks:
- `/Validate src/drawer.ahk` x64 and x86;
- `git diff --check`;
- confirm `src/config.ini` unchanged;
- exact diff/lineage audit showing only intended rollback + unavoidable conflict resolution.

If a revert conflict makes behavior ambiguous, STOP `BLOCKED` rather than inventing semantics.

## Deliver
- one Code SHA suitable for immediate user manual test;
- exact list of reverted integrated commits/files;
- short note of anything retained from the failed candidate;
- report `docs/agent-reports/2026-09-07-antigravity-multimon-recovery-candidate-06.md`;
- verdict `READY_FOR_USER_RETEST` or `BLOCKED`.

No promotion. No new refactors. Do not modify AGENT_BOARD. Publish-before-DONE invariant applies.