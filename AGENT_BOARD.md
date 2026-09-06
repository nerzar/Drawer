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

## Общие правила

- Private repo: `nerzar/Drawer.Dev`, remote `dev`.
- Публичный `origin` не трогать.
- Git CLI/remote — источник истины.
- Не плодить сущности/слои/harnesses/docs/worktrees без необходимости.
- `drawer-debug.log` и `Нашёл баг…` сохранять и использовать для runtime-диагностики.
- Claude — резерв. Astra без отдельного решения архитектора не использовать.
- Gemini — основной дешёвый worker; Codex — сложная логика/многослойные задачи.
- Два параллельных агента — нормальный режим, но задачи должны быть разведены по файлам/границам.

## Текущее состояние

- orchestration branch: `dev/wip/slots-parity`
- базовая кодовая точка первой волны: `b2ec249`
- diagnostics на `b2ec249` вручную приняты пользователем.
- hotkey product contract: `docs/03-решения.md`, Р24.

---

# ЗАВЕРШЁННАЯ ПАРАЛЛЕЛЬНАЯ ВОЛНА

## TASK C01 — Slots product contract

**Status:** READY_FOR_INTEGRATION  
**Executor:** Codex, GPT-5.6 Terra High  
**Branch:** `codex/slots-user-contract`  
**Reviewed remote HEAD:** `e4f5271`

Реализовано: один persisted show/hide hotkey на слот, runtime rebind без restart, dynamic/permanent, WebView keyboard capture, native Hotkey control, release/reset dynamic, late permanent discovery через foreground lifecycle, handle после bind, удаление старого `focusHotkey`, factual report.

### Review note для integration

В `e4f5271` в `SlotsView.vue` случайно появился `readonly` на поле **имени permanent-слота** (`slot-name`). Имя — человеческая подпись и должно оставаться редактируемым. При интеграции убрать этот `readonly` и добавить/сохранить простой regression, если это уместно.

Codex сообщил один toolchain issue: `npx vue-tsc --noEmit` подтягивает внешний несовместимый `vue-tsc`; локального `vue-tsc` в repo нет. Это вынесено в отдельную задачу T00 и не является продуктовым blocker C01.

---

## TASK G01 — Settings/build cleanup

**Status:** READY_FOR_INTEGRATION  
**Executor:** Gemini  
**Branch:** `feat/settings-ui-build-cleanup`  
**Reviewed remote HEAD:** `8d01da3`

Реализовано: удалён внутренний WebView titlebar, native titlebar стилизован через DWM с fallback, build не затирает существующий `config.ini`, release zip исключает `.log`, About/mock cleanup, внешний GitHub link, dark select readability, checkbox targets, keyboard accessibility color controls.

Отдельного нового factual report в ветке нет; два commit message достаточно подробно фиксируют изменения. Не блокировать интеграцию только из-за отсутствия отчёта.

---

# ACTIVE WAVE 2

## TASK I01 — интегрировать C01 + G01

**Status:** READY  
**Executor:** Codex, GPT-5.6 Terra High  
**Base:** актуальный `dev/wip/slots-parity`  
**Inputs:** `dev/codex/slots-user-contract@e4f5271` + `dev/feat/settings-ui-build-cleanup@8d01da3`  
**Suggested branch:** `integration/slots-settings-wave1`

### Цель

Создать отдельную integration-ветку от актуального `dev/wip/slots-parity`, интегрировать обе feature-ветки и получить одну проверенную кодовую базу.

### Обязательно

- не терять изменения ни C01, ни G01;
- конфликты `src/drawer.ahk` решить по смыслу: сохранить новую hotkey/slot runtime-семантику Codex и DWM/theme изменения Gemini;
- убрать случайный `readonly` с имени permanent-слота;
- убедиться, что `focusHotkey` не возвращён конфликтом;
- сохранить `drawer-debug.log` / `Нашёл баг…`;
- сохранить build/config safety Gemini;
- не начинать Wave 3 correctness/architecture в этой задаче.

### Проверки

- AHK `/validate`;
- `settings-seam`;
- `webview-slice`;
- frontend `npm test` + build;
- typecheck использовать локальный repo script/dependency, если он уже существует; внешний `npx vue-tsc` не считать достоверным gate до T00;
- production build запустить, потому что G01 менял packaging/config safety; проверить два случая: fresh output получает default config, rebuild существующего output сохраняет изменённый config;
- VM/full suite не запускать.

После зелёной интеграции: commit + push `dev/integration/slots-settings-wave1`, clean tree, обновить `PROJECT_STATE.md`, factual integration report. **Не вливать в `wip/slots-parity` самостоятельно** — архитектор проверит remote branch и передвинет базу.

---

## TASK T00 — сделать frontend typecheck локальным и воспроизводимым

**Status:** READY  
**Executor:** Gemini, strongest available Gemini mode; NOT Astra  
**Base:** актуальный `dev/wip/slots-parity`  
**Suggested branch:** `chore/frontend-local-typecheck`

### Причина

C01 обнаружил: `npx vue-tsc --noEmit` подтягивает внешний `vue-tsc`, несовместимый с установленным TypeScript 5.9 (`ERR_PACKAGE_PATH_NOT_EXPORTED`), а локального `vue-tsc` в repo нет. Значит typecheck зависит от случайного внешнего состояния машины.

### Цель

Сделать `settings-ui` typecheck локальным, детерминированным и запускаемым одной repo-командой.

### Требования

- проверить текущие `package.json` / lockfile / TypeScript / Vue версии;
- добавить совместимую локальную dev dependency только если она действительно нужна;
- завести/исправить `npm run typecheck` так, чтобы он использовал локальную dependency, а не скачивал что-то через внешний `npx`;
- lockfile должен фиксировать результат;
- не обновлять весь dependency graph без необходимости;
- не трогать runtime Drawer, Slots, Settings UI behavior или build semantics;
- `npm test`, `npm run typecheck`, `npm run build` должны проходить из clean install state (`npm ci` если применимо).

Перед завершением: commit + push `dev/chore/frontend-local-typecheck`, clean tree, factual report. Не merge в `wip/slots-parity`.

---

# СЛЕДОМ

## TASK A01 — ручная приёмка интегрированных Slots + Settings shell

**Status:** BLOCKED_ON_I01  
**Executor:** пользователь; инструкции даёт архитектор

После принятой integration-ветки пользователь проверяет только человеческие сценарии: custom show/hide hotkeys, hotkey меняется сразу, dynamic bind/release/reset, permanent↔dynamic с живым окном, handle после bind, late permanent launch, Settings titlebar/About, build config safety. При баге: воспроизвести → `Нашёл баг…` → сообщить номер BUG и действие/результат.

---

# WAVE 3 — Settings correctness

## TASK C02 — General + dynamic override в одном Save

**Status:** BLOCKED_ON_I01  
**Preferred executor:** Codex Terra High

Подтверждённый дефект: old General=70, slot override=50; одним Apply General→50 и slot→70. План сравнивает slot с old General 70 и ошибочно удаляет override. Планировать overrides нужно относительно **финального General state этого же Save**. Добавить regression и симметричные no-op/delete случаи; persistence pipeline не переписывать.

## TASK C03 — partial/retryable/diagnostics correctness

**Status:** BLOCKED_ON_C02_OR_SEPARATE_FILE_REVIEW  
**Preferred executor:** Codex Terra High / Opus reserve

Structured partial-save/reload/reconcile должен доходить до UI; без ложного `Сохранено`, без потери draft/field diagnostics, warning не должен исчезать после no-op. Один persistence path, без фиктивного rollback.

## TASK G02 — stale windowClass + picker identity

**Status:** BLOCKED_ON_I01  
**Preferred executor:** Gemini

Смена exe не оставляет class старого app; picker согласованно обновляет exe/class/name seed; dynamic→permanent с live window получает чистые identity data. Не менять permanent FindWindow больше необходимого.

## TASK G03 — live hideOnBlur/blurMs + save lock

**Status:** BLOCKED_ON_I01  
**Preferred executor:** Gemini, эскалация Codex при runtime race

После Apply runtime-настройки должны реально влиять на уже показанное окно; blur timer не stale; General inputs защищены во время Save от перезаписи позднего ввода.

## TASK G04 — custom animation preset `Своя`

**Status:** BLOCKED_ON_I01  
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

1. Сейчас параллельно: **I01 Codex + T00 Gemini**.
2. Архитектор проверяет обе remote branches.
3. Принятая integration-база → A01 ручная приёмка.
4. Wave 3 correctness по две непересекающиеся задачи.
5. Wave 4 UX.
6. Только потом modular architecture.
7. Test/release debt.
8. Future product отдельно.
