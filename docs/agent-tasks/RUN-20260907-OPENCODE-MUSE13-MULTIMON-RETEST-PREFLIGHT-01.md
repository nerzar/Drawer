# Manual retest preflight — fixed multi-monitor candidate

- Status: `READY`
- Run ID: `RUN-20260907-OPENCODE-MUSE13-MULTIMON-RETEST-PREFLIGHT-01`
- Eligible: `OPENCODE-MUSE13`
- Required model: `Muse Spark 1.3 Contributor Free`
- Session: `NEW`
- Base/source: failed candidate `cd6dc00b3d58c6abea709687618ea3702432bc45`; Muse FIX `073a9e649bb85b4766acec33e49f975d5444a140`; accepted production comparison `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`.
- Branch: `analysis/multimon-retest-preflight-muse13`

## Goal
Prepare a repo-only/manual-retest preflight for the exact Muse FIX without modifying production/tests and without assembling/promoting a candidate. This runs in parallel with Antigravity's independent verification.

## Required
- verify exact lineage/scope from failed candidate to FIX and list changed production/test files;
- check whether FIX can be used directly as the next manual candidate tip or whether a separate integration assembly commit is actually necessary;
- inspect for obvious integration hazards with the already assembled focus/geometry/handles/settings wave, especially state initialization, `st.geom` legacy shape, `Release`/rebind, topology changes, and config-monitor fingerprint behavior;
- produce a concise dual-monitor manual retest checklist focused on the exact failures the user saw, including cursor-crossing timing, internal/external edges, monitor-2 deployment origin, repeated hide/show, handle persistence, rebind/release, and Settings smoke;
- identify what runtime logging/diagnostic facts would be most useful if the user still sees a failure, but do not add logging code unless explicitly asked;
- do not rely on Muse implementation report as proof; inspect exact code/diff.

## Deliver
Report `docs/agent-reports/2026-09-07-opencode-muse13-multimon-retest-preflight.md` with verdict `READY_FOR_MANUAL_RETEST_IF_VERIFY_PASSES`, `NEEDS_FIX`, or `BLOCKED`. Report-only branch, no production/test edits, no promotion/merge/candidate assembly. Claim/report/push per board protocol, then STOP unless architect publishes another READY task.
