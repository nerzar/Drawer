# Manual acceptance candidate assembly — focus + geometry + handles + settings-test foundation

- Status: `READY`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-MANUAL-CANDIDATE-ASSEMBLE-01`
- Eligible: `ANTIGRAVITY`
- Preferred model: `Gemini 3.8 Flash (Medium)`
- Session: `NEW`
- Base: accepted production `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`
- Branch: `integration/manual-candidate-20260907`

## Goal
Assemble the independently reviewed/verified overnight work into ONE integration branch for user manual acceptance. This is NOT acceptance or promotion.

Candidate components, all required unless an integration blocker is found:
1. T01 settings-seam determinism: `34efdb62d8fb1dcaa55119f47794c3b269772e9c`.
2. A02S2 focus-history extraction lineage: implementation `c482ad3ae9c499ea32eb3c0cdd590e495a919e30` plus FIX `313b3af8b6377b2b66e07256f985b1663c5630ee`.
3. A03S1 geometry lineage: implementation `700f033cc2700dcdbb6c9fbd387e2e44b8510ef8` plus FIX `90718c99de1609b40a7b7a8dbe314fbcb2d857dd`.
4. A04 handles lineage: S1 `851f47566dd074538f412b9d258193dbde65195b` -> S2 `e862c4f7b71f0aced86dc2b19843b47b4b23a0f2` -> S3 `4d1a3106c3e3f64f8caa5b26bceacf9fafdf5873`.

## Required procedure
- Fresh `git fetch dev`; read current board and REPORT_FORMAT; claim this Run ID.
- Create a sibling worktree from exact accepted base.
- Before cherry-picking, inspect changed-file overlap and expected conflicts across the four lines.
- Integrate in the order above unless Git evidence shows a safer equivalent order. Preserve each component's behavior and Code SHA intent; record any conflict resolution explicitly.
- If a conflict is semantic/ambiguous rather than mechanical, STOP and mark BLOCKED. Do not invent architecture.
- Do not modify `src/config.ini`.
- Do not update accepted production identity, master, or public `origin`.

## Verification gates
At the assembled candidate tip:
- `AutoHotkey64.exe /Validate src\drawer.ahk` EXIT 0.
- x86 `/Validate src\drawer.ahk` EXIT 0 where available.
- Validate extracted modules: `WindowFocus.ahk`, `WindowGeometry.ahk`, `WindowHandles.ahk`.
- `window-focus-seam.ahk` full pass.
- `window-geometry-seam.ahk` full pass plus `window-geometry-adapter-seam.ahk` full pass.
- `window-handles-seam.ahk` full pass, at least 3 consecutive runs.
- `settings-seam.ahk` full pass, at least 3 consecutive runs with bounded timeout and no hang.
- `git diff --check` clean; `src/config.ini` untouched.

## Deliver
- Candidate Code SHA and remote branch verification.
- Exact integrated component SHAs and any conflict-resolution notes.
- Test counts/exits.
- A short HUMAN manual-test checklist focused on visible behavior: focus return, two-monitor geometry/internal edges/parking, handle hover/click/sync, Settings open/save/reload.
- Verdict `READY_FOR_MANUAL_ACCEPTANCE` or `BLOCKED`.
- Report: `docs/agent-reports/2026-09-07-antigravity-manual-candidate-assemble.md`.

Do not self-accept, self-promote, merge to accepted production, or start A03S2/A03S3/A05. Stop after publishing the candidate/report/claim.