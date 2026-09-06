# P08 — promote accepted A02S1 into shared lineage

- Run ID: `RUN-20260906-AUTO-ANTIGRAVITY-P08-A02S1-PROMOTE-01`
- Eligible: `ANTIGRAVITY`
- Preferred model: `Gemini 3.8 Flash`
- Session: `REUSE_OK`
- Accepted A02S1 Code SHA: `ac71581b98a58e51128a987d20d8b5b1952c1756`
- Current shared production ancestor: `886e68663a0f487f3ad00c248a4aed87e02861c7`
- Output: authorized shared promotion to `refs/heads/wip/slots-parity`

## Goal
Promote A02S1 now that independent DEV1 review returned `ACCEPT_WITH_RUNTIME_CHECK` and Antigravity live acceptance returned `ACCEPT` (9/9 seam + 7/7 acceptance + validates).

## Requirements
- Fresh fetch; obey Critical Git ref hygiene.
- Verify both accepted A02S1 and current shared production ancestry/content before merging.
- Use normal merge/cherry-pick only as appropriate; no force-push, no production rewriting beyond integrating accepted A02S1.
- Preserve G06/shared production, `src/config.ini`, board/task/claim docs.
- Run targeted AHK validate + window-focus seam. Run broader checks only if merge resolution touches relevant files.
- Do not delete refs unless reachability and worktree safety are proven; cleanup is secondary to safe promotion.
- Report shared Code SHA after promotion; update claim DONE.
