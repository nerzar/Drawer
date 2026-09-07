# A03S1 — independent pre-promotion review

- Status: `READY`
- Run ID: `RUN-20260907-OPENCODE-MUSE13-A03S1-REVIEW-01`
- Eligible: `OPENCODE-MUSE13`
- Required model: `Muse Spark 1.3 Contributor Free`
- Session: `NEW`
- Base SHA: `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`
- Code SHA under review: `700f033cc2700dcdbb6c9fbd387e2e44b8510ef8`
- Source branch: `refactor/window-geometry-plan-seam`
- Output branch: `review/a03s1-muse13`

## Goal
Independent read-only/code-review gate before any acceptance or promotion of A03S1. Verify repository facts rather than trusting the implementation report.

## Required review
- Compare exact Base SHA -> Code SHA and confirm lineage/scope.
- Inspect all production declarations moved/extracted into `src/WindowGeometry.ahk` and all remaining definitions/call sites in `src/drawer.ahk`.
- Explicitly check for the same defect class seen in A02S2: duplicate function declarations caused by `#Include` plus stale copies left in `drawer.ahk`.
- Run bounded x64 and x86 `/Validate` for `src/drawer.ahk` and the extracted module if available locally; record exact exit codes. If x86 binary is unavailable, report that fact rather than guessing.
- Verify the new narrow seam executes production code rather than a copied model for the extracted policy.
- Check behavior-preservation risks: integer truncation/clamping, negative coordinates, work-area vs monitor-area semantics, internal-edge slide behavior, virtual-screen parking, and compatibility wrapper behavior.
- Identify blockers separately from non-blocking debt. Do not invent a blocker.

## Verdict
Return one of: `ACCEPT_CANDIDATE`, `NEEDS_FIX`, `BLOCKED_REVIEW`.

## Constraints
Review/report only. Do not modify production/test code, accept, promote, merge, or clean refs. Follow current board claim/ref-hygiene protocol and REPORT_FORMAT. Report to `docs/agent-reports/2026-09-07-opencode-muse13-a03s1-review.md`, update claim DONE/BLOCKED, push/verify report branch and shared claim.