# G05R — independent review of Slots UX terminology/onboarding implementation

- Task ID: `G05R`
- Run ID: `RUN-20260906-CHATGPT-DEV1-G05-REVIEW-01`
- Agent/client: `ChatGPT browser/GitHub-native`
- Model: `GPT-5.6 Sol`
- Chat/session ID: `NOT_EXPOSED`
- Chat title: `NOT_EXPOSED`
- Search anchor: `Drawer G05R independent Slots UX review — ChatGPT DEV1 — 20260906`
- Started at: `2026-09-06T14:37:29+03:00` (task-assignment commit timestamp)
- Finished at: `2026-09-06T14:48:53+03:00`
- Worktree: `N/A — GitHub-native repo-only review; local worktree not required by task`
- Branch: `review/g05-slots-ux`
- Base SHA: `2739e9ccbbb2a95b2f5c5a1f72fb65dbbcb5f65f` (`dev/wip/slots-parity` at review-branch creation)
- Code SHA: `bb385fa63294addcdbb82fbbcd900c2258ce50ff`
- Report tip SHA: `PENDING_FINAL_COMMIT`
- Remote: `dev`

## 1. Goal

Independently review G05 Code SHA `bb385fa63294addcdbb82fbbcd900c2258ce50ff` against the approved G05A analysis and the existing accepted slot semantics, without changing production code.

Review scope:

1. rendered terminology/internal-jargon cleanup;
2. empty/bound temporary-slot onboarding and actual hotkey behavior;
3. `Отвязать окно` versus `Вернуть общие настройки` semantics/wiring;
4. permanent↔temporary conversion wording versus draft/runtime reality;
5. narrow-layout CSS fix and obvious wide-layout regressions;
6. quality/limits of added tests and remaining manual WebView checks;
7. diff scope and preservation of backend/protocol behavior.

## 2. Result

**Verdict: `NEEDS_FIX`.**

Most of the intended G05 cleanup is implemented cleanly and in the correct frontend-only scope:

- internal INI/AHK vocabulary is removed from rendered Slots copy;
- temporary-mode wording is substantially clearer;
- the fixed `Ctrl+Alt+Shift+N` bind path is finally discoverable;
- ordinary canonical-dynamic `Отвязать окно` still calls the existing immediate Release action;
- Reset still mutates only the dynamic behavior draft and explicitly says the bound window remains;
- the local 120 px `.hotkey-cap` margin is neutralized inside the reset block and wrapping is enabled;
- no backend/AHK/config/protocol semantics were changed.

However, two user-visible correctness problems remain in the newly added onboarding/presentation logic:

1. the show/hide hotkey helper can state a shortcut that is not active — including showing the default even when the slot hotkey is intentionally disabled;
2. after a draft-only permanent→temporary conversion, the new temporary onboarding interprets the old canonical permanent status as if the conversion were already applied, and can claim that a window is temporarily bound when no such binding exists.

These are not merely missing runtime confirmation; they are deterministically visible from the current state model and directly violate the approved G05A acceptance intent that helper copy must not claim pending edits are already active and that conversion copy must match actual behavior.

A small SlotsView-only correction is sufficient; no backend change is required.

## 3. Commits

### Reviewed implementation

- Base/parent: `c1e710345543c3eb7ff3cb2a9d3a6f13c57ff297`
- Code SHA: `bb385fa63294addcdbb82fbbcd900c2258ce50ff` — `fix(settings): clarify temporary slot UX`
- Code SHA is exactly one commit ahead of its base and changes only:
  - `settings-ui/src/views/SlotsView.vue`;
  - `settings-ui/test/slotsUx.test.ts`.

### G05 branch tip after Code SHA

- Observed `dev/fix/slots-ux-terminology-layout` tip: `8593c618ad15cd66a3bc142ab695ece307f83227`.
- `bb385fa -> 8593c61` is report-only: `docs/agent-reports/2026-09-06-codex-g05.md`.
- Review identity therefore correctly remains Code SHA `bb385fa...`.

### This review

- Report-only commit on `review/g05-slots-ux`; production/test files are not modified by this Run ID.

## 4. Important decisions / findings

Findings are ordered by severity.

### HIGH — temporary onboarding can advertise a show/hide hotkey that does not exist or is not active yet

**Files/functions:**

- `settings-ui/src/views/SlotsView.vue::captureHotkey()`
- `settings-ui/src/views/SlotsView.vue` temporary onboarding block
- `settings-ui/src/bridge/slotDraft.ts::draftFromSlot()`
- `src/drawer.ahk::SettingsHotkeyIn()`
- `src/drawer.ahk::RebindSlotHotkeys()`

The new onboarding renders:

`draft?.hotkey || Ctrl + Alt + N — показать или убрать окно.`

This is inaccurate in two supported states.

#### A. Empty hotkey means disabled, not “use the default”

`captureHotkey()` explicitly lets Backspace/Delete set `draft.hotkey = ''`.

Backend validation explicitly documents and accepts empty hotkey as **“у слота нет хоткея”**. After Apply, `RebindSlotHotkeys()` removes the registration when `now == ""`.

Therefore a legitimately disabled slot reaches canonical/draft state with `hotkey == ""`, while the new helper falls back to `Ctrl + Alt + N` and tells the user that this key shows/hides the window. In reality no show/hide hotkey is registered for that slot.

This conflicts with the stable contract: `Ctrl+Alt+N` is a default, not an unconditional fixed shortcut.

#### B. Pending custom hotkey is shown as if it already works

The helper reads the mutable slot **draft**, not applied canonical state. When the user changes a hotkey but has not yet pressed Apply/OK, the new combination immediately appears as:

`<new draft hotkey> — показать или убрать окно.`

But hotkey registration changes only after Save/reconcile. Until Apply, the old applied hotkey remains live.

G05A manual acceptance explicitly required that helper copy must not claim edits are active before Apply; it may state that no restart is required **after Apply**. The permanent helper follows that rule, but the temporary onboarding does not.

**Required correction property:**

The helper must distinguish applied/live from pending draft state. Examples of acceptable behavior:

- show the applied hotkey as the one that works now and separately indicate a pending replacement;
- or, if showing the draft value, phrase it as `После «Применить»: ...` when it differs;
- if the applied/draft hotkey is empty, say that the show/hide hotkey is disabled rather than falling back to `Ctrl+Alt+N`.

No backend change is needed.

### HIGH — draft-only permanent→temporary conversion produces false “temporarily bound” copy and exposes an unusable Release action

**Files/functions:**

- `settings-ui/src/views/SlotsView.vue::makeDynamic()`
- `settings-ui/src/views/SlotsView.vue` `kind`, `selectedSlot`, temporary onboarding and Release-button conditions
- `settings-ui/src/bridge/settings.ts::releaseSlot()` / `slotRuntime()`
- `src/Slots.ahk::SlotRelease()`

`makeDynamic()` is intentionally draft-only: it sets `d.kind = 'dynamic'`, resets draft behavior, and does not call the backend. The canonical `selectedSlot` remains a permanent slot until Apply/OK.

The template then switches immediately to the temporary branch because it uses draft `kind`, but the new onboarding decides whether a window is “free” using the **canonical permanent status**:

- only `status.state === 'empty'` gets `Слот свободен`;
- every other status gets `Окно привязано временно.`

A permanent slot whose application is not running has canonical status `applicationNotRunning`, not `empty`. Immediately after clicking `Сделать временным…`, before Apply, G05 therefore displays:

- `Окно привязано временно.`
- `Привязка текущего окна живёт до перезапуска Drawer...`

although there is no window at all and the runtime slot is still permanent.

For a running permanent slot, the wording is still premature: conversion/live-window retention is only committed after Apply, while the copy says the window **is** temporarily bound now.

The same draft/canonical split also exposes `Отвязать окно`, because its condition is:

`kind === 'dynamic' && selectedSlot.status.state !== 'empty'`.

After staging permanent→temporary, `kind` is dynamic but canonical `selectedSlot` is still permanent. Clicking Release calls the existing backend `slot.release`; `SlotRelease()` checks the actual runtime slot and rejects permanent slots with `slot_is_permanent`.

The Release condition predates G05, but the new G05 onboarding now positively tells the user that the temporary binding exists, making the inconsistent staged-conversion state much more visible and directly contradicting review question 4.

The new `resetPending` helper can compound the same problem: in a staged conversion whose permanent behavior differs from General, it can say `привязанное окно останется` even when canonical status is `applicationNotRunning`.

**Required correction property:**

Presentation must distinguish:

- applied canonical slot kind/status;
- staged draft conversion intent.

For staged permanent→temporary, use future/pending wording until Apply. If the permanent app is not running, say the slot **will become free/temporary after Apply**; if a live permanent window is present and accepted conversion semantics retain it, say it **will remain temporarily bound after Apply**.

`Отвязать окно` should only be offered when the applied/runtime slot is actually dynamic and currently bound, not merely because the draft kind has been switched to dynamic.

No backend change is needed.

### PASS — ordinary Release and Reset remain semantically distinct

**File:** `settings-ui/src/views/SlotsView.vue`

For an already-applied dynamic slot:

- `Отвязать окно` still calls `releaseSlot(selectedNumber)`, which uses the established immediate runtime `slot.release` path;
- `resetDynamic()` still calls only `resetToShared(d, shared)` and remains an Apply/OK-time draft edit;
- Reset copy explicitly says parameters change while the bound window remains;
- after a staged reset, `resetPending` leaves an explanatory pending state instead of silently disabling the button.

No code was found that makes Reset unbind a window or makes Release reset behavior settings.

### PASS — rendered internal vocabulary cleanup is substantially complete

**File:** `settings-ui/src/views/SlotsView.vue`

The rendered template no longer teaches the user:

- `[dynamic]`;
- `[dynamicSlotN]`;
- `[slot N]`;
- raw `ahk_class`;
- mixed-English `show/hide`.

User-facing replacements match the G05A direction:

- `Временный`;
- `Закрепить за приложением…`;
- `Сделать временным…`;
- `Приложение (.exe)`;
- clearer picker titles;
- `Дополнительный признак окна`;
- `Показать / убрать`.

Internal protocol/config identifiers are unchanged.

### PASS — fixed dynamic bind onboarding itself is accurate

The empty temporary-slot block uses the selected slot number in the fixed:

`Ctrl + Alt + Shift + N`

capture/bind instruction. That matches the stable runtime contract: bind is fixed per slot number and is not presented as user-configurable.

The problem is only the adjacent show/hide helper described above.

### PASS — narrow reset layout fix addresses the identified local CSS defect

**File:** `settings-ui/src/views/SlotsView.vue`

The known 120 px inherited offset is explicitly neutralized by:

`.override-box .hotkey-cap { margin: 0; }`

The reset container now permits wrapping; `.override-copy` can shrink/wrap, and `.btn-reset-override` uses `white-space: normal`, `max-width: 100%`, and no fixed height. Header actions also permit wrapping.

From static CSS inspection there is no obvious wide-layout regression: the reset box remains a normal flex row when space is available and wraps only as needed.

Actual WebView width/font rendering still requires the manual check listed below; the source-level regex test cannot prove layout geometry.

### PASS — scope is correctly frontend-only

`c1e710... -> bb385fa...` changes only `SlotsView.vue` and the isolated `slotsUx.test.ts`.

No changes were made to:

- `src/drawer.ahk`;
- `src/Slots.ahk`;
- `src/config.ini`;
- bridge/protocol/persistence files;
- package/build architecture.

Accepted A01FIX/G02/C03 backend semantics are therefore not directly modified by G05.

## 5. Problems found in test coverage / false confidence

### All three `slotsUx.test.ts` cases are source-shape/string assertions

The focused G05 test reads `SlotsView.vue` as text and checks regex/string presence.

It proves only that:

1. onboarding phrases and button labels exist in source;
2. selected internal words do not occur in the extracted template;
3. selected CSS declarations (`margin:0`, `flex-wrap`, `white-space:normal`) exist.

It does **not** execute Vue computed state, draft/canonical transitions, hotkey editing, button visibility, Release/Reset actions, or actual CSS layout.

This explains both correctness misses:

- no test sets `draft.hotkey = ''` or a custom pending hotkey;
- no test stages `makeDynamic()` while canonical slot remains permanent with `applicationNotRunning` or a live status.

### Focused G05 test is not part of the shared `npm test` script

At Code SHA, `settings-ui/package.json` runs only:

- `canonical.test.ts`;
- `fieldError.test.ts`;
- `animationPreset.test.ts`.

`slotsUx.test.ts` is therefore a separate targeted command, as the implementation report correctly states. This was consistent with G05A's instruction not to create unnecessary package-entrypoint conflicts, but future runs of only `npm --prefix settings-ui test` will not execute the G05 source assertions.

This is test-infrastructure debt, not by itself a production blocker.

### Existing behavioral suite still protects the underlying slot draft/backend semantics

The implementation did not alter `slotDraft.ts`, `settings.ts`, protocol or AHK. Existing behavioral tests remaining green is useful evidence that the underlying accepted mechanics were not changed.

It does not validate the new conditional copy layer.

## 6. Tests / verification

This review is explicitly GitHub/repository-only. No local npm, WebView, AHK or Windows execution was performed.

Repository verification performed:

- reviewed exact Code SHA `bb385fa63294addcdbb82fbbcd900c2258ce50ff`;
- verified parent/base `c1e710345543c3eb7ff3cb2a9d3a6f13c57ff297`;
- verified implementation diff is one commit / two files only;
- inspected full changed `SlotsView.vue` and `slotsUx.test.ts`;
- inspected G05A analysis/acceptance checklist;
- inspected current hotkey draft conversion and backend acceptance of an empty hotkey;
- inspected live hotkey re-registration behavior;
- inspected Release bridge/backend path and permanent-slot rejection;
- verified post-Code-SHA G05 branch delta is report-only.

The original G05 implementation report records:

- focused `slotsUx.test.ts`: 3/3 pass;
- `npm --prefix settings-ui test`: 47/47 pass;
- typecheck: pass;
- build: pass;
- `git diff --check`: pass.

This review did not rerun those commands and does not treat those green gates as coverage for the two conditional-state issues above.

### Short operator manual acceptance checklist after correction

1. **Default hotkey:** applied default temporary slot shows `Ctrl+Alt+N` and that shortcut works.
2. **Custom applied hotkey:** after Apply, onboarding shows the custom shortcut, not the default.
3. **Pending custom hotkey:** before Apply, UI does not claim the new combination is already live; old applied shortcut remains clearly distinguishable.
4. **Disabled hotkey:** clear the show/hide hotkey, Apply, reopen/select the slot; onboarding says show/hide hotkey is disabled and does not display `Ctrl+Alt+N` as active.
5. **Permanent→temporary, app not running:** immediately after staging conversion but before Apply, no copy claims that a window is temporarily bound and no usable `Отвязать окно` action is offered; after Apply the slot becomes free temporary.
6. **Permanent→temporary, live window:** before Apply, wording is pending/future; after Apply, accepted live-window retention is reflected accurately.
7. **Ordinary bound temporary:** `Отвязать окно` releases immediately and monitor/edge/width/activate/hide settings remain unchanged.
8. **Reset:** `Вернуть общие настройки` changes only draft behavior, keeps the live binding, persists only on Apply/OK, and Cancel restores applied state.
9. **Narrow WebView:** onboarding, reset source/help, reset button and header actions have no clipping/horizontal scroll at the known narrow Settings width.
10. **Wide WebView:** list/detail hierarchy and button alignment remain visually normal.

## 7. Known issues / unfinished

- No live WebView geometry/layout check was executed in this repo-only review.
- The value/provenance model for dynamic overrides when General has unsaved changes predates G05 and was not expanded into a new architecture task here.
- Broader navigation/accessibility issues belong to G06, not this review.

## 8. Suggested next step

Do **not** accept G05 Code SHA `bb385fa...` unchanged.

Create a narrow G05 correction, preferably touching only `settings-ui/src/views/SlotsView.vue` plus focused tests, that:

1. makes show/hide onboarding truthful for applied, pending-custom and disabled-hotkey states;
2. makes permanent→temporary staged conversion copy explicitly pending and based on real canonical/live status;
3. hides/disables Release until the runtime/canonical slot is actually dynamic and bound;
4. keeps the successful jargon/layout/reset changes intact;
5. adds targeted assertions/models for blank/custom hotkeys and staged conversion states, then reruns frontend tests/typecheck/build and the manual WebView checklist above.

After that correction, re-review for `ACCEPT` or `ACCEPT_WITH_MANUAL_CHECK`.