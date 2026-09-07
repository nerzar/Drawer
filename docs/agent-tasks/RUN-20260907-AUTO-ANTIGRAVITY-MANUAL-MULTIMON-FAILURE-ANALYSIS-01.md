# Manual acceptance failure — multi-monitor runtime analysis

- Status: `READY`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-MANUAL-MULTIMON-FAILURE-ANALYSIS-01`
- Eligible: `ANTIGRAVITY`
- Preferred model: `Gemini 3.8 Flash (Medium)`
- Session: `NEW`
- Base/source: failed manual candidate `cd6dc00b3d58c6abea709687618ea3702432bc45` on `integration/manual-candidate-20260907`; accepted production `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa` is the known-good behavioral comparison.
- Branch: `analysis/manual-multimon-regression-antigravity`

## User-observed material failures
Manual acceptance FAILED:
- handles basic behavior passed;
- Settings basic lifecycle passed;
- on monitor 2, a Drawer window begins deployment/animation on the wrong monitor / where the cursor is not;
- deployment on monitor 2 visibly starts from monitor 1 / neighboring monitor;
- an edge handle disappeared completely once;
- overall multi-monitor behavior is worse than accepted production.

## Goal
Root-cause the regression(s) before any promotion. Determine which integrated lineage/commit introduced each symptom. Compare candidate behavior/code against accepted production and relevant pre-integration feature bases. Do not assume the earlier A03S1 braces fix fully solved multi-monitor runtime behavior; existing seams demonstrably did not predict this manual failure.

## Required analysis
- Trace slot monitor identity, geometry calculation, parking/deploy start/end coordinates, handle ownership/placement, mouse/monitor selection and runtime sync paths.
- Inspect interaction between WindowGeometry extraction and WindowHandles extraction, including internal monitor edges and monitor coordinate origins.
- Identify whether wrong-monitor animation and disappearing handle share one cause or are separate defects.
- Use `git bisect`/targeted commit comparison or equivalent bounded evidence where practical across the assembled candidate lineage.
- Reproduce with deterministic/runtime probes if possible without destructive GUI automation; if real dual-monitor reproduction is unavailable, state that explicitly and derive a minimal regression test that would fail on candidate and pass on accepted production.
- Check whether the candidate integration conflict resolutions changed semantics.

## Deliver
- exact root cause(s) with file/function/commit evidence;
- first bad integrated commit/lineage for each symptom where determinable;
- proposed smallest safe fix and regression coverage;
- verdict `READY_FOR_FIX` or `BLOCKED_NEEDS_RUNTIME_DATA`;
- report `docs/agent-reports/2026-09-07-antigravity-manual-multimon-failure-analysis.md`.

## Constraints
Analysis/report only. Do not modify production/test code, do not promote candidate, and do not weaken tests to fit current behavior. Claim/report/push per board protocol, then stop unless architect publishes a new READY task.
