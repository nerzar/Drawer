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

## Текущая база

- orchestration branch: `dev/wip/slots-parity`
- общая code base параллельной волны: `b2ec249`
- diagnostics на `b2ec249` вручную приняты пользователем.
- hotkey product contract: `docs/03-решения.md`, Р24.

---

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

## После C01 + G01

Архитектор проверяет remote branches/diff и выдаёт отдельную integration-задачу. После принятой интеграции следующая волна: Settings correctness (General+override same Save, stale windowClass, partial/retryable/diagnostics, hideOnBlur/blurMs, General save-lock, custom animation), затем UX leftovers, и только после этого windows/focus/parking architecture.
