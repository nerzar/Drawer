# Отчёт: RUN-20260908-MUSE-FULL-RESET-VM-01

- Task / Run ID: `RUN-20260908-MUSE-FULL-RESET-VM-01`
- Агент и модель: `MUSE` / Muse Spark (внешний coding/runtime agent)
- Ветка и worktree: `muse/full-reset-vm-01`, основной checkout без отдельного worktree
- Base SHA: `12c45e4a7fb59642e42318f4b8a8ef4b4db0343b` (проверен после fresh fetch)
- Code SHA итогового кода: `12c45e4a7fb59642e42318f4b8a8ef4b4db0343b` (production-код не менялся — только runtime-проверка)
- Статус task-файла: файл задачи удалён из доски коммитом `973848b` во время выполнения; результат относится к разделу `AGENT_BOARD.md` «Acceptance без отдельной READY-задачи — full reset». Доску не правил.

## Короткий результат

**PASS.** Физический `Ctrl+Alt+Shift+0` в одномониторной Windows VM выполняет полный сброс по `PRODUCT_SPEC.md`, Drawer не завершается. Все 6 пунктов приёмки из task-файла пройдены.

## Что реально проверено

Стенд: отдельная копия `src` ровно на Base SHA (хеши `drawer.ahk`/`Slots.ahk`/`WindowFocus.ahk` побайтово совпали с blob base) + собранный `settings-ui` base + отдельный тестовый `config.ini` в `C:\fullreset-test\src` гостя. Настройки владельца не затронуты. VM одномониторная (`Monitors detected: 1`).

Тестовый конфиг «до» отличался от defaults: `[general]` 260/20/500, `[dynamic]` TestSlot/monitor=1/edge=left/width=40/hideOnBlur=false, `[slot3]` PermTest, `[dynamicSlot4]` edge=top, `[hotkeys]` slot2=`^!F2`. Создана динамическая привязка слота 1 к Notepad (`[BIND] Slot 1 bound to hwnd=590008`).

1. Процесс жив, хоткеи работают: после сброса PID 2452 на месте, `^!0` в 16:19:55 обработан (`[HOTKEY] Pressed ^!0 (Clear slots)`).
2. Привязки отсутствуют: лог `[RELEASE] SlotClearAll`, `Slot 1 fully reset hwnd=590008`; reconcile показывает 9 динамических слотов без overrides; UI слотов — все «пусто / Временный».
3. `[slot3]`, `[dynamicSlot4]`, `[hotkeys]` удалены (файл «после», ниже).
4. Общие настройки и defaults восстановлены: `[general]` 160/14/250/true, `[dynamic]` Слот/cursor/right/70/true/true.
5. WebView2 Settings открываются и показывают сброшенное состояние: «Общие» (70, Справа, Следовать за курсором, Обычная, 250) и «Слоты» (9 × пусто/Временный) — скриншоты в отчёте.
6. Debug log: `[HOTKEY] Pressed ^!+0 (Full reset)` → `[RESET] Full reset completed`; строк `Exit Drawer`, `EXCEPTION`, `Failed` нет.

Фрагмент лога сброса:

```text
2026-09-08 16:18:43.784 [HOTKEY] Pressed ^!+0 (Full reset)
2026-09-08 16:18:43.868 [RELEASE] SlotClearAll: clearing all slots
2026-09-08 16:18:43.871 [RELEASE] Slot 1 fully reset hwnd=590008
2026-09-08 16:18:43.979 [RESET] Full reset completed
```

Конфиг «после» (полностью):

```ini
[general]
animMs=160
animSteps=14
blurMs=250
handles=true
[dynamic]
name=Слот
monitor=cursor
edge=right
width=70
activateOnShow=true
hideOnBlur=true
```

Полные файлы: `RUN-20260908-MUSE-FULL-RESET-VM-01.drawer-debug.log`, `.config-before.ini`, `.config-after.ini`, `.settings-general.jpg`, `.settings-slots.jpg` рядом с отчётом.

## Что осталось нерешённым

- Ничего по самому full reset: дефектов не найдено, исправление кода не требуется.
- В госте остался предсуществующий процесс `AutoHotkey64` (PID 3264, был до начала работ) — не исследован и не тронут (возможный VM-tooling, вне scope). Notepad оставлен свёрнутым с нетронутым содержимым. Каталог `C:\fullreset-test` оставлен в госте как evidence. Мой Drawer (PID 2452) завершён через `killProcessInGuest`.
- По пути были два инцидента без последствий: промахи мышью из-за разрешения скриншотов 1920x1200 (лечится пересчётом координат) и `Alt+F4`, открывший диалог «Завершение работы Windows» (закрыт через `Esc`, ничего не выполнено).
- Новую MUSE-очередь из обновлённой доски не брал — жду отдельной команды.

## Следующий шаг

Архитектор может интегрировать `codex/full-reset-hotkey` в `master` — runtime-приёмка физического хоткея закрыта этим отчётом.
