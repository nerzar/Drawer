# Cursor-follow contract audit — identify semantic drift without pinning

- Status: `READY`
- Run ID: `RUN-20260907-OPENCODE-MUSE13-CURSOR-CONTRACT-AUDIT-02`
- Eligible: `OPENCODE-MUSE13`
- Required model: `Muse Spark 1.3 Contributor Free`
- Session: `NEW`
- Accepted behavioral baseline: `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`
- Failed candidate: `cd6dc00b3d58c6abea709687618ea3702432bc45`
- Rejected fix: `073a9e649bb85b4766acec33e49f975d5444a140`
- Branch: `analysis/cursor-contract-audit-02-muse13`

## Product contract confirmed by user
`monitor: cursor` is intentionally dynamic even for already-bound/managed windows. Moving cursor to another monitor must move the edge handle there, and deployment must occur on the cursor monitor. The pinning behavior introduced by `073a9e6` is wrong and must not be preserved.

## Goal
Perform an exact semantic diff/audit between accepted baseline and failed candidate to identify where cursor-follow, animation staging, or handle lifecycle drifted. Treat `073a9e6` only as evidence of a wrong hypothesis, not as a base for a fix.

## Required
- Prove the accepted contract from code/call paths (`Show`, `HandlesSync`, monitor resolution, state/geometry lifecycle).
- Compare each integrated lineage from accepted to candidate and list every behavior-affecting change touching monitor resolution, geometry/slide/parking, handle grouping/sync, visibility and animation start.
- Identify which changes are pure extraction and which alter semantics.
- Explain how a window can target monitor 2 while visible animation begins on monitor 1.
- Explain disappearing-handle symptom while preserving legitimate handle movement with cursor.
- Define regression assertions that explicitly REQUIRE cursor-follow for managed windows and catch wrong animation origin.

## Deliver
A concise behavior contract, first suspicious/bad commit(s) with file/function evidence, candidate smallest fix strategy, tests that fail on `cd6dc00` and on rejected `073a9e6` for different reasons while passing accepted semantics, verdict `READY_FOR_FIX` or `NEEDS_RUNTIME_BISECT`.

Analysis/report only. Do not modify production/tests, do not promote/merge. Report: `docs/agent-reports/2026-09-07-opencode-muse13-cursor-contract-audit-02.md`.
