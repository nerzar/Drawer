# G05A — Slots terminology/onboarding UX analysis

- Task ID: `G05A`
- Run ID: `RUN-20260906-CHATGPT-DEV1-G05-ANALYSIS-01`
- Agent/client: `ChatGPT browser/GitHub-native`
- Model: `GPT-5.6 Sol`
- Chat/session ID: `NOT_EXPOSED`
- Chat title: `NOT_EXPOSED`
- Search anchor: `Drawer G05A Slots onboarding terminology UX — ChatGPT DEV1 — 20260906`
- Started at: `2026-09-06T13:44:14+03:00` (task-assignment commit timestamp; first precise task-adjacent timestamp available)
- Finished at: `2026-09-06T13:48:37+03:00`
- Worktree: `N/A — GitHub-native repo-only run; local worktree requirements waived by task`
- Branch: `analysis/g05-slots-ux`
- Base SHA: `08a3e6cf24fb67af05a1e7f332366bd3cf96ef32` (`dev/wip/slots-parity` at branch creation)
- Analyzed production candidate: `e4136c577d52e2fbf0b57d65b8344809236d5985` (`dev/integration/slots-settings-wave4`)
- Final SHA: `PENDING_FINAL_COMMIT`
- Remote: `dev`

## 1. Goal

Prepare a narrow, code-grounded UX cleanup plan for the Slots tab after A01FIX/G02 without changing runtime/product behavior. The focus is terminology, empty-slot onboarding, release/reset clarity, internal jargon leakage, and the known narrow-pane debt around the reset-to-General block.

Product semantics explicitly preserved by this plan:

- one configurable show/hide hotkey per slot;
- `Ctrl+Alt+N` is a default, not a permanently fixed show/hide combination;
- `Ctrl+Alt+Shift+N` remains the fixed dynamic bind shortcut;
- Apply/OK commit draft edits; Cancel discards them;
- Release immediately removes a live dynamic window binding but does not reset slot behavior;
- Reset-to-General changes the dynamic slot behavior draft and does not release its live window;
- no F12/specific-window selector, arbitrary-slot redesign, new persistence model, or slot architecture changes.

## 2. Result

Recommendation: **`READY_TO_IMPLEMENT`**.

The current UI already exposes all required product operations, but several labels describe implementation rather than intent. The largest onboarding gap is an empty dynamic slot: the view says the slot is `пусто`, shows fake `Имя`/`Файл (exe)` rows, and offers conversion/settings controls, but does not tell the user how to perform the primary dynamic action — activate a window and press `Ctrl+Alt+Shift+N`.

The cleanup can stay behavior-neutral and mostly inside `settings-ui/src/views/SlotsView.vue`, with an optional small wording change in `settings-ui/src/bridge/slots.ts`. No backend, bridge, protocol, slot-draft, or persistence changes are needed.

## 3. Commits

This run creates only this report on `dev/analysis/g05-slots-ux`. No production source file is modified.

## 4. Current UX/copy inventory

### 4.1 Slot list

Current list shows:

- row label from configured permanent name, dynamic application name when bound, otherwise `Слот N`;
- status texts from `settings-ui/src/bridge/slots.ts`: `пусто`, `не запущено`, `запущено`, `убрано`, `на экране`;
- behavior summary: edge, monitor, width;
- kind pill: `Постоянный` / `Динамический`.

Issue: `Динамический` is an implementation/model term. It does not tell a new user that the binding is temporary/session-lived and is assigned to the currently active window. `Постоянный` is more understandable but still only becomes meaningful by contrast.

Classification: **copy-only**.

### 4.2 Detail-header actions

Current actions:

- permanent -> `Сделать динамическим…`;
- bound dynamic -> `Освободить слот`;
- any dynamic -> `Сделать постоянным…`.

The permanent->dynamic button has a title containing internal storage detail: `Секция [slot N] будет удалена по «Применить»`.

Issues:

- `Сделать динамическим` asks the user to understand the data model rather than the effect: the app-specific persistent binding is removed; a currently held window can continue as a temporary binding.
- `Освободить слот` is vague about what is released. It is an immediate runtime unbind, not a reset of slot settings and not an Apply-time draft operation.
- `Сделать постоянным` is understandable only after the user learns what permanent means.
- `[slot N]` is storage jargon with no user value.

Classification: **copy-only**.

### 4.3 Permanent editor identity copy

Current visible/interactive copy includes:

- `Имя`;
- `Файл (exe)`;
- icon buttons titled `Обзор…` and `Окно…`;
- tooltip `Класс окна (ahk_class): ... Уточняет, какое именно окно ловить, если под этим exe их несколько. Заполняется кнопкой «Окно…».`;
- invalid monitor option `в файле: <raw>`;
- hotkey caption `show/hide, применяется сразу`.

Issues:

- `ahk_class` exposes AutoHotkey terminology; the user only needs to know it is an optional window discriminator.
- `под этим exe` is developer vocabulary in explanatory copy.
- icon-only `Обзор…` / `Окно…` does not state whether the user is choosing an executable or sampling identity from an already open window.
- `в файле:` exposes storage instead of saying the current value is invalid and must be chosen again.
- `show/hide` is mixed-language copy.
- `применяется сразу` is ambiguous: the hotkey participates in the settings draft and takes effect after Apply/OK; it does not require Drawer restart after successful Apply.

Classification: **copy-only**. No picker/identity behavior change is needed.

### 4.4 Dynamic editor and empty dynamic state

For a dynamic slot, the UI currently renders:

- `Имя` -> `slotLabel(...)` -> secondary `по умолчанию`;
- `Файл (exe)` -> `(пусто)` -> secondary `по умолчанию`;
- behavior editor for monitor/edge/width/activate/hide;
- show/hide hotkey field;
- override source note;
- free-note explaining inheritance and suggesting permanent conversion.

For an empty dynamic slot, there is **no inline instruction for binding a window**. `SlotsView.vue` imports `releaseSlot` but not `bindSlot`; therefore this view currently relies on the fixed shortcut as the primary bind workflow, yet does not surface that shortcut. The accepted config/runtime contract documents `Ctrl+Alt+Shift+N` as the bind action.

Issues:

- a dynamic slot does not conceptually have an application identity, so `Файл (exe): (пусто)` looks like missing required data rather than a property that simply does not exist in this mode;
- `Имя ... по умолчанию` similarly creates a fake editable-model impression even though dynamic rows are labeled by slot/application state;
- empty-state onboarding prioritizes configuration details over the first action a user needs to perform;
- the fixed bind shortcut is invisible;
- the current free-note says `Сделайте его постоянным, чтобы задать своё приложение и хоткей.` This is misleading for the hotkey: the show/hide hotkey belongs to the slot number and remains configurable independently of whether the slot is permanent or dynamic.

Classification: **copy/conditional-presentation only**; no new bind button or runtime action is required for G05.

### 4.5 Dynamic override source / Reset-to-General

Current source note is generated as either:

- `своё в [dynamicSlotN]: монитор, край, ...`;
- `всё из [dynamic] — общих настроек динамических слотов`.

When overrides exist, the adjacent button is `Использовать общие настройки`.

Runtime/draft semantics are already correct after A01FIX:

- `resetDynamic()` calls `resetToShared()` against `currentShared`;
- `currentShared` includes pending General draft values when present;
- reset does not release the live dynamic window;
- persistence occurs later through Apply/OK.

Issues:

- `[dynamicSlotN]` and `[dynamic]` are direct INI schema leakage;
- `Использовать общие настройки` does not tell the user that only the five behavior parameters are being reset, while the current window binding remains;
- `Release` and reset are conceptually adjacent but affect different things, and the UI does not explain that difference;
- after reset is clicked, canonical overrides can still make the reset control remain visible but disabled until Apply, which can look like the click did nothing unless the changed field values are noticed.

Classification: mostly **copy-only**. Optional pending-feedback copy is presentation-state behavior but does not change Drawer semantics.

### 4.6 Narrow-pane layout debt

`SlotsView.vue` currently styles `.override-box` as a single flex row with `justify-content: space-between`, while `.btn-reset-override` uses `white-space: nowrap`. The source text inside it is `.hotkey-cap`, whose global style still carries `margin: -3px 0 8px 120px`.

At a narrow detail-pane width this combination wastes horizontal space and makes the long reset label compete with the source note. This is exactly the known debt around `Использовать общие настройки`.

`detail-actions` is also a single flex row in the accepted Wave 4 source, so long conversion/release labels have little room on narrower panes.

Classification: **layout-only**.

## 5. Concrete before -> after recommendations

### 5.1 Slot mode terminology

**Before**

- `Постоянный`
- `Динамический`
- `Сделать постоянным…`
- `Сделать динамическим…`

**After — recommended**

- pill: `Постоянный` / `Временный`;
- permanent helper when useful: `Drawer находит это приложение снова после перезапуска.`;
- temporary helper: `Привязка текущего окна живёт до перезапуска Drawer.`;
- action dynamic->permanent: `Закрепить за приложением…`;
- action permanent->dynamic: `Сделать временным…`.

Why: `Временный` maps directly to lifetime; `Закрепить за приложением` describes the intent without requiring users to learn `kind=permanent`.

Type: **copy-only**.

Alternative if consistency is preferred over stronger intent wording: retain `Сделать постоянным…`, but still replace `Динамический` / `Сделать динамическим…` with `Временный` / `Сделать временным…` and add the lifetime helper.

### 5.2 Empty dynamic onboarding

**Before**

- state `пусто`;
- `Имя: Слот N — по умолчанию`;
- `Файл (exe): (пусто) — по умолчанию`;
- no bind instruction.

**After — recommended**

Replace the fake identity rows for an empty temporary slot with a compact onboarding block:

`Слот свободен.`

`Откройте нужное окно и нажмите Ctrl + Alt + Shift + N — оно будет привязано к слоту N до перезапуска Drawer.`

`Ctrl + Alt + N — показать или убрать окно.`

Keep `Закрепить за приложением…` as the existing alternative for a persistent/app-specific setup; do not add a new binding architecture or F12 selector.

For a bound temporary slot, rely on the existing `Состояние` / `Окно` / application label instead of displaying fake empty exe identity rows.

Type: **copy/conditional-presentation only**.

### 5.3 Release vs Reset

**Before**

- `Освободить слот`
- `Использовать общие настройки`
- no nearby explanation of their different scopes.

**After — recommended**

- `Освободить слот` -> `Отвязать окно`;
- reset button -> `Вернуть общие настройки`;
- source/help text:
  - when no own behavior: `Параметры: общие`;
  - when own behavior exists: `Свои параметры: монитор, ширина, автоскрытие`;
  - below/tooltip for Release: `Окно будет отвязано сразу; настройки слота останутся.`;
  - below/tooltip for Reset: `Вернёт параметры слота к общим; привязанное окно останется.`.

After reset is already staged in the draft, replace a mysteriously disabled reset affordance with a short state such as `Будут использованы общие настройки после «Применить»` if implementation can do this locally without new state machinery.

Type: **copy-only**, plus optional presentation-state feedback. Runtime semantics stay unchanged.

### 5.4 Remove INI/AHK jargon

**Before -> after**

- `своё в [dynamicSlotN]: ...` -> `Свои параметры: ...`;
- `всё из [dynamic] — общих настроек динамических слотов` -> `Параметры: общие`;
- title `Секция [slot N] будет удалена по «Применить»` -> `После «Применить» Drawer перестанет автоматически искать это приложение.`;
- `Файл (exe)` -> `Приложение (.exe)`;
- tooltip `Класс окна (ahk_class)` -> `Дополнительный признак окна` / `Класс окна: <value>`;
- `если под этим exe их несколько` -> `если у приложения несколько типов окон`;
- picker title `Обзор…` -> `Выбрать приложение…`;
- picker title `Окно…` -> `Взять данные из открытого окна…`;
- monitor invalid `в файле: <raw>` -> `Некорректное значение: <raw> — выберите монитор`;
- `show/hide, применяется сразу` -> `Показать / убрать; после «Применить» работает без перезапуска Drawer.`.

Type: **copy-only**.

### 5.5 Narrow override block

Recommended local CSS behavior:

- reset `.override-box .hotkey-cap` margin to `0` so the generic 120px editor-label offset does not apply inside the box;
- allow `.override-box` to wrap, or stack source text over the reset button when space is insufficient;
- keep the reset button intact but allow it to move to a second line instead of compressing content;
- allow `.detail-actions` to wrap as a safety net for the longer user-facing labels;
- verify there is no horizontal scrolling/clipping in the right pane at the normal narrow content width used during A01.

Type: **layout-only**.

## 6. What not to change

G05 implementation should deliberately avoid these tempting expansions:

- do not add arbitrary numbers of slots;
- do not implement F12/window targeting or a new window picker flow;
- do not replace `Ctrl+Alt+Shift+N` with a configurable bind shortcut;
- do not add a second hotkey model: show/hide remains one configurable hotkey per slot;
- do not turn Release into an Apply-time persisted edit;
- do not make Reset release the current window;
- do not change permanent/dynamic conversion persistence semantics;
- do not touch slot identity reconciliation from G02;
- do not redesign the entire Settings navigation/sidebar in this task;
- do not expose INI sections as a teaching device.

## 7. Minimal implementation scope

### Required production file

**`settings-ui/src/views/SlotsView.vue`**

Enough for:

- mode/action wording;
- empty-temporary onboarding;
- removal/replacement of fake identity rows;
- internal-jargon cleanup in override note and tooltips;
- Release/Reset explanatory copy;
- hotkey caption correction;
- local narrow-pane CSS fixes.

Existing methods, data-testids, draft mutations and bridge calls should remain intact wherever possible.

### Optional second file

**`settings-ui/src/bridge/slots.ts`** only if the implementation decides to change centralized status text such as `пусто` -> `свободен`. This is not required to deliver the main G05 value.

### Files that should not be needed

- `settings-ui/src/bridge/settings.ts`;
- `settings-ui/src/bridge/slotDraft.ts`;
- `settings-ui/src/bridge/protocol.ts`;
- `src/drawer.ahk`;
- `src/Slots.ahk`;
- `src/webview/SettingsPort.ahk`;
- package/build architecture.

If implementation requires those files, re-check scope before proceeding: the proposed UX cleanup does not require runtime or contract changes.

## 8. Conflict/parallelism risk

### I05 / C03

C03 changed `settings-ui/src/bridge/client.ts`, `protocol.ts`, `settings.ts`, `FooterBar.vue`, `canonical.test.ts`, and `src/webview/SettingsPort.ahk`; it did not change `SlotsView.vue` or `slots.ts`. I05 is integrating that accepted C03 branch into Wave 5.

Therefore direct code collision risk is **low** if G05 implementation is kept to `SlotsView.vue` (+ optional `slots.ts`). The implementation should nevertheless start from the accepted Wave 5/C03-integrated lineage rather than from old Wave 4, so diagnostics/canonical work is not accidentally dropped.

### G03

G03's assigned preferred scope is `src/drawer.ahk`, `settings-ui/src/views/GeneralView.vue`, and targeted tests, with explicit instruction not to broaden into Slots layout. Direct conflict with the proposed G05 production files is **low**.

Avoid modifying shared package/test entrypoints just to assert copy, because that creates unnecessary overlap with G03/C03 test work.

### A01FIX/G02 semantics inside SlotsView

The important local risk is semantic, not Git conflict: `SlotsView.vue` already contains accepted A01FIX/G02 behavior for Reset-to-General, hotkey handling and permanent identity seeding. G05 must preserve methods such as `resetDynamic`, `makeDynamic`, `makePermanent`, `onExecutableInput`, picker calls, `locked`, and their data-testids unless a narrowly justified test-preserving refactor is required.

## 9. Regression / manual acceptance checklist

Because the proposed G05 changes are copy/layout/presentation only, no new backend seam is required. Existing correctness tests for slot draft/reset/identity should remain green.

### Automated gates for implementation

Run on the final implementation lineage:

- `npm --prefix settings-ui test`;
- `npm --prefix settings-ui run typecheck`;
- `npm --prefix settings-ui run build`.

Do not add a DOM test framework just for wording/layout. The current frontend test stack is pure Node/esbuild and already covers important slot draft/reset/identity semantics. If a source-level copy assertion is desired, keep it isolated and do not enlarge the harness.

AHK/settings-seam tests are not necessary for a strictly frontend copy/layout implementation. If implementation unexpectedly touches AHK/bridge/contract, then the scope has expanded and the corresponding gates become mandatory.

### Manual acceptance

1. Empty temporary slot clearly says it is free and shows the exact `Ctrl+Alt+Shift+N` bind instruction for that slot number.
2. `Ctrl+Alt+N` is described only as show/hide; the fixed bind shortcut is not presented as configurable.
3. Dynamic show/hide hotkey remains configurable exactly as before.
4. A bound temporary slot still shows application/window status and `Отвязать окно` performs the same immediate Release action.
5. Releasing a window does not reset monitor/edge/width/activate/hide settings.
6. `Вернуть общие настройки` changes only the dynamic behavior draft; a bound window remains bound.
7. Reset uses pending General draft values in the same Settings session, as A01FIX already guarantees.
8. Reset is not persisted until Apply/OK; Cancel restores the prior applied state.
9. Temporary->permanent conversion still seeds executable/window class from `permanentDefaults` when available and does not invent identity for an empty live state.
10. Permanent->temporary conversion remains draft-only until Apply/OK and retains the accepted live-window semantics.
11. Permanent app picker/existing-window picker work exactly as before.
12. No visible copy mentions `[dynamic]`, `[dynamicSlotN]`, `[slotN]`, or `ahk_class` as concepts the user must understand.
13. Hotkey helper copy does not claim edits are active before Apply; it may state that no restart is required after Apply.
14. At the known narrow detail-pane width, override source text and reset button do not overlap, clip, or force horizontal scroll.
15. Header actions wrap/fit cleanly with the revised labels.
16. At normal/wide width, the existing list/detail visual hierarchy is preserved; this task does not become a redesign.

## 10. Prioritized implementation checklist

### MUST

1. Add explicit empty-temporary-slot onboarding with `Ctrl+Alt+Shift+N` and show/hide shortcut guidance.
2. Replace internal `[dynamic]` / `[dynamicSlotN]` / `[slotN]` wording with user-facing descriptions.
3. Clarify `Release` vs Reset: `Отвязать окно` versus behavior reset that keeps the binding.
4. Replace `Динамический`/`Сделать динамическим` with user-understandable temporary-binding terminology, and make the permanent action describe app persistence.
5. Fix the narrow `.override-box` layout (`.hotkey-cap` inherited margin + no wrapping) without redesigning the pane.

### SHOULD

1. Remove fake dynamic `Файл (exe): (пусто)` / default-name rows and replace them with a binding/lifetime summary.
2. Clean identity tooltips: remove `ahk_class`, explain the second picker as taking identity from an open window.
3. Replace mixed-language/ambiguous hotkey caption with `Показать / убрать; после «Применить» работает без перезапуска Drawer.`
4. Add clear pending-reset feedback after the draft has already been reset but before Apply.
5. Allow detail-header actions to wrap safely at narrow widths.

### LATER

1. Consider localizing global navigation labels (`General`, `Slots`, `About`) in a separate Settings-wide consistency task; do not pull that into G05 unless explicitly assigned.
2. Consider whether a one-click `Привязать активное окно` UI action is desirable in addition to the fixed shortcut. That is a product interaction decision and is not required for onboarding once the shortcut is explained.
3. Broader accessibility/component testing for Settings can be evaluated separately; do not add a large DOM-test stack solely for this cleanup.

## 11. Problems found

- Primary dynamic workflow is undiscoverable from the Slots tab despite being the default mode for all slots.
- Current dynamic detail renders absence of permanent identity as if it were missing data.
- One explanatory sentence incorrectly implies a dynamic slot cannot have its own show/hide hotkey.
- User-facing text leaks three levels of implementation vocabulary: INI section names, `exe`, and `ahk_class`.
- Release and Reset affect different state domains but are not explained in those terms.
- The reset block's current flex/margin rules are structurally hostile to narrow widths.

No architecture or product decision is required to fix the MUST set.

## 12. Tests / verification

No local npm/AHK/runtime tests were run or required for this Run ID. Verification was GitHub/repository-only as explicitly requested.

Repository inspection covered:

- `settings-ui/src/views/SlotsView.vue` on accepted Wave 4;
- `settings-ui/src/bridge/slots.ts`;
- `settings-ui/src/bridge/slotDraft.ts`;
- `settings-ui/src/bridge/protocol.ts`;
- `src/config.ini` hotkey/binding contract;
- A01FIX report for accepted Reset-to-General semantics;
- C03/I05/G03 task scopes and C03 changed-file set for collision analysis.

## 13. Known issues / unfinished

This is analysis only; no UI change was implemented. Exact wording may receive minor product/editorial adjustment during implementation, but the MUST recommendations do not require a new architecture or behavior decision.

## 14. Suggested next step

Implement G05 from the latest accepted correctness lineage (prefer Wave 5 after I05, and include G03 only if already accepted) with `SlotsView.vue` as the primary scope. Preserve all A01FIX/G02 behavior and data-testids, run frontend gates, then do a short manual narrow-pane and empty-slot onboarding acceptance pass.
