# Recovery boundary audit — preserve accepted behavior

- Status: `READY`
- Run ID: `RUN-20260907-OPENCODE-MUSE13-MULTIMON-RECOVERY-BOUNDARY-06`
- Eligible: `OPENCODE-MUSE13`
- Required model: `Muse Spark 1.3 Contributor Free`
- Session: `NEW`
- Failed candidate: `cd6dc00b3d58c6abea709687618ea3702432bc45`
- Accepted behavior reference: `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`
- Branch: `analysis/multimon-recovery-boundary-muse13`

## Goal
Prepare an exact rollback boundary for the user-test recovery candidate. Do not search for a new semantic fix. The task is to identify which geometry/handles integrated commits/files must be removed so those runtime paths match accepted behavior again, while retaining unrelated focus/settings-test changes.

## Locked behavior
`monitor: cursor` remains live/dynamic exactly as accepted production. No pinning, no stabilization, no UX reinterpretation.

## Required
- inspect exact integrated lineage `6bfa010..cd6dc00`;
- map `5ed8b9a`, `26b1133`, `815e0e9`, `6e5a71c`, `fae1850` to touched files/functions and dependencies;
- identify whether clean reverse reverts should restore accepted geometry/handles semantics or whether any later commit outside that set depends on them;
- flag any rollback conflict that would accidentally remove focus-history or Settings-test work;
- provide a concise expected final diff boundary for Antigravity/user review.

No `src/` or `test/` edits. No broad tests. No promotion.

## Deliver
Report `docs/agent-reports/2026-09-07-opencode-muse13-multimon-recovery-boundary-06.md` with verdict `ROLLBACK_BOUNDARY_CLEAR` or `BLOCKED` and exact commit/file map. Publish-before-DONE invariant applies.