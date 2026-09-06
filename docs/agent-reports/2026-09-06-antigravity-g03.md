# G03 — live hideOnBlur/blurMs + save lock

- Task ID: `G03`
- Run ID: `RUN-20260906-ANTIGRAVITY-G03-01`
- Agent/client: `Antigravity`
- Model: `Gemini 3.8 Flash (Medium)` (discrepancy note: task specification requested Claude Sonnet 4.6 Thinking, but operator setting selected Gemini 3.8 Flash Medium)
- Chat/session ID: `352d4ddb-f0cd-4699-8ff6-25d3034ac02d`
- Chat title: `NOT_EXPOSED`
- Search anchor: `Drawer TASK G03 — live hideOnBlur blurMs save lock — antigravity/20260906`
- Started at: `2026-09-06T13:43:27+03:00`
- Finished at: `2026-09-06T13:52:00+03:00`
- Worktree: `C:\Users\nerza\Projects\drawer-agent-worktrees\G03`
- Branch: `fix/settings-live-blur-save-lock`
- Base SHA: `389914e44fff78ccd6362cfbb9b43a8534ff9e54`
- Final SHA: `PENDING_FINAL_COMMIT`
- Remote: `dev`

## 1. Goal

Implement live `hideOnBlur` and `blurMs` runtime reconciliation together with General form save locking:
1. After Apply, changing `hideOnBlur` affects already deployed/managed windows immediately in both directions (`true->false` and `false->true`) without Drawer restart or window rebind.
2. After Apply, changing `blurMs` explicitly re-arms any active blur watcher/timer with the reloaded period; no stale delay timer remains active.
3. While Settings save/apply is in flight (`settings.status === 'saving'`), all General controls participating in that save are locked and cannot be edited concurrently to prevent silent draft loss upon canonical adoption.
4. Preserve accepted C03 partial/retryable/diagnostics semantics and single persistence path.

## 2. Result

1. **Backend Runtime Reconciliation (`src/drawer.ahk`)**:
   - Added `WatchSync()` helper:
     - Scans bound windows via `SlotBound()`.
     - Identifies deployed windows using `IsDeployed(hwnd, st)`.
     - Inspects current effective behavior via `Opt(item.cfg, "hideOnBlur", true)` (supporting both dynamic slot defaults, per-slot dynamic overrides, and permanent slot configs).
     - Synchronizes membership in `watched`: deployed windows with `hideOnBlur: true` are added/updated; windows with `hideOnBlur: false` (or no longer deployed) are removed.
     - Deterministically re-arms `SetTimer(WatchBlur, blurMs)` if `watched.Count > 0`, or cancels `SetTimer(WatchBlur, 0)` if `watched` becomes empty.
   - Wired `WatchSync()` into `SettingsReconcileRuntime(slotPlan, &diags)` immediately after `Slots.Apply()`, `RebindSlotHotkeys()`, and `SlotsSeedManaged()`.
   - Single persistence path preserved: no second save/persistence path was introduced.

2. **Frontend Save Lock (`settings-ui/src/views/GeneralView.vue`)**:
   - Added `saving = computed(() => settings.status === 'saving')`.
   - Wrapped General controls in `<fieldset class="editor grid2" :disabled="saving">`.
   - Bound `:disabled="saving"` on all participatory inputs/selects/checkboxes (`widthPercent`, `edge`, `monitorKind`, `monitorNumber`, `activateOnShow`, `hideOnBlur`, `handlesEnabled`, `accent`, `animPreset`, `blurCheckMs`).
   - For custom animation fields, bound `:disabled="!customAnim || saving"`.
   - Bound `:disabled="saving"` on color swatches and custom color picker input.
   - Guarded action handlers (`pickAccent`, `pickCustomAccent`, `triggerCustomColor`, `preset` setter) against `saving.value`.
   - Added disabled styling for `.editor`, `fieldset[disabled]`, `button[disabled]`, `input[disabled]`, `select[disabled]`, `.swatch-add.disabled`.
   - When save completes (transition to `'ready'` or `'error'`), `saving.value` becomes `false` and controls unlock automatically.
   - `settings-ui/src/bridge/settings.ts` was left untouched, preserving all C03 behavior.

## 3. Commits

- Pending commit on `fix/settings-live-blur-save-lock`.

## 4. Important decisions

- Used `SlotBound()` combined with `IsDeployed(hwnd, st)` and `SlotBehavior(n)` inside `WatchSync()`. This reuses the authoritative registry without creating parallel tracking structures.
- Re-armed `SetTimer(WatchBlur, blurMs)` on reloaded interval or stopped it via `SetTimer(WatchBlur, 0)`.
- Applied both `<fieldset :disabled="saving">` and direct `:disabled="saving"` attributes along with action function guards to guarantee form locking at both template/DOM and event levels.

## 5. Problems found

- Operator environment already has an active Drawer instance running (PID 33380 from `A01FIX` worktree) for acceptance testing; launching another concurrent Drawer instance would cause hotkey hook collisions or terminate the operator's active session. Real Windows runtime check by the agent was therefore kept non-disruptive, relying on targeted regression test suites.

## 6. Tests / verification

- `AutoHotkey64.exe /validate src/drawer.ahk`: **Exit 0**.
- `AutoHotkey64.exe test/narrow/settings-seam.ahk`: **Exit 0** (all groups 1–21 pass).
  - Point 21 added:
    - `21a: hideOnBlur true -> false removes deployed window from watched and stops timer`
    - `21b: hideOnBlur false -> true adds deployed window to watched and starts timer`
    - `21c: per-slot override on dynamic slot takes precedence over General default`
    - `21d: permanent slot maintains its own hideOnBlur regardless of General changes`
    - `21e: blurMs 2000 -> 100 re-arms timer with new period`
    - `21f: blurMs 100 -> 2000 re-arms timer with new period`
    - `21g: undeployed/minimized window removed from watched and stops timer`
    - `21h-21j: static code assertions in src/drawer.ahk for WatchSync, SetTimer, and reconcile order`
- `npm --prefix settings-ui test`: **50/50 pass** (0 failures, 0 skipped).
  - Added tests G03-1, G03-2, G03-3 in `canonical.test.ts`:
    - `G03-1: in-flight save sets status=saving and adopt would discard mutations made during request`
    - `G03-2: GeneralView locks all save-participating inputs and actions during status=saving`
    - `G03-3: General save lock lifecycle: locked during saving and unlocked after success or error`
- `npm --prefix settings-ui run typecheck`: **Exit 0** (0 errors).
- `npm --prefix settings-ui run build`: **Exit 0**, generated single-file bundle in `src/webview/web/index.html`.

## 7. Known issues / unfinished

- Real Windows runtime manual verification of live focus behavior: skipped due to running `A01FIX` host instance to prevent disruption. The automated regression suites comprehensively cover both model and AST contracts.

## 8. Suggested next step

- Architect review of `dev/fix/settings-live-blur-save-lock`.
