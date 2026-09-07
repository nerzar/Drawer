# RUN-20260907-AUTO-ANTIGRAVITY-MULTIMON-EVIDENCE-RECONCILE-03

- Status: `READY`
- Eligible: `ANTIGRAVITY`
- Preferred model: `Gemini 3.8 Flash (Medium)`
- Session: `NEW`
- Accepted baseline: `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`
- Failed candidate: `cd6dc00b3d58c6abea709687618ea3702432bc45`
- Rejected semantic fix: `073a9e649bb85b4766acec33e49f975d5444a140`
- Prior runtime report: `docs/agent-reports/2026-09-07-antigravity-multimon-runtime-bisect-02.md`
- Independent static audit: `docs/agent-reports/2026-09-07-opencode-muse13-cursor-contract-audit-02.md`
- Branch: `analysis/multimon-evidence-reconcile-03-antigravity`

## Goal
Reconcile the contradiction between the prior Antigravity report and the independent static audit before any implementation is allowed. Produce hard evidence for the actual first-bad commit(s) and mechanism(s) while preserving the user-required dynamic `monitor: cursor` behavior.

## Product contract — immutable
For `monitor: cursor`, managed windows and the active handle follow the current cursor monitor. `Show()` and handle sync must continue resolving the live cursor monitor. Do not pin to the bind monitor, do not redefine this behavior, and do not treat a behavior change as a fix.

## Required
1. Fresh-fetch and independently inspect exact lineage `6bfa010..cd6dc00`.
2. Do not assume prior report conclusions are correct. In particular, the claim that `5ed8b9a` is the live wrong-origin first-bad conflicts with the fact that `26b1133` fixes its missing-braces bug and the candidate contains that fix.
3. If a dual-monitor runtime/VM harness is available, produce an explicit pass/fail matrix for at least:
   - `6bfa010` accepted baseline;
   - `2bab75c`;
   - `42a16ee`;
   - `5ed8b9a`;
   - `26b1133`;
   - `fae1850` (and `6e5a71c` if materially distinct);
   - `cd6dc00`.
   Run the same deterministic scenario for wrong-origin and handle disappearance. Record exact monitor coordinates/topology and observable result. If actual dual-monitor runtime is unavailable, do NOT label static reasoning as runtime bisection; report `BLOCKED_RUNTIME_EVIDENCE` and provide the best bounded instrumentation plan instead.
4. For wrong-origin, distinguish with evidence: geometry-plan/internal-edge staging; focus/watcher ordering; handles/runtime ordering; any other exact accepted-vs-candidate delta.
5. For disappearing handle, prove or falsify whether `fae1850` is actually first-bad. Log/observe keep/handle lifecycle and monitor transition; do not rely on generic DWM/timer claims without reproduction.
6. Preserve cursor-follow exactly. No pinning.
7. Analysis/report only. No production/test edits, no fix, no promotion.

## Repo navigation
RepoWise is available in the Drawer environment and may be used as a supplementary navigation/indexing aid. Git refs, exact SHAs, repository files and runtime evidence remain the source of truth; never substitute indexed summaries for Git verification.

## Deliver
A report with one of:
- `READY_FOR_NARROW_FIX` — only if first-bad commit(s) and concrete mechanism(s) are supported by an explicit runtime pass/fail matrix or equally strong deterministic evidence;
- `BLOCKED_RUNTIME_EVIDENCE` — if required runtime proof cannot be produced;
- `NEEDS_MORE_BISECT` — if evidence remains contradictory.

Include exact SHAs, per-commit result table, commands/harness used, topology, and the smallest behavior-preserving fix boundary justified by evidence.