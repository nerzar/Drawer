# RUN-20260908-GEMINI-SETTINGS-MONITOR-PICKER-01

- Run ID: `RUN-20260908-GEMINI-SETTINGS-MONITOR-PICKER-01`
- Agent: `GEMINI`
- Status: `READY`
- Session: `NEW`
- Base SHA: `c68929c6adf2a6b7291af4b8c829b863c00754ca`
- Task branch: `gemini/settings-monitor-picker`

## Цель

Заменить угадывание номера монитора в WebView2 Settings на список доступных мониторов с номером и разрешением.

## Scope

1. Сделать fresh fetch и создать task-ветку от точного base SHA.
2. Получить список мониторов в AHK через штатные monitor APIs и передать frontend descriptors: номер, ширина и высота рабочей области.
3. В General и обеих формах слота заменить свободный ввод номера на select вида `Монитор 1 — 1920×1080`; «Следовать за курсором» сохранить.
4. Сохранять в config прежний формат: `cursor` или номер.
5. Для отсутствующего сохранённого номера показывать отдельный недоступный вариант и не менять значение до явного выбора.
6. Добавить тесты protocol mapping, rendering и сохранения выбранного номера.

## Ограничения

- Не менять runtime-поведение при физическом отключении монитора: контракт ещё не определён.
- Не менять `monitor=cursor`, геометрию, multi-monitor animation и DWM.
- Не перерабатывать остальной layout Settings.
- Runtime acceptance провести на доступной одномониторной VM.

## Ожидаемый результат

Один commit с минимально необходимым protocol/backend/UI diff. Frontend tests, typecheck, build и релевантный AHK seam проходят. В VM реальный монитор показан с номером и разрешением, Apply/reopen сохраняет выбор, отсутствующее значение не переписывается молча.
