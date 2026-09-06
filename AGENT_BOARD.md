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

### Critical Git ref hygiene

`dev` is the private **remote name**, not a local branch namespace.

- The shared remote branch is `refs/remotes/dev/wip/slots-parity` when reading/fetching and `refs/heads/wip/slots-parity` as the remote push destination.
- **Never create a local branch named `dev/wip/slots-parity` or any local branch beginning with a remote-name prefix such as `dev/...`.**
- If local `refs/heads/dev/wip/slots-parity` exists, treat it as a hygiene defect: before normal work, verify it contains no unique commits and is not checked out by any worktree; then delete it. If it is checked out or has unique commits, stop with `BLOCKED` rather than guessing.
- Never use ambiguous shorthand `dev/wip/slots-parity` in commands that resolve revisions. Use `refs/remotes/dev/wip/slots-parity` (or an exact SHA) for reads/bases.
- Never run `git push dev dev/wip/slots-parity`. Push explicit destinations, e.g. `git push dev HEAD:refs/heads/wip/slots-parity` for an authorized shared-branch claim/docs update, or `git push dev HEAD:refs/heads/<task-branch>` for task output.
- Before any destructive branch cleanup, inspect `git worktree list --porcelain` and `git show-ref` using fully qualified refs.

Before starting an autonomous task, an agent must claim it by creating `docs/agent-claims/<RUN-ID>.md` on the shared remote branch after a fresh `git fetch dev`. If that claim already exists for another agent, skip the task. One Run ID = one working branch. No extra analysis/review/verify/tmp branches unless the task explicitly requires them.

Claim file must contain: Run ID, agent/client, actual model, claimed timestamp, observed shared SHA, task branch, status `CLAIMED`. On successful completion update the same claim to `DONE` with Code SHA, report tip SHA and checks. On blocker update to `BLOCKED` and stop autonomous pickup until architect action.

For claim/docs commits targeting the shared branch, base from `refs/remotes/dev/wip/slots-parity` (or its exact SHA), use a non-ambiguous temporary/local claim branch name that does **not** begin with `dev/`, and push explicitly to `HEAD:refs/heads/wip/slots-parity`. If the push is rejected because the shared branch advanced, fetch/rebase or recreate the claim commit on the new remote tip, then re-check whether another claim now exists before retrying.

Autonomous workers must never self-promote code into `wip/slots-parity`, self-delete other agents' branches, mark a feature accepted, or change architecture/priority. Promotion, acceptance, branch cleanup, and dependency unblocking remain architect-owned unless a task explicitly delegates them.

## Общий протокол

1. `git fetch dev`.
2. Прочитать актуальный `AGENT_BOARD.md` именно из `refs/remotes/dev/wip/slots-parity` (или exact shared SHA).
3. Прочитать `docs/agent-reports/REPORT_FORMAT.md`.
4. Взять только автономную `READY` задачу, где агент явно указан в `Eligible`, либо Run ID, данный оператором.
5. Перед изменениями проверить worktree, branch, base и status; отдельно убедиться, что нет неоднозначного local ref `refs/heads/dev/wip/slots-parity`.
6. Coding-задачи работают в отдельных sibling-worktree `C:\Users\nerza\Projects\drawer-agent-worktrees\<task-id>`.
7. Не reset/clean/discard чужую работу; public `origin` не трогать.
8. Выполнить задачу строго в scope.
9. VM/full suite только если требует задача; иначе целевые gates.
10. Перед завершением: factual report, commit, push private `dev` с явным `HEAD:refs/heads/<task-branch>`, verify remote, clean tree.
11. `docs/ARCHITECT_STATE.md` не редактировать.
12. Архитектурная идентичность результата — `Code SHA`; report-tip не использовать как coding base.

При blocker/conflict/product ambiguity/risk: сохранить безопасное состояние, push/report `BLOCKED` и прекратить автономный pickup до решения архитектора.

## Текущий статус

- Shared production identity после P06: `9162d157a3f6b3155519ed6248605b0f432ff832`; текущий `wip/slots-parity` может быть выше только docs/task/claim-коммитами.
- G03 accepted + runtime verified + promoted.
- G05/G05FIX accepted + runtime verified + promoted.
- G06 implementation Code SHA: `5e9c717f23ee4503c0850a9be5d406892d49bed9`; awaiting independent review + runtime acceptance.
- A02 analysis: `READY_TO_IMPLEMENT`; first implementation slice is watcher policy/state extraction.
- Branch cleanup P06 reduced remote refs substantially; archive refs are intentionally retained.

## AUTONOMOUS READY QUEUE

### 1. A02S1 — watcher policy/state seam
- Status: `READY`
- Eligible: `CODEX`
- Run ID: `RUN-20260906-AUTO-CODEX-A02S1-01`
- Base: shared production identity `9162d157a3f6b3155519ed6248605b0f432ff832` (latest shared tip allowed if newer commits are docs/claims only)
- Branch: `refactor/window-focus-watch-seam`
- Task file: `docs/agent-tasks/RUN-20260906-AUTO-CODEX-A02S1-01.md`

### 2. G06ACCEPT — live WebView/Windows acceptance
- Status: `READY`
- Eligible: `ANTIGRAVITY`
- Run ID: `RUN-20260906-AUTO-ANTIGRAVITY-G06ACCEPT-01`
- Base: G06 Code SHA `5e9c717f23ee4503c0850a9be5d406892d49bed9`
- Branch: `verify/g06-runtime-acceptance`
- Task file: `docs/agent-tasks/RUN-20260906-AUTO-ANTIGRAVITY-G06ACCEPT-01.md`

### 3. G06R — independent code review
- Status: `READY`
- Eligible: `DEV1`
- Run ID: `RUN-20260906-AUTO-DEV1-G06REVIEW-01`
- Base: G06 Code SHA `5e9c717f23ee4503c0850a9be5d406892d49bed9`
- Branch: `review/g06-navigation-accessibility`
- Task file: `docs/agent-tasks/RUN-20260906-AUTO-DEV1-G06REVIEW-01.md`

## NEXT AFTER ARCHITECT REVIEW

- If G06 review + runtime acceptance both pass: architect promotes G06 and cleans its temporary refs.
- Review A02S1; if accepted, publish A02S2 focus-history/foreground-state extraction.
- Then A03 parking/geometries seam, A04 handles seam, A05 Settings service/tray seams.
- T01/T02 test debt after architecture stabilizes.
- R01 diagnostics production policy; R02 production build acceptance; R03 final human acceptance.
- F01/F02/F03/F04/F08/F11/F12 remain deferred/future product decisions.
