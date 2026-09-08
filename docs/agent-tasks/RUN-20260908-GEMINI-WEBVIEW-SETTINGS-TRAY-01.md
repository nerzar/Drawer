# RUN-20260908-GEMINI-WEBVIEW-SETTINGS-TRAY-01

- Run ID: `RUN-20260908-GEMINI-WEBVIEW-SETTINGS-TRAY-01`
- Agent: `GEMINI`
- Status: `READY`
- Session: `NEW`
- Base SHA: `c68929c6adf2a6b7291af4b8c829b863c00754ca`
- Task branch: `gemini/webview-settings-tray`

## Цель

Сделать WebView2 единственной пользовательской точкой Settings в tray, чтобы Drawer не предлагал два редактора одного `config.ini` и обычный пункт Settings открывал актуальный интерфейс.

## Scope

1. Сделать fresh fetch и создать task-ветку от точного base SHA.
2. Оставить в tray один пункт `Settings`, который вызывает `SettingsWebShow()`.
3. Убрать из пользовательского tray отдельные native Settings и подпись `Settings (WebView2)`.
4. Повторный выбор Settings должен активировать уже открытое WebView2-окно, а не создавать второй редактор.
5. Legacy native Settings не удалять и не рефакторить: оно может оставаться внутренним кодом до отдельного решения.
6. Добавить узкую статическую/AHK-проверку tray registration и single-instance WebView path.

## Ограничения

- Не менять содержимое WebView2 Settings, Settings protocol, save semantics и config format.
- Не удалять большой блок native Settings и не выполнять соседний refactoring `drawer.ahk`.
- Не менять остальные пункты tray.
- Runtime acceptance выполнять в готовой одномониторной VM; инфраструктуру и multi-monitor не трогать.

## Ожидаемый результат

Один commit с минимальным diff и пройденными релевантными repo-проверками. В VM tray содержит ровно один `Settings`; он открывает WebView2, повторный клик активирует то же окно, native редактор параллельно не появляется, закрытие и повторное открытие работают.
