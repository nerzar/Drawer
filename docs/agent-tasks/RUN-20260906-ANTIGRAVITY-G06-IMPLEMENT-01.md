# G06 — navigation/accessibility/polish implementation

- Run ID: `RUN-20260906-ANTIGRAVITY-G06-IMPLEMENT-01`
- Executor: Antigravity
- Model: Gemini 3.8 Flash
- Base Code SHA: `97962bdf8f821f4c42bc26df81856231fa04164c` (accepted G05FIX; includes G05 UX truth fixes)
- Analysis input: `analysis/g06-navigation-accessibility`
- Output branch: `fix/settings-navigation-accessibility`

## Goal
Implement the repo-approved G06 navigation/accessibility/polish items on top of accepted G05FIX without changing backend/runtime semantics.

## Required scope
Implement the high-value, low-risk G06 items from the analysis report:
1. Preserve selected slot when leaving/re-entering Slots by lifting selection state to parent (`App.vue`) and passing/updating it explicitly. Do NOT use KeepAlive.
2. About: replace fixed-looking per-slot show/hide shortcut copy with truthful configurable/default wording.
3. Sidebar: navigation semantics (`nav`, accessible label, active `aria-current`) and Russian labels `Общие`, `Слоты`, `О программе`.
4. General labels: stable ids/`for`, `aria-invalid` where applicable, accessible label for monitor number. Preserve G03 save-lock behavior.
5. Footer status/error announcement semantics (`role=status`, `aria-live` etc.) without changing C03 state logic.
6. Slots picker/help accessible names/description using final G05 wording, without changing picker behavior.
7. Consistent visible `:focus-visible` treatment for common controls.
8. Improve small muted-text contrast via a token-level change, then visually review hierarchy.
9. Add `scrollbar-gutter: stable` where useful and ensure restored/error-selected slot row is scrolled into view with `block: nearest`.
10. Preserve accepted G05 narrow-layout behavior and G03 disabled-opacity fix; do not reintroduce compounded fieldset opacity.

## Constraints
- Frontend-only unless an unforeseen protocol blocker is proven; if backend change seems needed, stop BLOCKED rather than expand scope.
- Do not modify `src/config.ini`.
- Preserve G03/G05 semantics exactly.
- One output branch only; no extra scratch remote branches.
- Read G06A report in full before editing.

## Verification
Run `npm --prefix settings-ui test`, typecheck, build. Add focused tests for selected-slot persistence and accessibility/state helpers where practical. Perform a live WebView smoke pass if environment permits: tab away/back keeps selected slot, keyboard focus visible, no narrow-pane overflow, About/sidebar copy correct. AHK gates only if AHK files are unexpectedly touched.

Report per REPORT_FORMAT with Code SHA and report tip SHA. Final: DONE/BLOCKED, branch, Code SHA, checks, manual-smoke summary, known gaps.