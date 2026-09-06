# G02 — stale windowClass + picker identity

- Task ID: `G02`
- Run ID: `RUN-20260906-ANTIGRAVITY-G02-02`
- Agent/client: `Antigravity`
- Model: `Gemini 3.8 Flash High`
- Chat/session ID: `5e0c175f-362b-4202-8a07-e3194d358acf`
- Chat title: `NOT_EXPOSED`
- Search anchor: `Drawer TASK G02 — stale windowClass + picker identity — antigravity/20260906`
- Started at: `2026-09-06T10:29:44+03:00`
- Finished at: `2026-09-06T10:41:30+03:00`
- Worktree: `C:\Users\nerza\Projects\drawer-agent-worktrees\G02`
- Branch: `fix/settings-picker-identity`
- Base SHA: `4cc0d77dac6beab25a37698172895a3df2267a64`
- Final SHA: `PENDING_FINAL_COMMIT`
- Remote: `dev`

## 1. Goal

Устранить дефект устаревания `windowClass` (stale class) и обеспечить согласованность identity постоянного слота при:
- ручной смене исполняемого файла в поле ввода (`Файл (exe)`);
- выборе нового executable через `picker.exe`;
- выборе окна через `picker.window`;
- переключении `dynamic -> permanent` и обратных переходах, сохраняя семантику Apply/Cancel и валидацию backend (`SettingsSlotValidate`) как источник истины.

## 2. Result

- Дефект полностью подтверждён тестами: на base `picker.exe` и ручной ввод `draft.executable` не сбрасывали `draft.windowClass`, что приводило к сохранению некорректного `ahk_class` старого окна в постоянном правиле слота.
- Реализован минимальный fix в frontend-модели (`slotDraft.ts`, `settings.ts`, `SlotsView.vue`) без изменения архитектуры `FindWindow` и без затрагивания файлов `GeneralView.vue`, `general.ts`, `package.json`, `animationPreset.test.ts`:
  - В `SlotDraft` добавлено отслеживание привязки класса к исполняемому файлу (`classAnchorExe`, `anchorClass`).
  - При ручной правке `executable` старый `windowClass` немедленно очищается в черновике и отображении; если пользователь возвращает то же имя exe (с учётом регистра/пробелов) — валидный класс окна восстанавливается.
  - При выборе нового executable через `picker.exe` старый класс окна и якорь сбрасываются целиком; при повторном выборе того же exe класс сохраняется.
  - При выборе через `picker.window` поля `executable` и `windowClass` выставляются строго согласованно из выбранного окна, якорь обновляется, а имя засеивается заголовком окна, если поле было пустым или дефолтным.
  - В `draftPermanentValue` добавлена строгая проверка согласованности, гарантирующая, что рассинхронизированный класс не попадёт на диск даже в обход UI-контрола.
  - При переключении `dynamic -> permanent` используется чистый seed из `permanentDefaults` (где `executable: ""` и `windowClass: ""`), не выдумывая имя/класс на frontend и делегируя валидацию/привязку к живому окну бэкенду на этапе `Apply`.
  - При циклах `dynamic -> permanent -> dirty -> dynamic -> permanent` черновик повторно очищается до канонического `permanentDefaults`.

## 3. Commits

- `PENDING_FINAL_COMMIT`: `fix(settings-ui): synchronize slot windowClass with executable and picker identity`

## 4. Important decisions

1. **Frontend-first реализация:** доказано, что backend `SettingsSlotValidate` уже корректно обрабатывает конверсию dynamic->permanent по живому `hwnd` и требует валидный `exe` при его отсутствии. Правка бэкенда не потребовалась, исключив риски регрессии в AHK core.
2. **Anchor-механизм против случайной потери при вводе:** класс окна не сбрасывается безвозвратно на первом же нажатом символе в поле ввода. Если пользователь случайно стёр букву и дописал обратно, или нормализованное имя совпадает — класс сохраняется. Но как только выбран/введён новый exe — класс гасится.
3. **Границы параллельности:** файлы I03/G04 (`GeneralView.vue`, `general.ts`, `package.json`, `animationPreset.test.ts`) не модифицировались. Все регрессионные тесты размещены в `settings-ui/test/canonical.test.ts`.

## 5. Problems found

- На Wave 2 `picker.exe` присваивал `draft.executable = result.executable`, игнорируя существующий `draft.windowClass`.
- В `SlotsView.vue` поле `slot-exe` использовало прямой `v-model="draft.executable"`, из-за чего ручной ввод никогда не уведомлял модель о смене файла для очистки класса.
- Переход `makePermanent()` не сбрасывал отменённые/грязные правки exe/class при повторном переключении dynamic->permanent.

## 6. Tests / verification

- `npm --prefix settings-ui test`: 32/32 pass (включая 7 новых таргетированных тестов для G02: ручная смена exe, `picker.exe` new vs same, `picker.window`, `dynamic->permanent` clean seed, цикл сброса грязного черновика, bridge integration).
- `npm --prefix settings-ui run typecheck`: clean (0 errors).
- `npm --prefix settings-ui run build`: clean, singlefile bundle собран без ошибок.
- AHK checks:
  - `AutoHotkey64.exe /validate src\drawer.ahk`: 0 errors.
  - `AutoHotkey64.exe test\narrow\settings-seam.ahk`: все тесты (точки 1-19) OK.

## 7. Known issues / unfinished

- Нет. Все 7 обязательных пунктов TASK G02 выполнены в полном объёме.

## 8. Suggested next step

- Закоммитить изменения в ветку `fix/settings-picker-identity`.
- Выполнить push в `dev/fix/settings-picker-identity`.
- Сверить `remote HEAD == local HEAD`.
- Оставить ветку для последующей controlled integration после A01 (по плану `AGENT_BOARD.md`).
