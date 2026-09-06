# AGENT_BOARD — Drawer autonomous work queue

Blackboard между архитектором ChatGPT и coding agents.

**Владелец файла:** архитектор ChatGPT. Coding agents этот файл не редактируют и приоритеты сами не меняют.

## Общий протокол

1. `git fetch dev`.
2. Прочитать актуальный `AGENT_BOARD.md` из `dev/wip/slots-parity`.
3. Взять задачу, назначенную своей модели/чату.
4. Проверить Git фактами. Продолжать указанную feature-ветку либо создать отдельную от указанного base.
5. Выполнить задачу целиком, не расширяя scope.
6. Разумные целевые проверки; VM/full suite только если задача прямо требует.
7. Перед завершением: commit, push feature-ветки в `dev`, clean tree, factual report в `docs/agent-reports/<date>-<agent>-<task>.md`.
8. Не merge/cherry-pick/rebase в `wip/slots-parity` без отдельной integration-задачи.
9. `docs/ARCHITECT_STATE.md` не редактировать.

Если есть блокер, неоднозначное продуктовое решение, конфликт с параллельной задачей или риск потери данных: записать `BLOCKED` в factual report, commit/push текущее состояние и остановиться.

## ОБЯЗАТЕЛЬНО: изоляция рабочих каталогов параллельных агентов

- Два одновременно работающих агента **никогда не используют один и тот же working tree**.
- Нельзя создавать worktree внутри другого repo/worktree. Никаких вложенных `...\drawer-settings-integration\...\worktree`.
- Для параллельных задач использовать отдельные sibling-каталоги, например `C:\Users\nerza\Projects\drawer-agent-worktrees\<task-id>`.
- Перед стартом агент обязан проверить `git worktree list` и убедиться, что его каталог уникален.
- Если в общем checkout уже есть незапушенная работа другого агента, второй агент туда не заходит: первый сначала commit+push либо переносит свою ветку в отдельный worktree.
- Удалять worktree можно только после того, как его ветка safely committed+pushed и больше не нужна для текущей проверки.
- Если есть две локальные ветки с одинаковой интеграцией, каноническое имя для Wave 1: `integration/slots-settings-wave1`. Перед удалением дубля сравнить SHA; если одинаковы — удалить дубль. Если расходятся — `BLOCKED`, не выбрасывать изменения.

## Общие правила

- Private repo: `nerzar/Drawer.Dev`, remote `dev`.
- Публичный `origin` не трогать.
- Git CLI/remote — источник истины.
- Не плодить сущности/слои/harnesses/docs/worktrees без необходимости.
- `drawer-debug.log` и `Нашёл баг…` сохранять и использовать для runtime-диагностики.
- Claude — резерв. Astra без отдельного решения архитектора не использовать.
- Gemini — основной дешёвый worker; Codex — сложная логика/многослойные задачи.
- Два параллельных агента — нормальный режим, но только в отдельных worktree и с разведёнными по файлам/границам задачами.
- Для frontend typecheck использовать `npm --prefix settings-ui run typecheck` / `npm run typecheck` из `settings-ui`. Не использовать внешний `npx vue-tsc` как gate.

## Текущее состояние

- orchestration branch: `dev/wip/slots-parity`
- diagnostics на `b2ec249` вручную приняты пользователем.
- hotkey product contract: `docs/03-решения.md`, Р24.
- remote feature inputs Wave 1: `dev/codex/slots-user-contract@e4f5271`, `dev/feat/settings-ui-build-cleanup@8d01da3`.
- T00 remote branch: `dev/chore/frontend-local-typecheck@9c856ea`.
- На GitHub сейчас **нет** опубликованной integration-ветки Wave 1; обнаруженные две одинаковые integration-ветки — локальная workspace-проблема.

---

# ЗАВЕРШЁННАЯ ПАРАЛЛЕЛЬНАЯ ВОЛНА

## TASK C01 — Slots product contract

**Status:** READY_FOR_INTEGRATION  
**Executor:** Codex, GPT-5.6 Terra High  
**Branch:** `codex/slots-user-contract`  
**Reviewed remote HEAD:** `e4f5271`

Реализовано: один persisted show/hide hotkey на слот, runtime rebind без restart, dynamic/permanent, WebView keyboard capture, native Hotkey control, release/reset dynamic, late permanent discovery через foreground lifecycle, handle после bind, удаление старого `focusHotkey`, factual report.

Integration обязана дополнительно проверить/исправить два review-дефекта C01:
- поле `Имя` permanent-слота должно быть редактируемым, лишний `readonly` убрать;
- `Tab` в поле capture hotkey должен переводить фокус на следующий контрол и **не** записываться как hotkey.

## TASK G01 — Settings/build cleanup

**Status:** READY_FOR_INTEGRATION  
**Executor:** Gemini  
**Branch:** `feat/settings-ui-build-cleanup`  
**Reviewed remote HEAD:** `8d01da3`

Реализовано: удалён внутренний WebView titlebar, native titlebar стилизован через DWM с fallback, build не затирает существующий `config.ini`, release zip исключает `.log`, About/mock cleanup, внешний GitHub link, dark select readability, checkbox targets, keyboard accessibility color controls.

## TASK T00 — frontend typecheck

**Status:** DONE  
**Executor:** Gemini  
**Branch:** `chore/frontend-local-typecheck`  
**Reviewed remote HEAD:** `9c856ea`

Проверено: в repo уже есть корректный локальный `typecheck = tsc -p tsconfig.json`, который проверяет все `.ts` bridge-файлы; `npm ci`, `npm test`, `npm run typecheck`, `npm run build` проходят. Ошибка C01 была вызвана неправильным внешним `npx vue-tsc`, а не отсутствием рабочего repo typecheck. Код/lockfile менять не потребовалось; branch содержит factual report.

---

# ACTIVE — сначала привести в порядок I01 и workspace

## TASK I01-PUBLISH — сохранить законченную интеграцию и убрать локальный дубль

**Status:** READY  
**Executor:** Codex, GPT-5.6 Terra High  
**Canonical branch:** `integration/slots-settings-wave1`

Codex уже сообщил о завершении I01 локально, но remote integration branch ещё не существует. Сейчас **не переписывать интеграцию с нуля**.

### Сделать

1. В текущем локальном состоянии проверить `git status`, `git branch -vv`, `git worktree list` и найти законченную работу I01.
2. Убедиться, что review-дефекты закрыты: permanent `Имя` редактируется; `Tab` выходит из hotkey capture и не становится хоткеем.
3. Зафиксировать всю законченную интеграцию в канонической ветке `integration/slots-settings-wave1`.
4. Если локально есть две одинаковые integration-ветки: сравнить их HEAD/tree; при идентичности оставить только `integration/slots-settings-wave1`, вторую удалить. Если не идентичны — не удалять, записать `BLOCKED` с разницей.
5. Commit + push канонической ветки в remote `dev`.
6. Проверить, что `dev/integration/slots-settings-wave1` существует и local HEAD ему равен.
7. Factual report в `docs/agent-reports/2026-09-06-codex-i01.md`, clean tree.
8. Не вливать в `wip/slots-parity` самостоятельно.

### Проверки

- AHK `/validate`;
- settings-seam;
- webview-slice;
- `npm --prefix settings-ui test`;
- `npm --prefix settings-ui run typecheck`;
- `npm --prefix settings-ui run build`;
- production build + fresh config / rebuild-preserves-config check;
- VM/full suite не запускать.

### Workspace cleanup

После commit+push убрать только лишний локальный integration branch/worktree, если он доказанно дубликат. Не трогать `chore/frontend-local-typecheck`: T00 уже safely pushed и может быть удалён локально позже отдельной уборкой.

---

# СЛЕДОМ

## TASK A01 — ручная приёмка интегрированных Slots + Settings shell

**Status:** BLOCKED_ON_I01_PUBLISH  
**Executor:** пользователь; инструкции даёт архитектор

После принятой remote integration-ветки пользователь проверяет только человеческие сценарии: custom show/hide hotkeys, hotkey меняется сразу, Tab у hotkey field, editable permanent name, dynamic bind/release/reset, permanent↔dynamic с живым окном, handle после bind, late permanent launch, Settings titlebar/About, build config safety. При баге: воспроизвести → `Нашёл баг…` → сообщить номер BUG и действие/результат.

---

# WAVE 3 — Settings correctness

## TASK C02 — General + dynamic override в одном Save

**Status:** BLOCKED_ON_I01_PUBLISH  
**Preferred executor:** Codex Terra High

Подтверждённый дефект: old General=70, slot override=50; одним Apply General→50 и slot→70. План сравнивает slot с old General 70 и ошибочно удаляет override. Планировать overrides нужно относительно **финального General state этого же Save**. Добавить regression и симметричные no-op/delete случаи; persistence pipeline не переписывать.

## TASK C03 — partial/retryable/diagnostics correctness

**Status:** BLOCKED_ON_C02_OR_SEPARATE_FILE_REVIEW  
**Preferred executor:** Codex Terra High / Opus reserve

Structured partial-save/reload/reconcile должен доходить до UI; без ложного `Сохранено`, без потери draft/field diagnostics, warning не должен исчезать после no-op. Один persistence path, без фиктивного rollback.

## TASK G02 — stale windowClass + picker identity

**Status:** BLOCKED_ON_I01_PUBLISH  
**Preferred executor:** Gemini

Смена exe не оставляет class старого app; picker согласованно обновляет exe/class/name seed; dynamic→permanent с live window получает чистые identity data. Не менять permanent FindWindow больше необходимого.

## TASK G03 — live hideOnBlur/blurMs + save lock

**Status:** BLOCKED_ON_I01_PUBLISH  
**Preferred executor:** Gemini, эскалация Codex при runtime race

После Apply runtime-настройки должны реально влиять на уже показанное окно; blur timer не stale; General inputs защищены во время Save от перезаписи позднего ввода.

## TASK G04 — custom animation preset `Своя`

**Status:** BLOCKED_ON_I01_PUBLISH  
**Preferred executor:** Gemini

Пользовательские animation duration/steps сохраняются и отображаются корректно, не сбрасываются preset/canonical. Целевые tests.

---

# WAVE 4 — UX cleanup

## TASK G05 — Slots terminology/onboarding

**Status:** BLOCKED_ON_WAVE3  
**Preferred executor:** Gemini

Убрать INI/internal jargon; понятно объяснить Permanent vs Dynamic; хороший empty dynamic onboarding; exe dynamic — информация о live window, не persistent binding; release/reset obvious; без redesign.

## TASK G06 — navigation/accessibility/polish

**Status:** BLOCKED_ON_WAVE3  
**Preferred executor:** Gemini

Selected slot сохраняется между tabs; scrollbar/list behavior; оставшиеся labels/select/contrast/keyboard issues; About follow-up; без arbitrary slots.

---

# WAVE 5 — modular architecture после стабилизации UX/Settings

## TASK A02 — windows/focus seam
**Status:** BLOCKED_ON_STABILIZATION  
**Preferred executor:** Codex Terra High / Opus reserve

Вынести оконную модель `state`, `watched`, Show/Hide, focus/foreground lifecycle за явный seam без изменения поведения.

## TASK A03 — parking/geometries seam
**Status:** BLOCKED_ON_A02

Отделить CaptureOrigin/ComputeGeom/parking logic без изменения multi-monitor behavior.

## TASK A04 — handles seam
**Status:** BLOCKED_ON_A02_A03

Вынести handles/edge sync lifecycle за Slot/window API, без второй модели slot state.

## TASK A05 — Settings service + tray seams
**Status:** BLOCKED_ON_A02_A04

Уменьшить `drawer.ahk`, не дублируя persistence/runtime paths.

---

# TEST / RELEASE DEBT

## TASK T01 — stale VM/safe tests
**Status:** PARKED_UNTIL_ARCH_STABLE

Разобраться с `setstat`/F11/F12; stale tests убрать из default safe либо сделать детерминированными; VM не должна быть gate каждой правки.

## TASK T02 — common VM/test helper
**Status:** PARKED_UNTIL_T01

Вынести повторяющиеся `Check`, `Out`, `OnScreen`, `PosOf`, `WaitOn` только если это реально уменьшает поддержку.

## TASK R01 — diagnostics production policy
**Status:** BLOCKED_ON_STABILIZATION

Bounded/rotated `drawer-debug.log`, dev/release policy, сохранить `Нашёл баг…`, без logging framework.

## TASK R02 — production build acceptance
**Status:** BLOCKED_ON_G01_AND_STABILIZATION

Fresh build, rebuild existing config, compiled Settings, clean package/version metadata.

## TASK R03 — final human acceptance
**Status:** BLOCKED_ON_1_0_BLOCKERS

Реальные окна, 1/2 monitors, dynamic/permanent, hotkeys, handles, Settings, restart, late app launch, exit/cleanup; VM только где полезна.

---

# FUTURE PRODUCT

## F01 arbitrary slots
**Status:** FUTURE_PRODUCT_DECISION

Убрать фундаментальный 1–9; новая slot identity/config/UI migration; старым слотам сохранить Ctrl+Alt+1…9 defaults.

## F02 Add/Delete slot UI
**Status:** BLOCKED_ON_F01

## F03 handle context menu + tray slot actions
**Status:** BLOCKED_ON_F01_F02

## F04 reset semantics
**Status:** FUTURE_AFTER_F02

Отдельно reset bindings/settings и полный reset Drawer.

## F12 конкретное permanent-window
**Status:** DEFERRED_PRODUCT

Сейчас exe + optional class + largest candidate. Отдельный выбор документа/чата требует отдельного решения.

## F08 убрать parked window из Alt+Tab
**Status:** DEFERRED_RISKY

## F11 autostart
**Status:** DEFERRED_UNTIL_DAILY_USE

---

# Ближайший порядок

1. Сейчас: **I01-PUBLISH Codex**, Gemini не трогает общий checkout.
2. Архитектор проверяет `dev/integration/slots-settings-wave1`.
3. Принятая integration-база → A01 ручная приёмка.
4. Следующая пара агентов стартует только в **двух отдельных sibling worktree**.
5. Wave 3 correctness по две непересекающиеся задачи.
6. Wave 4 UX.
7. Только потом modular architecture.
8. Test/release debt.
9. Future product отдельно.