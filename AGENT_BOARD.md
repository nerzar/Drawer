# AGENT_BOARD — Drawer autonomous work queue

Этот файл — blackboard между архитектором ChatGPT и coding agents.

**Владелец файла:** архитектор ChatGPT. Coding agents **не редактируют этот файл** и не меняют приоритеты задач сами.

## Как агент начинает работу

1. `git fetch dev`.
2. Прочитать актуальный `AGENT_BOARD.md` из `dev/wip/slots-parity`.
3. Найти задачу, назначенную своей модели/чату.
4. Проверить фактический Git и создать отдельную feature-ветку + worktree от указанного `base`.
5. Выполнить задачу целиком. Не расширять scope без необходимости.
6. Только разумные целевые проверки; VM/full suite не запускать, если задача прямо этого не требует.
7. Перед завершением: commit, push своей feature-ветки в `dev`, clean tree, factual report в `docs/agent-reports/<date>-<agent>-<task>.md`.
8. **Не merge/cherry-pick/rebase обратно в `wip/slots-parity`.** Интеграцию решает архитектор.
9. `docs/ARCHITECT_STATE.md` не редактировать.

Если возник блокер, неоднозначное продуктовое решение, конфликт с параллельной задачей или риск потери данных: не импровизировать. Записать `BLOCKED` в factual report, commit/push ветку и остановиться. Архитектор увидит это в Git.

## Общие правила

- Private repo: `nerzar/Drawer.Dev`, remote `dev`.
- Публичный `origin` не трогать.
- Git CLI/remote — источник истины, UI вторичен.
- Не плодить новые слои, harnesses, документы, worktrees и абстракции без необходимости.
- `drawer-debug.log` и tray action `Нашёл баг…` сохранять и использовать при runtime-диагностике.
- Claude держим в резерве. Astra без отдельного разрешения архитектора не использовать.
- Gemini — основной дешёвый worker. Codex — для сложной логики/многослойных задач.

## Текущая кодовая база

- orchestration branch: `dev/wip/slots-parity`
- code base для параллельной волны: `b2ec249`
- dev diagnostics на `b2ec249` вручную приняты пользователем.
- продуктовый hotkey contract: `docs/03-решения.md`, Р24.

---

## TASK C01 — привести Slots к утверждённому продуктовому контракту

**Status:** READY  
**Executor:** Codex, GPT-5.6 Terra, reasoning High  
**Base:** `b2ec249`  
**Suggested branch:** `feat/slots-product-contract`

### Цель

Привести runtime + Settings + config contract + tests к утверждённой модели слотов.

### Обязательное поведение

- У слота ровно один настраиваемый hotkey: show/hide toggle.
- `Ctrl+Alt+N` — только default для slot N, а не жёстко вшитое действие.
- Hotkey настраивается и у permanent, и у dynamic.
- Отдельного `focusHotkey` в целевой модели нет: удалить концепцию из runtime, Settings, persisted contract и тестов. Старый `focusHotkey` из существующего config не регистрировать и не превращать молча в новый toggle-hotkey.
- Поле hotkey — реальный keyboard capture. UI показывает человеческую комбинацию, пользователь не вводит AHK syntax.
- После `Применить` новый hotkey начинает работать сразу, старый перестаёт; restart не нужен.
- Конфликты проверяются против всех hotkeys Drawer и других slot hotkeys; сообщение человеку должно объяснять конфликт.
- Настроенный hotkey принадлежит номеру слота и переживает restart, пустой dynamic и conversion permanent↔dynamic.
- `Ctrl+Alt+Shift+N` пока остаётся отдельным действием bind active window → dynamic slot N.

### Dynamic

- хранит конкретный HWND только текущей сессии;
- после bind слот сразу считается занятым, сразу имеет кромку и сразу управляется своим hotkey;
- exe живого окна можно показывать как информацию, но не использовать для восстановления dynamic после restart;
- UI должен давать `Освободить слот`;
- UI должен давать сброс индивидуальных dynamic-настроек к General;
- после restart HWND исчезает, но настройки слота и пользовательский hotkey сохраняются.

### Conversion

Dynamic → Permanent:
- если есть живое окно, автоматически подхватить exe, разумное имя и class при необходимости;
- после Apply то же окно остаётся в том же слоте;
- после restart permanent сам ищет приложение;
- пустой dynamic нельзя сохранить permanent без приложения/окна.

Permanent → Dynamic:
- если есть живое окно, после Apply оно остаётся привязанным как dynamic;
- hotkey и кромка не пропадают;
- после restart dynamic пуст;
- если приложение не запущено, conversion даёт пустой dynamic.

### Permanent lifecycle / handles

- если приложение запущено при старте Drawer, кромка появляется сразу;
- если permanent-приложение запускается уже после Drawer, оно должно быть обнаружено и кромка должна появиться без предварительного нажатия hotkey;
- использовать подходящий Windows event lifecycle; не добавлять грубый частый polling без необходимости;
- если у слота есть живое назначенное окно, кромка должна быть видна независимо от permanent/dynamic.

### Диагностика

Сохранить `drawer-debug.log` и `Нашёл баг…`; обновить лог/snapshot под новую hotkey-модель. В конечном snapshot нет `focusHotkey`, есть реально зарегистрированный show/hide hotkey каждого слота.

### Границы

Не начинать следующую архитектурную фазу windows/focus/parking и не исправлять остальные пункты аудита.

### Проверки

`/validate`, settings seam, WebView slice, frontend tests/typecheck/build и целевые regression tests. VM/full suite не нужен. Production build не нужен.

---

## TASK G01 — независимый Settings/build cleanup по аудиту

**Status:** READY  
**Executor:** Gemini, strongest available Gemini mode; NOT Astra  
**Base:** `b2ec249`  
**Suggested branch:** `feat/settings-audit-cleanup-1`

### Граница параллельной работы

Другой агент меняет Slots/hotkeys. Поэтому **не трогать**:

- `src/Slots.ahk`;
- slot hotkeys / conversion semantics;
- `settings-ui/src/views/SlotsView.vue`;
- `drawer-debug.log` / `Нашёл баг…`, кроме безопасной build-интеграции.

### Задача

1. **Двойная шапка Settings**
   - оставить native Windows titlebar;
   - убрать внутренний WebView header/titlebar с дублирующими logo/title/minimize/close;
   - custom chrome не делать;
   - через DWM, если поддерживается текущей Windows, привести системный titlebar к текущей теме Drawer: caption background/text/border/dark mode из существующей палитры; системные drag/resize/min/max/close и fallback сохранить.

2. **Build/config safety**
   - fresh package получает default `config.ini`;
   - rebuild существующей package-папки не должен молча затирать пользовательский/acceptance `config.ini`;
   - не вводить новую систему конфигурации.

3. **About / mock элементы**
   - GitHub action должна вести на настоящий проект;
   - fake/mock действия убрать или сделать рабочими;
   - не показывать ложный путь к config;
   - если реальный runtime path нельзя получить без пересечения с параллельной backend-задачей — корректно скрыть/переименовать и отметить в отчёте.

4. **Небольшой UI cleanup вне Slots**
   - читаемость option/select в dark theme;
   - нормальные label/checkbox click targets;
   - keyboard accessibility интерактивных color controls;
   - убрать очевидные декоративные controls, выглядящие рабочими, но ничего не делающие.

### Не делать сейчас

- General+override correctness;
- partial/retryable/reconcile;
- hideOnBlur/blurMs correctness;
- redesign;
- Slots changes.

### Проверки

Frontend tests/typecheck/build + необходимые build/narrow checks. VM/full suite не нужен.

---

## После C01 + G01

Архитектор проверяет remote branches и diff, затем создаёт отдельную integration-задачу. Coding agents сами ветки не сливают.

Следующая плановая волна после принятой интеграции:

- Settings correctness: General+override same Save, stale windowClass, partial/retryable/diagnostics, hideOnBlur/blurMs, General save-lock, custom animation, build/config follow-up;
- UX cleanup leftovers;
- только затем продолжение архитектуры windows/focus/parking.
