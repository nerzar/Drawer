# AGENT_BOARD — Drawer autonomous work queue

Blackboard между архитектором ChatGPT и coding agents.

**Владелец файла:** архитектор ChatGPT. Coding agents этот файл не редактируют и приоритеты сами не меняют.

## Общий протокол

1. `git fetch dev`.
2. Прочитать актуальный `AGENT_BOARD.md` из `dev/wip/slots-parity`.
3. Прочитать `docs/agent-reports/REPORT_FORMAT.md` из `dev/wip/slots-parity`.
4. Взять только задачу, чей Run ID дан оператором.
5. Перед любыми изменениями проверить `git worktree list`, branch, base и `git status`.
6. Для параллельной задачи использовать отдельный sibling-worktree: `C:\Users\nerza\Projects\drawer-agent-worktrees\<task-id>`; не создавать worktree внутри другого repo/worktree.
7. Незакоммиченную работу другого агента не reset/clean/discard.
8. Выполнить задачу целиком, но не расширять scope без необходимости.
9. VM/full suite не является default gate. Запускать только разумные целевые проверки, если задача прямо не требует больше.
10. Перед завершением: factual report по `REPORT_FORMAT.md`, commit, push в private remote `dev`, verify remote HEAD = local HEAD, clean tree.
11. Публичный `origin` не трогать.
12. `docs/ARCHITECT_STATE.md` coding agents не редактируют.

Если есть blocker, неоднозначное продуктовое решение, конфликт с параллельной задачей или риск потери данных: сохранить безопасное состояние, push и остановиться с `BLOCKED` в отчёте.

## Идентификация запусков

Каждая задача получает **Run ID**. Агент повторяет его в factual report и финальном ответе.

Отчёт обязан содержать: Task ID, Run ID, client, **фактически использованную модель**, chat/session ID если доступен, chat title если доступен, Search anchor, timestamps, worktree, branch, base SHA, final SHA.

**Модель в отчёте берётся из фактического выбора клиента/оператора, а не копируется слепо из старого AGENT_BOARD.** Если есть расхождение — явно написать его.

## Ресурсы моделей сейчас

- Codex GPT quota исчерпана после C02; новые GPT-задачи Codex не назначать до сообщения оператора о reset.
- OpenCode подключён через сторонний provider. Gemini 3.8 Flash там не заработал.
- Qualification run I02 фактически выполнялся в OpenCode на **GPT 5.6 Luna, выбранной оператором в UI APInex**. Агентский report ошибочно записал Gemini 3.8 Flash из старого board; считать это metadata bug, а не фактической моделью.
- OpenCode + Luna прошёл практический harness-test: worktree/Git/merge/AHK/PowerShell/npm/build/report/push без ручной Git-помощи.
- Для следующих OpenCode-задач после Luna можно отдельно тестировать Qwen 3.8 MAX, затем DeepSeek V4 Pro; не считать названия стороннего provider доказательством идентичности официальному endpoint — оцениваем практическое качество.
- Antigravity доступен. G04 фактически был выполнен на Gemini 3.8 Flash High, потому что Sonnet не был выбран оператором.
- **Следующий Antigravity run должен явно использовать Claude Sonnet 4.6 (Thinking)** — это первый настоящий qualification run Sonnet-пула.
- Claude Opus 4.6 Thinking держать для тяжёлых correctness/runtime/architecture escalation, не для дешёвого cleanup.
- Astra не использовать без отдельного решения.

## Общие технические правила

- Git CLI/remote — источник истины.
- Не плодить новые слои/harnesses/docs/абстракции без необходимости.
- `drawer-debug.log` и tray action `Нашёл баг…` сохранять.
- Frontend typecheck: `npm --prefix settings-ui run typecheck`; внешний `npx vue-tsc` не использовать как gate.
- Stable product contract hotkeys: один настраиваемый show/hide hotkey на slot; `Ctrl+Alt+N` default only; `Ctrl+Alt+Shift+N` — fixed dynamic bind.

---

# Текущее фактическое состояние

- Private repo: `nerzar/Drawer.Dev`, remote `dev`.
- Diagnostics base `b2ec249` вручную принята пользователем.
- Wave 1 integration: `dev/integration/slots-settings-wave1@ac63ead`.
- C02: `dev/fix/settings-general-override-atomic@f75dcc6`.
- B01: `dev/fix/integration-production-build@1bd8f6e`.
- **I02 завершена и проверена архитектором:** `dev/integration/slots-settings-wave2@4cc0d77`.
- I02 содержит Wave 1 + C02 + B01 + orchestration docs. `SettingsDynamicFinal` присутствует; duplicate `ApplyDwmTitlebarTheme` удалён; production build fixes присутствуют.
- I02 gates: AHK validate green, settings-seam green, frontend tests 25/25, typecheck/build green, production build green, fresh/rebuild config safety green, embedded assets green.
- `webview-slice` больше не блокируется compile duplicate, но в текущей среде остаётся CDP `inject-timeout` после boot/getInitialState/dirty-Apply/dispose. Считать environment blocker, пока не доказано обратное.
- G04 завершена отдельно: `dev/fix/settings-custom-animation-preset@37cb31d`, frontend-only, tests 33/33, typecheck/build green.
- G04 исправляет «Своя»: явный custom-mode не откатывается до ввода, значения не меняются при переключении, wire DTO остаётся прежним.
- `wip/slots-parity` пока остаётся orchestration branch; кодовую base не двигать до I03 и architect review.

## Проверка I02 архитектором

Проверено на remote:
- branch HEAD `4cc0d77`;
- merge B01 присутствует (`07c7d10`), C02 входит в историю;
- `src/drawer.ahk` содержит `SettingsDynamicFinal(...)` и одну полную `ApplyDwmTitlebarTheme(...)`;
- `src/webview/SettingsWebView.ahk` вызывает DWM helper, но не объявляет duplicate;
- `build/build.ps1` содержит `/silent`, PS5.1-compatible ISO-8859-1 check и сохраняет существующий `config.ini`.

---

# DONE / WAITING FOR FINAL WAVE INTEGRATION

## TASK I02 — C02 + B01 integration

**Status:** DONE_ARCH_REVIEWED  
**Run ID:** `RUN-20260906-OPENCODE-I02-02`  
**Client:** OpenCode  
**Actual model selected by operator:** `GPT 5.6 Luna` via APInex UI  
**Branch:** `dev/integration/slots-settings-wave2`  
**Reviewed HEAD:** `4cc0d77`

Metadata note: report `docs/agent-reports/2026-09-06-opencode-i02.md` ошибочно пишет Gemini 3.8 Flash из старого board. При следующей интеграции добавить короткую correction note, не переписывая историю так, будто агент сам это знал.

## TASK G04 — custom animation preset `Своя`

**Status:** DONE_WAITING_FOR_I03  
**Run ID:** `RUN-20260906-ANTIGRAVITY-G04-01`  
**Client:** Antigravity  
**Actual model:** `Gemini 3.8 Flash (High)`  
**Chat/session ID:** `f5c32174-862b-4f11-9177-8e8771fa41e2`  
**Branch:** `dev/fix/settings-custom-animation-preset`  
**Reviewed HEAD:** `37cb31d`

---

# ACTIVE

## TASK I03 — интегрировать G04 в Wave 2 и подготовить базу к ручной приёмке

**Status:** READY  
**Executor:** Antigravity  
**MODEL: Claude Sonnet 4.6 (Thinking) — ОБЯЗАТЕЛЬНО выбрать в UI перед отправкой prompt**  
**Run ID:** `RUN-20260906-ANTIGRAVITY-I03-01`  
**Base:** `dev/integration/slots-settings-wave2@4cc0d77`  
**Input:** `dev/fix/settings-custom-animation-preset@37cb31d`  
**Branch:** `integration/slots-settings-wave3`  
**Worktree:** `C:\Users\nerza\Projects\drawer-agent-worktrees\I03`

### Цель

Получить одну чистую candidate-base для A01: Wave 2 + проверенный frontend-fix G04 + актуальные orchestration docs. Это integration/review task, не новая feature-wave.

### Обязательно

1. Создать новый sibling-worktree I03 от exact base `4cc0d77`; не работать в I02/G04/shared checkout.
2. Интегрировать G04 по смыслу. Не переписывать его заново без причины.
3. Проверить, что G04 не меняет backend/wire contract: `animCustom` остаётся только draft/UI состоянием; на wire уходят прежние `durationMs/steps`.
4. Подтянуть актуальные `AGENT_BOARD.md` и `REPORT_FORMAT.md` из `dev/wip/slots-parity`.
5. В `docs/agent-reports/2026-09-06-opencode-i02.md` добавить **correction note**, что оператор подтверждает фактически выбранную в OpenCode модель `GPT 5.6 Luna` через APInex UI, а строка Gemini в исходном self-report была скопирована из stale board. Не выдавать это за автоматически обнаруженную модель.
6. Не брать G02/G03/C03 и не менять slot/runtime semantics.
7. Проверить branch diff: кроме I02 + G04 + docs/correction не должно быть лишних изменений.

### Проверки

- AHK `/validate src/drawer.ahk`;
- settings-seam;
- `npm --prefix settings-ui test` — ожидается не меньше 33 тестов;
- `npm --prefix settings-ui run typecheck`;
- `npm --prefix settings-ui run build`;
- production `build/build.ps1`;
- quick fresh-config + rebuild-preserves-config;
- webview-slice можно повторить один раз; если снова тот же CDP `inject-timeout` после успешного boot/bridge stages — зафиксировать и не тратить время на бесконечные retries;
- VM/full suite не запускать.

Перед завершением: factual report, commit, push `dev/integration/slots-settings-wave3`, verify remote HEAD = local HEAD, clean tree. **Не двигать `wip/slots-parity` самостоятельно.**

---

# NEXT

## TASK P01 — promotion после architect review I03

**Status:** BLOCKED_ON_I03_ARCH_REVIEW

После проверки I03 архитектор даст короткую promotion-команду агенту: безопасно привести `dev/wip/slots-parity` и локальный рабочий checkout `C:\Users\nerza\Projects\drawer-settings-integration` к принятой candidate-base без потери чужой работы. Пользователь Git руками не делает.

## TASK A01 — короткая ручная приёмка

**Status:** BLOCKED_ON_P01  
**Executor:** пользователь

Человеческий checklist без внутренних терминов:
- новый custom show/hide hotkey работает сразу после Apply, старый перестаёт;
- Tab выходит из hotkey field;
- permanent name редактируется;
- dynamic bind → кромка сразу появляется → hotkey показывает/убирает;
- Release освобождает dynamic slot;
- Reset slot settings возвращает наследование General;
- permanent↔dynamic с живым окном не теряет окно;
- permanent app, запущенное после Drawer, само получает кромку;
- системный titlebar тёмный и About без mock-элементов;
- «Своя» сразу открывает поля анимации и не откатывается до ввода.

При баге: tray `Нашёл баг…` → сообщить номер BUG + что сделал + что произошло.

---

# BACKLOG — Settings correctness

## TASK C03 — partial/retryable/diagnostics correctness
**Status:** BLOCKED_ON_A01_AND_STRONG_MODEL
**Preferred:** Codex after reset / Sonnet / Opus reserve if genuinely hard

Structured partial-save/reload/reconcile должен доходить до UI; без ложного `Сохранено`, потери draft/field diagnostics и исчезновения warning после no-op. Один persistence path.

## TASK G02 — stale windowClass + picker identity
**Status:** BLOCKED_ON_A01
**Preferred:** OpenCode Luna/Qwen test or Antigravity Sonnet

Смена exe не оставляет class старого app; picker согласованно обновляет exe/class/name seed; dynamic→permanent получает чистые identity data.

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

1. `RUN-20260906-ANTIGRAVITY-I03-01` — Sonnet 4.6 Thinking интегрирует G04 в I02 и делает candidate-base.
2. Архитектор проверяет remote I03.
3. P01 — агентом промотировать candidate-base в `wip/slots-parity` + локальный рабочий checkout.
4. A01 — короткая ручная приёмка пользователем.
5. После A01: C03 + G02/G03 по доступным пулам.
6. UX cleanup.
7. Modular architecture.
8. Test/release debt.
9. Future product отдельно.
