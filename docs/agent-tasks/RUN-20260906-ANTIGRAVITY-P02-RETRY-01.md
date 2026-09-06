# TASK P02-RETRY — promote accepted Wave 4 after ChatGPT DEV-1 blocker

- Run ID: `RUN-20260906-ANTIGRAVITY-P02-RETRY-01`
- Executor: Antigravity
- Preferred model: Gemini 3.8 Flash High or Medium
- Current orchestration branch: `dev/wip/slots-parity@14216e539e39a1d79363cad8ede1ce996ae99dfb`
- Accepted candidate: `dev/integration/slots-settings-wave4@e4136c577d52e2fbf0b57d65b8344809236d5985`
- Required local checkout: `C:\Users\nerza\Projects\drawer-settings-integration`

## Context
Previous run `RUN-20260906-CHATGPT-DEV1-P02-01` correctly stopped BLOCKED because the browser ChatGPT GitHub session cannot inspect or synchronize the user's local checkout/worktrees. It only added a factual blocked report to `dev/wip/slots-parity`; no Wave 4 code was promoted.

C03 may be running concurrently in its own sibling worktree. Do not touch that worktree or its branch.

## Goal
Safely complete P02 using Antigravity's local filesystem/Git access: promote accepted Wave 4 into `dev/wip/slots-parity` while preserving orchestration/report-only commits added after Wave 4 branched, then synchronize `C:\Users\nerza\Projects\drawer-settings-integration`.

## Required procedure
1. `git fetch dev`.
2. Read current `AGENT_BOARD.md`, this task file, and `docs/agent-reports/REPORT_FORMAT.md` from `dev/wip/slots-parity`.
3. Inspect `git worktree list`, all relevant refs, and `git status` of `C:\Users\nerza\Projects\drawer-settings-integration` before changing anything.
4. If that checkout has uncommitted/unpushed work that could be lost, STOP/BLOCKED; do not reset/clean/discard.
5. Promote `dev/integration/slots-settings-wave4@e4136c5` into current `dev/wip/slots-parity@14216e5` with a safe merge strategy preserving current orchestration/task docs and the blocked P02 report.
6. Do not integrate C03 or any other feature branch.
7. Synchronize the local integration checkout to the promoted `dev/wip/slots-parity` safely.
8. Verify remote HEAD, local branch/SHA, clean tree, and that Wave 4 behavior is present without accidental extra feature diff.

## Verification
Run lightweight gates only:
- `AutoHotkey64.exe /validate src/drawer.ahk`
- `AutoHotkey64.exe test/narrow/settings-seam.ahk`
- `npm --prefix settings-ui test` (expect >=42)
- `npm --prefix settings-ui run typecheck`
- `npm --prefix settings-ui run build`

No VM/full suite. Do not redesign frontend visual debt.

## Completion
Create factual report per `REPORT_FORMAT.md`, commit/push required promotion/orchestration changes, verify remote HEAD and local checkout.

Final response: Run ID, DONE/BLOCKED, final `dev/wip/slots-parity` SHA, observed Wave 4 SHA, local integration checkout branch/SHA, tests, any conflict/divergence.
