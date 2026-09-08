# AGENT_BOARD — текущая работа Drawer

Это рабочая доска, а не архив. Поведение определяется `docs/PRODUCT_SPEC.md` и свежими решениями владельца; общий порядок — `docs/05-план-работ.md`.

**Доску ведёт архитектор. Запущенный агент берёт только назначенные ему READY-задачи в указанном порядке и не меняет приоритеты.**

## База и текущая интеграция

- Актуальный `master`: `51bdcda72f32de03096cdf0abd72124448120237`.
- Ветка сведения: `codex/integrate-wave-20260908`; `master` пока не изменён.
- В ветку сведены Settings instrumentation, full reset, единый WebView2 Settings в tray, настоящий путь `config.ini`, monitor picker и ускоренный Hide.
- Code/semantic review и объединённые repo-проверки пройдены. Отдельный worker VM acceptance не является gate этой волны; владелец проверяет runtime на итоговой сведённой версии.

## Роли

- `CODEX` — архитектор/оркестратор; сложные решения и неоднозначное продуктовое поведение.
- `MUSE` — repo-only анализ, небольшие исправления и одномониторные runtime/GUI-проверки в готовой VM.
- `GEMINI` — владелец VM-инфраструктуры и исполнитель ограниченных product changes, которым полезна собственная runtime/GUI-проверка.

Готовность VM для `MUSE` подтверждена smoke-проверкой владельца: `VM_READY`, `GUEST_READY`, screenshots, tray, `OpenSettings`, `ActivateWindow`, `SendKeys` и `RunAhk` работают. Multi-monitor в этой VM не проверяем.

## Кто сейчас работает

- Последние активные задачи `MUSE` и `GEMINI` завершены; активных Run сейчас нет.

## READY

- READY-задач нет: текущая integration wave закрывается, новую разработку агенты не начинают.

## PAUSED до решения о следующей волне

- [`RUN-20260908-MUSE-SETTINGS-USER-FACING-CONTROLS-01`](docs/agent-tasks/RUN-20260908-MUSE-SETTINGS-USER-FACING-CONTROLS-01.md).
- [`RUN-20260908-MUSE-SETTINGS-ANIMATION-PRESETS-01`](docs/agent-tasks/RUN-20260908-MUSE-SETTINGS-ANIMATION-PRESETS-01.md).
- [`RUN-20260908-MUSE-TRAY-MODULE-EXTRACT-01`](docs/agent-tasks/RUN-20260908-MUSE-TRAY-MODULE-EXTRACT-01.md).

## INTEGRATED в текущей волне

- [`RUN-20260908-GEMINI-WEBVIEW-SETTINGS-TRAY-01`](docs/agent-tasks/RUN-20260908-GEMINI-WEBVIEW-SETTINGS-TRAY-01.md) — `57bc0cea3a5c4dab6e0a0a1ca5aacd72deac2bec`.
- [`RUN-20260908-GEMINI-SETTINGS-MONITOR-PICKER-01`](docs/agent-tasks/RUN-20260908-GEMINI-SETTINGS-MONITOR-PICKER-01.md) — `e660bee2153d058e76497f3be1fc796103968dc9`.
- [`RUN-20260908-GEMINI-FAST-HIDE-ANIMATION-01`](docs/agent-tasks/RUN-20260908-GEMINI-FAST-HIDE-ANIMATION-01.md) — `f61696ddfb7279d7bb425f8589cbfbcc56a5a6cb`.
- [`RUN-20260908-MUSE-SETTINGS-CONFIG-PATH-01`](docs/agent-tasks/RUN-20260908-MUSE-SETTINGS-CONFIG-PATH-01.md) — `9753d3be2c39ce9adcfe44c793dd6bc937fdfe07`; принято владельцем без отдельного VM acceptance.
- Full reset — `68218127b1a8a65d32eb3b7147905385772f01cf`; физический хоткей PASS по `docs/agent-reports/RUN-20260908-MUSE-FULL-RESET-VM-01.md`.

## Acceptance без отдельной READY-задачи

- Владелец проводит общую ручную runtime-приёмку итоговой версии после сведения; отсутствие отдельных worker VM-прогонов не блокирует эту integration wave.
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
- Реализация сопровождается repo-проверками; runtime acceptance обычно входит в задачу, но архитектор или владелец может перенести его на итоговую интегрированную версию.
- Если стенд перестал быть готов, вернуть конкретный инфраструктурный blocker и не превращать product task в ремонт VMware.
- При расхождении с `PRODUCT_SPEC.md` или неоднозначности остановиться и вернуть вопрос архитектору.
