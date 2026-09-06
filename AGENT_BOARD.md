# AGENT_BOARD — Drawer autonomous work queue

Blackboard между архитектором ChatGPT и coding agents.

**Владелец файла:** архитектор ChatGPT. Coding agents этот файл **не редактируют** и приоритеты сами не меняют.

## Общий протокол агента

1. `git fetch dev`.
2. Прочитать актуальный `AGENT_BOARD.md` из `dev/wip/slots-parity`.
3. Найти задачу для своей модели/чата.
4. Проверить фактический Git. Продолжать указанную feature-ветку либо создать отдельную от указанного base.
5. Выполнить задачу целиком, не расширяя scope.
6. Разумные целевые проверки; VM/full suite — только если задача требует.
7. Перед завершением: commit, push feature-ветки в `dev`, clean tree, factual report в `docs/agent-reports/<date>-<agent>-<task>.md`.
8. **Не merge/cherry-pick/rebase в `wip/slots-parity`** без отдельной integration-задачи.
9. `docs/ARCHITECT_STATE.md` не редактировать.

Если есть блокер, неоднозначное продуктовое решение, конфликт с параллельной задачей или риск потери данных: записать `BLOCKED` в factual report, commit/push текущее состояние и остановиться.

## Общие правила

- Private repo: `nerzar/Drawer.Dev`, remote `dev`.
- Публичный `origin` не трогать.
- Git CLI/remote — источник истины.
- Не плодить сущности/слои/harnesses/docs/worktrees без необходимости.
- `drawer-debug.log` и `Нашёл баг…` сохранять и использовать для runtime-диагностики.
- Claude — резерв. Astra без отдельного решения архитектора не использовать.
- Gemini — основной дешёвый worker; Codex — сложная логика/многослойные задачи.
- Сильный агент получает целую задачу и доводит её до результата. Не устраивать автоматические review-loop'ы и бесконечные fix/test циклы.
- Два параллельных агента — нормальный режим, но задачи должны быть разведены по файлам/границам. Больше двух одновременно пока не запускать без отдельного решения архитектора.

## Текущая база

- orchestration branch: `dev/wip/slots-parity`
- общая code base первой параллельной волны: `b2ec249`
- diagnostics на `b2ec249` вручную приняты пользователем.
- hotkey product contract: `docs/03-решения.md`, Р24.
- старый `docs/05-план-работ.md` полезен как roadmap, но если он расходится с более новым продуктовым контрактом/этим board, приоритет у более нового решения.

---

# ACTIVE WAVE 1

## TASK C01 — Slots product contract

**Status:** NEEDS_FIX_AFTER_REVIEW  
**Executor:** Codex, GPT-5.6 Terra, reasoning High  
**Base:** `b2ec249`  
**Current branch:** `codex/slots-user-contract`  
**Reviewed remote HEAD:** `8708b06`

### Что уже есть в ветке

Ветка запушена и на 2 commits впереди `b2ec249`. Есть новая persisted show/hide hotkey-модель, runtime rebind, immediate dynamic handle seed, late permanent discovery через foreground lifecycle и часть conversion/runtime изменений.

### Review: задача пока НЕ завершена

Исправить в ЭТОЙ ЖЕ ветке, не начинать заново:

1. **WebView hotkey capture не реализован.** Сейчас permanent и dynamic всё ещё используют обычный `<input type="text" v-model="draft.hotkey">`. Требование — настоящий keyboard capture: клик/фокус в поле → пользователь нажимает комбинацию → UI показывает человеческое значение. Ручной ввод AHK/text syntax не является целевым UX.

2. **В permanent UI остался противоречащий контракту старый блок:** `Основной хоткей Ctrl + Alt + N / не настраивается`. Его не должно быть: единственный show/hide hotkey ниже — настраиваемый, а `Ctrl+Alt+N` лишь default.

3. **Dynamic UI не получил обязательные действия:**
   - `Освободить слот` для занятого dynamic;
   - `Сбросить настройки слота` / reset индивидуальных dynamic behavior overrides обратно к General.
   Backend release уже существует; не заводить вторую реализацию.

4. После этих правок проверить, что WebView и native fallback не расходятся по смыслу одного hotkey и lifecycle.

5. Добавить factual report для C01 в `docs/agent-reports/`; предыдущий push его не содержит.

### Полный контракт, который всё ещё обязателен

- один настраиваемый show/hide hotkey на slot;
- `Ctrl+Alt+N` только default;
- permanent + dynamic оба настраиваются;
- `focusHotkey` отсутствует в целевой runtime/UI/persisted модели и не регистрируется;
- hotkey применяется сразу после Apply, старый отключается;
- конфликты с hotkeys Drawer и других slots объясняются человеку;
- hotkey принадлежит номеру slot и переживает restart / пустой dynamic / conversion;
- `Ctrl+Alt+Shift+N` остаётся bind active window → dynamic N;
- dynamic bind сразу даёт occupied state + handle + управление;
- dynamic HWND не переживает restart, настройки/hotkey переживают;
- Dynamic→Permanent подхватывает live window exe/name/class при необходимости и не теряет окно;
- Permanent→Dynamic сохраняет live window до restart;
- permanent app уже запущен при Drawer start → handle сразу;
- permanent app запущен позже → handle появляется без предварительного hotkey;
- живое назначенное окно → handle виден независимо от lifecycle;
- bug log/snapshot отражает реальный show/hide hotkey, без `focusHotkey`.

### Проверки

`/validate`, settings seam, WebView slice, frontend tests/typecheck/build и целевые regression tests. VM/full suite и production build не нужны.

После исправления: commit + push в `dev/codex/slots-user-contract`, clean tree, factual report. Не merge в `wip/slots-parity`.

---

## TASK G01 — Settings/build cleanup по аудиту

**Status:** IN_PROGRESS_OBSERVED  
**Executor:** Gemini, strongest available Gemini mode; NOT Astra  
**Base:** `b2ec249`  
**Current branch:** `feat/settings-ui-build-cleanup`  
**Latest observed remote HEAD:** `8d01da3`

Параллельно другой агент меняет Slots/hotkeys. Поэтому **не трогать** `src/Slots.ahk`, slot hotkeys/conversion semantics, `settings-ui/src/views/SlotsView.vue` и diagnostics runtime.

### Scope

1. Убрать внутренний дублирующий WebView header; оставить native Windows titlebar, без custom chrome. Если DWM поддерживается — приблизить caption background/text/border/dark mode к существующей теме Drawer, сохранив native fallback и системные controls.
2. Build/config safety: fresh package получает default config, rebuild существующей package-папки не затирает пользовательский/acceptance `config.ini`.
3. About/mock: настоящий GitHub action, убрать/оживить fake actions, не показывать ложный config path.
4. Небольшой UI cleanup вне Slots: readable select/options dark theme, labels/checkbox targets, keyboard accessibility color controls, убрать очевидные fake controls.

Не брать сейчас General+override correctness, partial/retryable/reconcile, hideOnBlur/blurMs correctness, redesign или Slots.

Frontend tests/typecheck/build + необходимые build/narrow checks. VM/full suite не нужен. Перед завершением — commit/push/clean/factual report, без merge.

---

# NEXT — после завершения ACTIVE WAVE 1

## TASK I01 — интегрировать C01 + G01

**Status:** BLOCKED_ON_C01_G01  
**Executor:** Gemini по умолчанию; Codex Terra если конфликты затрагивают runtime semantics  
**Base:** будет актуальный `dev/wip/slots-parity` после завершения обеих веток

### Цель

Проверить обе remote feature-ветки, интегрировать их в отдельной integration-ветке и затем fast-forward/merge в `wip/slots-parity` только после зелёных целевых проверок.

### Правила

- не терять изменения ни одной ветки;
- если конфликт только механический — решить минимально;
- если конфликт меняет продуктовую семантику Slots/Settings — `BLOCKED`, не гадать;
- после интеграции `/validate`, settings seam, WebView slice, frontend tests/typecheck/build; production build только если G01 трогал packaging настолько, что без него safety не проверяется;
- VM/full suite не нужен.

После успешной интеграции обновить `PROJECT_STATE.md` и factual integration report. `docs/ARCHITECT_STATE.md` не трогать.

---

## TASK A01 — ручная приёмка интегрированных Slots + Settings shell

**Status:** BLOCKED_ON_I01  
**Executor:** пользователь, инструкции готовит архитектор  
**Code changes:** нет

Короткая человеческая приёмка без терминов реализации:
- show/hide custom hotkeys;
- hotkey меняется сразу;
- dynamic bind/release/reset;
- permanent↔dynamic с живым окном;
- кромка сразу после bind;
- permanent app запускается позже → кромка появляется;
- Settings titlebar/About/build config safety визуально/поведенчески.

Если найден баг: воспроизвести → `Нашёл баг…` → коротко описать → сообщить архитектору только номер BUG и действие/результат.

---

# WAVE 2 — Settings correctness

Запускается после I01; можно делить на два параллельных потока, но только после проверки пересечения файлов.

## TASK C02 — атомарная корректность Save: General + dynamic overrides

**Status:** BLOCKED_ON_I01  
**Preferred executor:** Codex Terra High / старый Opus в Codex как резерв

### Подтверждённый дефект

Если старый General=70, override slot=50, а одним Apply пользователь меняет General→50 и slot→70, план сравнивает slot с **старым** General 70, удаляет override, потом General становится 50 — в итоге slot ошибочно получает 50.

### Требование

Планировать slot overrides относительно **финального General state этого же Save**, а не старого canonical. Один Save должен давать тот результат, который видит пользователь в черновике.

Добавить regression именно на этот сценарий и симметричные no-op/delete случаи. Не переписывать persistence pipeline заново.

---

## TASK C03 — Settings partial/retryable/diagnostics correctness

**Status:** BLOCKED_ON_I01  
**Preferred executor:** Codex Terra High; Opus reserve если понадобится

### Scope

- structured partial-save/reload/reconcile outcome должен реально доходить до UI;
- distinguish retryable/partial/reloaded state без ложного `Сохранено`;
- field diagnostics не теряются;
- draft не уничтожается при частичном/неуспешном Save;
- warning/diagnostics не исчезают из-за следующего no-op save;
- не обещать rollback, которого нет.

Сохранить один persistence path.

---

## TASK G02 — stale windowClass + picker/app identity hygiene

**Status:** BLOCKED_ON_I01  
**Preferred executor:** Gemini; Codex если выяснится глубокая runtime-семантика

### Scope

- смена exe не должна молча оставлять class от предыдущего приложения;
- выбор окна должен согласованно обновлять exe/class/name seed;
- dynamic→permanent с живым окном должен получать разумные identity данные без скрытого stale class;
- UI должен объяснять class как уточнение, а не заставлять пользователя знать AHK.

Не менять правило permanent FindWindow больше необходимого; отдельный выбор конкретного документа/чата — будущая задача F12.

---

## TASK G03 — live Settings behavior + save lock

**Status:** BLOCKED_ON_I01  
**Preferred executor:** Gemini, эскалация Codex при runtime race

### Scope

- `hideOnBlur` и связанные runtime-настройки после Apply должны влиять на уже показанное окно предсказуемо;
- `blurMs`/таймер должны принять новое значение без stale watcher state;
- General inputs должны блокироваться/защищаться во время Save так же, как Slots, чтобы поздний ввод не был перетёрт canonical response;
- не добавлять второй state manager.

---

## TASK G04 — custom animation preset correctness

**Status:** BLOCKED_ON_I01  
**Preferred executor:** Gemini

Исправить bug пресета `Своя`: пользовательские значения animation duration/steps должны сохраняться, корректно отображаться и не сбрасываться пресетом/канонизацией. Целевые frontend/backend seam tests.

---

# WAVE 3 — UX cleanup после correctness

## TASK G05 — Slots terminology/onboarding cleanup

**Status:** BLOCKED_ON_WAVE2  
**Preferred executor:** Gemini

### Scope

- убрать INI/internal jargon (`[dynamic]`, `[dynamicSlotN]`) из пользовательских подписей;
- ясно объяснить Permanent vs Dynamic обычным языком;
- empty dynamic: понятный onboarding «сделайте окно активным и назначьте...»;
- release/reset actions должны быть очевидны;
- exe dynamic показывать как информацию о живом окне, а не как постоянную привязку;
- не возвращать отдельный focus hotkey;
- сохранить одобренный общий layout, без redesign.

---

## TASK G06 — Settings navigation/accessibility/polish leftovers

**Status:** BLOCKED_ON_G01_WAVE2  
**Preferred executor:** Gemini

### Scope

- выбранный slot не должен сбрасываться при переходе между tabs;
- scrollbar/list behavior при 9 слотах и будущем росте;
- positioning reset/add-related controls только там, где они уже существуют;
- оставшиеся label/select/contrast/keyboard accessibility дефекты;
- убрать ложные/технические подписи;
- проверить About после интеграции.

Не начинать произвольные slots/Add/Delete в этом этапе.

---

# WAVE 4 — архитектура после стабилизации Settings

Все задачи ниже **не стартовать до принятой ручной приёмки Waves 1–3**. Поведение менять нельзя без отдельного продуктового решения.

## TASK A02 — вынести windows/focus seam из drawer.ahk

**Status:** BLOCKED_ON_STABILIZATION  
**Preferred executor:** Codex Terra High / Opus reserve

Вынести оконную модель (`state`, `watched`, Show/Hide, focus/foreground predicates, related lifecycle) по одному явному seam. Modular monolith, не новый framework. Сначала граница/контракт, потом перенос. Не менять поведение.

---

## TASK A03 — parking/geometries module seam

**Status:** BLOCKED_ON_A02  
**Preferred executor:** Codex Terra или Gemini после чёткой границы

Отделить CaptureOrigin/ComputeGeom/parking-related logic от orchestration без изменения поведения. Сохранить multi-monitor edge rules и внутренний край без анимации на соседний монитор.

---

## TASK A04 — handles module seam

**Status:** BLOCKED_ON_A02_A03  
**Preferred executor:** Gemini, Codex при сложных lifecycle conflicts

Вынести handles/edge UI и sync lifecycle из монолита за явный Slot/window API. Никакой второй модели slot state.

---

## TASK A05 — Settings/service + tray seams

**Status:** BLOCKED_ON_A02_A04  
**Preferred executor:** Gemini

Уменьшить `drawer.ahk`, отделив Settings service orchestration и tray actions после стабилизации предыдущих границ. Не дублировать persistence/runtime paths.

---

# WAVE 5 — test infrastructure debt

## TASK T01 — решить судьбу stale VM/safe tests

**Status:** PARKED_UNTIL_ARCH_STABLE  
**Preferred executor:** Gemini

- разобраться с нестабильными `setstat`/F11/F12 сценариями;
- убрать stale проверки из default safe либо сделать их детерминированными;
- не превращать VM в обязательный gate для каждой правки;
- сохранить быстрые narrow tests главным feedback loop.

---

## TASK T02 — общий helper для VM/test drivers

**Status:** PARKED_UNTIL_T01  
**Preferred executor:** Gemini

Вынести повторяющиеся `Check`, `Out`, `OnScreen`, `PosOf`, `WaitOn` в общий helper без изменения сценариев. Только если это реально сокращает поддержку; не плодить abstraction ради abstraction.

---

# FUTURE PRODUCT — после стабильной 1.0-базы

## TASK F01 — произвольное количество слотов

**Status:** FUTURE_PRODUCT_DECISION  
**Preferred executor:** Codex/Opus architecture + Gemini UI

Убрать фундаментальный лимит 1–9. Номер перестаёт быть частью фундаментальной identity hotkey. Существующим слотам сохранить `Ctrl+Alt+1…9` как defaults. Нужен отдельный дизайн migration/config/UI; не начинать автоматически.

---

## TASK F02 — Add/Delete slot UI

**Status:** BLOCKED_ON_F01

Добавить `Добавить слот` / `Удалить слот`, empty states и безопасное удаление занятого dynamic/permanent. Не делать до новой slot identity model.

---

## TASK F03 — context menu на кромке + tray slot actions

**Status:** BLOCKED_ON_F01_F02

Контекстное меню ПКМ кромки, полезные slot actions и расширенный tray. Без Hide all/Show all/search, пока отдельно не решено.

---

## TASK F04 — reset semantics

**Status:** FUTURE_AFTER_F02

Два независимых действия:
- сброс slot bindings/settings;
- полный reset Drawer к defaults.

Нужны чёткие confirmation/what-is-lost semantics.

---

## TASK F12 — выбор конкретного окна permanent app

**Status:** DEFERRED_PRODUCT  
**Preferred executor:** Codex/Opus

Сейчас permanent ищет по exe + optional class и при нескольких кандидатах выбирает самое большое. Отбор конкретного документа/чата/последнего активного окна требует отдельного продуктового решения. Не менять FindWindow эвристики случайно в других задачах.

---

## TASK F08 — убрать припаркованное окно из Alt+Tab

**Status:** DEFERRED_RISKY

Потребует временного `WS_EX_TOOLWINDOW` и гарантированного восстановления style при штатном/аварийном завершении. Не брать без отдельной причины.

---

## TASK F11 — autostart

**Status:** DEFERRED_UNTIL_DAILY_USE

Добавлять только после длительной ручной эксплуатации стабильной сборки.

---

# RELEASE PREP — когда продуктовые и architecture blockers закрыты

## TASK R01 — diagnostics production policy

**Status:** BLOCKED_ON_STABILIZATION  
**Preferred executor:** Gemini

Определить dev/release режим логирования; ограничить/ротировать `drawer-debug.log` (например, bounded size), сохранить `Нашёл баг…` полезным для beta. Не раздувать отдельную logging subsystem.

---

## TASK R02 — production build + clean config acceptance

**Status:** BLOCKED_ON_G01_AND_STABILIZATION

Fresh build, rebuild with existing config, compiled Settings, clean package contents, version metadata. Проверить, что build не уничтожает пользовательский config.

---

## TASK R03 — финальная человеческая acceptance matrix

**Status:** BLOCKED_ON_ALL_1_0_BLOCKERS  
**Executor:** пользователь; архитектор выдаёт короткий checklist

Реальные окна, 1/2 monitor, dynamic/permanent, hotkeys, handles, Settings, restart, late app launch, exit/cleanup. VM только там, где она действительно добавляет покрытие.

---

# Порядок ближайших волн

1. **Сейчас:** C01 + G01.
2. I01 integration.
3. A01 короткая ручная приёмка.
4. Wave 2 correctness: C02/C03 + G02/G03/G04, по две непересекающиеся задачи одновременно.
5. Wave 3 UX: G05/G06.
6. Только после этого A02→A05 modular architecture.
7. Test debt / release prep.
8. Future arbitrary slots/product features отдельно, не смешивать с 1.0 stabilization.

Архитектор при каждом завершении задачи обновляет статусы, reviewed HEAD и назначает следующую пару. Агенты сами backlog не переставляют и не начинают BLOCKED/FUTURE задачи.