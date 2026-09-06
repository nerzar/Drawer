# TASK P03 — recover missed Wave 5 promotion + remove orchestration dummy branches

- Run ID: `RUN-20260906-CODEX-P03-RECOVER-WAVE5-01`
- Executor: Codex
- Model: use an economical/older coding model; do not switch to a heavy model unless blocked
- Source/orchestration branch: `dev/wip/slots-parity`
- Accepted candidate: `dev/integration/slots-settings-wave5@9db6fdf27cddc56e528fcf1f3edc9c9ae67a3466`
- Local integration checkout: `C:\Users\nerza\Projects\drawer-settings-integration`

## Context
The Wave 4/5 production lineage was never promoted into the shared `dev/wip/slots-parity` after P02 became BLOCKED. This task was accidentally dropped from the active queue while later work continued. Recover it now before any further shared-base work.

The repository also has five architect-created temporary/dummy branches that must be removed if they still exist and contain no unique work:
- `orchestration/p02-task`
- `tmp-p02`
- `tmp-p02-task`
- `tmp-ignore`
- `tmp-final`

Do not delete any branch other than these five unless explicitly instructed by the architect.

## Goal
1. Safely promote accepted Wave 5 into shared `dev/wip/slots-parity`, preserving all newer orchestration/task/report commits already on wip.
2. Synchronize the local integration checkout to the resulting shared branch.
3. Delete the five listed dummy branches after verifying each has no unique work worth preserving.

## Required procedure
1. `git fetch dev --prune`.
2. Read current `AGENT_BOARD.md` and `docs/agent-reports/REPORT_FORMAT.md` from `dev/wip/slots-parity`.
3. Inspect `git worktree list`, local integration checkout branch/status, and exact refs.
4. If `C:\Users\nerza\Projects\drawer-settings-integration` has uncommitted or unpushed user/agent work, STOP `BLOCKED`; do not reset/clean/discard.
5. Compare current wip with accepted Wave 5 `9db6fdf27cddc56e528fcf1f3edc9c9ae67a3466`.
6. Promote Wave 5 using a safe merge strategy that preserves all architect/orchestration commits created on wip after Wave 5 branched. Do not integrate G03 or any other feature branch in this run.
7. Synchronize the local integration checkout to the resulting `dev/wip/slots-parity` safely.
8. For each of the five dummy branches, verify whether it has unique commits not reachable from wip. If it has no unique work, delete the remote and local branch if present. If any has unique work, do not delete it; report `BLOCKED` for cleanup with the exact commits.
9. Verify no nested worktree/repository was created, source `src/config.ini` remains untouched unless Wave 5 already contains an intentional tracked change, and no unrelated production files changed during promotion.

## Verification
Run:
- `AutoHotkey64.exe /validate src/drawer.ahk`
- `AutoHotkey64.exe test/narrow/settings-seam.ahk`
- `npm --prefix settings-ui test`
- `npm --prefix settings-ui run typecheck`
- `npm --prefix settings-ui run build`

Expected frontend count: at least 47. No VM/full suite.

## Completion
Create factual report per `REPORT_FORMAT.md`, commit/push required promotion/orchestration changes, verify remote HEAD, ensure integration checkout clean, and confirm status of all five dummy branches.

Final response must include:
- Run ID
- DONE/BLOCKED
- final `dev/wip/slots-parity` SHA
- observed Wave 5 SHA
- local integration checkout branch/SHA/cleanliness
- exact merge strategy
- test results
- status for each of the five dummy branches
- confirmation that no unrelated feature branch was integrated
