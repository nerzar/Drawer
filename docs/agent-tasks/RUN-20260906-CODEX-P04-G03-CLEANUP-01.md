# P04 — promote accepted G03 and clean obsolete G03 branches

- Run ID: `RUN-20260906-CODEX-P04-G03-CLEANUP-01`
- Executor: Codex
- Model: economical/older coding model
- Accepted G03 Code SHA: `5a779c736fb562d11e1d617ce32adb1210743c1d`
- Runtime acceptance: `verify/g03-runtime-acceptance` report verdict ACCEPT, 30/30
- Shared branch: `dev/wip/slots-parity`

## Goal
Promote the accepted G03 code into the shared working branch and remove G03 orchestration debris without losing unique work.

## Required steps
1. `git fetch dev`; inspect current `dev/wip/slots-parity`, local integration checkout/worktrees, and all G03-related refs.
2. Verify accepted G03 Code SHA `5a779c7...` is based on the expected accepted C03 lineage and determine the safest fast-forward/merge/cherry-pick promotion path into current shared branch. Do not discard newer shared docs/tasks.
3. Promote G03 production code to `dev/wip/slots-parity`; shared branch must actually contain the G03 production diff afterward.
4. Synchronize the normal local integration/shared checkout if present and safe. Verify clean tree and matching remote/local SHA.
5. Re-run lightweight gates appropriate to promoted code: AHK validate, settings-seam, settings-ui tests/typecheck/build, git diff --check.
6. Verify `src/config.ini` remains clean/intact.
7. Inspect these G03 refs for unique production commits before deletion:
   - `analysis/g03-live-settings`
   - `review/g03-live-settings`
   - `verify/g03-runtime-acceptance`
   - `fix/settings-live-blur-save-lock`
   - `fix/settings-live-blur-watch-authority`
   Delete obsolete refs only after confirming accepted Code SHA/report history is preserved/reachable and no unique required production work would be lost.
8. Also inspect and delete the accidental empty orchestration refs created by architect tooling if they contain no unique work: `orchestration/post-g03-g05`, `tmp-unused-post-g03-g05`, `tmp-unused-post-g03-g05-2`.

Do not touch public origin. Do not edit unrelated production code. Factual report per REPORT_FORMAT, with Code SHA being the resulting shared production SHA/promotion identity and report tip separate.

Final answer: DONE/BLOCKED, resulting `dev/wip/slots-parity` SHA, checks, exact refs deleted/retained and why.