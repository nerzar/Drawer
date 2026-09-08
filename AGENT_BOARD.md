# AGENT_BOARD — текущая работа Drawer

Это рабочая доска, а не архив. Поведение определяется `docs/PRODUCT_SPEC.md` и свежими решениями владельца; общий порядок — `docs/05-план-работ.md`.

**Доску ведёт архитектор. Запущенный агент берёт только назначенные ему READY-задачи в указанном порядке и не меняет приоритеты.**

## База и незавершённая интеграция

- Актуальный `master`: `51bdcda72f32de03096cdf0abd72124448120237`.
- WebView2 Settings: `c68929c6adf2a6b7291af4b8c829b863c00754ca` в `codex/fix-settings-open`; запуск подтверждён владельцем на host, в `master` ещё не слито.
- Full reset: `12c45e4a7fb59642e42318f4b8a8ef4b4db0343b` в `codex/full-reset-hotkey`; repo-проверки и изолированный host-runtime пройдены, физический хоткей ещё нужно подтвердить в VM, в `master` ещё не слито.
- Ветка доски не является новой code base для продуктовых задач: каждый task-файл задаёт свой точный base SHA.

## Роли

- `CODEX` — архитектор/оркестратор; сложные решения и неоднозначное продуктовое поведение.
- `MUSE` — repo-only анализ, небольшие исправления и одномониторные runtime/GUI-проверки в готовой VM.
- `GEMINI` — владелец VM-инфраструктуры и исполнитель ограниченных product changes, которым полезна собственная runtime/GUI-проверка.

Готовность VM для `MUSE` подтверждена smoke-проверкой владельца: `VM_READY`, `GUEST_READY`, screenshots, tray, `OpenSettings`, `ActivateWindow`, `SendKeys` и `RunAhk` работают. Multi-monitor в этой VM не проверяем.

## Кто сейчас работает

- `MUSE` — запущена и забирает свою READY-очередь.
- `GEMINI` — запущен и забирает свою READY-очередь.

## READY

### MUSE — по порядку

1. [`RUN-20260908-MUSE-SETTINGS-CONFIG-PATH-01`](docs/agent-tasks/RUN-20260908-MUSE-SETTINGS-CONFIG-PATH-01.md) — реализовать показ настоящего пути `config.ini` и «Копировать путь» в WebView2 Settings, base `12c45e4a7fb59642e42318f4b8a8ef4b4db0343b`.
2. [`RUN-20260908-MUSE-SETTINGS-USER-FACING-CONTROLS-01`](docs/agent-tasks/RUN-20260908-MUSE-SETTINGS-USER-FACING-CONTROLS-01.md) — убрать из обычного UI технические `activateOnShow`/`blurCheckMs` и привести подпись размера панели к контракту, base `12c45e4a7fb59642e42318f4b8a8ef4b4db0343b`.
3. [`RUN-20260908-MUSE-SETTINGS-ANIMATION-PRESETS-01`](docs/agent-tasks/RUN-20260908-MUSE-SETTINGS-ANIMATION-PRESETS-01.md) — оставить пользователю пресеты анимации без прямого редактирования `animMs`/`animSteps`, base `12c45e4a7fb59642e42318f4b8a8ef4b4db0343b`.
4. [`RUN-20260908-MUSE-TRAY-MODULE-EXTRACT-01`](docs/agent-tasks/RUN-20260908-MUSE-TRAY-MODULE-EXTRACT-01.md) — после готового tray fix вынести только регистрацию tray и её callbacks из `drawer.ahk`, base `bbae7aaab110aa0ab995a796292a58d0ae3ec382`.

Один сеанс `MUSE` выполняет задачи по порядку и останавливается после каждой. Runtime acceptance входит в задачу реализации и не создаёт отдельный Run.

### GEMINI — по порядку

- [`RUN-20260908-GEMINI-WEBVIEW-SETTINGS-TRAY-01`](docs/agent-tasks/RUN-20260908-GEMINI-WEBVIEW-SETTINGS-TRAY-01.md) — BLOCKED на guest VM acceptance: реализация и AHK-проверки выполнены в `gemini/webview-settings-tray` (Code SHA: `bbae7aaab110aa0ab995a796292a58d0ae3ec382`), на хосте отсутствует `$env:DRAWER_VM_PASSWORD`.
- [`RUN-20260908-GEMINI-SETTINGS-MONITOR-PICKER-01`](docs/agent-tasks/RUN-20260908-GEMINI-SETTINGS-MONITOR-PICKER-01.md) — BLOCKED на guest VM acceptance: реализация, типы, Vue UI и тесты выполнены в `gemini/settings-monitor-picker` (Code SHA: `a9a101f018c8044565ef5ffb835f480387334ded`), на хосте отсутствует `$env:DRAWER_VM_PASSWORD`.
- [`RUN-20260908-GEMINI-FAST-HIDE-ANIMATION-01`](docs/agent-tasks/RUN-20260908-GEMINI-FAST-HIDE-ANIMATION-01.md) — BLOCKED на guest VM acceptance: реализация и seam-проверки выполнены в `gemini/fast-hide-animation` (Code SHA: `8c6863e52b04f9635dffee5e567ac6fd7e8087d9`), на хосте отсутствует `$env:DRAWER_VM_PASSWORD`.

`GEMINI` пропускает BLOCKED acceptance и берёт READY-задачи по порядку; возврат к tray acceptance — после восстановления VM credentials.

## Acceptance без отдельной READY-задачи

- Для full reset из `12c45e4a7fb59642e42318f4b8a8ef4b4db0343b` перед интеграцией один раз проверить в disposable config физический `Ctrl+Alt+Shift+0`: Drawer остаётся запущен, bindings и настройки сброшены. Автоматические проверки уже пройдены.
- «Сбросить слот», конверсии и picker не образуют отдельный фронт проверки. Если конкретный runtime-сценарий выявит дефект, архитектор создаст узкую fix-задачу с воспроизведением.

## Не READY / сознательно не трогаем

- DWM Thumbnail PoC остаётся DRAFT: [`RUN-20260908-ANTIGRAVITY-DWM-THUMBNAIL-POC-01`](docs/agent-tasks/RUN-20260908-ANTIGRAVITY-DWM-THUMBNAIL-POC-01.md). Это техническая развилка, а не очередная автоматическая задача.
- Попытка динамически назначить окно из постоянного слота должна получить отказ и Windows-уведомление с номером постоянного слота; решение владельца принято, но отдельную задачу сейчас не создаём.
- Инвариант «одно окно — один слот» позже проверяется отдельно и сейчас не считается подтверждённым багом.
- Поведение при недоступном закреплённом мониторе требует отдельного решения владельца.
- Сведение трёх размеров кромки к одному пользовательскому параметру не выдаём без уточнения правила пересчёта существующих значений.
- Полное context-menu parity для кромки пока не READY: нужно сначала определить, выполняются ли destructive actions немедленно или открывают Settings с черновиком.
- Новые модульные выносы из `drawer.ahk`, расширение числа слотов, installer и autostart не входят в ближайший фронт стабилизации.

## Общие ограничения READY-задач

- По умолчанию READY-задача изменяет продукт; проверка входит в её acceptance criteria. Verification-only Run допустим только когда новый runtime-факт необходим, чтобы понять, какое изменение делать.
- Fresh fetch и проверка точного base SHA перед началом.
- Одна task-ветка и один логический результат; никаких соседних рефакторингов.
- Реализация сопровождается repo-проверками и коротким runtime acceptance в готовой одномониторной VM, когда изменение затрагивает GUI/runtime.
- Если стенд перестал быть готов, вернуть конкретный инфраструктурный blocker и не превращать product task в ремонт VMware.
- При расхождении с `PRODUCT_SPEC.md` или неоднозначности остановиться и вернуть вопрос архитектору.
