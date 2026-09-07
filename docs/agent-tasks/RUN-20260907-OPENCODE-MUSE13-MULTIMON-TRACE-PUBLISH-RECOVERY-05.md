# Recover/publish dual-monitor runtime trace harness

- Status: `READY`
- Run ID: `RUN-20260907-OPENCODE-MUSE13-MULTIMON-TRACE-PUBLISH-RECOVERY-05`
- Eligible: `OPENCODE-MUSE13`
- Required model: `Muse Spark 1.3 Contributor Free`
- Session: `CONTINUE_IF_LOCAL_STATE_EXISTS_ELSE_NEW`
- Source context: previous architect task `RUN-20260907-OPENCODE-MUSE13-MULTIMON-RUNTIME-TRACE-HARNESS-04` was published, but no corresponding claim/report/remote branch is visible on `dev` after fresh architect inspection.
- Base/Code SHA: failed candidate `cd6dc00b3d58c6abea709687618ea3702432bc45`
- Accepted comparison: `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`
- Rejected behavior-changing fix: `073a9e649bb85b4766acec33e49f975d5444a140`
- Branch: `diag/multimon-runtime-trace-harness-muse13`

## Goal
Recover and publish the completed work from the previous runtime-trace-harness task if it exists locally. If no recoverable local work exists, execute the previous harness task now. Do not silently discard completed local work and do not create a second competing implementation.

## Required first step
1. Fresh `git fetch dev` and read current board/task/report format.
2. Inspect local worktrees/branches for the previous Run ID or branch `diag/multimon-runtime-trace-harness-muse13` before creating anything.
3. If completed local work exists, verify it, preserve it, and publish it to the exact remote branch plus claim/report.
4. If not, build the diagnostic harness from scratch per task 04.

## Harness contract
Test/diagnostic code only. No `src/` behavior changes. Must be able to capture/compare at minimum: cursor position + resolved monitor, handle lifecycle/rect/group, Show/Hide/Toggle sequence, computed geometry (`mi/sx/sy/hx/hy/px/py/slide`), actual window rect before/after staging/animation, and relevant focus ordering. It must preserve the accepted `monitor: cursor` behavior rather than pinning monitor identity.

Prefer integrating with existing VM/test tooling where practical. RepoWise may be used for navigation only; exact Git refs/code/runtime output are authoritative.

## Deliver
- published branch `diag/multimon-runtime-trace-harness-muse13`;
- claim for this recovery Run ID with exact Code SHA/report tip;
- report `docs/agent-reports/2026-09-07-opencode-muse13-multimon-trace-harness-recovery.md`;
- exact commands to run capture on `6bfa010` and `cd6dc00`;
- verdict `READY_FOR_RUNTIME_CAPTURE` or `BLOCKED`.

Do not implement a product fix, merge, promote, or alter the locked product behavior. After DONE/BLOCKED, fresh-fetch and continue only if a new explicit READY task exists.
