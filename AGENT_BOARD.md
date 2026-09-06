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

Каждая задача получает **Run ID**. Формат отчёта — строго по `docs/agent-reports/REPORT_FORMAT.md`.

Агент повторяет Run ID в factual report и финальном ответе. Chat/session ID не придумывать: если клиент не показывает — `NOT_EXPOSED`. Search anchor обязателен.

Если после зависания/перезапуска создаётся новый чат для продолжения той же задачи, это **новый Run ID**, а в отчёте нового запуска указывается предыдущий Run ID. Код не начинать заново: сначала проверить существующий worktree/branch и продолжить безопасное состояние.

## Изоляция рабочих каталогов

- Два одновременно работающих агента никогда не используют один working tree.
- Worktree нельзя создавать внутри другого repo/worktree.
- Канонический корень: `C:\Users\nerza\Projects\drawer-agent-worktrees\<task-id>`.
- Перед стартом: `git worktree list`; каталог задачи должен быть уникальным.
- Незакоммиченная работа другого агента не трогается.
- Удалять worktree только после safe commit+push.
- Публичный `origin` не трогать; private remote — `dev` (`nerzar/Drawer.Dev`).

## Ресурсы моделей сейчас

- Codex GPT quota исчерпана после C02. **Новые задачи Codex не назначать до сообщения оператора о восстановлении лимита.**
- Claude держим в резерве.
- Gemini/Antigravity — основной доступный worker сейчас.
- Старые/отдельно лимитируемые модели в Codex не использовать автоматически: только по отдельному решению архитектора/оператора.
- Astra не использовать без отдельного решения.

## Общие правила

- Git CLI/remote — источник истины.
- Не плодить слои/harnesses/docs/абстракции без необходимости.
- `drawer-debug.log` и tray action `Нашёл баг…` сохранять.
- Frontend typecheck: `npm --prefix settings-ui run typecheck`; внешний `npx vue-tsc` не использовать как gate.
- VM/full `safe` suite не является default gate.

---

# Текущее фактическое состояние

- orchestration branch: `dev/wip/slots-parity`.
- diagnostics base `b2ec249` вручную принята пользователем.
- Wave 1 integration: `dev/integration/slots-settings-wave1@ac63ead`.
- C01 + G01 объединены; permanent `Имя` редактируется; `Tab` не захватывается hotkey field; narrow/frontend checks зелёные.
- T00: `dev/chore/frontend-local-typecheck@9c856ea`; repo typecheck уже корректен, code change не понадобился.
- Wave 1 ещё не принята как новая основная база из-за production-build blocker B01.
- На integration branch действительно есть два определения `ApplyDwmTitlebarTheme`: в `src/drawer.ahk` и `src/webview/SettingsWebView.ahk`. C02 подтвердил, что WebView smoke упирается в duplicate compile error; B01 должен устранить это по смыслу и затем проверить production build.
- `wip/slots-parity` пока не передвигаем на code integration до B01 + I02.

---

# DONE / WAITING FOR INTEGRATION

## TASK C02 — General + dynamic override в одном Save

**Status:** DONE_WAITING_FOR_B01_I02  
**Executor:** Codex  
**Run ID:** `RUN-20260906-CODEX-C02-01`  
**Branch:** `dev/fix/settings-general-override-atomic`  
**Reviewed remote HEAD:** `f75dcc6`  
**Base:** `ac63ead`

### Результат

- `SettingsDynamicFinal()` накладывает planned `[dynamic]` writes на текущие defaults до планирования slots.
- Dynamic overrides теперь сравниваются с **финальным General state этого же Save**.
- Regression покрывает swap `General 70→50` + slot `50→70`, а также delete/no-op cases.
- Persistence pipeline не переписывался.

### Проверки

- AHK `/validate` — green.
- settings-seam — green.
- frontend test 25/25, typecheck, build — green.
- webview-slice не дошёл до bridge checks из-за уже существующего duplicate `ApplyDwmTitlebarTheme`; это B01, не дефект C02.

Factual report: `docs/agent-reports/2026-09-06-codex-c02.md` в ветке C02.

---

# ACTIVE

## TASK B01 — восстановить production build и проверить config-preservation

**Status:** RESUME_AFTER_CLIENT_RESTART  
**Executor:** Gemini / Antigravity, strongest available Gemini mode; NOT Astra  
**Previous Run ID:** `RUN-20260906-GEMINI-B01-01`  
**Current Run ID:** `RUN-20260906-GEMINI-B01-02`  
**Base:** `dev/integration/slots-settings-wave1@ac63ead`  
**Branch:** `fix/integration-production-build`  
**Worktree:** `C:\Users\nerza\Projects\drawer-agent-worktrees\B01`

Antigravity был перезапущен после зависания. **Не начинать B01 заново и не удалять существующий worktree.**

### Сначала

1. `git fetch dev`.
2. Проверить `git worktree list`, `git status`, текущую branch и содержимое `C:\Users\nerza\Projects\drawer-agent-worktrees\B01`.
3. Если предыдущий запуск оставил незакоммиченные изменения — сохранить их и продолжить, не reset/clean/discard.
4. Если branch ещё не опубликована — это не повод пересоздавать worktree.
5. В новом factual report указать previous Run ID `RUN-20260906-GEMINI-B01-01`.

### Задача

1. Устранить duplicate `ApplyDwmTitlebarTheme` по смыслу. Оставить **одно** определение, пригодное и для Settings WebView, и для нужных native dialogs, сохранив dark mode + caption/text/border colors + безопасный fallback; custom chrome не делать.
2. Проверить, был ли duplicate реальной причиной `Ahk2Exe exit 17`; зафиксировать факт.
3. Production `build/build.ps1` должен завершаться успешно.
4. Проверить build/config safety:
   - fresh output получает default `config.ini`;
   - изменить output `config.ini`, повторить build → файл сохраняется;
   - release zip не содержит `.log`;
   - WebView assets embedded и build-проверка проходит.
5. Не брать C02/C03 и не менять slot semantics.

### Проверки

Production build обязателен; AHK `/validate`; узкие checks, затронутые исправлением. VM/full suite не нужен.

Перед завершением: factual report по REPORT_FORMAT с Run ID `RUN-20260906-GEMINI-B01-02`, commit, push `dev/fix/integration-production-build`, clean tree. Не merge.

---

# NEXT

## TASK I02 — интегрировать C02 + B01 + orchestration docs

**Status:** BLOCKED_ON_B01  
**Preferred executor сейчас:** Gemini, потому что Codex quota exhausted.

После B01 создать отдельный integration worktree/branch от `ac63ead`, интегрировать:
- `dev/fix/settings-general-override-atomic@f75dcc6`;
- финальный B01 branch;
- актуальные `AGENT_BOARD.md` + `docs/agent-reports/REPORT_FORMAT.md` из `dev/wip/slots-parity`.

Затем полный narrow/frontend gate + production build. После проверки архитектор передвигает рабочую base branch; агент сам `wip/slots-parity` не двигает.

## TASK A01 — короткая ручная приёмка

**Status:** BLOCKED_ON_I02  
**Executor:** пользователь

Проверить обычными действиями: custom show/hide hotkey, смена hotkey без restart, Tab из hotkey field, editable permanent name, dynamic bind/release/reset, permanent↔dynamic с живым окном, handle после bind, late permanent launch, native dark titlebar/About. При баге: `Нашёл баг…` → номер BUG + действие/результат.

---

# BACKLOG — Settings correctness

## TASK C03 — partial/retryable/diagnostics correctness
**Status:** BLOCKED_ON_I02_AND_STRONG_MODEL
**Preferred executor:** Codex после reset / Opus reserve по отдельному решению

Structured partial-save/reload/reconcile должен доходить до UI; без ложного `Сохранено`, потери draft/field diagnostics и исчезновения warning после no-op. Один persistence path.

## TASK G02 — stale windowClass + picker identity
**Status:** BLOCKED_ON_I02
**Preferred executor:** Gemini

Смена exe не оставляет class старого app; picker согласованно обновляет exe/class/name seed; dynamic→permanent получает чистые identity data. Не менять FindWindow больше необходимого.

## TASK G03 — live hideOnBlur/blurMs + save lock
**Status:** BLOCKED_ON_I02
**Preferred executor:** Gemini

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
**Status:** BLOCKED_ON_STABILIZATION_AND_STRONG_MODEL

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

## TASK R02 — production build acceptance
**Status:** BLOCKED_ON_STABILIZATION

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

1. Сейчас: продолжить B01 после restart как `RUN-20260906-GEMINI-B01-02` в существующем отдельном worktree.
2. После B01 — I02 (Gemini, если Codex лимит ещё не восстановился).
3. A01 короткая ручная приёмка.
4. Затем G02/G03/G04 и C03 по доступности сильной модели.
5. UX cleanup.
6. Modular architecture.
7. Test/release debt.
8. Future product отдельно.