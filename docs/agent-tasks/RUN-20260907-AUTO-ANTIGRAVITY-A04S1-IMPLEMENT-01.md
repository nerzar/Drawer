# A04S1 — pure handle geometry & color seam

- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-A04S1-IMPLEMENT-01`
- Eligible: `ANTIGRAVITY`
- Preferred model: `Gemini 3.8 Flash (Medium)`; Claude allowed if Gemini unavailable
- Session: `NEW`
- Base/source rule: accepted shared production identity `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`; later shared docs/task/claim/report commits are allowed only if production/test tree is unchanged
- Analysis input: A04A report `docs/agent-reports/2026-09-07-antigravity-a04-analysis.md` / verdict `READY_TO_IMPLEMENT`
- Branch: `refactor/window-handles-pure-seam`
- Worktree: `C:\Users\nerza\Projects\drawer-agent-worktrees\A04S1`

## Goal
Implement only the first A04 slice: extract deterministic handle color/layout/hover math into a production-callable `src/WindowHandles.ahk` seam while preserving runtime behavior exactly.

## Scope
Expected files:
- `[NEW] src/WindowHandles.ahk`
- `[MODIFY] src/drawer.ahk` only for include + thin compatibility adapters/wiring
- `[NEW] test/narrow/window-handles-seam.ahk`

Do not move GUI lifecycle, timers, click orchestration, icon ownership, handle state map, Settings integration, or full `HandlesSync` in this run.

## Required behavior
Preserve exactly:
- `HandleLighten` semantics including channel math/clamping and invalid-input behavior;
- stack centering/index math for all four edges;
- work-area placement semantics, including negative coordinates/asymmetric taskbars;
- grown rect expands inward from monitor/work-area edge exactly as today;
- hover/near/rest thresholds and distance reference must preserve existing no-jitter behavior (reference rest/base geometry, not animated rect where current behavior does so);
- no change to handle grouping membership, click behavior, focus invisibility, icon ownership, timers, cadence, settings repaint, slot authority, geometry/window-focus behavior.

## Design constraint
Prefer explicit pure functions such as `HandleBaseCalc`, `HandleGrownCalc`, `HandleTargetCalc`, plus `HandleLighten`, with thin live wrappers retaining existing public runtime names/signatures where practical. No generic DI/framework layer.

## Tests
Add direct narrow tests against production functions for at least:
- color lighten/clamp/invalid input;
- 1/2/3 handle stack positioning on top/bottom/left/right;
- negative monitor coordinates and asymmetric work area;
- grown rectangle direction for all four edges;
- hover/near/rest thresholds and boundary cases;
- no-jitter invariant via base/rest geometry input.

Run AHK `/Validate` for changed/included files, new narrow handle seam, and any cheap directly affected existing seam available. `src/config.ini` must remain untouched.

## Git/output
Follow current AGENT_BOARD, claim protocol, Critical Git ref hygiene and REPORT_FORMAT. One Run ID = one branch. Production/test commit first; record Code SHA separately from report-tip SHA. Push explicitly to `dev` `refs/heads/refactor/window-handles-pure-seam`, verify remote contains Code SHA, leave clean tree, update claim DONE/BLOCKED.

Report: `docs/agent-reports/2026-09-07-antigravity-a04s1.md`.
