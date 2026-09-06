# Agent report format

Каждый coding agent перед завершением задачи пишет factual report в `docs/agent-reports/<date>-<agent>-<task>.md`.

Цель отчёта — не только зафиксировать код, но и позволить быстро найти **тот самый чат/сеанс**, даже если человек уже не следит за процессом вручную.

## Обязательный заголовок

```md
# <TASK ID> — <короткое название>

- Task ID: `<TASK ID>`
- Run ID: `<yyyyMMdd>-<agent>-<task>-<nn>`
- Agent/client: `<Codex | Antigravity | Claude Code | другое>`
- Model: `<точная модель/режим>`
- Chat/session ID: `<идентификатор, если клиент/среда его реально показывает; иначе NOT_EXPOSED>`
- Chat title: `<название чата, если доступно; иначе NOT_EXPOSED>`
- Search anchor: `<короткая уникальная строка, по которой этот чат можно найти поиском>`
- Started at: `<ISO/local timestamp если доступен>`
- Finished at: `<ISO/local timestamp если доступен>`
- Worktree: `<полный путь>`
- Branch: `<ветка>`
- Base SHA: `<sha>`
- Code SHA: `<sha коммита с итоговым production/test-кодом; если код не менялся — NONE>`
- Report tip SHA: `<sha финального report/docs commit или PENDING_FINAL_COMMIT>`
- Remote: `dev`
```

## Что считать Chat/session ID

Не придумывать идентификатор.

Если клиент реально показывает stable conversation/session/thread/task ID — записать его дословно. Если не показывает, писать `NOT_EXPOSED`.

В таком случае обязательны `Chat title` (если виден) и `Search anchor`. `Search anchor` — уникальная фраза для поиска истории, например:

`Drawer TASK C02 — General+dynamic override — codex/20260906`

Агент должен вставить этот anchor также в свой финальный ответ пользователю/оператору, чтобы его можно было найти через поиск по чатам.

## Основная часть отчёта

После заголовка:

1. Goal
2. Result
3. Commits
4. Important decisions
5. Problems found
6. Tests / verification
7. Known issues / unfinished
8. Suggested next step

Только факты, без chain-of-thought.

## Правила

- Отчёт создаётся **после фиксации итогового production/test-кода** либо отдельным завершающим report-only commit той же feature-ветки.
- **Все архитектурные review/integration/base-ссылки на реализацию должны указывать на `Code SHA`, а не на report tip SHA.** Это устраняет циклическую проблему, когда агент вписывает SHA в собственный отчёт и создаёт новый SHA без изменения кода.
- `Code SHA` должен быть стабильным коммитом с итоговым кодом задачи. После него разрешены только report/docs-only commits, если не началась новая итерация кода.
- `Report tip SHA` можно оставить как `PENDING_FINAL_COMMIT` внутри самого отчёта и сообщить фактический remote tip SHA в финальном ответе. **Не делать дополнительный commit только ради вписывания `Report tip SHA` в сам отчёт.**
- Если после report commit код всё же пришлось изменить, это новая кодовая итерация: обновить `Code SHA`, затем сделать новый report/docs commit. В review всегда использовать последний `Code SHA`.
- Для параллельных агентов обязательно указывать точный `Worktree`.
- Если работа продолжает старый чат/сеанс, Run ID остаётся прежним; если это новый чат для той же задачи — новый Run ID и ссылка текстом на предыдущий Run ID в разделе Result/Important decisions.
- Не редактировать `docs/ARCHITECT_STATE.md`.
