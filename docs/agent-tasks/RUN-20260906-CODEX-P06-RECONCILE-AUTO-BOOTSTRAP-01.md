# P06 — reconcile shared lineage before autonomous workers

- Run ID: `RUN-20260906-CODEX-P06-RECONCILE-AUTO-BOOTSTRAP-01`
- Executor: Codex
- Model: economical/older coding model
- Current remote shared tip at assignment: `dev/wip/slots-parity@0f7902e7a022da90fc00041f838bcedfe624acc7`
- Accepted G05 promotion/history tip to reconcile: `68233f74d7f54687adfcceb0c9aa1fdfde4255a2`
- Output: update the actual `dev/wip/slots-parity`; do not create an extra integration branch unless technically required and then delete it before completion.

## Situation
P05 produced accepted G05/G05FIX promotion/history at `68233f74...`, and G06 was subsequently based on that lineage, but the remote `dev/wip/slots-parity` ref did not move to it. Architect then added the autonomous-worker board protocol as one docs-only commit `0f7902e...` on the old shared line. The two tips now diverge by exactly one board commit versus the accepted G05 lineage.

## Goal
Create one correct shared lineage that contains BOTH:
1. all accepted production/test/report history represented by `68233f74...` (G03 + accepted G05/G05FIX and reports/history), and
2. the current autonomous-worker `AGENT_BOARD.md` from `0f7902e...`.

Then push that reconciled result to `dev/wip/slots-parity` and verify it is the actual remote shared tip.

## Required checks
- `git fetch dev` first; abort/re-evaluate if remote shared tip changed unexpectedly.
- Prove current relation using merge-base/log before changing refs.
- Merge/reconcile without dropping either tree. No force-push unless absolutely unavoidable; expected solution is a normal merge/replay because the divergence is known and small.
- Preserve `src/config.ini` exactly.
- Verify resulting shared production includes canonical G05FIX behavior from Code SHA `97962bdf8f821f4c42bc26df81856231fa04164c` and accepted G03 production already present in the 682 lineage.
- Preserve the autonomous-worker protocol text currently in `AGENT_BOARD.md`.
- Run `npm --prefix settings-ui test`, typecheck, build; AHK validate/settings seam if shared production changes include AHK relative to current checkout or if cheap to run.
- Verify remote `dev/wip/slots-parity` equals local final SHA and clean tree.

## Branch cleanup
After shared ref is safely reconciled, perform a conservative cleanup pass ONLY for clearly obsolete non-archive refs whose unique work is already reachable from the reconciled shared history. Do not delete `archive/*`. Do not delete active G06 or A02 branches. Explicitly remove known architect-created junk if still present and unique-work-free: `orchestration/next-wave-assignments`, `orchestration/next-wave-assignments-2`, `tmp-do-not-use`. For old `integration/slots-settings-wave1..5` and completed G05 analysis/review/fix/verify refs, delete only after proving their unique accepted/report history remains reachable from the reconciled shared tip.

Report branch count before/after and list deleted refs.

## Completion
Write factual report `docs/agent-reports/2026-09-06-codex-p06-reconcile-auto-bootstrap.md` into the final shared tree, following REPORT_FORMAT and Code SHA/report-tip rules. Final response: Run ID, DONE/BLOCKED, final shared SHA, tests, branch count before/after, deleted refs, and confirmation that both 682 lineage + autonomous board protocol are present.
