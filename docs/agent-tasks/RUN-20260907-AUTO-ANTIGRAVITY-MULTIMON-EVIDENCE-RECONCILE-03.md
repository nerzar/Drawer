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
4. For wrong-origin, distinguish these hypotheses with evidence:
   - geometry-plan/internal-edge staging (`5ed8b9a` / `26b1133`);
   - focus/watcher ordering (`2bab75c` / `42a16ee`);
   - other runtime ordering.
5. For disappearing handle, prove or falsify whether monitor change with in-place GUI migration (`fae1850`) is actually first-bad. Log/observe keep/handle lifecycle and monitor transition; do not rely on generic DWM claims without reproduction.
6. Preserve product contract: managed `monitor: cursor` must resolve live cursor in both handle sync and Show. No pinning.
7. Analysis/report only. No production/test edits, no fix, no promotion.

## Deliver
A report with one of:
- `READY_FOR_NARROW_FIX` — only if first-bad commit(s) and concrete mechanism(s) are supported by an explicit runtime pass/fail matrix or equally strong deterministic evidence;
- `BLOCKED_RUNTIME_EVIDENCE` — if the required runtime proof cannot be produced;
- `NEEDS_MORE_BISECT` — if evidence is contradictory.

Include exact SHAs, per-commit result table, commands/harness used, topology, and the smallest fix boundary justified by evidence. Do not propose changing existing user-visible behavior.