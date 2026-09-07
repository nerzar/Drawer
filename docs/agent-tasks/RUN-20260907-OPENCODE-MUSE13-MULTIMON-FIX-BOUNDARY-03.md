# RUN-20260907-OPENCODE-MUSE13-MULTIMON-FIX-BOUNDARY-03

- Status: `READY`
- Eligible: `OPENCODE-MUSE13`
- Required model: `Muse Spark 1.3 Contributor Free`
- Session: `NEW`
- Accepted baseline: `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`
- Failed candidate: `cd6dc00b3d58c6abea709687618ea3702432bc45`
- Rejected semantic fix: `073a9e649bb85b4766acec33e49f975d5444a140`
- Antigravity prior report: `docs/agent-reports/2026-09-07-antigravity-multimon-runtime-bisect-02.md`
- Muse prior audit: `docs/agent-reports/2026-09-07-opencode-muse13-cursor-contract-audit-02.md`
- Branch: `analysis/multimon-fix-boundary-03-muse13`

## Goal
Independently review the two latest analyses and define the smallest behavior-preserving fix boundary, without implementing it yet. The purpose is to catch unsupported assumptions before code changes.

## Product contract — immutable
For `monitor: cursor`, managed windows and handles follow the current cursor monitor. `Show()` and handle sync must keep live cursor resolution. Do not pin windows to the bind monitor, do not redefine this behavior, and do not propose any user-visible behavior change.

## Required
1. Fresh-fetch and verify both reports against exact code/SHAs rather than trusting their prose.
2. Explicitly assess each Antigravity proposed mechanism:
   - `5ed8b9a` geometry extraction versus `26b1133` brace fix: can it still explain `cd6dc00` after the fix is present?
   - `fae1850` handle migration: what exact accepted-vs-candidate semantic delta can explain disappearance while cursor-follow remains dynamic?
   - cross-monitor Show staging / WinActivate order: identify exact accepted-vs-candidate deltas, if any.
3. Re-check focus commits `2bab75c` and `42a16ee` as possible remaining behavior/timing deltas.
4. Build a fix-boundary matrix: hypothesis, evidence for, evidence against, exact touched functions/files if eventually fixed, risk to accepted behavior.
5. Specify regression requirements that preserve existing behavior and distinguish:
   - accepted `6bfa010`;
   - failed `cd6dc00`;
   - rejected pinning `073a9e6`.
6. Do not edit `src/` or `test/`. Do not implement, merge, promote, or create a candidate.

## Repo navigation
RepoWise is available in the Drawer environment and may be used as a supplementary navigation/indexing aid. Exact Git refs/SHAs and repository files remain authoritative; verify every architectural or behavioral claim against the actual code. Hindsight is not part of the architect workflow and must not be assumed as a required dependency.

## Deliver
Report verdict:
- `FIX_BOUNDARY_READY` only if a narrow implementation can be justified without changing product behavior;
- `WAIT_FOR_RUNTIME_EVIDENCE` if Antigravity runtime reconciliation is required before implementation;
- `BLOCKED` for a concrete blocker.

The report must call out any prior claim that is speculative, contradicted by exact code, or not backed by runtime evidence.