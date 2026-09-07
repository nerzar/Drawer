# A02S2 FIX — focus/history extraction promotion blockers

- Run ID: `RUN-20260907-OPENCODE-CLAUDE48-A02S2-FIX-01`
- Eligible: `OPENCODE-CLAUDE48`
- Required model: Claude 4.8 exposed by OpenCode; record exact model ID in claim/report
- Session: `NEW`
- Base: `c482ad3ae9c499ea32eb3c0cdd590e495a919e30` (reviewed broken A02S2 Code SHA)
- Review evidence: `review/a02s2-claude5`, `docs/agent-reports/2026-09-07-opencode-claude5-a02s2-review.md`
- Branch: `fix/a02s2-focus-history-blockers`
- Worktree: `C:\Users\nerza\Projects\drawer-agent-worktrees\A02S2FIX-CLAUDE48`

## Goal
Make A02S2 promotable with the smallest behavior-preserving fix. Fix the two Claude Opus 5 promotion blockers and add production-direct regression coverage sufficient to prevent recurrence. Do not expand into A03/A04 or redesign the extraction.

## Required fixes
1. F1 duplicate declarations: remove the duplicate focus functions from `src/drawer.ahk` so `#Include WindowFocus.ahk` yields one definition per function and `src/drawer.ahk` validates/loads. Preserve useful rationale comments in the surviving production module where appropriate; do not keep dead duplicate code for static tests.
2. F2/P17 focus restore regression: ensure hiding a deployed window does not erase its previous-focus history before `RestoreFocus()` consumes it. Preserve the distinction between watcher-only removal and full focus-history forgetting. `Release()` may fully forget; `Hide()`/blur-hide must preserve the previous-focus value long enough for restoration. Preserve Settings/service-window return behavior.

## Tests
Replace or minimally repoint the static assertions that forced duplicate source code. Add direct execution coverage against production `WindowFocus.ahk`/production seam for at least:
- drawer source validates with the module included (gate, not source-text mimicry);
- previous-focus survives the hide/forget ordering until restore and is then cleaned at the correct lifecycle point;
- positive `FocusCandidate` / service-window previous-focus restore path where practical in the narrow harness;
- foreground dedup test must actually reach the dedup branch rather than pass because the HWND is untracked/nonexistent.
Do not broadly rewrite the test framework.

## Scope
Expected: `src/drawer.ahk`, `src/WindowFocus.ahk`, `test/narrow/window-focus-seam.ahk`, and only directly necessary assertions in `test/narrow/settings-seam.ahk`. `src/config.ini` untouched. No geometry/handles/Settings persistence/product UX changes.

## Gates
Run x64 `/Validate src/drawer.ahk` at minimum (x86 too if available), targeted `window-focus-seam`, affected `settings-seam` with a bounded timeout/diagnostic wrapper if needed, and any cheap directly affected gate. Report exact commands/results. A green narrow test is not sufficient if `/Validate` fails.

## Git / report
Follow current shared `AGENT_BOARD.md`, claim protocol, Critical Git ref hygiene and `REPORT_FORMAT.md`. One Run ID = one branch. Production/test commit first; record its Code SHA separately from report-tip SHA. Push explicitly to `dev` `refs/heads/fix/a02s2-focus-history-blockers`, verify remote contains Code SHA, clean tree, claim DONE/BLOCKED. Report: `docs/agent-reports/2026-09-07-opencode-claude48-a02s2-fix.md`. Do not self-promote.