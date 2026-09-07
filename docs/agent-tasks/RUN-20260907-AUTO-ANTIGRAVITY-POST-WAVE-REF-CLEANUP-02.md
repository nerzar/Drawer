# Post-wave branch/worktree cleanup 02

- Status: `WAITING_DEPENDENCY`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-POST-WAVE-REF-CLEANUP-02`
- Eligible: `ANTIGRAVITY`
- Preferred model: `Gemini 3.8 Flash (Medium)`
- Session: `NEW`
- Dependency: current multi-monitor diagnostic/fix wave must reach a stable architect checkpoint; architect must explicitly switch this task to READY.
- Branch: `maintenance/post-wave-ref-cleanup-02`

## Goal
Reduce branch/worktree sprawl after the current wave without losing unique work.

## Required
- inventory all local and remote `dev` refs plus worktrees;
- classify refs as accepted/promoted, active, report-only, superseded, rejected, archived, or unique/unmerged;
- preserve any ref with unique commits not reachable from a retained canonical/report/archive ref;
- remove only demonstrably safe local/remote branches and stale worktrees per Critical Git ref hygiene;
- specifically collapse redundant review/fix/report branches where the same Code SHA/report is already preserved elsewhere;
- never touch public `origin`;
- deliver before/after counts and a retained-ref rationale.

No production changes, no promotion, no architectural changes. Report-only + safe ref/worktree cleanup.