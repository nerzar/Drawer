# AGENT_BOARD — Drawer autonomous work queue

Blackboard между архитектором ChatGPT и coding agents.

**Владелец файла:** архитектор ChatGPT. Coding agents этот файл не редактируют и приоритеты сами не меняют.

## AUTONOMOUS WORKER PROTOCOL

Coding agents may self-pick work only when a task explicitly contains all of:
- `Status: READY`
- `Eligible: <agent types>`
- `Run ID`
- exact `Base` / source rule
- output `Branch`
- task file path

If any field is missing, the task is NOT autonomous-ready.

Before starting an autonomous task, an agent must atomically claim it by creating `docs/agent-claims/<RUN-ID>.md` on `dev/wip/slots-parity` after a fresh `git fetch dev`. If that claim already exists for another agent, skip the task. One Run ID = one working branch. No extra analysis/review/verify/tmp branches unless the task explicitly requires them.

Claim file must contain: Run ID, agent/client, actual model, claimed timestamp, observed shared SHA, task branch, status `CLAIMED`. On successful completion update the same claim to `DONE` with Code SHA, report tip SHA and checks. On blocker update to `BLOCKED` and stop autonomous pickup until architect action.

Autonomous workers must never self-promote code into `wip/slots-parity`, self-delete other agents' branches, mark a feature accepted, or change architecture/priority. Promotion, acceptance, branch cleanup, and dependency unblocking remain architect-owned unless a task explicitly delegates them.

## Общий протокол

1. `git fetch dev`.
2. Прочитать актуальный `AGENT_BOARD.md` из `dev/wip/slots-parity`.
3. Прочитать `docs/agent-reports/REPORT_FORMAT.md` из `dev/wip/slots-parity`.
4. Взять только задачу, чей Run ID дан оператором, либо автономную `READY` задачу, где агент явно указан в `Eligible`.
5. Перед изменениями проверить `git worktree list`, branch, base и `git status`.
6. Параллельные coding-задачи всегда работают в отдельных sibling-worktree: `C:\Users\nerza\Projects\drawer-agent-worktrees\<task-id>`.
7. Worktree нельзя создавать внутри другого repo/worktree. Незакоммиченную работу другого агента нельзя reset/clean/discard.
8. Выполнить задачу целиком, не расширяя scope без необходимости.
9. VM/full suite не является default gate; только разумные целевые проверки, если задача не требует иного.
10. Перед завершением: factual report по `REPORT_FORMAT.md`, commit, push в private remote `dev`, verify remote HEAD = local HEAD, clean tree.
11. Публичный `origin` не трогать.
12. `docs/ARCHITECT_STATE.md` coding agents не редактируют.
13. Архитектурная идентичность результата — `Code SHA`; report-tip SHA не использовать как base для следующего coding run.

Если есть blocker, неоднозначное продуктовое решение, конфликт с параллельной задачей или риск потери данных: сохранить безопасное состояние, push и остановиться с `BLOCKED` в отчёте.

## Текущий статус на 2026-09-06 после G03/G05

- G03 accepted and runtime-verified; shared promotion lineage exists.
- G05/G05FIX accepted and runtime-verified at Code SHA `97962bdf8f821f4c42bc26df81856231fa04164c`.
- G06 implementation completed at Code SHA `5e9c717f23ee4503c0850a9be5d406892d49bed9`; **awaiting architect review**, therefore not autonomous promotion-ready.
- A02 analysis completed on `analysis/a02-windows-focus-seam`; recommendation `READY_TO_IMPLEMENT`, but A02 implementation must be architect-sliced before becoming autonomous-ready.

## AUTONOMOUS READY QUEUE

No tasks are READY for autonomous pickup yet.

Reason: first reconcile shared branch/promotion state and review G06, then architect will publish explicit READY tasks with Eligible fields. Agents must idle rather than invent work.

## BACKLOG — next architect actions

1. Reconcile `dev/wip/slots-parity` to the accepted G05 promotion lineage and verify remote shared tip.
2. Review G06 Code SHA `5e9c717f23ee4503c0850a9be5d406892d49bed9`.
3. Perform broad safe cleanup of obsolete non-archive branches after reachability verification.
4. Split A02 into implementation slices from the completed A02 analysis.
5. Populate `AUTONOMOUS READY QUEUE` with explicit Run IDs + Eligible agents.

## FUTURE PRODUCT / RELEASE DEBT

- A03 parking/geometries seam — after A02.
- A04 handles seam — after A02/A03.
- A05 Settings service + tray seams — after A02/A04.
- T01/T02 test debt — after architecture stabilizes.
- R01 diagnostics production policy.
- R02 production build acceptance.
- R03 final human acceptance.
- F01/F02/F03/F04/F08/F11/F12 remain deferred/future product decisions.
