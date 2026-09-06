# T01 — settings-seam direct-run timeout / determinism

- Run ID: `RUN-20260907-OPENCODE-DEEPSEEK-T01-SETTINGS-SEAM-01`
- Eligible: `OPENCODE-DEEPSEEK`
- Required model: `deepseek-v4-flash`
- Session: `NEW`
- Base/source rule: accepted shared production identity `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`; latest shared tip allowed only if newer commits are docs/tasks/claims/reports.
- Branch: `test/settings-seam-determinism`
- Worktree: `C:\Users\nerza\Projects\drawer-agent-worktrees\T01-DEEPSEEK`

## Goal
Investigate and, if the cause is inside the test harness/seam, fix the repeated direct-run hang where `test/narrow/settings-seam.ahk` sometimes does not exit within ~20 seconds and emits no diagnostic. Keep production behavior unchanged.

This is independent of A02S2/A03S1 and may start immediately.

## Scope
Primary scope:
- `test/narrow/settings-seam.ahk`
- narrowly related test helpers/scripts only if the root cause is there.

Production files under `src/` are **out of scope** unless the test uncovers a real production defect that can be demonstrated reproducibly. If that happens, do not fix production in this run: report `BLOCKED`/`NEEDS_PRODUCT_FIX` with evidence and stop.

## Required investigation
1. Reproduce the direct-run timeout from a clean worktree using the installed AutoHotkey runtime.
2. Determine whether the process is waiting on:
   - an active timer;
   - hidden GUI/window lifetime;
   - callback/event hook;
   - unclosed test fixture/state;
   - an assertion/error path that never exits;
   - child process or other harness resource.
3. Add the smallest deterministic teardown/exit mechanism that preserves all existing assertions and test intent.
4. Do not paper over the problem with an arbitrary external `taskkill`, unconditional short timeout, or by skipping assertions.
5. Re-run repeatedly enough to establish that the seam exits reliably, not just once.

## Acceptance
At minimum:
- `AutoHotkey64.exe /validate test\narrow\settings-seam.ahk` passes;
- direct `AutoHotkey64.exe test\narrow\settings-seam.ahk` exits by itself with exit 0;
- repeat direct run at least 5 times, all exit 0 without external kill;
- `test/narrow/window-focus-seam.ahk` still passes;
- `AutoHotkey64.exe /validate src\drawer.ahk` passes;
- `git diff --check` passes;
- `src/config.ini` untouched.

If the hang cannot be reproduced, do not invent a fix. Instead instrument minimally if useful, document exact commands/timings/environment, and return a factual `INCONCLUSIVE` report with no production changes.

## Git / output
Follow current `AGENT_BOARD.md`, claim protocol, `REPORT_FORMAT.md`, and Critical Git ref hygiene. One Run ID = one branch. Never create local `dev/...` refs. Do not edit `AGENT_BOARD.md` or `docs/ARCHITECT_STATE.md`.

If code/test changes are made, commit them first and record `Code SHA`; report-tip SHA is metadata only. Push explicitly to `dev` branch `refs/heads/test/settings-seam-determinism`, verify remote contains the Code SHA, clean tree, update claim to DONE/BLOCKED.

Report: `docs/agent-reports/2026-09-07-opencode-deepseek-t01-settings-seam.md`.
