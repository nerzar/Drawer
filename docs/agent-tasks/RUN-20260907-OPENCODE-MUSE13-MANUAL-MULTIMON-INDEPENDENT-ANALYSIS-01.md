# Independent manual-failure analysis — multi-monitor runtime regression

- Status: `READY`
- Run ID: `RUN-20260907-OPENCODE-MUSE13-MANUAL-MULTIMON-INDEPENDENT-ANALYSIS-01`
- Eligible: `OPENCODE-MUSE13`
- Required model: `Muse Spark 1.3 Contributor Free`
- Session: `NEW`
- Base/source: failed candidate `cd6dc00b3d58c6abea709687618ea3702432bc45`; compare to accepted production `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`. Do not read Antigravity's new failure-analysis report until your own root-cause hypothesis/evidence is written down.
- Branch: `analysis/manual-multimon-regression-muse13`

## User-observed failure
Manual acceptance failed although automated seams were green:
- monitor-2 deployment/animation starts on monitor 1 / neighboring monitor;
- visible origin does not match cursor/target monitor;
- one edge handle disappeared completely once;
- basic handle interaction and Settings lifecycle otherwise passed.

## Goal
Independently localize the regression and identify the first bad integrated lineage/commit. Focus on actual production runtime adapters and interactions that narrow pure seams may miss.

## Required
- Compare exact candidate to accepted production and walk integrated commits.
- Trace monitor selection/identity, slot monitor, ComputeGeom inputs/outputs, park/deploy animation coordinates, handle ownership/placement and sync.
- Explicitly inspect integration conflict resolutions.
- Determine whether wrong-monitor animation and disappearing handle plausibly share a cause.
- Prefer evidence that distinguishes candidate from accepted production; use bounded probes/bisect where possible.
- Propose a regression test that fails on candidate and passes on accepted production if feasible.

## Deliver
Root cause(s), first bad commit/lineage where determinable, smallest safe fix, regression coverage, verdict `READY_FOR_FIX` or `BLOCKED_NEEDS_RUNTIME_DATA`, and report `docs/agent-reports/2026-09-07-opencode-muse13-manual-multimon-analysis.md`.

Analysis/report only. Do not edit production/tests, do not promote. Claim/report/push per board, then stop unless a new READY task exists.
