# Independent verification — Muse multi-monitor runtime FIX

- Status: `READY`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-MULTIMON-FIX-VERIFY-01`
- Eligible: `ANTIGRAVITY`
- Preferred model: `Gemini 3.8 Flash (Medium)`
- Session: `NEW`
- Dependency: satisfied — `RUN-20260907-OPENCODE-MUSE13-MANUAL-MULTIMON-FIX-01` DONE with verdict `READY_FOR_INDEPENDENT_VERIFY`.
- Base/source: accepted comparison `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`; failed candidate `cd6dc00b3d58c6abea709687618ea3702432bc45`; FIX Code SHA `073a9e649bb85b4766acec33e49f975d5444a140` on `fix/manual-multimon-monitor-identity-muse13`.
- Branch: `review/manual-multimon-fix-antigravity`

## Goal
Independently verify Muse's narrow monitor-identity fix against exact Code SHA `073a9e649bb85b4766acec33e49f975d5444a140`. Do not trust the implementation report as evidence. Confirm the fix addresses the user's observed dual-monitor regression without breaking first-bind cursor semantics, geometry/internal-edge behavior, focus, handles, or Settings.

## Required
- inspect exact `cd6dc00..073a9e6` diff/lineage and scope;
- independently reason through `monitor: cursor` lifecycle for unmanaged/bind, managed/hidden, HandlesSync, handle click, Show/deploy and Release/rebind;
- independently validate the chosen contract (`st.geom.mi` / monitor config fingerprint) and look for stale-state/topology-change/rebind edge cases;
- reproduce negative control against `cd6dc00` for the new monitor-identity regression and positive result on `073a9e6`; do not accept text-only assertions without checking the actual test logic and production call sites;
- `/Validate` x64/x86 for `src/drawer.ahk` and touched production modules where meaningful in production context;
- run `window-monitor-identity-seam.ahk` at least 3x and relevant handles, geometry, adapter, focus and settings seams;
- explicitly confirm internal-edge monitor-2 slide suppression remains intact;
- ensure `src/config.ini` untouched and `git diff --check` clean;
- separate real blockers from pre-existing standalone warning/flakes.

## Deliver
Report `docs/agent-reports/2026-09-07-antigravity-multimon-fix-verify.md` with verdict `ACCEPT_FOR_MANUAL_RETEST`, `NEEDS_FIX`, or `BLOCKED`.

Verification/report only. Do not modify production/tests, do not self-fix, promote, merge, or assemble a candidate. Claim/report/push per board protocol, then STOP unless architect publishes another READY task.
