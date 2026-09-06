# AGENT_BOARD — Drawer autonomous work queue

Blackboard между архитектором ChatGPT и coding agents.

**Владелец файла:** архитектор ChatGPT. Coding agents этот файл не редактируют и приоритеты сами не меняют.

## Общий протокол

1. `git fetch dev`.
2. Прочитать актуальный `AGENT_BOARD.md` из `dev/wip/slots-parity`.
3. Прочитать `docs/agent-reports/REPORT_FORMAT.md` из `dev/wip/slots-parity`.
4. Взять только задачу, чей Run ID дан оператором в чате.
5. Проверить Git фактами и создать/использовать указанный отдельный worktree.
6. Выполнить задачу целиком, не расширяя scope.
7. Разумные целевые проверки; VM/full suite только если задача прямо требует.
8. Перед завершением: factual report, commit, push feature-ветки в `dev`, clean tree.
9. Не merge/cherry-pick/rebase в `wip/slots-parity` без отдельной integration-задачи.
10. `docs/ARCHITECT_STATE.md` не редактировать.

Если есть блокер, неоднозначное продуктовое решение, конфликт с параллельной задачей или риск потери данных: записать `BLOCKED` в factual report, commit/push безопасное состояние и остановиться.

## Обязательная идентификация чата/запуска

Каждая задача получает **Run ID** от архитектора/оператора. Агент обязан повторить его в factual report и финальном ответе.

Формат отчёта строго по `docs/agent-reports/REPORT_FORMAT.md`: Task ID, Run ID, client, model, chat/session ID если реально доступен, chat title если доступен, Search anchor, timestamps, worktree, branch, base SHA, final SHA.

Chat/session ID **не придумывать**. Если клиент его не показывает — `NOT_EXPOSED`. Search anchor обязателен и должен быть также в финальном ответе агента.

## Изоляция параллельных агентов

- Два одновременно работающих агента никогда не используют один working tree.
- Worktree нельзя создавать внутри другого repo/worktree.
- Канонический корень параллельных worktree: `C:\Users\nerza\Projects\drawer-agent-worktrees\<task-id>`.
- Перед стартом: `git worktree list`; каталог задачи должен быть уникальным.
- Незакоммиченная работа другого агента не трогается.
- Удалять worktree только после safe commit+push.
- Публичный `origin` не трогать; private remote — `dev` (`nerzar/Drawer.Dev`).

## Общие правила

- Git CLI/remote — источник истины.
- Не плодить слои/harnesses/docs/абстракции без необходимости.
- `drawer-debug.log` и tray action `Нашёл баг…` сохранять.
- Claude — резерв. Astra без отдельного решения архитектора не использовать.
- Gemini — основной дешёвый worker; Codex — сложная логика/многослойные задачи.
- Frontend typecheck: `npm --prefix settings-ui run typecheck`; внешний `npx vue-tsc` не использовать как gate.
- VM/full `safe` suite не является default gate.

---

# Текущее фактическое состояние

- orchestration branch: `dev/wip/slots-parity`.
- diagnostics base `b2ec249` вручную принята пользователем.
- T00 typecheck investigation: `dev/chore/frontend-local-typecheck@9c856ea`; код менять не потребовалось, локальный `tsc` уже корректен.
- Wave 1 integration опубликована: `dev/integration/slots-settings-wave1@ac63ead`.
- C01 + G01 объединены; permanent `Имя` снова редактируется; `Tab` не захватывается полем hotkey; narrow/frontend checks зелёные.
- **Wave 1 ещё не считается полностью принятой базой**, потому что production build в isolated worktree завершился `Ahk2Exe` exit code 17. Это отдельный активный blocker B01.
- Static review архитектора заметил, что на integration branch `ApplyDwmTitlebarTheme` определён и в `src/drawer.ahk`, и в `src/webview/SettingsWebView.ahk`. Не считать это заранее причиной exit 17, но B01 обязан проверить дублирование и оставить одну корректную реализацию, если оно реально участвует в build/runtime.
- `wip/slots-parity` пока содержит orchestration docs и не передвинут на integration code, чтобы не скрыть build blocker.

---

# ACTIVE WAVE — две отдельные папки

## TASK C02 — General + dynamic override в одном Save

**Status:** READY  
**Executor:** Codex, GPT-5.6 Terra High  
**Run ID:** `RUN-20260906-CODEX-C02-01`  
**Base:** `dev/integration/slots-settings-wave1@ac63ead`  
**Branch:** `fix/settings-general-override-atomic`  
**Worktree:** `C:\Users\nerza\Projects\drawer-agent-worktrees\C02`

### Подтверждённый дефект

Old General=70, slot override=50. В одном Apply пользователь меняет General→50 и slot→70. Текущий plan сравнивает slot с **old General 70**, считает override лишним и удаляет его; затем General становится 50, поэтому slot ошибочно получает 50.

### Требование

- Планировать dynamic slot overrides относительно **финального General state этого же Save**, а не старого canonical.
- Один Save должен давать ровно результат текущего draft.
- Добавить regression на описанный сценарий и симметричные no-op/delete cases.
- Не переписывать persistence pipeline заново.
- Не трогать DWM/build/toolchain/B01 area.

### Проверки

AHK `/validate`, settings-seam, webview-slice, relevant frontend tests/typecheck/build. VM/full suite не нужен. Production package build не нужен для C02.

Перед завершением: factual report по REPORT_FORMAT, commit, push `dev/fix/settings-general-override-atomic`, clean tree. Не merge.

---

## TASK B01 — восстановить production build и проверить config-preservation

**Status:** READY  
**Executor:** Gemini, strongest available Gemini mode; NOT Astra  
**Run ID:** `RUN-20260906-GEMINI-B01-01`  
**Base:** `dev/integration/slots-settings-wave1@ac63ead`  
**Branch:** `fix/integration-production-build`  
**Worktree:** `C:\Users\nerza\Projects\drawer-agent-worktrees\B01`

### Причина

Integration I01 прошла `/validate`, settings-seam, webview-slice, frontend test/typecheck/build, но production `build/build.ps1` в isolated worktree упал на `Ahk2Exe` exit code 17 при компиляции `src/drawer.ahk`. G01 build/config safety нельзя считать проверенной, пока production build не проходит.

### Задача

1. Воспроизвести exit 17 из отдельного worktree и получить фактическую причину, а не гадать по коду возврата.
2. Проверить integration-only состояние вокруг DWM. На branch одновременно видны определения `ApplyDwmTitlebarTheme` в `src/drawer.ahk` и `src/webview/SettingsWebView.ahk`; выяснить, является ли это ошибочным дублированием/причиной compile failure. Если да — оставить одну реализацию с полным нужным поведением: dark mode + caption/text/border colors + fallback, без custom chrome.
3. Исправить только build/integration defect; не брать Settings correctness C02/C03 и не менять slot semantics.
4. Production build должен завершаться успешно.
5. Проверить build/config safety:
   - fresh output получает default `config.ini`;
   - изменить этот `config.ini`, повторить build → файл остаётся изменённым, не затирается;
   - release zip не содержит `.log`;
   - WebView assets реально embedded, как проверяет build script.
6. Если exit 17 вызван только некорректной локальной установкой/копированием Ahk2Exe, а код исправлять не нужно — зафиксировать точную причину и воспроизводимый правильный способ запуска; не вносить фиктивный code change.

### Проверки

Production build обязателен; плюс AHK `/validate` и узкие checks, затронутые фактическим исправлением. VM/full suite не нужен.

Перед завершением: factual report по REPORT_FORMAT, commit (report-only допустим, если code change не нужен), push `dev/fix/integration-production-build`, clean tree. Не merge.

---

# NEXT — после C02 + B01

## TASK I02 — интегрировать C02 + B01 + orchestration docs

**Status:** BLOCKED_ON_C02_B01

Создать единую base branch, сохранить integration Wave 1, build fix, C02 и свежие `AGENT_BOARD.md`/`REPORT_FORMAT.md`; затем архитектор проверяет remote и только после этого передвигает `wip/slots-parity`.

## TASK A01 — короткая ручная приёмка

**Status:** BLOCKED_ON_I02  
**Executor:** пользователь

Проверить обычными действиями: custom show/hide hotkey, смена hotkey без restart, Tab из hotkey field, editable permanent name, dynamic bind/release/reset, permanent↔dynamic с живым окном, handle после bind, late permanent launch, native dark titlebar/About. При баге: `Нашёл баг…`, затем сообщить архитектору номер BUG + действие/результат.

---

# BACKLOG — Settings correctness

## TASK C03 — partial/retryable/diagnostics correctness
**Status:** BLOCKED_ON_C02
**Preferred executor:** Codex Terra High / Opus reserve

Structured partial-save/reload/reconcile должен доходить до UI; без ложного `Сохранено`, потери draft/field diagnostics и исчезновения warning после no-op. Один persistence path, без фиктивного rollback.

## TASK G02 — stale windowClass + picker identity
**Status:** BLOCKED_ON_I02
**Preferred executor:** Gemini

Смена exe не оставляет class старого app; picker согласованно обновляет exe/class/name seed; dynamic→permanent получает чистые identity data. Не менять FindWindow больше необходимого.

## TASK G03 — live hideOnBlur/blurMs + save lock
**Status:** BLOCKED_ON_I02
**Preferred executor:** Gemini / Codex при runtime race

После Apply runtime-настройки реально влияют на уже показанное окно; blur timer не stale; General inputs защищены во время Save.

## TASK G04 — custom animation preset `Своя`
**Status:** BLOCKED_ON_I02
**Preferred executor:** Gemini

Custom animation duration/steps сохраняются, корректно отображаются и не сбрасываются preset/canonical.

---

# BACKLOG — UX

## TASK G05 — Slots terminology/onboarding
**Status:** BLOCKED_ON_SETTINGS_CORRECTNESS

Убрать INI/internal jargon; ясно объяснить Permanent/Dynamic; хороший empty dynamic onboarding; release/reset очевидны; без redesign.

## TASK G06 — navigation/accessibility/polish
**Status:** BLOCKED_ON_SETTINGS_CORRECTNESS

Selected slot сохраняется между tabs; scrollbar/list behavior; remaining labels/select/contrast/keyboard issues; About follow-up.

---

# BACKLOG — modular architecture после стабилизации

## TASK A02 — windows/focus seam
**Status:** BLOCKED_ON_STABILIZATION
**Preferred executor:** Codex Terra High / Opus reserve

Вынести оконную модель `state`, `watched`, Show/Hide, focus/foreground lifecycle за явный seam без изменения поведения.

## TASK A03 — parking/geometries seam
**Status:** BLOCKED_ON_A02

## TASK A04 — handles seam
**Status:** BLOCKED_ON_A02_A03

## TASK A05 — Settings service + tray seams
**Status:** BLOCKED_ON_A02_A04

---

# TEST / RELEASE DEBT

## TASK T01 — stale VM/safe tests
**Status:** PARKED_UNTIL_ARCH_STABLE

## TASK T02 — common VM/test helper
**Status:** PARKED_UNTIL_T01

## TASK R01 — diagnostics production policy
**Status:** BLOCKED_ON_STABILIZATION

Bounded/rotated debug log, dev/release policy, сохранить `Нашёл баг…`, без logging framework.

## TASK R02 — production build acceptance
**Status:** BLOCKED_ON_STABILIZATION

Fresh build, rebuild preserving config, compiled Settings, clean package/version metadata.

## TASK R03 — final human acceptance
**Status:** BLOCKED_ON_1_0_BLOCKERS

---

# FUTURE PRODUCT

## F01 — arbitrary slots
**Status:** FUTURE_PRODUCT_DECISION

## F02 — Add/Delete slot UI
**Status:** BLOCKED_ON_F01

## F03 — handle context menu + tray slot actions
**Status:** BLOCKED_ON_F01_F02

## F04 — reset semantics
**Status:** FUTURE_AFTER_F02

## F12 — concrete permanent-window selection
**Status:** DEFERRED_PRODUCT

## F08 — remove parked window from Alt+Tab
**Status:** DEFERRED_RISKY

## F11 — autostart
**Status:** DEFERRED_UNTIL_DAILY_USE

---

# Ближайший порядок

1. Сейчас параллельно: `RUN-20260906-CODEX-C02-01` + `RUN-20260906-GEMINI-B01-01` в отдельных sibling worktree.
2. I02 integration.
3. A01 короткая ручная приёмка.
4. C03 + один из G02/G03/G04 параллельно.
5. Остальной Settings correctness.
6. UX cleanup.
7. Modular architecture.
8. Test/release debt.
9. Future product отдельно.
