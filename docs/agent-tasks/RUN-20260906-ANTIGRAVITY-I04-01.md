# TASK I04 — integrate accepted A01FIX + reviewed G02

Run ID: `RUN-20260906-ANTIGRAVITY-I04-01`
Client: Antigravity
Model: Gemini 3.8 Flash High
Status: READY

## Context

Current orchestration base is `dev/wip/slots-parity@42a17838` (the latest commit is only the manual acceptance record).

A01FIX was manually accepted by the user:
- `dev/fix/a01-hotkey-reset-general@e10509d`
- correctness accepted live: hotkey lifecycle works, fixed dynamic bind works, Reset-to-General works.
- known non-blocking visual regression: the `Использовать общие настройки` area is cramped/clipped. Do NOT polish/redesign it in I04; preserve behavior and record the visual debt.

G02 was architect-reviewed earlier and accepted for controlled integration:
- `dev/fix/settings-picker-identity@d97b67f`
- based on Wave 2, so it diverges historically from current base.
- G02 touches `SlotsView.vue` and `canonical.test.ts`, which also changed in A01FIX. Treat this as a semantic integration, not blind merge conflict resolution.

Observed refs before queueing I04:
- `wip/slots-parity` vs A01FIX: diverged only because wip has the later manual-acceptance docs commit; A01FIX is 2 code/report commits from their merge base `faa6d7d`.
- A01FIX vs G02: historical divergence from Wave 2; overlapping files include `settings-ui/src/views/SlotsView.vue` and `settings-ui/test/canonical.test.ts`.

## Goal

Create a new integration candidate containing BOTH:
1. manually accepted A01FIX behavior;
2. reviewed G02 picker/identity correctness;
3. current orchestration/manual-acceptance docs from `dev/wip/slots-parity`.

Do not promote `wip/slots-parity` in this task.

## Required integration strategy

1. `git fetch dev` and verify exact refs/clean worktrees.
2. Create sibling worktree `C:\Users\nerza\Projects\drawer-agent-worktrees\I04`.
3. Create branch `integration/slots-settings-wave4` from current `dev/wip/slots-parity`.
4. Integrate A01FIX code commits first, preserving the current wip acceptance-record commit. Since wip already contains only the later acceptance docs on top of the A01FIX base point, use a controlled cherry-pick/merge strategy that does not lose docs.
5. Then integrate G02 semantically. Resolve overlapping `SlotsView.vue` and `canonical.test.ts` by preserving BOTH sets of behavior/tests:
   - A01FIX hotkey A→B→A and Reset-to-General correctness;
   - G02 stale `windowClass`, picker.exe/window identity, dynamic→permanent identity behavior.
6. Do not reintroduce the old crowded header layout. Do not attempt visual polish beyond preserving A01FIX's current accepted functionality.
7. Do not change unrelated General animation behavior, DWM/titlebar, build system, FindWindow architecture, or hotkey product contract.
8. Do not take C03/G03/F12.

If semantic conflict cannot be resolved confidently, stop BLOCKED with safe pushed state rather than guessing.

## Verification

Required:
- AHK validate if AHK touched/comes through A01FIX;
- `test/narrow/settings-seam.ahk`;
- `npm --prefix settings-ui test`;
- `npm --prefix settings-ui run typecheck`;
- `npm --prefix settings-ui run build`;
- ensure regression coverage from BOTH A01FIX and G02 remains present and green;
- inspect final diff/commit ancestry to ensure no accepted behavior was dropped.

No VM/full suite. No production build unless integration unexpectedly touches build artifacts beyond normal generated web index.

## Finish

Factual report per `docs/agent-reports/REPORT_FORMAT.md`, commit, push `dev/integration/slots-settings-wave4`, verify remote HEAD = local HEAD, clean tree.

Report exact conflict resolutions (especially `SlotsView.vue` / `canonical.test.ts`) and final test counts.