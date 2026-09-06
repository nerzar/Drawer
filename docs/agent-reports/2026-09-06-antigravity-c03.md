# C03 — partial/retryable/diagnostics correctness

- Task ID: `C03`
- Run ID: `RUN-20260906-ANTIGRAVITY-C03-01`
- Agent/client: `Antigravity`
- Model: `Gemini 3.8 Flash (Medium)`
- Chat/session ID: `5449223d-39f9-44a7-8c28-5e24aabde369`
- Chat title: `NOT_EXPOSED`
- Search anchor: `Drawer TASK C03 — partial retryable diagnostics correctness — antigravity/20260906`
- Started at: `2026-09-06T13:17:08+03:00`
- Finished at: `2026-09-06T13:35:00+03:00`
- Worktree: `C:\Users\nerza\Projects\drawer-agent-worktrees\C03`
- Branch: `fix/settings-partial-retry-diagnostics`
- Base SHA: `e4136c577d52e2fbf0b57d65b8344809236d5985`
- Final SHA: `2c09c1bbbb652ec69ff153fa89d48b1aa612f00d` (code commit: `2c09c1b`)
- Remote: `dev`

## 1. Goal

Fix Settings partial/retryable/diagnostics correctness end-to-end. Structured partial-save/reload/reconcile outcomes must reach the UI without false `Сохранено`, without losing retryable draft/field diagnostics, and without warnings disappearing after a no-op/reconcile path. Preserve one persistence path rather than adding a parallel save mechanism.

## 2. Result

1. **Root Causes Identified**:
   - In `SettingsPort.ahk` (`_SaveOutcome`): `extra["diagnostics"]` was omitted when `outcome.code != ""` (during error or partial failure), dropping diagnostics returned from runtime reconciliation across the wire.
   - In `settings-ui/src/bridge/protocol.ts` & `client.ts`: `ProtocolErrorBody` and `ProtocolError` lacked a `diagnostics` field, losing structured warning diagnostics on error/partial failures.
   - In `settings-ui/src/bridge/settings.ts`:
     - On no-op (`!result.saved`), `adopt(result.state)` was called unconditionally, which re-initialized drafts from canonical and discarded user retryable draft edits.
     - On no-op (`!result.saved`), `settings.diagnostics = result.diagnostics ?? []` unconditionally cleared existing warnings because AHK returns empty `diagnostics` when no write occurred.
     - `settings.field` was unconditionally wiped on save entry, erasing unresolved field error highlights on no-op.
     - `fail()` did not ingest `e.diagnostics` from `ProtocolError`.
     - `slotRuntime()` wiped `settings.field`, clearing field diagnostics on un-related slot operations.
   - In `settings-ui/src/components/FooterBar.vue`: active `settings.diagnostics` were never exposed visually in the UI.

2. **Fixes Applied**:
   - `SettingsPort.ahk`: preserved `extra["diagnostics"] := outcome.diagnostics` on errors/partial saves.
   - `protocol.ts` & `client.ts`: added `diagnostics?: string[]` to `ProtocolErrorBody` and `ProtocolError`.
   - `settings.ts`:
     - On `result.saved === true`: adopts canonical baseline (`adopt`), updates `settings.diagnostics` (clearing resolved warnings), clears `settings.field`, sets `Сохранено. Изменённых строк: N`.
     - On `result.saved === false` (no-op): does not call `adopt`; applies `absorb(result.state)`; preserves unresolved `settings.diagnostics` and active `settings.field`; sets `Менять нечего: всё уже так`.
     - In `fail()`: keeps error status and bad flag, sets `settings.message = e.message` (never shows `Сохранено`), updates `settings.field` and `settings.diagnostics`, and uses `absorb(e.state)` to protect retryable draft values.
     - Added and exported `diagnosticsHint(): string`.
   - `FooterBar.vue`: exposed diagnostics via computed `diagnosticsHint()` with dedicated `.warning` styling and `data-testid="diagnostics"`.

3. **Behavior across lifecycles**:
   - **Partial Save**: Status is `error`, `bad = true`, message displays error, field diagnostic highlighted, diagnostics exposed, draft values preserved via `absorb`. Never shows `Сохранено`.
   - **No-Op / Reconcile**: Does not erase unresolved warnings or field highlights; does not wipe retryable drafts.
   - **Eventual Success / Retry**: On full success, draft and canonical converge (`adopt`), resolved diagnostics are cleared, field error is cleared, `bad = false`, status shows `Сохранено. Изменённых строк: N`.

4. **Risk & Overlap with Wave 4/P02**:
   - Minimal and isolated: no changes to hotkey registration, layout redesign, picker identity, or general override logic. Single persistence path maintained. Clean merge base on `dev/integration/slots-settings-wave4`.

## 3. Commits

- Pending commit on `fix/settings-partial-retry-diagnostics`.

## 4. Important decisions

- Reused existing `absorb(state)` mechanism instead of `adopt(state)` for partial failures and no-ops to protect dirty/retryable drafts.
- Diagnostics rendered within `.footer-status` with `data-testid="diagnostics"` and CSS class `.warning` to ensure backward compatibility with `data-testid="status"` text checks while clearly displaying warnings.
- Preserved single persistence path through `SettingsGeneralPlan` -> `SettingsSlotsPlan` -> `SettingsApplyPlan`.

## 5. Problems found

- Worktree `C03` lacked `node_modules` (gitignored). Installed via `npm --prefix settings-ui ci`.

## 6. Tests / verification

- `npm --prefix settings-ui test`: **47/47 pass** (0 failures, 0 skipped), including 5 new regression tests:
  - `C03-1: full success shows Сохранено, clears diagnostics and converges draft`
  - `C03-2: partial/retryable result does not become false success and exposes diagnostics`
  - `C03-3: retryable draft and field diagnostic survive reload/reconcile`
  - `C03-4: unresolved warning and field diagnostic survive no-op/reconcile`
  - `C03-5: successful retry clears resolved diagnostic, field, and converges state`
- `npm --prefix settings-ui run typecheck`: **Exit 0** (0 errors).
- `npm --prefix settings-ui run build`: **Exit 0**, generated `src/webview/web/index.html`.
- `AutoHotkey64.exe /validate src/drawer.ahk`: **Exit 0**.
- `AutoHotkey64.exe test/narrow/settings-seam.ahk`: **Exit 0** (all seam groups pass).

## 7. Known issues / unfinished

- Visual debt in `Использовать общие настройки` intentionally untouched per task constraints.

## 8. Suggested next step

- Architect reviews `dev/fix/settings-partial-retry-diagnostics` for integration.
