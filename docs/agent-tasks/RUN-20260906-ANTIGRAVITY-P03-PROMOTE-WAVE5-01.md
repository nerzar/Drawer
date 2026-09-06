# TASK P03 — recover missed promotion and move Wave 5 into shared wip

- Run ID: `RUN-20260906-ANTIGRAVITY-P03-PROMOTE-WAVE5-01`
- Executor: Antigravity
- Model: Claude Sonnet 4.6 Thinking (explicitly select this model; do not use Gemini for this run)
- Source/orchestration branch: `dev/wip/slots-parity`
- Accepted candidate: `dev/integration/slots-settings-wave5@9db6fdf27cddc56e528fcf1f3edc9c9ae67a3466`
- Local integration checkout: `C:\Users\nerza\Projects\drawer-settings-integration`

## Context
A previous promotion task (P02) was blocked in ChatGPT DEV-1 because that browser session could not inspect the operator's local Windows checkout. A retry task was created but then fell out of the active queue when later work was assigned. Meanwhile Wave 5 was created and contains Wave 4 + accepted C03. The shared `dev/wip/slots-parity` has therefore not received the accepted production-code lineage for several waves.

This task explicitly repairs that orchestration gap. Do not treat it as optional or superseded by G03.

## Goal
Safely promote accepted Wave 5 into the shared `dev/wip/slots-parity` and synchronize `C:\Users\nerza\Projects\drawer-settings-integration` to the promoted shared branch, preserving orchestration/task/report commits that exist only on current wip.

## Required procedure
1. `git fetch dev`.
2. Read current `AGENT_BOARD.md` and `docs/agent-reports/REPORT_FORMAT.md` from `dev/wip/slots-parity`.
3. Inspect `git worktree list`, local integration checkout branch/status, and exact remote refs.
4. If the local integration checkout has uncommitted/unpushed user or agent work, STOP `BLOCKED`; do not reset/clean/discard.
5. Compare current `dev/wip/slots-parity` with accepted Wave 5 `9db6fdf27cddc56e528fcf1f3edc9c9ae67a3466`.
6. Promote Wave 5 into wip using a safe merge strategy that preserves all newer orchestration docs/reports/tasks on wip. Do not drop the DEV-1 blocked P02 report, G03 analysis/task docs, or any later architect-owned docs.
7. Do not integrate G03 implementation in this run, even if its branch exists. Do not integrate any unrelated feature branch.
8. Synchronize `C:\Users\nerza\Projects\drawer-settings-integration` to the resulting promoted `wip/slots-parity` safely.
9. Verify shared wip working-code tree contains Wave 5 behavior and no accidental extra production changes.

## Verification
Run lightweight promotion gates:
- `AutoHotkey64.exe /validate src/drawer.ahk`
- `AutoHotkey64.exe test/narrow/settings-seam.ahk`
- `npm --prefix settings-ui test`
- `npm --prefix settings-ui run typecheck`
- `npm --prefix settings-ui run build`

Expected frontend count is at least 47 tests (Wave 5 / C03 lineage). No VM/full suite. No visual redesign.

## Completion
Create factual report per `REPORT_FORMAT.md`, commit/push promotion/orchestration changes, verify remote HEADs, and leave the local integration checkout clean.

Final response must include:
- Run ID
- DONE/BLOCKED
- final `dev/wip/slots-parity` SHA
- observed Wave 5 SHA
- local integration checkout branch/SHA/cleanliness
- test results
- exact merge strategy used
- any unexpected divergence/conflict
