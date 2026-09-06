# TASK A01FIX — manual acceptance hotkey + Reset-to-General fixes

- Task ID: `A01FIX`
- Run ID: `RUN-20260906-ANTIGRAVITY-A01FIX-01`
- Agent/client: `Antigravity`
- Model: `Gemini 3.8 Flash High`
- Chat/session ID: `78ab3d29-9852-4d10-81ed-1df525e37bb4`
- Chat title: `Drawer TASK A01FIX — manual acceptance hotkey + Reset-to-General fixes`
- Search anchor: `Drawer TASK A01FIX — hotkey cycle + reset to general — antigravity/20260906`
- Started at: `2026-09-06T11:45:00+03:00`
- Finished at: `2026-09-06T12:20:00+03:00`
- Worktree: `C:\Users\nerza\Projects\drawer-agent-worktrees\A01FIX`
- Branch: `fix/a01-hotkey-reset-general`
- Base SHA: `faa6d7d9786bfda98849c5925bc9641ce0fd0dc0`
- Final SHA: `e10509d`
- Remote: `dev`

## 1. Goal

Eliminate regressions found during manual acceptance of task A01:
1. Fix runtime crash `Parameter #1 of Integer.Call requires a Number, but received an empty string.` on hotkey save and restore full `A -> B -> A` hotkey registration lifecycle.
2. Fix Reset-to-General functionality in dynamic slots and solve the crowded 3-button layout in `SlotsView.vue` header without full redesign.

## 2. Result

- **BUG 1 (Hotkey lifecycle & crash):**
  - Resolved `Integer.Call` crash in `SettingsChangedSlots` by inspecting key target when section is `"hotkeys"` (`w.key` / `d.key`), and making `SettingsSectionSlot(sec)` safely match digits (`RegExMatch(sec, "\d+", &m) ? Integer(m[0]) : 0`) instead of throwing on empty string or non-numeric section names.
  - Fixed `RebindSlotHotkeys()` hotkey lifecycle: when hotkeys are cleared (`now == ""`) or registration fails, previous hotkey is unregistered and deleted from `slotRegistered` map. This prevents stale state and allows clean re-registration.
  - Fixed frontend canonical adoption for hotkeys: because the runtime crash in `SettingsApplyPlan` is eliminated, successful `SaveOutcome` returns updated canonical state to webview, which adopts it, preventing stale baseline hotkey comparisons.
  - Added Backspace/Delete hotkey clearing in `SlotsView.vue` `captureHotkey`.

- **BUG 2 (Reset-to-General & Layout):**
  - Relocated reset button from `.detail-head` action bar to `.override-box` beside the override source indicator (`.dyn-source` / `overrideNote`).
  - Labeled clearly: `Использовать общие настройки`.
  - Displayed conditionally: visible whenever dynamic overrides exist (`hasOverrides`), enabled when draft has overrides (`hasDraftOverrides`).
  - Fixed reset semantics: reads `currentShared` computed property (evaluating pending General draft edits if present, else canonical `general.dynamicDefaults`), resetting draft fields without releasing the slot or losing window binding. On Save, `slotPlan.dynDeletes` removes `[dynamicSlotN]` from INI.
  - Top action bar (`.detail-actions`) now cleanly fits `make-dynamic`, `release-slot`, `make-permanent` with `flex-wrap: wrap` and no text overlap at normal window width (~550px).

## 3. Commits

- `1d09152` and `e10509d` fix(slots): resolve hotkey cycle crash and dynamic override reset layout

## 4. Important decisions

- Maintained the exact function signature `SettingsSectionSlot(sec) {` in `src/drawer.ahk` because static verification in test suites checks this signature.
- Used `RegExMatch(sec, "\d+", &m)` for safe parsing of slot indices, returning 0 if no digits exist, instead of `Integer(RegExReplace(sec, "^\D+"))` which crashes AutoHotkey v2 with an uncaught `TypeError` when input has no digits.
- Evaluated `currentShared` in `SlotsView.vue` by falling back to `settings.canonical.general.dynamicDefaults` only if `settings.draft.general` fields are not set or when reading directly, ensuring that unsaved General changes are respected when resetting overrides in the same session.

## 5. Problems found

- **Root cause of `Integer.Call(empty string)`:**
  When a hotkey was modified, `slotPlan.writes` contained `{ sec: "hotkeys", key: "slot" n, val: hotkey }`. `SettingsChangedSlots` called `SettingsSectionSlot(w.sec)` directly on `w.sec`. Because `w.sec` was `"hotkeys"`, `RegExReplace("hotkeys", "^\D+")` stripped non-digits and returned empty string. Passing empty string to `Integer("")` raised an uncaught runtime exception in AutoHotkey v2: `Parameter #1 of Integer.Call requires a Number, but received an empty string.`
- **Why `Ctrl+Alt+1` failed to register again (`A -> B -> A` break):**
  Because of the exception thrown by `SettingsChangedSlots(slotPlan)` inside `SettingsApplyPlan`, the settings save operation terminated prematurely before returning a successful `SaveOutcome`. `SettingsPort.ahk` caught the exception and returned `internal_error` to the webview bridge instead of the updated canonical state. Consequently, the webview never executed `adopt(result.state)` and kept `settings.canonical.slots[0].value.hotkey = "Ctrl + Alt + 1"`, even though the AHK runtime had already registered `Ctrl + Z`. When the user later set the draft back to `Ctrl + Alt + 1`, `slotEditsToWire` compared `draft.hotkey` against stale `canonical.hotkey`, found them identical, and excluded Slot 1 from `slotEdits`. AHK received empty edits (no changes to apply) and never re-bound `Ctrl + Alt + 1`.
- **Root cause of Reset-to-General & Layout Cram:**
  In `SlotsView.vue`, `resetDynamic` read `settings.canonical.general.dynamicDefaults` instead of considering unapplied draft changes in General. Furthermore, `overrideNote` strictly reflected canonical state rather than draft state, giving no immediate visual feedback upon clicking reset. Placing `Сбросить к General` into `.detail-head` alongside two other long buttons broke the layout on normal window widths (~550px content pane).

## 6. Tests / verification

- **Narrow regression tests in `test/narrow/settings-seam.ahk`:**
  - Group 20 added with 9 assertions covering:
    - Safe parsing of `slot1..slot9`, `dynamicSlot1..dynamicSlot9` in `SettingsSectionSlot`.
    - Safe non-crashing handling of `"hotkeys"`, empty string, `"general"`, non-digit sections (returns 0).
    - `SettingsChangedSlots` correctly identifying slots from hotkeys writes/deletes and `dynamicSlot` without exceptions.
    - `A -> B -> A` hotkey registration lifecycle simulation (unregisters old hotkey, registers new hotkey, clean re-registration of previous hotkey, unregistering upon hotkey clear).
    - Source code inspection ensuring `drawer.ahk` uses safe matching and checks `w.sec = "hotkeys"` before resolving slot index.
  - Result: All 20 test groups passed (Exit code 0).
- **Backend syntax validation:**
  - `AutoHotkey64.exe /validate src/drawer.ahk`: Exit code 0.
- **Frontend unit tests (`settings-ui/test/canonical.test.ts`):**
  - Added unit test: `hotkey A -> B -> A lifecycle: draft emits edits upon change and after canonical adoption`.
  - Added unit test: `resetToShared resets dynamic slot overrides to General defaults`.
  - `npm --prefix settings-ui test`: 35/35 passed (0 failures).
- **Frontend typecheck & build:**
  - `npm --prefix settings-ui run typecheck`: Exit code 0 (0 errors).
  - `npm --prefix settings-ui run build`: Exit code 0 (singlefile inlined to `src/webview/web/index.html`).

## 7. Known issues / unfinished

- None. Both bugs are fully fixed, verified by automated unit and narrow regression suites, with clean build outputs.

## 8. Suggested next step

- Proceed with manual acceptance of `fix/a01-hotkey-reset-general` or merge into `dev/wip/slots-parity`.
