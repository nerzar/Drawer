# G05 — Slots UX terminology/onboarding/narrow-layout implementation

- Run ID: `RUN-20260906-CODEX-G05-IMPLEMENT-01`
- Executor: Codex
- Model: use an economical/older coding model; do not use a heavy model unless blocked
- Source of truth: latest `dev/wip/slots-parity` after `git fetch dev`
- Analysis input: `dev/analysis/g05-slots-ux@bb8ca5e3724a853744f434c7698382ee8e48bbe1`
- Output branch: `fix/slots-ux-terminology-layout`

## Goal
Implement the already-approved G05A Slots UX cleanup without changing slot semantics.

Required outcomes:
1. Empty temporary/dynamic slot clearly explains its `Ctrl+Alt+Shift+N` capture/bind workflow.
2. Replace user-facing `Динамический` terminology with understandable temporary-binding wording/actions (e.g. `Закрепить за приложением…`) while preserving internal identifiers/contracts.
3. Clearly separate the user actions/concepts `Отвязать окно` and `Вернуть общие настройки`; do not conflate reset semantics.
4. Remove developer/internal vocabulary from user-facing UI where identified by G05A: `[dynamic]`, `[dynamicSlotN]`, `[slotN]`, raw `ahk_class`, mixed English `show/hide`. Internal protocol/config names stay unchanged.
5. Fix the narrow-layout reset block so the General reset action fits/wraps and remains usable; specifically investigate/remove the nested `.hotkey-cap` 120px margin problem identified in G05A rather than hiding/clipping the action.

## Constraints
- Start from the latest shared `dev/wip/slots-parity` actually present after fetch. Record exact Base SHA.
- Read G05A report before editing.
- Do not change backend slot behavior unless a tiny change is strictly required to preserve existing UI action semantics; if semantics are ambiguous, BLOCK instead of inventing behavior.
- Preserve accepted A01FIX/G02/C03 behavior.
- Do not touch `src/config.ini`.
- Keep scope focused on Slots UI/wording/layout and targeted tests.
- Use a dedicated sibling worktree per AGENT_BOARD.

## Verification
Run relevant settings-ui tests, typecheck and build. Add/update focused regression assertions for terminology and narrow-layout/reset controls where practical. AHK checks only if AHK/runtime files are actually touched.

## Completion
Report per `docs/agent-reports/REPORT_FORMAT.md`, including separate Code SHA and Report tip SHA. Push branch to `dev`, verify remote Code SHA/ref, clean tree. Final answer: Run ID, DONE/BLOCKED, branch, Code SHA, report tip SHA, checks, concise summary.