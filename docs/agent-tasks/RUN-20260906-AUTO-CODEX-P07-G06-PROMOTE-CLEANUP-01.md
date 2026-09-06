# P07 — promote accepted G06 and clean completed G06 refs

- Run ID: `RUN-20260906-AUTO-CODEX-P07-G06-PROMOTE-CLEANUP-01`
- Eligible: `CODEX`
- Session: `REUSE_OK`
- Accepted G06 Code SHA: `5e9c717f23ee4503c0850a9be5d406892d49bed9`
- Required evidence: G06 review claim verdict `ACCEPT_WITH_RUNTIME_CHECK` and G06 runtime acceptance verdict `ACCEPT`
- Shared target: `refs/heads/wip/slots-parity`
- Output: shared branch promotion + safe cleanup; no extra feature branch required unless needed temporarily for the authorized promotion

## Goal
Promote accepted G06 into the actual shared `wip/slots-parity` lineage, preserve all newer board/task/claim docs commits, verify ancestry and gates, then safely remove only completed G06 temporary refs proven reachable from the promoted shared history.

## Required steps
1. Fresh fetch; obey Critical Git ref hygiene and inspect `git worktree list --porcelain` before cleanup.
2. Verify both acceptance inputs exist and are non-blocking: DEV1 review of G06 and Antigravity live G06 acceptance.
3. Reconcile current shared docs/claim tip with G06 Code SHA using a normal merge/cherry-pick strategy that preserves both histories; no force-push and no production edits beyond the accepted G06 change.
4. Push explicitly to `HEAD:refs/heads/wip/slots-parity`.
5. Verify G03/G05 accepted production identities and G06 Code SHA are ancestors of the resulting shared Code SHA; `src/config.ini` must remain untouched.
6. Run `npm --prefix settings-ui test`, typecheck, build and `git diff --check`; AHK validate/settings seam if available without inventing environment changes.
7. Cleanup only completed G06 refs that are now fully reachable from shared history and not held by a live worktree. Use worktree porcelain + fully-qualified refs, not branch-name inference. Do not delete archive refs or active A02/A03 refs.
8. Factual report with shared Code SHA, report tip SHA, checks, branch count before/after, and exact deleted refs.

## Constraints
- Authorized shared-branch promotion/cleanup task.
- Do not touch AGENT_BOARD priorities/architecture.
- Do not create remote-name-prefixed local branches.
- If shared branch advances during work, refetch/reconcile; never force.
- If either G06 acceptance input is missing/non-accept, BLOCK.
