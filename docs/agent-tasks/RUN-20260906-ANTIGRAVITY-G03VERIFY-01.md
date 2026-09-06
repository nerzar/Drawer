# TASK G03VERIFY — live runtime verification of G03

- Run ID: `RUN-20260906-ANTIGRAVITY-G03VERIFY-01`
- Executor: Antigravity
- Required model: **Claude Sonnet 4.6 Thinking**
- Source branch: `dev/fix/settings-live-blur-save-lock@9f5c3df`
- Worktree: `C:\Users\nerza\Projects\drawer-agent-worktrees\G03VERIFY`
- Output branch: `fix/settings-live-blur-save-lock-verify`

## Goal
Independently verify the Gemini-produced G03 fix on a real Windows runtime and make only minimal corrective changes if a reproducible defect is found.

## Required checks
1. Read current `AGENT_BOARD.md`, the G03 task/report, and `docs/agent-reports/REPORT_FORMAT.md`.
2. Create a sibling worktree from exact G03 tip `9f5c3df`.
3. Before launching Drawer, inspect running Drawer processes. Do not kill or disturb the operator's active instance without necessity. If a safe isolated runtime verification is impossible, document exactly why and stop `BLOCKED` rather than faking a runtime result.
4. Verify live behavior on an already deployed window:
   - `hideOnBlur: true -> false` after Apply takes effect immediately;
   - `hideOnBlur: false -> true` after Apply takes effect immediately;
   - `blurMs` change after Apply uses the new delay, not a stale timer;
   - General controls are locked while Save/Apply is in flight and unlock after success/error.
5. Re-run lightweight gates: AHK validate, settings-seam, frontend tests, typecheck, build.

## Scope
- Prefer verification-only.
- If a real runtime defect is reproduced, fix only G03-owned files (`src/drawer.ahk`, `settings-ui/src/views/GeneralView.vue`, directly related targeted tests) unless a blocker proves otherwise.
- Preserve C03 semantics and single persistence path.
- Do not integrate/promote branches. Do not redesign frontend.

## Completion
Factual report, commit/push only if needed, verify remote HEAD, clean tree. Final response: Run ID, DONE/BLOCKED, branch, final SHA, exact runtime checks performed, whether code changed, tests, any residual risk.