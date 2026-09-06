# G03R — independent review of live hideOnBlur/blurMs + General save lock

- Task ID: `G03R`
- Run ID: `RUN-20260906-CHATGPT-DEV1-G03-REVIEW-01`
- Agent/client: `ChatGPT browser/GitHub-native`
- Model: `GPT-5.6 Sol`
- Chat/session ID: `NOT_EXPOSED`
- Chat title: `NOT_EXPOSED`
- Search anchor: `Drawer G03R independent live settings review — ChatGPT DEV1 — 20260906`
- Started at: `2026-09-06T14:26:50+03:00` (task-assignment commit timestamp; first precise task-adjacent timestamp available)
- Finished at: `2026-09-06T14:27:00+03:00` (client-local timestamp supplied for this review turn)
- Worktree: `N/A — GitHub-native repo-only review; local worktree not required by task`
- Branch: `review/g03-live-settings`
- Base SHA: `c1e710345543c3eb7ff3cb2a9d3a6f13c57ff297` (`dev/wip/slots-parity` at review-branch creation)
- Code SHA: `be028a0b10af88040c79f7faa9bd04219288b256` (canonical G03 implementation reviewed)
- Report tip SHA: `PENDING_FINAL_COMMIT`
- Remote: `dev`

## 1. Goal

Independently review canonical G03 Code SHA `be028a0` against C03/base lineage `389914e44fff78ccd6362cfbb9b43a8534ff9e54`, without changing production code.

Review scope:

1. `WatchSync()` membership/timer correctness for live permanent/dynamic windows, deployed/undeployed state and stale entries.
2. Runtime reconcile ordering and side effects.
3. GeneralView save lock completeness and obvious interaction/accessibility regressions.
4. Preservation of accepted C03 partial/retryable/diagnostics semantics and the single persistence path.
5. Test quality and false-confidence gaps.
6. Diff scope.

## 2. Result

**Verdict: `NEEDS_FIX`.**

The implementation correctly addresses the straightforward single-slot `hideOnBlur true -> false`, `false -> true`, stale watcher cleanup, timer re-arm, and General in-flight-edit problem. C03 save/diagnostics plumbing is preserved and no second persistence path was introduced.

However, `WatchSync()` reconstructs `watched` from only two facts — `IsDeployed()` and current `hideOnBlur` — while the existing runtime has stricter eligibility semantics. This creates two correctness regressions:

1. a window shown with `activateOnShow=false` can become newly auto-hidden after any Settings reconciliation even though the established product/runtime contract says `hideOnBlur` only works together with activation;
2. when one HWND is represented by both a permanent and a dynamic slot, `WatchSync()` does not preserve the existing `SlotOf()` rule that permanent binding wins.

Both cases are absent from the added regressions. The first is common enough to block acceptance; the second is an explicit supported registry state in existing code and should be fixed at the same watcher-authority seam.

Real Windows verification remains valuable after correction because the test suite models watcher/timer state but does not execute real focus transitions or AHK timer cadence.

## 3. Commits

### Reviewed implementation

- `be028a0b10af88040c79f7faa9bd04219288b256` — `fix(settings): reconcile live hideOnBlur/blurMs and lock General controls during save`
- parent/base: `389914e44fff78ccd6362cfbb9b43a8534ff9e54`
- production/test diff is one commit ahead, zero behind the required C03 base.

### G03 report metadata after Code SHA

- Current `dev/fix/settings-live-blur-save-lock` remote tip observed during review: `47fb682b3efd1cda8196d7146f57e69eb19cfddd`.
- `be028a0 -> 47fb682` changes only `docs/agent-reports/2026-09-06-antigravity-g03.md`.
- The G03 report itself currently says `Final SHA: 9f5c3df (code commit: be028a0)`, which does not match the actual observed branch tip. This is metadata debt only; review identity is the task-mandated Code SHA `be028a0`.

### This review

- Report-only commit on `review/g03-live-settings`; production files are unchanged.

## 4. Important decisions / findings

Findings are ordered by severity.

### HIGH — `WatchSync()` breaks the existing `activateOnShow` eligibility contract

**Files/functions:**

- `src/drawer.ahk::Show()`
- `src/drawer.ahk::FocusWindow()`
- `src/drawer.ahk::Watch()`
- `src/drawer.ahk::WatchSync()`
- `src/config.ini` documentation for `activateOnShow` / `hideOnBlur`

**Existing behavior before G03:**

`Show()` computes:

`activate := forceActivate || Opt(cfg, "activateOnShow", true)`

and calls `Watch(hwnd, cfg)` only when `activate` is true. Therefore a normal show with `activateOnShow=false` deliberately leaves the window deployed but not in `watched`.

The shipped config contract states that `hideOnBlur` works only together with `activateOnShow=true`.

`FocusWindow()` is a deliberate special case: focus hotkey force-activates a window even when `activateOnShow=false`, then calls `Watch()`. This means watcher eligibility is not simply the current boolean pair; it also reflects how the window was activated.

**G03 behavior:**

`WatchSync()` scans every `SlotBound()` item and, when the window is alive/deployed and `hideOnBlur=true`, unconditionally inserts it into `watched`. It does not inspect `activateOnShow` and does not preserve the prior distinction between a window merely shown on top and a window Drawer actually activated.

**Reproducible code path:**

1. slot behavior has `activateOnShow=false`, `hideOnBlur=true`;
2. show the slot normally; `Show()` leaves it deployed and intentionally does not call `Watch()`;
3. Apply any Settings change that causes runtime reconciliation — the changed field need not be `hideOnBlur`;
4. `WatchSync()` sees `IsDeployed=true` and `hideOnBlur=true`, inserts the HWND into `watched` and starts `WatchBlur`;
5. after Settings is no longer the service foreground window, a later unrelated focus change can hide the slot even though normal `activateOnShow=false` behavior previously did not participate in auto-hide.

**Why this blocks acceptance:**

This is a behavior regression caused by G03 reconciliation itself, not only an unverified timing detail. It can be triggered by an unrelated Apply and contradicts both existing `Show()` control flow and documented config semantics.

**Fix constraint:**

Do not fix this by mechanically requiring `activateOnShow=true` for every watched window: `FocusWindow()` intentionally creates a legitimate watched state even when that option is false. The corrected reconciliation needs to preserve/derive the authoritative watcher eligibility without converting all merely-deployed windows into activated windows and without dropping legitimate focus-hotkey watcher state.

### MEDIUM — duplicate HWND resolution ignores the established permanent-slot precedence

**Files/functions:**

- `src/Slots.ahk::SlotOf()`
- `src/Slots.ahk::SlotBound()`
- `src/Slots.ahk::SlotBind()`
- `src/drawer.ahk::WatchSync()`

**Existing registry contract:**

`SlotOf(hwnd)` explicitly documents and implements that the same HWND can be captured by a permanent slot and separately bound to a dynamic slot, and that the permanent slot's behavior wins.

`SlotBound()` is slot-oriented, not HWND-unique: it returns an entry for every live slot binding. Therefore the same HWND may appear more than once with different `cfg` values.

`SlotBind()` does not globally reject an HWND because another slot already references it, so this state is not theoretical according to current registry rules.

**G03 behavior:**

`WatchSync()` iterates all `SlotBound()` entries. For a given HWND, any entry with `hideOnBlur=true` sets `boundMap[hwnd]` and keeps the window in `watched`. A later conflicting item with `hideOnBlur=false` does not remove that prior decision.

Therefore a dynamic slot with `hideOnBlur=true` can keep an HWND watched even when the authoritative permanent slot for the same HWND has `hideOnBlur=false`. This disagrees with `SlotOf()` and can make `WatchBlur()` hide a window under the wrong slot behavior.

**Required correction property:**

Watcher reconciliation must resolve one authoritative behavior per HWND using the same precedence semantics as the rest of the window model, rather than treating `SlotBound()` rows as independent votes.

### LOW — save-lock styling compounds opacity

**File:** `settings-ui/src/views/GeneralView.vue`

The functional lock is complete, but disabled styling applies `opacity: 0.5` to the disabled `<fieldset>` and also `opacity: 0.5` to disabled descendant inputs/selects/buttons. Descendant controls therefore render at effectively compounded opacity while saving.

This is transient and does not break save correctness, but it is an avoidable contrast/accessibility regression in the new lock presentation. Prefer one disabled-opacity layer rather than dimming both the whole fieldset and individual controls.

### PASS — reconcile stage ordering is otherwise coherent

**File/function:** `src/drawer.ahk::SettingsReconcileRuntime()`

Observed order at Code SHA:

1. `LoadConfig()`
2. `ConfigApply()`
3. handle accent repaint
4. `Slots.Apply(cfg, slotPlan.prevPerm)`
5. `RebindSlotHotkeys()`
6. `SlotsSeedManaged()`
7. `WatchSync()`
8. schedule `HandlesSync`

Placing watcher reconciliation after `Slots.Apply()` and `SlotsSeedManaged()` is directionally correct: it sees the final post-save slot registry and managed state. No duplicate persistence/reload stage was added.

### PASS — General save lock covers the participating General edit surface

**File:** `settings-ui/src/views/GeneralView.vue`

At Code SHA:

- `saving` is driven by `settings.status === 'saving'`;
- the General editor is wrapped in a disabled fieldset;
- width, edge, monitor kind/number, activate, hide-on-blur, handles, accent, animation preset/values and blur interval are disabled during save;
- accent palette buttons and native custom color input are disabled;
- custom color/preset handlers also guard `saving.value`;
- `settings.ts` transitions out of `saving` on full success, no-op success and `fail()` error, so controls unlock for success/error/retry.

No save-participating General control was found left mutable through the template during `saving`.

### PASS — accepted C03 save/partial/retryable/diagnostics semantics remain structurally intact

Diff from C03 base `389914e...` does not modify:

- `settings-ui/src/bridge/settings.ts`;
- Settings protocol/client;
- `src/webview/SettingsPort.ahk`;
- `src/webview/SettingsJsonBridge.ahk`.

Backend G03 adds `WatchSync()` to the existing `SettingsReconcileRuntime()` called by `SettingsApplyPlan()` after `SettingsPersistVerified()`. It does not introduce an additional persistence function or alternate frontend save path.

Partial-write behavior remains on the existing C03 path: when persistence may have changed disk, the same runtime reconciliation reloads actual config, then canonical state is snapshotted when reload succeeds.

### PASS — diff scope is narrow

`389914e... -> be028a0` changes only:

- `src/drawer.ahk`;
- `test/narrow/settings-seam.ahk`;
- `settings-ui/src/views/GeneralView.vue`;
- `settings-ui/test/canonical.test.ts`;
- the G03 factual report.

No unrelated product/runtime subsystem was changed.

## 5. Problems found in test coverage / false confidence

### Backend tests 21a–21g are a model copy, not execution of production `WatchSync()`

`test/narrow/settings-seam.ahk` defines a separate `WatchSyncModel()` and verifies that model with synthetic maps. The tests are useful for the intended state transitions, but they do not call production `WatchSync()`, real `SlotBound()`, real `SlotOf()`, `WinExist()`, `IsDeployed()` or actual `SetTimer()`.

This allows the model and production implementation to share the same missing concept and still pass.

Specific false-confidence examples:

- `21c` is described as proving dynamic per-slot override precedence, but the test simply hands the model a pre-resolved `{ hideOnBlur: false }` cfg; it does not exercise `SlotCfg()` / `SlotBehavior()` resolution.
- `21d` is described as proving permanent-slot independence, but the model has no slot kind at all; it simply receives `{ hideOnBlur: true }`.
- no test supplies two `SlotBound()` rows with the same HWND and conflicting configs.
- no test models the difference between deployed-but-never-activated and deployed-and-watched windows.

### Backend tests 21h–21j are source-shape checks

They only prove:

- a `WatchSync()` function text exists and mentions `SlotBound()`;
- both `SetTimer(WatchBlur, blurMs)` and `SetTimer(WatchBlur, 0)` text occur;
- a `WatchSync()` occurrence appears after a `Slots.Apply()` occurrence.

They do not verify actual runtime timer cadence, exact reconcile ordering after `RebindSlotHotkeys()` / `SlotsSeedManaged()`, or behavior under real HWND/focus state.

### Frontend G03-2 is source-shape coverage

`G03-2` reads `GeneralView.vue` as text and regex-checks `:disabled`/guard expressions. It does not mount the Vue component and cannot prove browser focusability, pointer behavior, native color-picker interaction, or visual opacity.

### Frontend G03-1 and G03-3 exercise bridge state, not component locking

- `G03-1` correctly demonstrates why an in-flight mutation would be lost on successful `adopt()`; it intentionally mutates the draft programmatically and proves the hazard.
- `G03-3` meaningfully verifies `settings.status` is `saving` during the request and exits that state after success/error.

Together they support the lock design but do not execute the DOM lock itself.

### Missing high-value automated/runtime cases

At minimum, the correction should add targeted coverage for:

1. deployed `activateOnShow=false`, `hideOnBlur=true` window that was not previously watched: unrelated Apply must not enroll it into auto-hide;
2. legitimate watcher created by `FocusWindow()` with `activateOnShow=false`: unrelated Apply must not incorrectly discard that valid state while `hideOnBlur` remains true;
3. duplicate HWND present in permanent + dynamic slots with conflicting `hideOnBlur`: permanent `SlotOf()` behavior must win;
4. two different watched HWNDs where one becomes ineligible: the other remains watched and timer remains armed;
5. stale/closed HWND present only in `watched`: reconciliation removes it without affecting valid watchers;
6. actual `blurMs` fast->slow and slow->fast timing in Windows, not only a synthetic `timerPeriod` variable.

## 6. Tests / verification

This Run ID is intentionally GitHub/repository-only. No local AHK, npm, WebView or Windows focus/timer execution was performed.

Repository verification performed:

- canonical code identity verified: `be028a0b10af88040c79f7faa9bd04219288b256`;
- base identity verified: `389914e44fff78ccd6362cfbb9b43a8534ff9e54`;
- diff relation: Code SHA is exactly one commit ahead and zero behind base;
- diff file scope inspected;
- full relevant production source inspected for `Show`, `FocusWindow`, `Watch`, `WatchBlur`, `WatchSync`, `IsDeployed`, `SlotOf`, `SlotBound`, `SlotBind`, `SettingsApplyPlan`, `SettingsReconcileRuntime` and GeneralView save lock;
- G03 AHK/frontend test additions inspected and classified as behavioral-model, bridge-state or static/source-shape coverage;
- post-code G03 branch delta verified as report-only.

The original G03 report states that the implementation run passed AHK validate, settings-seam groups 1–21, frontend 50/50, typecheck and build. This review did not rerun those commands and does not treat reported green gates as evidence for the uncovered watcher-authority cases above.

### Short manual Windows acceptance checklist after fix

1. **Non-activating show:** set `activateOnShow=false`, `hideOnBlur=true`; show the slot, Apply an unrelated setting, switch focus elsewhere — the slot must not newly auto-hide merely because Apply ran.
2. **Normal live toggle:** with an already shown/activated window, Apply `hideOnBlur true -> false` and `false -> true`; both directions must work without rebind/restart.
3. **Focus-hotkey special case:** with `activateOnShow=false`, use the permanent focus action so Drawer explicitly activates/watches the window; unrelated Apply must preserve the legitimate watcher while `hideOnBlur=true`.
4. **Shared HWND precedence:** bind/capture one HWND in permanent + dynamic slots with opposite `hideOnBlur`; after Apply, behavior must follow the permanent slot exactly as `SlotOf()` specifies.
5. **Timer cadence:** while a watcher is active, Apply a large `blurMs` decrease and increase; observed hide delay must follow the new interval and no old cadence should remain authoritative.
6. **Multiple watchers:** keep two eligible shown windows; make only one ineligible and Apply — the other watcher must remain and timer must stay active.
7. **General lock:** during a deliberately slow Apply, verify text/select/check/color/preset controls cannot mutate; after success and after a retryable error they become editable again.

## 7. Known issues / unfinished

- No real Windows timer/focus test was executed in this repo-only review.
- Exact AHK scheduler timing remains runtime evidence; the code-level `SetTimer(WatchBlur, blurMs)` re-arm shape is reasonable, but must be tested after watcher-membership correctness is fixed.
- Existing broader HWND-reuse/state-lifecycle risks were not expanded into this review unless directly touched by `WatchSync()`.
- General label/accessibility debt identified by G06 is pre-existing and outside G03 review scope; only the newly compounded disabled opacity is called out here.

## 8. Suggested next step

Do **not** integrate G03 Code SHA `be028a0` as accepted yet.

Create one narrow G03 correction from the same accepted C03 lineage (or from the current controlled integration lineage, per architect choice) that:

1. fixes watcher reconciliation so it preserves existing activation/focus eligibility rather than treating every deployed `hideOnBlur=true` window as watchable;
2. resolves duplicate HWND behavior through the same permanent-first authority used by `SlotOf()`;
3. adds targeted regressions for both cases plus a multi-watcher cleanup case;
4. avoids changing C03 persistence/diagnostics semantics or unrelated UI;
5. then reruns AHK validate, settings-seam, frontend tests/typecheck/build and the short Windows focus/timer checklist above.

After that correction, an independent review can re-evaluate for `ACCEPT` / `ACCEPT_WITH_RUNTIME_CHECK`.