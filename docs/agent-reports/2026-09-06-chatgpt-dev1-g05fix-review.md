# G05FIXR — independent review of corrected Slots UX state truth

- Task ID: `G05FIXR`
- Run ID: `RUN-20260906-CHATGPT-DEV1-G05FIX-REVIEW-01`
- Agent/client: `ChatGPT browser/GitHub-native`
- Model: `GPT-5.6 Sol`
- Chat/session ID: `NOT_EXPOSED`
- Chat title: `NOT_EXPOSED`
- Search anchor: `Drawer G05FIXR slot state truth review — ChatGPT DEV1 — 20260906`
- Started at: `2026-09-06T21:33:48+03:00` (task-assignment commit timestamp)
- Finished at: `NOT_EXPOSED`
- Worktree: `N/A — GitHub-native repo-only review; local worktree not required by task`
- Branch: `review/g05fix-slots-ux`
- Base SHA: `f4630b1dd90749eb9296c058aae0aea6c9ce54ea` (`dev/wip/slots-parity` at review-branch creation)
- Code SHA: `97962bdf8f821f4c42bc26df81856231fa04164c`
- Report tip SHA: `PENDING_FINAL_COMMIT`
- Remote: `dev`

## 1. Goal

Independently verify canonical G05FIX Code SHA `97962bdf8f821f4c42bc26df81856231fa04164c` against the two blocking findings from G05 review, without changing production code.

Review focus:

1. canonical versus draft show/hide hotkey truth, including active, disabled and pending states;
2. staged permanent -> temporary conversion wording and Release visibility;
3. applied temporary-slot Release/override behavior after conversion;
4. edge cases in the new presentation helpers in `settings-ui/src/bridge/slots.ts`;
5. test quality and remaining manual gaps;
6. diff scope and preservation of prior G05 terminology/layout cleanup.

## 2. Result

**Verdict: `ACCEPT_WITH_MANUAL_CHECK`.**

G05FIX resolves both prior G05 review blockers at the correct presentation/state seam:

- the temporary-slot onboarding now derives the currently active hotkey from canonical slot state, keeps a differing draft hotkey explicitly pending until Apply, and reports an empty canonical hotkey as disabled instead of inventing `Ctrl+Alt+N`;
- permanent -> temporary staging is now explicitly described as pending/future state, while the runtime-only Release action is gated by canonical dynamic + bound status and is not exposed while runtime remains permanent.

The correction stays frontend-only and does not alter AHK/backend/protocol/config semantics. Existing G05 terminology and narrow-layout changes remain intact.

No code-level correctness blocker was found. A short live WebView/manual check remains appropriate because the new copy/conditional presentation is not mounted in a DOM/component test and the actual narrow-window visual result was not exercised by this review.

## 3. Commits

### Reviewed implementation

- Previous G05 Code SHA/base: `bb385fa63294addcdbb82fbbcd900c2258ce50ff`.
- G05FIX Code SHA: `97962bdf8f821f4c42bc26df81856231fa04164c` — `fix(settings): show canonical slot state truth`.
- Code SHA is exactly one commit ahead of the previous G05 code.

Changed production/test files:

- `settings-ui/package.json`;
- `settings-ui/src/bridge/slots.ts`;
- `settings-ui/src/views/SlotsView.vue`;
- `settings-ui/test/slotsUx.test.ts`.

### G05FIX report tip

- Observed `dev/fix/slots-ux-state-truth` tip: `f38cbc3841989419507ead9fb98afc5157c2a3f2`.
- `97962bdf -> f38cbc3` is report-only: `docs/agent-reports/2026-09-06-codex-g05fix.md`.
- Review identity therefore correctly remains Code SHA `97962bdf...`.

### This review

- Report-only commit on `review/g05fix-slots-ux`; no production/test source is changed by this Run ID.

## 4. Important decisions / findings

### PASS — canonical active hotkey truth is now authoritative

**Files/functions:**

- `settings-ui/src/bridge/slots.ts::hotkeyPresentation()`
- `settings-ui/src/views/SlotsView.vue::shownHotkey`
- temporary onboarding block

`hotkeyPresentation()` selects `active` only from canonical slot state:

- permanent slot -> `slot.value.hotkey`;
- dynamic slot -> `slot.hotkey`.

A draft value becomes `pending` only when it differs from canonical active state.

This closes both prior failure modes:

1. a newly typed draft hotkey is no longer described as already active;
2. empty canonical hotkey remains empty and is rendered as `Сейчас горячая клавиша «Показать / убрать» отключена.` rather than falling back to the default shortcut.

Pending enable/change is rendered with `После «Применить»: ...`; pending disable is rendered as `После «Применить» горячая клавиша будет отключена.`

This matches the established product contract that `Ctrl+Alt+N` is only the default and that slot hotkey changes become runtime truth through Apply/reconcile.

### PASS — helper behavior remains correct across slot kinds

`hotkeyPresentation()` is intentionally canonical-kind driven, not draft-kind driven. This is correct during staged kind conversion:

- canonical permanent + draft temporary: current permanent hotkey remains `active`; draft replacement, if any, is only `pending`;
- canonical dynamic + draft permanent: current dynamic hotkey remains the active runtime truth until Apply.

No helper path was found that promotes draft kind or draft hotkey into current runtime truth.

### PASS — staged permanent -> temporary no longer claims conversion is applied

**Files/functions:**

- `settings-ui/src/bridge/slots.ts::isPendingDynamicConversion()`
- `settings-ui/src/views/SlotsView.vue::pendingDynamicConversion`
- temporary onboarding block

The helper returns true only when canonical slot kind is permanent while draft kind is dynamic.

The view then renders explicit pending copy:

- `Изменение ещё не применено.`;
- if no permanent application window exists: `После «Применить» слот станет временным и свободным.`;
- if a permanent window exists: `После «Применить» текущее окно останется привязано к временному слоту.`

This is consistent with backend conversion semantics. `Slots.PermSnapshot()` resolves a permanent window through `SlotWindow()` even when it is only `available` and not yet cached, and `Slots.Apply()` carries that window into the dynamic binding when the slot becomes temporary. Therefore the future-retention wording is supported for `available` / `parked` / `shown` states, not guessed by the frontend.

### PASS — runtime Release visibility now follows canonical runtime state

**Files/functions:**

- `settings-ui/src/bridge/slots.ts::isRuntimeDynamicBound()`
- `settings-ui/src/views/SlotsView.vue::runtimeDynamicBound`
- Release button condition

`isRuntimeDynamicBound()` requires:

- canonical `slot.kind === 'dynamic'`;
- runtime status not `empty`.

The previous bug path is therefore closed: after clicking draft-only `Сделать временным…`, canonical slot is still permanent, so Release is not exposed and cannot call `slot.release` against a permanent runtime slot.

For an actually applied/bound temporary slot, Release remains visible and still invokes the unchanged existing `releaseSlot(selectedNumber)` path.

For an applied empty temporary slot, Release remains hidden.

### PASS — applied override wording no longer interprets staged permanent state as an applied dynamic override

`hasAppliedOverrides` now checks `selectedSlot.value?.kind === 'dynamic'` rather than draft `kind`.

Therefore staging permanent -> temporary no longer lets current permanent behavior participate in the `applied dynamic override` state.

`hasDraftOverrides`, `overrideNote`, `resetDynamic()` and `resetToShared()` retain their existing draft semantics. For an already-applied temporary slot, Reset remains a behavior-draft operation and does not release the window.

### PASS — G05 terminology/onboarding/layout cleanup is preserved

The G05FIX diff does not revert the accepted G05 copy/layout changes:

- `Постоянный` / `Временный` terminology remains;
- fixed `Ctrl+Alt+Shift+N` temporary bind onboarding remains;
- `Отвязать окно` and `Вернуть общие настройки` remain semantically separate;
- INI/AHK implementation vocabulary remains removed from rendered copy;
- narrow reset block CSS, local `.override-box .hotkey-cap { margin: 0; }`, wrapping and long-button handling are untouched by G05FIX.

### PASS — no backend/protocol/config semantic expansion

G05FIX does not modify:

- `src/drawer.ahk`;
- `src/Slots.ahk`;
- `src/config.ini`;
- WebView/AHK protocol implementation;
- Settings persistence or runtime actions.

`slots.ts` receives only pure presentation-state helpers; no request/action semantics are added.

### LOW / manual-only — actual rendered conditional copy still needs one live WebView pass

The logic is correct by source/state inspection, but no component/DOM test mounts `SlotsView.vue` and no live WebView screenshot/manual acceptance was performed in this review.

This is not a correctness blocker because the helpers and template conditions line up directly, but a live check should confirm the combined copy is visually understandable in the real narrow pane.

## 5. Problems found in tests / remaining gaps

### Improvement — state helpers now have real behavioral tests

Unlike the original G05 source-only suite, G05FIX imports and executes:

- `hotkeyPresentation()`;
- `isPendingDynamicConversion()`;
- `isRuntimeDynamicBound()`.

The tests now behaviorally prove at least:

- canonical disabled hotkey -> `{ active: '', pending: null }`;
- canonical active + differing draft -> canonical remains active and draft is pending;
- canonical permanent + draft dynamic -> pending conversion true;
- canonical permanent state is not runtime dynamic-bound.

These are meaningful pure-function tests, not source-shape assertions.

### Existing first three G05 tests remain source-shape/string checks

They still only inspect `SlotsView.vue` source to verify:

- onboarding/copy strings exist;
- selected internal vocabulary is absent;
- selected narrow-layout CSS declarations exist.

They do not execute Vue rendering or CSS geometry.

### Shared gate now includes `slotsUx.test.ts`

G05FIX updates `settings-ui/package.json` so `npm --prefix settings-ui test` bundles and runs `slotsUx.test.ts` alongside canonical, field-error and animation-preset tests.

This closes the previous test-infrastructure gap where the focused G05 suite existed but was not part of the normal frontend gate.

### Missing useful cases, non-blocking

The pure helper suite could be stronger with explicit cases for:

1. active non-empty -> pending empty hotkey, proving pending disable as a helper result;
2. canonical empty -> pending non-empty hotkey, proving pending enable;
3. canonical dynamic `available` / `parked` / `shown` -> `isRuntimeDynamicBound() === true`;
4. canonical dynamic `empty` -> false;
5. canonical permanent with live status + draft dynamic -> pending conversion true while runtimeDynamicBound remains false;
6. no draft -> pending hotkey remains null.

The implementation for these branches is simple and was inspected directly; their absence does not justify another correction cycle.

## 6. Tests / verification

This Run ID is GitHub/repository-only. No local npm, WebView, AHK or Windows execution was performed by this reviewer.

Repository verification performed:

- exact review identity: `97962bdf8f821f4c42bc26df81856231fa04164c`;
- previous G05 Code SHA/base: `bb385fa63294addcdbb82fbbcd900c2258ce50ff`;
- relation: G05FIX Code SHA is one commit ahead, zero behind previous G05 code;
- G05FIX production/test diff inspected in full relevant areas;
- `slots.ts` helpers, `SlotsView.vue` conditions/copy, protocol slot status types, existing slot draft/reconcile semantics and backend permanent->dynamic retention path inspected;
- feature branch post-Code-SHA delta verified as report-only.

Implementation report evidence (not rerun by this reviewer):

- `npm --prefix settings-ui test`: PASS, 52/52;
- `npm --prefix settings-ui run typecheck`: PASS;
- `npm --prefix settings-ui run build`: PASS;
- `git diff --check`: PASS;
- no AHK/runtime/config files changed.

### Short manual WebView acceptance checklist

1. **Active hotkey:** applied temporary slot shows `Сейчас: <actual canonical hotkey>`.
2. **Pending change:** edit hotkey without Apply; old hotkey remains under `Сейчас`, new one appears only under `После «Применить»`.
3. **Disabled active hotkey:** Apply an empty show/hide hotkey; helper says it is disabled and does not show `Ctrl+Alt+N` as active.
4. **Pending disable:** clear an active hotkey before Apply; current active key remains shown plus `После «Применить» ... будет отключена`.
5. **Permanent -> temporary, app stopped:** click `Сделать временным…`; before Apply the view says change is pending / slot will become free, and `Отвязать окно` is absent.
6. **Permanent -> temporary, live window:** stage conversion; copy says the window will remain bound only after Apply, Release remains absent before Apply; after Apply the slot becomes temporary and Release appears.
7. **Applied temporary bound:** `Отвязать окно` immediately unbinds the window while behavior settings remain.
8. **Narrow pane:** new extra hotkey/pending lines do not cause clipping or horizontal overflow.

## 7. Known issues / unfinished

- No live WebView visual/manual acceptance was performed by this reviewer.
- The view still has no mounted component test framework; conditional rendering is validated by pure helper tests plus source inspection.
- Broader G06 accessibility/navigation work is outside this Run ID.

## 8. Suggested next step

G05FIX Code SHA `97962bdf8f821f4c42bc26df81856231fa04164c` is suitable for integration after the short manual WebView check above.

No additional G05FIX code correction is recommended from this review.