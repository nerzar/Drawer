# Multi-monitor manual-regression FIX

- Status: `READY`
- Run ID: `RUN-20260907-OPENCODE-MUSE13-MULTIMON-RUNTIME-FIX-01`
- Eligible: `OPENCODE-MUSE13`
- Required model: `Muse Spark 1.3 Contributor Free`
- Session: `NEW`
- Base: failed integrated candidate `cd6dc00b3d58c6abea709687618ea3702432bc45`
- Branch: `fix/manual-multimon-runtime-muse13`

## Context / accepted evidence
Manual candidate failed on dual monitors. Independent Antigravity and Muse analyses converge on a remaining cursor-monitor identity race between handle placement and Show/runtime geometry. Both also confirm the earlier `5ed8b9a` monitor enumeration bug is already fixed by `26b1133` in this base, so do NOT re-fix braces as if it explained the current candidate failure.

Observed user failures: monitor-2 deployment starts/animates from monitor 1 / neighboring monitor; target/cursor and visible origin disagree; one edge handle disappeared once. Basic handles and Settings passed.

## Goal
Implement the smallest coherent fix that stabilizes monitor identity for an already-managed slot/window and prevents handles/runtime Show from independently re-resolving `monitor: cursor` to different monitors during timer/click races. Preserve intended cursor-based selection when initially binding/capturing or when an explicit user action legitimately chooses a new monitor; do not globally convert `monitor: cursor` into a fixed config value.

Also ensure internal-edge slide suppression remains correct with full multi-monitor topology. Do not redesign parking/animation unless required by demonstrated evidence.

## Required regression evidence
Add/extend a production-direct or adapter-level deterministic regression that can run on a single-monitor host with stubs and demonstrates:
1. managed window anchored on monitor 2 does not have its handle jump/disappear merely because cursor moves to monitor 1;
2. handle-triggered Show and handle placement use one stable monitor identity for that managed window;
3. internal edge monitor-2 geometry remains `slide=false` with a neighbor monitor;
4. test fails against the relevant broken candidate behavior and passes on the fix (document exact negative-control evidence).

Run bounded `/Validate` x64/x86 on changed production modules and relevant narrow seams. Preserve `src/config.ini`. `git diff --check` clean.

## Constraints
- Narrow fix only; no A03S2/A03S3/A05/new refactors.
- Do not promote or rebuild accepted production.
- Do not paper over behavior by weakening tests.
- Claim/report/push per board protocol.
- Report: `docs/agent-reports/2026-09-07-opencode-muse13-multimon-runtime-fix.md`.
- Final verdict `FIX_READY_FOR_VERIFY` or `BLOCKED`.
- After completion STOP; independent verification and user dual-monitor retest are separate gates.
