# RUN-20260908-MUSE-SETTINGS-USER-FACING-CONTROLS-01

- Run ID: `RUN-20260908-MUSE-SETTINGS-USER-FACING-CONTROLS-01`
- Agent: `MUSE`
- Status: `PAUSED` (текущая integration wave закрывается; запуск только после нового решения архитектора/владельца)
- Session: `NEW`
- Base SHA: `12c45e4a7fb59642e42318f4b8a8ef4b4db0343b`
- Task branch: `muse/settings-user-facing-controls`

## Цель

Привести обычный WebView2 Settings к утверждённому пользовательскому контракту: не показывать технические `activateOnShow` и `blurCheckMs`, сохранить настройку скрытия при потере фокуса и называть размер слота «Размер панели».

## Scope

1. Сделать fresh fetch и создать task-ветку от точного base SHA.
2. Удалить `activateOnShow` из General и обеих форм слота, не удаляя поле из wire/backend и не изменяя сохранённое значение при Apply других полей.
3. Удалить из UI редактирование и техническое отображение `blurCheckMs`, сохранив его текущее canonical значение при Apply.
4. Оставить «Убирать окно, когда фокус ушёл» доступным и кликабельным через всю подпись.
5. Заменить пользовательские подписи «Ширина (%)»/`ширина` на «Размер панели» там, где речь идёт о доле экрана слота. Внутреннее `widthPercent` не переименовывать.
6. Обновить только связанные UI-тесты, включая проверку, что скрытые поля продолжают round-trip без потери значения.

## Ограничения

- Не менять runtime-семантику активации, blur watcher, config keys, wire DTO и validation ranges.
- Не трогать технические поля custom animation и размеры кромки: для них нужен отдельный следующий slice.
- Не менять layout, цвета и остальные Settings controls.
- Runtime acceptance выполнять в готовой одномониторной VM; multi-monitor не нужен.

## Ожидаемый результат

Один commit с минимальным diff. `npm test`, `npm run typecheck` и `npm run build` проходят. В VM технические поля отсутствуют, «Убирать окно…» работает как раньше, Apply другой настройки не меняет скрытые значения в `config.ini`, подпись размера панели отображается в General и slot details.
