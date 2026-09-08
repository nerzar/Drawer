# RUN-20260908-MUSE-SETTINGS-CONFIG-PATH-01

- Run ID: `RUN-20260908-MUSE-SETTINGS-CONFIG-PATH-01`
- Agent: `MUSE`
- Status: `READY`
- Session: `NEW`
- Base SHA: `12c45e4a7fb59642e42318f4b8a8ef4b4db0343b`
- Task branch: `muse/settings-config-path`

## Цель

В WebView2 Settings, раздел «О программе», показать настоящий абсолютный путь к используемому `config.ini` и добавить работающую команду «Копировать путь».

## Scope

1. Сделать fresh fetch, создать task-ветку от точного SHA `12c45e4a7fb59642e42318f4b8a8ef4b4db0343b`.
2. Передать фактический `configPath` из AHK в WebView через типизированный Settings protocol; не вычислять путь во frontend.
3. Показать путь в `AboutView` без названий INI-секций и других внутренних деталей.
4. «Копировать путь» должно копировать именно строку, полученную от host. Предпочесть явное действие host/bridge, чтобы не зависеть от разрешений browser clipboard.
5. Существующая ссылка GitHub должна остаться рабочей через текущий WebView new-window handler.
6. Добавить только узкие тесты protocol/UI/host seam, необходимые для этого поведения.

## Ограничения

- Repo-only: Drawer, host GUI и VM не запускать.
- Не менять визуальную структуру Settings, другие вкладки, сохранение настроек или native Settings.
- Не добавлять открытие Explorer, редактирование файла и другие соседние действия.
- Не менять product semantics full reset из base commit.

## Ожидаемый результат

Один commit с минимальным diff. Обязательные проверки: `npm test`, `npm run typecheck`, `npm run build` и релевантный AHK seam. В отчёте указать commit, изменённые файлы, результаты проверок и один точный runtime-сценарий, который затем должен подтвердить `GEMINI`.
