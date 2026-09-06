# G05ACCEPT — live WebView/manual acceptance of corrected Slots UX

- Run ID: `RUN-20260906-ANTIGRAVITY-G05ACCEPT-01`
- Executor: Antigravity
- Preferred model: Gemini 3.8 Flash Medium/High if available; otherwise any available non-Opus model
- Canonical G05FIX Code SHA: `97962bdf8f821f4c42bc26df81856231fa04164c`
- Branch: `fix/slots-ux-state-truth`

## Goal
Perform focused real Windows/WebView acceptance of the corrected G05 UX code. Do not redesign or add features.

## Required manual/runtime scenarios
1. Empty temporary slot at narrow Settings width: onboarding text is fully visible, not clipped, and explains capture workflow clearly.
2. Reset block: `Вернуть общие настройки` is visible, wraps cleanly, and does not overlap neighboring controls.
3. Canonical hotkey truth:
   - active custom hotkey is shown as active;
   - disabled/empty canonical hotkey is shown as disabled, not as a fake default;
   - a draft hotkey changed but not Applied is clearly marked pending and not presented as currently active.
4. Permanent -> temporary conversion staged but not Applied: UI must not pretend runtime is already temporary and must not show the runtime `Отвязать окно` action prematurely.
5. After Apply, temporary slot copy/actions match actual runtime state; Release/`Отвязать окно` works only when runtime is actually temporary/bound.
6. Check wide and narrow layout for obvious regression.

## Verification
Use dedicated worktree at Code SHA `97962bdf...`. Run settings-ui tests/typecheck/build. No production code changes unless a tiny acceptance-only fix is clearly necessary; if any substantive defect is found, report BLOCKED/NEEDS_FIX rather than expanding scope.

Preserve `src/config.ini`; restore any temporary runtime changes before completion. Report per REPORT_FORMAT with reviewed Code SHA and report tip separately.

Final verdict: ACCEPT / NEEDS_FIX / BLOCKED, with concise observed results.