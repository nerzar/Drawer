# RUN-20260908-MUSE-TRAY-MODULE-EXTRACT-01

- Run ID: `RUN-20260908-MUSE-TRAY-MODULE-EXTRACT-01`
- Agent: `MUSE`
- Status: `READY`
- Session: `NEW`
- Base SHA: `bbae7aaab110aa0ab995a796292a58d0ae3ec382`
- Task branch: `muse/tray-module-extract`

## Цель

Сделать один behavior-neutral шаг уменьшения `drawer.ahk`: вынести только построение tray menu и его callbacks в `Tray.ahk` после готового WebView2 tray fix.

## Scope

1. Сделать fresh fetch и создать task-ветку от точного base SHA.
2. Перенести регистрацию tray menu, его подписи и маленькие callback-обёртки в новый `src/Tray.ahk`.
3. Оставить product operations (`SettingsWebShow`, reload, exit и другие существующие действия) в текущих владельцах; модуль tray только связывает menu items с ними.
4. Подключить модуль одним явным entrypoint из `drawer.ahk`.
5. Добавить узкую статическую/AHK-проверку состава menu и callback routing.

## Ограничения

- Никаких изменений пунктов, порядка, подписей, хоткеев или поведения tray относительно base commit.
- Не переносить Settings, Cleanup, config loading или другие крупные функции.
- Не трогать WebView protocol/UI и VM-инфраструктуру.

## Ожидаемый результат

Один commit с новым малым модулем и уменьшенным `drawer.ahk`; релевантные AHK tests проходят. Короткий VM acceptance подтверждает неизменный tray, открытие WebView2 Settings, reload и exit cleanup.
