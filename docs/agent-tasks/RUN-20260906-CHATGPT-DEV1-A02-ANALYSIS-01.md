# A02A — repo-only analysis for windows/focus seam modularization

- Run ID: `RUN-20260906-CHATGPT-DEV1-A02-ANALYSIS-01`
- Executor: ChatGPT DEV-1
- Model: GPT-5.6 Sol
- Source: latest `dev/wip/slots-parity`
- Output branch: `analysis/a02-windows-focus-seam`

## Goal
Prepare A02 (windows/focus seam) for later implementation without changing production code. Identify the smallest modular extraction that reduces coupling in `src/drawer.ahk` while preserving current window activation/focus/show/hide/watch semantics proven by G03.

## Required analysis
1. Trace current call graph and shared state around Show/Hide/FocusWindow/Watch/WatchBlur/IsDeployed/SlotOf/SlotBound/window activation/foreground decisions.
2. Separate pure policy decisions from Win32/AHK side effects and from slot registry access.
3. Identify concrete module/function boundaries for an A02 seam, with proposed file(s), exported API, owned state, and dependencies.
4. Explicitly preserve G03 watcher-authority rules: activateOnShow=false normal show is not auto-enrolled; FocusWindow legitimate watcher state; permanent binding precedence for duplicate HWND; live hideOnBlur/blurMs reconcile.
5. Identify tests that currently pin behavior and where seam-level tests could replace model/source-shape tests with real callable production logic.
6. Flag collision risk with A03 parking/geometries and A05 Settings/tray so A02 does not steal future ownership.
7. Recommend implementation slices in safe order and whether A02 should be one task or multiple sub-runs.

## Output
Create `docs/agent-reports/2026-09-06-chatgpt-dev1-a02-analysis.md` with current architecture map, proposed seam, API sketch, state ownership, migration plan, tests, risks, and verdict `READY_TO_IMPLEMENT`, `NEEDS_ARCH_DECISION`, or `BLOCKED`.

## Constraints
GitHub/repo-only. No production edits, no AGENT_BOARD/ARCHITECT_STATE edits. One report-only branch; no extra scratch branches. Use exact current shared Code SHA as analysis base identity.

Final answer: Run ID, DONE/BLOCKED, branch, report tip SHA, recommendation, top 5 design findings.