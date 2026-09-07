# Deferred Git branch/worktree cleanup

- Status: `WAITING_QUEUE`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-REF-CLEANUP-01`
- Eligible: `ANTIGRAVITY`
- Preferred model: `Gemini 3.8 Flash (Medium)`
- Session: `NEW`
- Base/source rule: operate only from a fresh fetch of current `refs/remotes/dev/wip/slots-parity`; this is repository-hygiene work, not production-code work.
- Branch: `maintenance/ref-cleanup-20260907`

## Goal
Reduce accumulated local/remote branch and worktree clutter without losing unique commits or deleting active/needed task refs.

## Required procedure
- Read current `AGENT_BOARD.md` and `REPORT_FORMAT.md`; claim this Run ID before any mutation.
- `git fetch dev --prune`.
- Inspect `git worktree list --porcelain` before touching any local branch/worktree refs.
- Inventory local branches, remote `dev` branches, stale worktree registrations, and merged/obsolete task/review branches.
- For every deletion candidate, record: exact ref, whether any worktree holds it, merge-base/ancestor relation to retained refs, and whether it contains unique commits.
- Never delete a branch with unique commits unless those commits are already reachable from another explicitly retained ref and that reachability is proven.
- Preserve `wip/slots-parity`, accepted production refs, all currently active/READY/WAITING task branches, and any branch still required for pending review/acceptance/promotion.
- Explicitly inspect remote `tmp/never`; delete it only if no worktree/local ref depends on it and it contains no unique required commit.
- Remove stale worktree registrations only after verifying the referenced worktree path is truly absent or safe to prune.
- Do not touch public `origin`.

## Output
Produce a report listing retained refs, deleted refs, reasons, unique-commit checks, worktree checks, and remaining cleanup debt. If any candidate is ambiguous, leave it intact and report it.

## Constraints
No production/test code changes. No acceptance/promotion. Do not force-delete refs merely to make the list shorter. Report to `docs/agent-reports/2026-09-07-antigravity-ref-cleanup.md`; update claim DONE/BLOCKED; push/verify report branch and shared claim.
