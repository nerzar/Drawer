# G06ACCEPT — live Windows/WebView acceptance

- Status: `READY`
- Eligible: `ANTIGRAVITY`
- Run ID: `RUN-20260906-AUTO-ANTIGRAVITY-G06ACCEPT-01`
- Base: G06 Code SHA `5e9c717f23ee4503c0850a9be5d406892d49bed9`
- Branch: `verify/g06-runtime-acceptance`
- Task file: `docs/agent-tasks/RUN-20260906-AUTO-ANTIGRAVITY-G06ACCEPT-01.md`
- Worktree: `C:\Users\nerza\Projects\drawer-agent-worktrees\G06ACCEPT`

## Goal
Perform focused live Windows/WebView2 acceptance of G06 without changing production code unless a blocker forces a separate architect decision.

Verify at least: selected slot persists across General/Slots/About; backend field error selects and reveals the correct slot; Sidebar labels/navigation/focus-visible; General labels and save-lock still work; Footer discard flow moves focus safely and status remains correct; picker buttons/hints are understandable; narrow/wide layout has no clipping or horizontal overflow; text contrast remains readable; slot list scrolls selected row into view without breaking independent list/detail scrolling; G05/G03 behavior remains intact in a smoke pass.

Run frontend tests/typecheck/build and AHK validate/settings seam if available. `src/config.ini` untouched. Use autonomous claim protocol. No self-promotion. Final verdict `ACCEPT`, `NEEDS_FIX`, or `BLOCKED`; report-only branch.