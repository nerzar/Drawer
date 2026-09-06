# TASK G03 — live hideOnBlur/blurMs + save lock

- Run ID: `RUN-20260906-ANTIGRAVITY-G03-01`
- Executor: Antigravity
- Model: Claude Sonnet 4.6 Thinking
- Base: `dev/fix/settings-partial-retry-diagnostics@389914e44fff78ccd6362cfbb9b43a8534ff9e54`
- Output branch: `dev/fix/settings-live-blur-save-lock`
- Worktree: `C:\Users\nerza\Projects\drawer-agent-worktrees\G03`

## Goal
Implement G03 on top of accepted C03 lineage, using the completed DEV-1 analysis as the investigation baseline.

Read first:
- `docs/agent-reports/2026-09-06-chatgpt-dev1-g03-analysis.md`
- `docs/agent-reports/2026-09-06-antigravity-c03.md`
- `AGENT_BOARD.md`
- `docs/agent-reports/REPORT_FORMAT.md`

## Required behavior
1. After Apply, changing `hideOnBlur` must affect already managed/shown windows immediately in both directions (`true→false` and `false→true`) without requiring Drawer restart or window rebind.
2. After Apply, changing `blurMs` must affect an already active blur watcher/timer; no stale old-delay timer may remain authoritative.
3. While Settings save/apply is in flight, General controls that participate in that save must not remain editable in a way that can be silently discarded by successful canonical adoption.
4. Preserve C03 semantics for partial/retryable/diagnostics and its single persistence path.
5. Do not broaden scope into unrelated slot identity, hotkeys, layout redesign, or modular-architecture work.

## Preferred scope
Start with the DEV-1 recommendation and keep changes minimal:
- `src/drawer.ahk`
- `settings-ui/src/views/GeneralView.vue`
- targeted seam/unit tests

Avoid touching `settings-ui/src/bridge/settings.ts` unless code inspection proves it is necessary. If it is necessary, explicitly explain why and preserve all C03 behavior.

## Runtime/reconcile expectations
- Trace where `hideOnBlur` is cached into watched/live window state and refresh that state on successful Apply/reconcile.
- For `blurMs`, explicitly ensure any currently running watch/timer is re-armed or otherwise made to use the new interval deterministically.
- Do not create a second persistence/save path.

## Verification
Required:
- targeted regression for live `hideOnBlur` both directions;
- targeted regression for `blurMs` stale-timer prevention/re-arm behavior;
- targeted frontend regression that General save-participating inputs/actions are locked while `settings.status === 'saving'` and become editable again afterward;
- `AutoHotkey64.exe /validate src/drawer.ahk`;
- `AutoHotkey64.exe test/narrow/settings-seam.ahk`;
- `npm --prefix settings-ui test`;
- `npm --prefix settings-ui run typecheck`;
- `npm --prefix settings-ui run build`.

Do a short real Windows runtime check if feasible in this environment for at least one already-managed window: change `hideOnBlur` and `blurMs` through Settings Apply and verify behavior without restart. If runtime check is infeasible, state that clearly; automated gates remain required.

## Parallelism constraints
Codex may concurrently perform I05 integration. Do not modify or promote `dev/wip/slots-parity` and do not merge I05. Work only in the G03 sibling worktree/branch from the exact C03 base above.

If you discover a semantic conflict with C03 or need to change its diagnostics/draft model, STOP with `BLOCKED` rather than improvising.

## Completion
Factual report per `REPORT_FORMAT.md` -> commit -> push `dev/fix/settings-live-blur-save-lock` -> verify remote HEAD = local HEAD -> clean tree.

Final response: Run ID, DONE/BLOCKED, branch, final SHA, tests, whether real runtime check was performed, and any overlap with C03.