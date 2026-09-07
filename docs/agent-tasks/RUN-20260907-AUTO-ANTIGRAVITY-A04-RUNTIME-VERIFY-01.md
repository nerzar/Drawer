# A04V — live runtime verification of extracted edge handles

- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-A04-RUNTIME-VERIFY-01`
- Eligible: `ANTIGRAVITY`
- Preferred model: Gemini available in Antigravity
- Session: `NEW`
- Base: exact A04S3 Code SHA `4d1a3106c3e3f64f8caa5b26bceacf9fafdf5873`
- Branch: `verify/window-handles-runtime`
- Worktree: `C:\Users\nerza\Projects\drawer-agent-worktrees\A04VERIFY`

## Goal
Verify the completed A04 handles extraction against real Windows GUI behavior before architect acceptance/promotion. This is verification-first: do not refactor production code and do not self-promote.

Human meaning: prove that the little Drawer edge handles still behave like the old implementation after their code was moved out of `drawer.ahk`.

## Required live scenarios
Using the available Windows host/VM runtime and the exact A04S3 Code SHA, exercise as many of these as the environment supports:
- handle appears for the correct hidden/deployed Drawer window and disappears when it should;
- handle position/size remains stable while polling; no visible jitter/drift;
- hover/aim state and face/icon update correctly;
- clicking a handle restores/shows the correct owning window;
- click does not steal focus in a way the previous implementation did not;
- asynchronous click dispatch remains functional (no dead click/reentrancy regression);
- multiple deployed windows/handles map to the correct owner;
- release/destroy/reconcile leaves no orphan handle GUI/state;
- multi-monitor behavior where practical, including an edge on the secondary monitor;
- repeat hide/show/click cycles to catch stale HWND/state problems.

Use existing VM/test orchestration where possible. Do not invent success for scenarios the environment cannot exercise; mark them NOT_RUN with reason.

## Gates
Also rerun x64 `/Validate src/drawer.ahk` and the targeted handle narrow suite as a sanity check. Record exact commands and results. Screens/log artifacts are welcome if the existing harness produces them.

## Scope / mutation rule
Verification/report task. Production code must remain unchanged. Test-harness-only diagnostic changes are allowed only if strictly necessary to observe the runtime scenario; keep them in a separate commit and explain them. If a real production bug is found, do not fix it in this Run ID: report `NEEDS_FIX`/`BLOCKED` with reproduction and smallest fix scope for a new architect task.

## Output
Report verdict: `PASS`, `PASS_WITH_GAPS`, `NEEDS_FIX`, or `BLOCKED`.
Report: `docs/agent-reports/2026-09-07-antigravity-a04-runtime-verify.md`.
Follow current claim/ref-hygiene protocol and REPORT_FORMAT. Push report-only (or clearly separated harness-only + report) branch to `dev` `refs/heads/verify/window-handles-runtime`, verify remote, update claim DONE/BLOCKED. Never edit AGENT_BOARD/ARCHITECT_STATE and never promote A04 yourself.