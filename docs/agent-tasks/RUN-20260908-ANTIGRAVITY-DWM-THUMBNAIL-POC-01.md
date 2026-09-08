# RUN-20260908-ANTIGRAVITY-DWM-THUMBNAIL-POC-01

Status: READY
Agent: ANTIGRAVITY
Session: NEW
Code SHA: `38c6daa586c86394733a09f1968c4de3f6351e13`
Task branch: `poc/dwm-thumbnail-animation-antigravity`

## Цель

Отдельным маленьким прототипом проверить, годится ли Windows DWM Thumbnail как visual animation layer для Drawer. Настоящее окно не должно проезжать через соседний монитор, а визуальная анимация должна происходить только внутри выбранного монитора.

Это исследование, не production-изменение.

## Что сделать

1. Fresh fetch перед работой.
2. Не менять production Drawer, `src/drawer.ahk`, `src/Slots.ahk` и Settings.
3. Сделать минимальный standalone PoC в `test/experiments` или другой явно экспериментальной области.
4. Источник — обычное тестовое окно. Реальное source-окно во время анимации остаётся в фиксированном безопасном положении.
5. На двух соседних мониторах показать thumbnail/overlay так, чтобы анимация не появлялась на соседнем экране.
6. Достаточно slide/reveal. Fade/zoom — только если получаются почти бесплатно из того же механизма.
7. Runtime-проверка только в подготовленной VM. На основной Windows владельца ничего не запускать.
8. Если VM требует существенного ремонта — остановиться с BLOCKED, не переносить runtime-тесты на host.

## Результат

Коротко зафиксировать:

- работает ли DWM Thumbnail для этой задачи;
- что происходит с source-окном и thumbnail;
- есть ли мерцание, задержка, артефакты, DPI/multi-monitor проблемы;
- вывод: `PROMISING`, `NOT_SUITABLE` или `NEEDS_FOLLOWUP`;
- commit/branch PoC;
- что реально удалось проверить в VM.

Не интегрировать PoC в Drawer и не промотить код. После завершения обновить report и снова прочитать `AGENT_BOARD.md`.
