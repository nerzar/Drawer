# TASK P02 — promote accepted Wave 4 into wip/slots-parity

- Run ID: `RUN-20260906-CHATGPT-DEV1-P02-01`
- Executor: ChatGPT DEV-1
- Model: GPT-5.6 Sol
- Base/orchestration branch: `dev/wip/slots-parity`
- Accepted candidate: `dev/integration/slots-settings-wave4@e4136c5`
- Candidate code/report parent: `8555c82`
- Local integration checkout: `C:\Users\nerza\Projects\drawer-settings-integration`

## Goal
Safely promote architect-reviewed Wave 4 into `dev/wip/slots-parity` and synchronize the local integration checkout, without pulling in unrelated feature branches or losing any local work.

## Architect review facts
- Wave 4 is based on current wip lineage and is 6 commits ahead with no behind/divergence at review time.
- It integrates accepted A01FIX and reviewed G02.
- Conflicts in `SlotsView.vue` and `canonical.test.ts` were resolved semantically in I04.
- Automated gates reported green: AHK validate, settings-seam groups 1–20, frontend 42/42, typecheck, build.
- Known non-blocking visual debt remains around `Использовать общие настройки` on narrow layouts; do not redesign it in P02.

## Required procedure
1. `git fetch dev`.
2. Read current `AGENT_BOARD.md` and `docs/agent-reports/REPORT_FORMAT.md` from `dev/wip/slots-parity`.
3. Inspect `git worktree list`, local integration checkout branch/status, and remote refs before changing anything.
4. If `C:\Users\nerza\Projects\drawer-settings-integration` contains uncommitted/unpushed user or agent work, STOP with `BLOCKED`; do not reset/clean/discard it.
5. Promote accepted candidate `dev/integration/slots-settings-wave4@e4136c5` into `dev/wip/slots-parity` using a safe merge strategy that preserves current orchestration/task documents added after the candidate branched.
6. Do not integrate any other branch (C03/G03/etc.). Do not change product/runtime/frontend semantics in this task.
7. Synchronize local integration checkout to the promoted `dev/wip/slots-parity` safely.
8. Verify the promoted working-code tree contains Wave 4 behavior and no accidental extra feature diff.

## Verification
Run lightweight promotion gates only:
- `AutoHotkey64.exe /validate src/drawer.ahk`
- `AutoHotkey64.exe test/narrow/settings-seam.ahk`
- `npm --prefix settings-ui test`
- `npm --prefix settings-ui run typecheck`
- `npm --prefix settings-ui run build`

Expected frontend count is at least 42 tests. No VM/full suite. Do not do visual redesign.

## Completion
Create factual report per `REPORT_FORMAT.md`, commit/push required promotion/orchestration changes, verify remote HEADs and clean tree.

Final response must include:
- Run ID
- DONE/BLOCKED
- final `dev/wip/slots-parity` SHA
- `dev/integration/slots-settings-wave4` SHA observed
- local integration checkout branch/SHA
- test results
- any conflict or unexpected divergence found
