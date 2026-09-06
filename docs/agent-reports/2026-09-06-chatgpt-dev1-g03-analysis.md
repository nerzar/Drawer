# G03A — repo-only design/test plan for live hideOnBlur/blurMs + save lock

- Task ID: `G03A`
- Run ID: `RUN-20260906-CHATGPT-DEV1-G03-ANALYSIS-01`
- Agent/client: `ChatGPT browser/GitHub-native`
- Model: `GPT-5.6 Sol`
- Chat/session ID: `NOT_EXPOSED`
- Chat title: `NOT_EXPOSED`
- Search anchor: `Drawer G03A live hideOnBlur blurMs save lock — ChatGPT DEV1 — 20260906`
- Started at: `2026-09-06T13:34:00+03:00` (first client-local timestamp available during this run)
- Finished at: `2026-09-06T13:34:00+03:00` (repo analysis completed in the same GitHub-native session window)
- Worktree: `N/A — GitHub-native repo-only run; local worktree requirements waived by task`
- Branch: `analysis/g03-live-settings`
- Base SHA: `ff5671dcf5af1f0364b0720129c2984f53a9e8ac` (`dev/wip/slots-parity` at branch creation)
- Analyzed production candidate: `e4136c577d52e2fbf0b57d65b8344809236d5985` (`dev/integration/slots-settings-wave4`)
- Final SHA: `PENDING_FINAL_COMMIT`
- Remote: `dev`

## 1. Goal

Prepare implementation task G03 without changing production code. The investigation covers:

1. live application of General `hideOnBlur` to windows already managed/deployed;
2. live application of General `blurCheckMs` / AHK `blurMs` without retaining an old active timer period;
3. preventing edits to General controls while Apply/OK is in flight, so post-click edits cannot be discarded by the successful save response.

The accepted production code inspected is Wave 4 at `e4136c5`.

## 2. Result

Recommendation: **`READY_TO_IMPLEMENT`**.

No product-level ambiguity blocks the implementation. The current save/reconcile architecture already has the right single persistence path; the missing pieces are a runtime blur-watch reconciliation step after config reload and a frontend General-form lock while `settings.status === 'saving'`.

The production fix should be based on the accepted Wave 4 lineage, but because C03 is simultaneously changing Settings save/result/reconcile correctness from the same Wave 4 base, G03 implementation should preferably start after C03 is reviewed/accepted (or rebase onto its accepted result) instead of independently editing the same save/reconcile seam and then resolving avoidable conflicts.

## 3. Commits

This run creates only this analysis report on `dev/analysis/g03-live-settings`. No runtime/frontend source file is changed.

## 4. Important decisions

### 4.1 Current General -> wire -> backend -> runtime path

**Frontend draft**

- `settings-ui/src/views/GeneralView.vue`
  - `d` is `settings.draft`.
  - `hideOnBlur` is edited directly with `v-model="d.hideOnBlur"`.
  - the UI label “Проверка потери фокуса (мс)” edits `d.blurCheckMs`.
  - the view does not inspect `settings.status` and has no saving lock on its inputs/selects/swatches/actions.

- `settings-ui/src/bridge/general.ts`
  - `draftFromState()` seeds the General draft from canonical AHK state.
  - `draftToWire()` maps:
    - `d.hideOnBlur` -> `general.dynamicDefaults.hideOnBlur`;
    - `d.blurCheckMs` -> `general.blurCheckMs`.

**Frontend save**

- `settings-ui/src/bridge/settings.ts::save()`:
  1. sets `settings.status = 'saving'`;
  2. sends `settings.apply` or `settings.ok` with `{ draft: buildDraft() }`;
  3. `buildDraft()` serializes General via `draftToWire()` and Slots via `slotEditsToWire()`;
  4. on successful response, `adopt(result.state)` replaces canonical and rebuilds both General and slot drafts from returned canonical state.

**JSON bridge / port**

- `src/webview/SettingsJsonBridge.ahk::HandleRequest()` dispatches `settings.apply` to `DrawerSettingsPort.Apply()` and `settings.ok` to `.Ok()`.
- `src/webview/SettingsPort.ahk::_Save()`:
  1. parses wire General through `_GeneralInput()`;
  2. calls `SettingsGeneralPlan()`;
  3. calls `SettingsSlotsPlan()`;
  4. sends both to the single existing `SettingsApplyPlan()` persistence/reconcile seam;
  5. returns `_SaveOutcome()` with canonical `state` after successful runtime reload/no-op.

**Persistence and live reconciliation**

- `src/drawer.ahk::SettingsGeneralPlan()` writes General dynamic defaults including `[dynamic] hideOnBlur` and writes `[general] blurMs`.
- `src/drawer.ahk::SettingsApplyPlan()` is the shared persistence path.
- after persisted changes, `src/drawer.ahk::SettingsReconcileRuntime()` does:
  1. `LoadConfig(configPath, &diags)`;
  2. `ConfigApply(cfg)`;
  3. `Slots.Apply(cfg, slotPlan.prevPerm)`;
  4. `RebindSlotHotkeys()`;
  5. `SlotsSeedManaged()`;
  6. schedules `HandlesSync`.

`ConfigApply(cfg)` updates global AHK `blurMs`. `Slots.Apply()` replaces `Slots.defaults`, permanent config and per-dynamic-slot overrides from the reloaded config. Therefore **new queries** through `SlotCfg()` / `SlotBehavior()` see the new effective `hideOnBlur` immediately after reconciliation.

### 4.2 Proven live `hideOnBlur` defect

Relevant runtime structures/functions in `src/drawer.ahk`:

- `watched := Map()` is the membership set for deployed windows currently participating in blur auto-hide.
- `Watch(hwnd, cfg)`:
  - returns immediately when `cfg.hideOnBlur` is false;
  - otherwise inserts `watched[hwnd] := cfg`;
  - calls `SetTimer(WatchBlur, blurMs)`.
- `WatchBlur()` iterates `watched`; it does **not** re-read the current slot config or current `hideOnBlur`. Membership in `watched` is what makes a deployed window eligible to auto-hide.
- `Hide()` and `Release()` remove a window from `watched`.
- `SettingsReconcileRuntime()` does not call `Watch()`, does not remove/rebuild `watched`, and does not otherwise reconcile this membership after `Slots.Apply()` replaces effective slot settings.

This proves two stale-state directions for an already deployed dynamic window that inherits General `hideOnBlur`:

1. **true -> false:** the window was already inserted in `watched`; Apply changes effective slot config, but its existing `watched` membership survives, so a later `WatchBlur()` can still hide it.
2. **false -> true:** the window was never inserted in `watched`; Apply changes effective slot config, but no code adds the already deployed window, so it does not start auto-hiding until a later show/focus path invokes `Watch()`.

Important detail: `watched[hwnd]` stores the old `cfg`, but current `WatchBlur()` does not inspect that value. The real stale state is primarily **membership**, not a later read of stale `cfg` fields.

`src/Slots.ahk::SlotBound()` already returns `{ n, hwnd, cfg: SlotBehavior(n) }` for live bound/captured windows. That is the existing smallest registry-level seam for discovering each live window together with its **current** effective behavior after `Slots.Apply()`; no new slot registry is needed.

### 4.3 Proven `blurMs` timer-refresh gap

`blurCheckMs` on the wire becomes AHK `blurMs` through `LoadConfig()` / `ConfigApply()`.

The active blur timer is scheduled by `Watch()` with:

`SetTimer(WatchBlur, blurMs)`

and is stopped by `WatchBlur()` when `watched` becomes empty:

`SetTimer(WatchBlur, 0)`.

In the inspected Wave 4 code there is no timer reschedule in `ConfigApply()` or `SettingsReconcileRuntime()`. Therefore changing only the global variable `blurMs` during Apply does not explicitly reconfigure an already running `WatchBlur` timer. The production code contains no path that intentionally applies the new interval to an already active watcher until `Watch()` is invoked again.

The setting is a periodic polling interval, not a per-window one-shot debounce. G03 should therefore make runtime reconciliation explicitly re-arm `WatchBlur` with the newly loaded `blurMs` when watched windows remain, or stop it when none remain.

Exact Windows/AHK tick timing and scheduling jitter must still be verified on real runtime; repo inspection proves the missing explicit reschedule, not millisecond-level observed timing.

### 4.4 Proven General edit-during-save loss window

`settings-ui/src/components/FooterBar.vue` computes `busy` from `settings.status === 'loading' || settings.status === 'saving'` and disables only the footer Cancel/Apply/OK buttons while busy.

`GeneralView.vue` has no equivalent lock. Its text inputs, selects, checkboxes, palette buttons, color input and preset actions remain editable while `settings.status === 'saving'` (apart from the unrelated custom-animation disabled state).

The save payload is built synchronously at request start by `buildDraft()`. Edits made **after** that snapshot while the request is awaiting AHK are not in that request. On full success `settings.ts::save()` calls `adopt(result.state)`, which recreates the General draft from returned canonical state. Consequently a General edit made during the in-flight request can be silently discarded by the successful response.

This is a frontend concurrency/UI-lock problem; it does not require a second save path or backend contract change.

### 4.5 Minimal proposed production scope

Preferred smallest G03 implementation:

1. **`src/drawer.ahk`**
   - add one focused helper near `Watch()/WatchBlur()` that reconciles blur-watch runtime state after config reload;
   - invoke it from `SettingsReconcileRuntime()` after `Slots.Apply(...)` and preferably after `SlotsSeedManaged()` so registry/window state is final for the save reconciliation;
   - use existing `SlotBound()` / `SlotBehavior()` rather than introducing another slot map;
   - for each live bound window, gate on the existing window state (`state.Has(hwnd)`, alive, deployed) and current effective `hideOnBlur` before making it watched;
   - remove stale watcher membership when current effective behavior no longer opts in;
   - explicitly call `SetTimer(WatchBlur, blurMs)` when the final watch set is non-empty, otherwise `SetTimer(WatchBlur, 0)`.

   The implementation agent must preserve the existing `Show()`/`FocusWindow()` intent: blur auto-hide only acts on Drawer-managed/deployed windows. It must not turn `WatchBlur` into a global foreground-window monitor.

2. **`settings-ui/src/views/GeneralView.vue`**
   - disable the General editing surface while `settings.status === 'saving'`.
   - Prefer keeping this local to GeneralView (for example a disabled `fieldset` around the editing grid with layout-reset CSS, or equivalent disabled bindings) rather than adding a new save-state abstraction in `settings.ts`.
   - This avoids unnecessary collision with C03, which owns save/result/reconcile/diagnostics logic.

3. **`test/narrow/settings-seam.ahk`**
   - extend the existing source/seam checks around `SettingsReconcileRuntime()` with assertions that the new blur-runtime reconciliation occurs after config/slot projection and that the active timer is explicitly re-armed/stopped from current `blurMs`/final watcher state;
   - add a small pure model if useful for the true->false / false->true membership cases, following the existing seam-test pattern of model + production-source structural assertion.

4. **Frontend regression coverage**
   - Current `settings-ui/package.json` test stack is pure Node/esbuild; it has no DOM/component test harness (`@vue/test-utils`, jsdom, etc.). Do **not** add a large component-test stack solely for this lock.
   - If an automated lock regression is required, prefer a very small source/static assertion or a minimal pure predicate only if it naturally belongs in production. Otherwise verify the lock manually in WebView plus existing typecheck/build gates.

Likely **not needed** for G03 if the above is sufficient:

- `src/Slots.ahk` (because `SlotBound()` and `SlotBehavior()` already expose the needed current effective config);
- `src/webview/SettingsPort.ahk` / `SettingsJsonBridge.ahk` (wire/save path already carries and reloads both settings correctly);
- `settings-ui/src/bridge/settings.ts` (saving state already exists; local GeneralView can consume it directly);
- `settings-ui/src/bridge/general.ts` (mapping is already correct).

## 5. Problems found

### Root-cause hypotheses ranked by confidence

#### A. `hideOnBlur` live mismatch — **PROVEN / very high confidence**

Fact: effective slot config is replaced by `Slots.Apply()`, while `watched` is neither rebuilt nor re-evaluated. `WatchBlur()` uses watcher membership and does not query current slot behavior. This directly explains both stale true->false and false->true behavior for already deployed windows.

#### B. stale `blurMs` timer period — **PROVEN code gap / high confidence**

Fact: `ConfigApply()` updates the global `blurMs`; the active `WatchBlur` timer is only explicitly scheduled with a period in `Watch()`. Runtime reconciliation does not call `SetTimer(WatchBlur, newPeriod)`. Therefore the new interval is not intentionally applied to an already active timer during Save reconciliation.

Runtime verification is still required for exact observed first-tick timing because timer scheduling is runtime behavior.

#### C. in-flight General edit can be lost — **PROVEN / very high confidence**

Fact: FooterBar disables only footer buttons; General controls remain bound to the mutable draft while `status === 'saving'`. Save snapshots the draft before awaiting the response; successful `adopt(result.state)` rebuilds the draft and discards edits made after the snapshot.

### Scope caution discovered

The same general pattern (body controls editable while save is in flight) may exist outside General, but this Run ID is explicitly about **General settings inputs**. G03 implementation should not silently expand into a whole-Settings interaction redesign unless the architect assigns that scope.

## 6. Tests / verification

No local AHK/npm/runtime execution was performed or expected: this Run ID explicitly requires GitHub/repository reads only.

### Regression-test matrix for implementation G03

| Case | Expected result | Best automated coverage | Real Windows runtime required? |
|---|---|---|---|
| General inherited `hideOnBlur` true -> false while dynamic window is already deployed | window is removed from blur watcher immediately after successful Apply and does not auto-hide on subsequent unrelated focus | seam/model + static assertion that post-reconcile refresh removes non-opt-in membership | **Yes** for actual focus/hide behavior |
| General inherited `hideOnBlur` false -> true while dynamic window is already deployed | window becomes eligible for blur auto-hide without requiring hide/show/rebind | seam/model + static assertion that current `SlotBehavior()` is used | **Yes** |
| Dynamic slot has explicit per-slot `hideOnBlur` override; General changes opposite value | current effective override wins; watcher membership follows `SlotBehavior(n)`, not raw General | seam/model using effective cfg | Recommended runtime check |
| Permanent slot present while General `hideOnBlur` changes | permanent slot behavior is unchanged by General defaults | seam/model via `SlotBehavior()` | Recommended smoke check |
| `blurMs` 2000 -> 100 while watcher already active | active watcher is explicitly re-armed at new interval; next loss-of-focus reaction uses new cadence, not stale old cadence | static/seam assertion for `SetTimer(WatchBlur, blurMs)` in reconciliation helper | **Yes** for timing |
| `blurMs` 100 -> 2000 while watcher already active | old rapid cadence does not remain active | same as above | **Yes** |
| Apply leaves zero watched windows | `WatchBlur` timer is stopped | pure model/static seam | No for structural check; runtime smoke useful |
| Apply leaves one or more watched windows | timer remains/restarts with current `blurMs` | pure model/static seam | Runtime smoke useful |
| User clicks Apply and attempts to edit General while request pending | General editing controls/actions are disabled; no post-snapshot mutation is possible | current harness has no DOM runner; source/static check possible | **Yes/manual WebView** unless component harness is deliberately added |
| Save completes | General controls become editable again from canonical/adopted state | source/static + manual | Recommended manual |
| Save returns error/retryable result | lock is released when `settings.status` leaves `saving`; C03 remains owner of diagnostics/draft semantics | frontend status-path test after C03 or manual | Recommended manual after C03 |

### Existing tests relevant to G03

- `test/narrow/settings-seam.ahk` already validates `SettingsReconcileRuntime()` source ordering and `Slots.Apply()` behavior using the project's accepted “pure model + static production-source assertion” pattern. This is the natural backend regression location.
- Existing seam coverage mentions/validates `hideOnBlur` parsing and settings projection but currently has no test for `watched` reconciliation or active `blurMs` timer rescheduling.
- `settings-ui/test/canonical.test.ts`, `fieldError.test.ts`, and `animationPreset.test.ts` are bundled as pure Node tests. They do not mount Vue components, so they cannot currently prove that General controls are disabled during a delayed request.

### Manual runtime verification checklist for the implementation agent

1. Start from accepted integration base containing Wave 4 (+ accepted C03 if it has landed).
2. Bind/show a dynamic slot that inherits General settings.
3. With `hideOnBlur=true`, confirm normal blur auto-hide works before changing anything.
4. Show the window again, open Settings, change General `hideOnBlur` to false, Apply **without re-showing/rebinding the slot**; move focus to an unrelated app and confirm the already deployed window stays shown.
5. Set General `hideOnBlur` back to true, Apply while the same window remains managed/deployed; after leaving Settings/focusing another app confirm it now auto-hides without an intermediate hide/show/rebind.
6. Repeat with a `dynamicSlotN` explicit override to confirm General only changes slots that actually inherit the default.
7. Smoke a permanent slot to confirm General default changes do not rewrite its per-slot behavior.
8. Set blur interval high (for example ~2000 ms), establish an active watched/deployed window, then Apply a low value (for example ~100 ms) while it remains deployed; verify loss-of-focus uses the new fast cadence.
9. Reverse low -> high and verify the old fast cadence is not retained. Use broad timing tolerance; this is a polling timer, not a deterministic deadline.
10. While Apply/OK is actually in flight, verify all General editing controls/actions are disabled and cannot change the draft. Confirm they re-enable after success and after an error response.
11. Run required implementation gates: AHK validate (because `drawer.ahk` changes), `test/narrow/settings-seam.ahk`, `npm --prefix settings-ui test`, `npm --prefix settings-ui run typecheck`, `npm --prefix settings-ui run build`. No VM/full suite unless runtime investigation finds an additional reason.

## 7. Known issues / unfinished

### C03 overlap/conflict risk

C03 (`fix/settings-partial-retry-diagnostics`) starts from the same exact Wave 4 SHA and owns partial/retryable save/result/reconcile/diagnostics correctness.

Expected overlap:

- **High:** `src/drawer.ahk` around `SettingsApplyPlan()` / `SettingsReconcileRuntime()` and `test/narrow/settings-seam.ahk`.
- **Potential/high if G03 is implemented naively:** `settings-ui/src/bridge/settings.ts`, because C03 will likely change success/error/adopt/absorb/diagnostic behavior there.
- **Low if G03 follows this plan:** `settings-ui/src/views/GeneralView.vue`, because the saving lock can consume the already existing `settings.status` directly.

Recommendation to implementation agent: do not implement G03 independently on stale Wave 4 if C03 has produced an accepted result. Rebase/start from the accepted C03-integrated lineage, preserve C03's result semantics, then add only the blur-runtime resync and General lock.

### Runtime behavior not provable repo-only

Repository inspection cannot prove exact AutoHotkey timer scheduling latency, focus transitions, or Windows/WebView interaction timing. The runtime checklist above is mandatory for implementation acceptance.

## 8. Suggested next step

**`READY_TO_IMPLEMENT`**.

Assign a runtime-capable G03 implementation run after C03 review/integration. Keep the implementation narrow:

- reconcile `watched` + explicitly re-arm/stop `WatchBlur` after Settings runtime config reconciliation using existing current `SlotBehavior()` / `SlotBound()`;
- lock General controls while `settings.status === 'saving'` without creating a second save state or touching persistence contracts;
- add seam/model regression coverage and perform the real Windows focus/timer checklist.
