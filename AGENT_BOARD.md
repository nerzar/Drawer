# AGENT_BOARD — Drawer autonomous work queue

Blackboard между архитектором ChatGPT и coding agents.

**Владелец файла:** архитектор ChatGPT. Coding agents этот файл не редактируют и приоритеты сами не меняют.

## Общий протокол

1. `git fetch dev`.
2. Прочитать актуальный `AGENT_BOARD.md` из `dev/wip/slots-parity`.
3. Прочитать `docs/agent-reports/REPORT_FORMAT.md` из `dev/wip/slots-parity`.
4. Взять только задачу, чей Run ID дан оператором.
5. Перед изменениями проверить `git worktree list`, branch, base и `git status`.
6. Параллельные задачи всегда работают в отдельных sibling-worktree: `C:\Users\nerza\Projects\drawer-agent-worktrees\<task-id>`.
7. Worktree нельзя создавать внутри другого repo/worktree. Незакоммиченную работу другого агента нельзя reset/clean/discard.
8. Выполнить задачу целиком, не расширяя scope без необходимости.
9. VM/full suite не является default gate; только разумные целевые проверки, если задача не требует иного.
10. Перед завершением: factual report по `REPORT_FORMAT.md`, commit, push в private remote `dev`, verify remote HEAD = local HEAD, clean tree.
11. Публичный `origin` не трогать.
12. `docs/ARCHITECT_STATE.md` coding agents не редактируют.

Если есть blocker, неоднозначное продуктовое решение, конфликт с параллельной задачей или риск потери данных: сохранить безопасное состояние, push и остановиться с `BLOCKED` в отчёте.

## Идентификация запусков

Каждая задача получает **Run ID**. Агент повторяет его в factual report и финальном ответе.

Отчёт обязан содержать: Task ID, Run ID, client, **фактически использованную модель**, chat/session ID если доступен, chat title если доступен, Search anchor, timestamps, worktree, branch, base SHA, final SHA.

**Модель в отчёте брать из фактического выбора клиента/оператора, а не копировать слепо из старого board.** Если есть расхождение — явно написать его.

## Ресурсы моделей сейчас

- Codex GPT quota исчерпана после C02; новые GPT-задачи Codex не назначать до сообщения оператора о reset.
- OpenCode подключён через сторонний provider. Gemini 3.8 Flash там не заработал.
- OpenCode + заявленная provider-модель `GPT 5.6 Luna` успешно прошёл реальный harness-test на I02: worktree/Git/merge/AHK/PowerShell/npm/build/report/push без ручной Git-помощи.
- Названия моделей стороннего provider не считаем доказательством официального endpoint; оцениваем практическое качество.
- Следующий qualification OpenCode: `Qwen 3.8 MAX` на G02. Если Qwen не справляется/ломает tool-use — сохранить безопасное состояние и остановиться; не переключать модель внутри того же Run ID.
- Antigravity доступен. G04 фактически был выполнен на Gemini 3.8 Flash High, потому что Sonnet не был выбран оператором.
- Текущий Antigravity I03 должен фактически использовать **Claude Sonnet 4.6 (Thinking)** — первый настоящий qualification run этого пула.
- Claude Opus 4.6 Thinking держать для тяжёлых correctness/runtime/architecture escalation.
- Astra не использовать без отдельного решения.

## Общие технические правила

- Git CLI/remote — источник истины.
- Не плодить новые слои/harnesses/docs/абстракции без необходимости.
- `drawer-debug.log` и tray action `Нашёл баг…` сохранять.
- Frontend typecheck: `npm --prefix settings-ui run typecheck`; внешний `npx vue-tsc` не использовать как gate.
- Stable hotkey contract: один настраиваемый show/hide hotkey на slot; `Ctrl+Alt+N` default only; `Ctrl+Alt+Shift+N` — fixed dynamic bind.

---

# Текущее фактическое состояние

- Private repo: `nerzar/Drawer.Dev`, remote `dev`.
- Diagnostics base `b2ec249` вручную принята пользователем.
- Wave 1: `dev/integration/slots-settings-wave1@ac63ead`.
- C02: `dev/fix/settings-general-override-atomic@f75dcc6`.
- B01: `dev/fix/integration-production-build@1bd8f6e`.
- **I02 architect-reviewed:** `dev/integration/slots-settings-wave2@4cc0d77`.
- I02 содержит Wave 1 + C02 + B01. `SettingsDynamicFinal` присутствует; duplicate `ApplyDwmTitlebarTheme` удалён; production build fixes присутствуют.
- I02 gates: AHK validate green, settings-seam green, frontend 25/25, typecheck/build green, production build green, fresh/rebuild config safety green, embedded assets green.
- `webview-slice` больше не блокируется compile duplicate, но остаётся CDP `inject-timeout` после успешных boot/getInitialState/dirty-Apply/dispose; считать environment blocker, пока не доказано обратное.
- G04: `dev/fix/settings-custom-animation-preset@37cb31d`, frontend-only, tests 33/33, typecheck/build green.
- `wip/slots-parity` пока orchestration branch; кодовую base не двигать до I03 + architect review + P01.

## Проверка I02 архитектором

Проверено на remote:
- branch HEAD `4cc0d77`;
- B01 merge `07c7d10`, C02 входит в историю;
- `src/drawer.ahk` содержит `SettingsDynamicFinal(...)` и одну полную `ApplyDwmTitlebarTheme(...)`;
- `src/webview/SettingsWebView.ahk` вызывает helper, но duplicate не объявляет;
- `build/build.ps1` содержит `/silent`, PS5.1-compatible ISO-8859-1 check и сохраняет существующий `config.ini`.

---

# DONE / WAITING

## TASK I02 — C02 + B01 integration

**Status:** DONE_ARCH_REVIEWED  
**Run ID:** `RUN-20260906-OPENCODE-I02-02`  
**Client:** OpenCode  
**Actual model selected by operator:** `GPT 5.6 Luna` via APInex UI  
**Branch:** `dev/integration/slots-settings-wave2`  
**Reviewed HEAD:** `4cc0d77`

Metadata note: self-report ошибочно записал Gemini 3.8 Flash из stale board. I03 добавляет correction note с подтверждением оператора.

## TASK G04 — custom animation preset `Своя`

**Status:** DONE_WAITING_FOR_I03  
**Run ID:** `RUN-20260906-ANTIGRAVITY-G04-01`  
**Client:** Antigravity  
**Actual model:** `Gemini 3.8 Flash (High)`  
**Chat/session ID:** `f5c32174-862b-4f11-9177-8e8771fa41e2`  
**Branch:** `dev/fix/settings-custom-animation-preset`  
**Reviewed HEAD:** `37cb31d`

---

# ACTIVE — параллельные отдельные worktree

## TASK I03 — интегрировать G04 в Wave 2 и подготовить базу к ручной приёмке

**Status:** ACTIVE  
**Executor:** Antigravity  
**MODEL: Claude Sonnet 4.6 (Thinking) — фактически выбрать в UI**  
**Run ID:** `RUN-20260906-ANTIGRAVITY-I03-01`  
**Base:** `dev/integration/slots-settings-wave2@4cc0d77`  
**Input:** `dev/fix/settings-custom-animation-preset@37cb31d`  
**Branch:** `integration/slots-settings-wave3`  
**Worktree:** `C:\Users\nerza\Projects\drawer-agent-worktrees\I03`

### Цель

Получить clean candidate-base для A01: Wave 2 + проверенный frontend-fix G04 + актуальные orchestration docs. Это integration/review task, не новая feature-wave.

### Обязательно

1. Новый sibling-worktree I03 от exact base `4cc0d77`; не работать в I02/G04/shared checkout.
2. Интегрировать G04 по смыслу, не переписывать без причины.
3. Проверить, что `animCustom` остаётся только draft/UI состоянием; wire по-прежнему `durationMs/steps`.
4. Подтянуть актуальные `AGENT_BOARD.md` и `REPORT_FORMAT.md` из `dev/wip/slots-parity`.
5. В `docs/agent-reports/2026-09-06-opencode-i02.md` добавить correction note: оператор подтверждает фактически выбранную модель `GPT 5.6 Luna` через APInex UI; старая строка Gemini была stale metadata.
6. Не брать G02/G03/C03 и не менять slot/runtime semantics.
7. Diff должен содержать только I02 + G04 + docs/correction.

### Проверки

AHK validate; settings-seam; frontend tests >=33; typecheck; frontend build; production build; quick fresh-config + rebuild-preserves-config. WebView slice максимум один раз; повтор того же CDP timeout зафиксировать и не ретраить бесконечно. VM/full suite не запускать.

Перед завершением: factual report, commit, push `dev/integration/slots-settings-wave3`, verify remote HEAD = local HEAD, clean tree. `wip/slots-parity` не двигать.

## TASK G02 — stale windowClass + picker identity

**Status:** READY_PARALLEL_WITH_I03_WAITING_FOR_A01_INTEGRATION  
**Executor:** OpenCode  
**MODEL: `Qwen 3.8 MAX` — фактически выбрать в OpenCode/APInex UI**  
**Run ID:** `RUN-20260906-OPENCODE-G02-01`  
**Purpose:** второй qualification run OpenCode, теперь на другой provider-модели  
**Base:** `dev/integration/slots-settings-wave2@4cc0d77`  
**Branch:** `fix/settings-picker-identity`  
**Worktree:** `C:\Users\nerza\Projects\drawer-agent-worktrees\G02`

### Почему можно параллельно

I03 интегрирует только G04 (`GeneralView.vue`, `general.ts`, animation test/package test-list + docs). G02 занимается identity постоянного слота и picker flow. **G02 не интегрировать в candidate-base до A01**, даже если закончит раньше.

### Цель

Убрать stale `windowClass` и сделать identity постоянного слота согласованным при ручной смене exe, `picker.exe`, `picker.window` и dynamic→permanent, не меняя общую FindWindow/slot архитектуру.

### Подтвердить текущий дефект

На Wave 2 `picker.exe` меняет `draft.executable`, но не очищает `draft.windowClass`; старый `ahk_class` может остаться от другого приложения/окна и затем попасть в permanent rule. Не считать это единственным сценарием — проверить кодом и тестами.

### Обязательное поведение

1. Если пользователь **реально меняет exe вручную**, `windowClass` старого exe не должен тихо пережить изменение.
2. Если `picker.exe` выбирает новый executable, stale class старого окна не должен остаться.
3. `picker.window` должен согласованно установить executable + windowClass из одного выбранного окна; default/пустое имя можно разумно засеять title как сейчас.
4. Dynamic→Permanent должен использовать чистый identity seed, который backend уже отдаёт через `permanentDefaults` для живого dynamic window. Не выдумывать exe/class на frontend и не превращать dynamic в persistent identity до Apply.
5. Если живого окна нет, не придумывать валидный permanent identity; существующая backend validation должна остаться источником истины.
6. Не расширять задачу до выбора конкретного permanent-window (`F12`) и не переписывать `FindWindow`.
7. Сохранить Apply/Cancel draft semantics.

### Жёсткая граница параллельности

Можно менять по необходимости: `settings-ui/src/views/SlotsView.vue`, `settings-ui/src/bridge/settings.ts`, `settings-ui/src/bridge/slotDraft.ts`, связанные slot/frontend tests; backend picker/port только если фактически доказано, что frontend-only fix недостаточен.

**Не менять**, потому что этим владеет I03/G04: `settings-ui/src/views/GeneralView.vue`, `settings-ui/src/bridge/general.ts`, `settings-ui/package.json`, `settings-ui/test/animationPreset.test.ts`. Не менять `build/build.ps1`, DWM/titlebar, hotkey product contract.

Если нужен frontend regression, предпочесть существующий test entrypoint/file или отдельный targeted command; **не править `settings-ui/package.json` в этой параллельной ветке**.

### Проверки

- `npm --prefix settings-ui test`;
- `npm --prefix settings-ui run typecheck`;
- `npm --prefix settings-ui run build`;
- targeted regression для stale-class/picker identity;
- если затронут AHK/backend: AHK validate + settings-seam;
- production build и VM/full suite не нужны.

Перед завершением: factual report, commit, push `dev/fix/settings-picker-identity`, verify remote HEAD = local HEAD, clean tree. **Не merge в Wave 3 / wip.** В отчёте отдельно оценить OpenCode+Qwen tool-use/качество относительно предыдущего Luna run.

---

# NEXT

## TASK P01 — promotion после architect review I03

**Status:** BLOCKED_ON_I03_ARCH_REVIEW

После проверки I03 архитектор даст агенту короткую promotion-задачу: безопасно привести `dev/wip/slots-parity` и локальный checkout `C:\Users\nerza\Projects\drawer-settings-integration` к принятой candidate-base без потери чужой работы. Пользователь Git руками не делает.

## TASK A01 — короткая ручная приёмка

**Status:** BLOCKED_ON_P01  
**Executor:** пользователь

Человеческий checklist:
- custom show/hide hotkey работает сразу после Apply, старый перестаёт;
- Tab выходит из hotkey field;
- permanent name редактируется;
- dynamic bind → кромка сразу → hotkey показывает/убирает;
- Release освобождает dynamic slot;
- Reset slot settings возвращает наследование General;
- permanent↔dynamic с живым окном не теряет окно;
- permanent app, запущенное после Drawer, само получает кромку;
- системный titlebar тёмный и About без mock-элементов;
- «Своя» сразу открывает поля анимации и не откатывается до ввода.

При баге: tray `Нашёл баг…` → номер BUG + что сделал + что произошло.

---

# BACKLOG — Settings correctness

## TASK C03 — partial/retryable/diagnostics correctness
**Status:** BLOCKED_ON_A01_AND_STRONG_MODEL
**Preferred:** Codex after reset / Sonnet / Opus reserve if genuinely hard

Structured partial-save/reload/reconcile должен доходить до UI; без ложного `Сохранено`, потери draft/field diagnostics и исчезновения warning после no-op. Один persistence path.

## TASK G02 integration
**Status:** BLOCKED_ON_G02_RESULT_AND_A01

Если G02 прошёл review, интегрировать его уже **после** A01 отдельной controlled task; не подмешивать в текущую candidate-base перед ручной приёмкой.

## TASK G03 — live hideOnBlur/blurMs + save lock
**Status:** BLOCKED_ON_A01
**Preferred:** Antigravity Sonnet / OpenCode if runtime tool-use proves stable

После Apply runtime-настройки реально влияют на уже показанное окно; blur timer не stale; General inputs защищены во время Save.

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

1. Параллельно сейчас: I03 в Antigravity/Sonnet и G02 в OpenCode/Qwen, каждый в своём sibling-worktree.
2. Архитектор проверяет I03 remote; затем P01.
3. A01 — короткая ручная приёмка candidate-base **без G02**.
4. Архитектор отдельно проверяет G02; после A01 — controlled integration G02, если результат принят.
5. Затем C03 + G03 по доступным пулам.
6. UX cleanup.
7. Modular architecture.
8. Test/release debt.
9. Future product отдельно.