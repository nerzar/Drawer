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

Если после зависания/перезапуска продолжается **тот же** реально сохранённый chat/session, Run ID можно сохранить. Если создаётся новый чат — новый Run ID, а previous Run ID указывается в отчёте. Код не начинать заново: сначала проверить existing worktree/branch.

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
- Старые/отдельно лимитируемые модели в Codex не использовать автоматически.
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
- T00: `dev/chore/frontend-local-typecheck@9c856ea`; repo typecheck уже корректен.
- C02 опубликована: `dev/fix/settings-general-override-atomic@f75dcc6`.
- B01 опубликована: `dev/fix/integration-production-build@1bd8f6e`.
- C02 и B01 обе основаны непосредственно на `ac63ead`, поэтому следующая задача — одна контролируемая интеграция I02.
- B01 доказала причину `Ahk2Exe exit 17`: duplicate `ApplyDwmTitlebarTheme`; production build теперь проходит, config preservation и embedded assets проверены.
- `wip/slots-parity` пока не передвигаем на code integration до проверки I02 архитектором.

---

# DONE / WAITING FOR I02

## TASK C02 — General + dynamic override в одном Save

**Status:** DONE_WAITING_FOR_I02  
**Executor:** Codex  
**Run ID:** `RUN-20260906-CODEX-C02-01`  
**Branch:** `dev/fix/settings-general-override-atomic`  
**Reviewed remote HEAD:** `f75dcc6`  
**Base:** `ac63ead`

Результат: dynamic overrides планируются относительно финального General state того же Save; regression покрывает swap/delete/no-op. `/validate`, settings-seam, frontend test/typecheck/build зелёные. WebView smoke на этой branch блокировался старым duplicate DWM из base, который закрыт B01.

Factual report: `docs/agent-reports/2026-09-06-codex-c02.md` в ветке C02.

## TASK B01 — production build + config preservation

**Status:** DONE_WAITING_FOR_I02  
**Executor:** Gemini / Antigravity  
**Run ID:** `RUN-20260906-GEMINI-B01-01`  
**Chat/session ID:** `58a95442-23fa-4251-a1f2-9276631611c8`  
**Branch:** `dev/fix/integration-production-build`  
**Reviewed remote HEAD:** `1bd8f6e`  
**Base:** `ac63ead`

Результат:
- duplicate `ApplyDwmTitlebarTheme` действительно был причиной Ahk2Exe exit 17;
- оставлена одна полная DWM implementation в `src/drawer.ahk`, duplicate из `SettingsWebView.ahk` удалён;
- build запускает Ahk2Exe с `/silent`;
- Windows PowerShell 5.1 compatibility build check исправлена (`ISO-8859-1`, UTF-8 BOM);
- fresh build получает default config, rebuild сохраняет изменённый config;
- `.log` исключён из zip;
- `index.html` + `WebView2Loader.dll` доказанно embedded;
- `/validate`, settings-seam 226/226, frontend 25/25, typecheck/build, `pwsh build` и `powershell.exe -SkipFrontend` зелёные.

Known environment note: `webview-slice.ps1` в B01 упёрся в interactive CDP/headless inject timeout; это не тот duplicate compile blocker, который уже устранён. I02 обязана повторить WebView slice в объединённом состоянии и зафиксировать результат.

Factual report: `docs/agent-reports/2026-09-06-gemini-b01.md` в ветке B01.

---

# ACTIVE

## TASK I02 — интегрировать C02 + B01 + orchestration docs

**Status:** READY  
**Executor:** Gemini / Antigravity, `Gemini 3.8 Flash High` либо strongest available Gemini mode; NOT Astra  
**Run ID:** `RUN-20260906-GEMINI-I02-01`  
**Base:** `dev/integration/slots-settings-wave1@ac63ead`  
**Inputs:**
- `dev/fix/settings-general-override-atomic@f75dcc6`
- `dev/fix/integration-production-build@1bd8f6e`
- актуальные `AGENT_BOARD.md` + `docs/agent-reports/REPORT_FORMAT.md` из `dev/wip/slots-parity`

**Branch:** `integration/slots-settings-wave2`  
**Worktree:** `C:\Users\nerza\Projects\drawer-agent-worktrees\I02`

### Цель

Получить одну чистую integration branch с Wave 1 + C02 + B01 + актуальными orchestration docs. Не начинать новые product/correctness задачи.

### Обязательно

1. Создать **новый отдельный sibling worktree I02**, не работать в B01/C02 worktrees и не использовать общий checkout.
2. Интегрировать C02 и B01 по смыслу. Обе ветки меняют `src/drawer.ahk` и `test/narrow/settings-seam.ahk`; не разрешать конфликт простым выбором одной стороны.
3. Сохранить одновременно:
   - `SettingsDynamicFinal` / final-General override semantics из C02;
   - единственную полную DWM implementation из B01;
   - B01 build fixes (`/silent`, PS5.1-compatible encoding, config safety);
   - C01/G01 slot/hotkey/settings behavior из Wave 1.
4. Подтянуть `AGENT_BOARD.md` и `docs/agent-reports/REPORT_FORMAT.md` из актуального `dev/wip/slots-parity` **без движения самого `wip/slots-parity` ref**.
5. Не менять slot product contract, persistence beyond C02 fix, или следующие backlog-задачи.

### Проверки

- AHK `/validate src/drawer.ahk`;
- settings-seam;
- webview-slice — повторить на объединённой ветке; если interactive environment снова не даёт пройти, зафиксировать точный runtime blocker, но duplicate compile error недопустим;
- `npm --prefix settings-ui test`;
- `npm --prefix settings-ui run typecheck`;
- `npm --prefix settings-ui run build`;
- production `build/build.ps1`;
- повторно быстро проверить fresh-config + rebuild-preserves-config + embedded assets;
- VM/full suite не запускать.

Перед завершением: factual report по REPORT_FORMAT, commit, push `dev/integration/slots-settings-wave2`, verify remote HEAD = local HEAD, clean tree. **Не двигать `wip/slots-parity` самостоятельно.**

---

# NEXT

## TASK A01 — короткая ручная приёмка

**Status:** BLOCKED_ON_I02_ARCH_REVIEW  
**Executor:** пользователь

После проверки I02 архитектором рабочая base branch будет передвинута на принятую integration и пользователь получит короткий человеческий checklist: hotkeys, Tab, editable name, dynamic bind/release/reset, permanent↔dynamic, handle lifecycle, late permanent app, dark titlebar/About. При баге: `Нашёл баг…` → номер BUG + действие/результат.

---

# BACKLOG — Settings correctness

## TASK C03 — partial/retryable/diagnostics correctness
**Status:** BLOCKED_ON_I02_AND_STRONG_MODEL
**Preferred executor:** Codex после reset / Opus reserve по отдельному решению

Structured partial-save/reload/reconcile должен доходить до UI; без ложного `Сохранено`, потери draft/field diagnostics и исчезновения warning после no-op. Один persistence path.

## TASK G02 — stale windowClass + picker identity
**Status:** BLOCKED_ON_I02
**Preferred executor:** Gemini

Смена exe не оставляет class старого app; picker согласованно обновляет exe/class/name seed; dynamic→permanent получает чистые identity data.

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

## TASK G06 — navigation/accessibility/polish
**Status:** BLOCKED_ON_SETTINGS_CORRECTNESS

---

# BACKLOG — modular architecture

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

1. Сейчас: `RUN-20260906-GEMINI-I02-01` — I02 integration в отдельном sibling worktree.
2. Архитектор проверяет remote `integration/slots-settings-wave2` и только затем двигает рабочую base branch.
3. A01 короткая ручная приёмка.
4. Затем G02/G03/G04 и C03 по доступности сильной модели.
5. UX cleanup.
6. Modular architecture.
7. Test/release debt.
8. Future product отдельно.
