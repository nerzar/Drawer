# A02S2 FIX — independent verification before acceptance

- Status: `READY`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-A02S2FIX-VERIFY-01`
- Eligible: `ANTIGRAVITY`
- Preferred model: `Gemini 3.8 Flash (Medium)`
- Session: `NEW`
- Base SHA: `c482ad3ae9c499ea32eb3c0cdd590e495a919e30`
- Code SHA under verification: `313b3af8b6377b2b66e07256f985b1663c5630ee`
- Source branch: `fix/a02s2-focus-history-blockers`
- Branch: `verify/a02s2fix-antigravity`

## Goal
Independently verify the A02S2 FIX before architect acceptance. This is verification/report only; do not change production/test code and do not promote.

## Required checks
- Fresh fetch and verify exact Base -> Code lineage and changed-file scope.
- Confirm the five duplicate focus declarations are absent from `src/drawer.ahk` and have exactly one production definition through `src/WindowFocus.ahk`.
- Run bounded x64 and x86 `/Validate` for `src/drawer.ahk`, `src/WindowFocus.ahk`, and the relevant narrow seams; record exact exits.
- Independently verify the P17 lifecycle contract: `Hide()`/`WatchForget()` must preserve previous-focus history until `RestoreFocus()` consumes it; full forgetting must remain on release/lifecycle teardown.
- Run `test/narrow/window-focus-seam.ahk` directly and record exact assertion count/exit.
- Run the repaired deterministic `settings-seam.ahk` using T01 coverage if this can be done without modifying the FIX branch: verify compatibility against the FIX code or clearly report why an exact combined verification requires an integration candidate. Do not silently substitute another SHA.
- Confirm `src/config.ini` untouched and `git diff --check` clean.
- Separate blockers from non-blocking debt. Do not invent issues.

## Verdict
Return exactly one of: `ACCEPT_CANDIDATE`, `NEEDS_FIX`, `BLOCKED_VERIFY`.

## Constraints
Follow current AGENT_BOARD claim/ref-hygiene protocol and REPORT_FORMAT. Report to `docs/agent-reports/2026-09-07-antigravity-a02s2fix-verify.md`, update claim DONE/BLOCKED, push/verify report branch and shared claim. Do not self-fix, accept, promote, merge, or clean unrelated refs.
