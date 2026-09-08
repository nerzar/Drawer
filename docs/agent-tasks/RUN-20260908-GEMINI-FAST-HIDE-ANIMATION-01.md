# RUN-20260908-GEMINI-FAST-HIDE-ANIMATION-01

- Run ID: `RUN-20260908-GEMINI-FAST-HIDE-ANIMATION-01`
- Agent: `GEMINI`
- Status: `INTEGRATED` (реализация принята после code/semantic review; отдельный worker VM acceptance снят как integration gate решением владельца)
- Session: `NEW`
- Base SHA: `12c45e4a7fb59642e42318f4b8a8ef4b4db0343b`
- Task branch: `gemini/fast-hide-animation`
- Code SHA: `8c6863e52b04f9635dffee5e567ac6fd7e8087d9`
- Integration SHA: `f61696ddfb7279d7bb425f8589cbfbcc56a5a6cb`

## Цель

Привести скорость скрытия к `PRODUCT_SPEC.md`: Hide должен занимать примерно 40% времени Show, чтобы уход окна был заметно быстрее появления.

## Scope

1. Сделать fresh fetch и создать task-ветку от точного base SHA.
2. Передать длительность или множитель в общий animation path: Show использует выбранный `animMs`, Hide — около 40% этого времени.
3. Сохранить текущую easing-кривую, финальную геометрию и поведение `animSteps=0`.
4. Не добавлять настройку скорости Hide и не менять `config.ini`.
5. Добавить узкую проверку расчёта длительности и Show/Hide call sites.

## Ограничения

- Не менять парковочную геометрию, monitor resolution, focus/blur policy и DWM/internal-edge поведение.
- Не выполнять общий refactoring animation engine.
- Runtime acceptance провести на одном мониторе с обычным внешним краем.

## Ожидаемый результат

Один commit с минимальным diff и зелёными релевантными AHK tests. В VM окно появляется с прежней скоростью, скрывается примерно в 2.5 раза быстрее, после обоих направлений остаётся в правильной геометрии и сохраняет прежнее focus behavior.
