# RUN-20260908-MUSE-SETTINGS-ANIMATION-PRESETS-01

- Run ID: `RUN-20260908-MUSE-SETTINGS-ANIMATION-PRESETS-01`
- Agent: `MUSE`
- Status: `PAUSED` (текущая integration wave закрывается; запуск только после нового решения архитектора/владельца)
- Session: `NEW`
- Base SHA: `12c45e4a7fb59642e42318f4b8a8ef4b4db0343b`
- Task branch: `muse/settings-animation-presets`

## Цель

В обычном WebView2 Settings оставить выбор понятного пресета анимации и убрать прямое редактирование технических `animMs`/`animSteps`.

## Scope

1. Сделать fresh fetch и создать task-ветку от точного base SHA.
2. Удалить из UI поля длительности в миллисекундах, числа шагов и пункт «Своя» как способ открыть эти поля.
3. Сохранить варианты «Без анимации» и существующие пресеты скорости/плавности.
4. Для canonical пары, не совпадающей с пресетом, показывать нейтральный пункт «Текущая нестандартная» без чисел; Apply других полей не меняет эту пару.
5. Выбор обычного пресета записывает соответствующие `animMs`/`animSteps` через существующий wire path.
6. Обновить узкие frontend-тесты round-trip и preset selection.

## Ограничения

- Не добавлять новые типы анимации, config keys или backend protocol.
- Не менять алгоритм Slide и скорость Hide: это отдельная задача.
- Не трогать native Settings и остальные General controls.
- Runtime acceptance выполнять в готовой одномониторной VM.

## Ожидаемый результат

Один commit с минимальным diff. `npm test`, `npm run typecheck` и `npm run build` проходят. В VM технические числа не видны; выбор пресета переживает повторное открытие; нестандартная пара не теряется при Apply несвязанного поля.
