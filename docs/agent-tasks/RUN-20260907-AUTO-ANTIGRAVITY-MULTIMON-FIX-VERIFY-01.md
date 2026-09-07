# Independent verification — Muse multi-monitor runtime FIX

- Status: `WAITING_DEPENDENCY`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-MULTIMON-FIX-VERIFY-01`
- Eligible: `ANTIGRAVITY`
- Preferred model: `Gemini 3.8 Flash (Medium)`
- Session: `NEW`
- Dependency: `RUN-20260907-OPENCODE-MUSE13-MANUAL-MULTIMON-FIX-01` must be DONE with verdict `READY_FOR_INDEPENDENT_VERIFY`; architect must pin its exact Code SHA and change this task to READY before pickup.
- Base/source: accepted comparison `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`; failed candidate `cd6dc00b3d58c6abea709687618ea3702432bc45`; FIX Code SHA `PENDING`.
- Branch: `review/manual-multimon-fix-antigravity`

## Goal
Independently verify Muse's narrow monitor-identity fix against the exact Code SHA. Do not trust the implementation report as evidence. Confirm the fix addresses the user's observed dual-monitor regression without breaking first-bind cursor semantics, geometry/internal-edge behavior, focus, handles, or Settings.

## Required once activated
- inspect exact diff/lineage and scope;
- independently reason through `monitor: cursor` lifecycle for unmanaged/bind, managed/hidden, HandlesSync, handle click, Show/deploy and Release/rebind;
- reproduce negative control against `cd6dc00` for the new regression test and positive result on FIX SHA;
- `/Validate` x64/x86 for touched production modules;
- run relevant monitor-identity, handles, geometry/adapter, focus and settings seams as bounded by the activated task;
- look specifically for stale `st.geom`/monitor identity after topology changes or intentional rebind;
- ensure `src/config.ini` untouched and `git diff --check` clean.

## Deliver
Report with verdict `ACCEPT_FOR_MANUAL_RETEST`, `NEEDS_FIX`, or `BLOCKED`. No production edits, no promotion, no candidate assembly unless architect separately authorizes it.
