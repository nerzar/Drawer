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
- Final SHA: `<sha>`
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

- Отчёт создаётся **до** финального push задачи и входит в её final commit либо в отдельный завершающий commit той же feature-ветки.
- `Final SHA` в самом отчёте можно оставить как `PENDING_FINAL_COMMIT`, если SHA ещё не существует; после commit агент обязан сообщить фактический final SHA в своём финальном ответе. Если удобно, сделать второй маленький report-only commit с заполненным SHA.
- Для параллельных агентов обязательно указывать точный `Worktree`.
- Если работа продолжает старый чат/сеанс, Run ID остаётся прежним; если это новый чат для той же задачи — новый Run ID и ссылка текстом на предыдущий Run ID в разделе Result/Important decisions.
- Не редактировать `docs/ARCHITECT_STATE.md`.
