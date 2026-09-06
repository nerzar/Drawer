# P05 — promote accepted G05FIX and clean obsolete G05 branches

- Run ID: `RUN-20260906-CODEX-P05-G05-PROMOTE-CLEANUP-01`
- Executor: Codex
- Model: economical/older coding model
- Accepted G05FIX Code SHA: `97962bdf8f821f4c42bc26df81856231fa04164c`
- Runtime acceptance: `verify/g05-runtime-acceptance`
- Shared target: `dev/wip/slots-parity`

## Goal
Promote accepted G05FIX production code into the shared branch and collapse G05 branch debt without losing accepted code or factual reports.

## Required
1. Fetch and verify current `dev/wip/slots-parity`; work from the designated integration checkout.
2. Promote canonical G05FIX Code SHA `97962bdf...` onto current shared tip, preserving already-promoted G03 and newer shared docs/tasks.
3. Preserve G05 analysis/review/fix/runtime-acceptance reports in shared history/tree as appropriate.
4. Run frontend tests/typecheck/build; AHK validate/settings seam as a safety gate because this is shared promotion, even though G05 itself is frontend-only.
5. Verify `src/config.ini` blob unchanged.
6. After verifying accepted code/report reachability, delete obsolete G05 refs if safe: `analysis/g05-slots-ux`, `review/g05-slots-ux`, `review/g05fix-slots-ux`, `verify/g05-runtime-acceptance`, `fix/slots-ux-terminology-layout`, `fix/slots-ux-state-truth`.
7. Also audit and remove only clearly empty/architect-created tmp/orchestration refs that have no unique work, including `orchestration/next-wave-assignments`, `orchestration/next-wave-assignments-2`, `tmp-do-not-use`, and any exact-empty siblings found by reachability check. Do not delete archives, active feature work, or branches with unique production/report history unless preserved first.
8. Report branch count before/after and list every deleted ref.

## Constraints
- Do not touch public `origin`.
- No force-push of shared branch.
- Do not modify product behavior beyond the accepted G05FIX promotion.
- One Run, one working branch/context; do not create extra scratch remote branches.

Report per REPORT_FORMAT with separate Code SHA and report tip SHA. Final answer: DONE/BLOCKED, shared Code SHA after promotion, checks, branch count before/after, deleted refs.