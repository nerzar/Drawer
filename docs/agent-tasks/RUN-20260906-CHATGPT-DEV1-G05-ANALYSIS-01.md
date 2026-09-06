# TASK G05A — repo-only UX/terminology analysis for Slots onboarding

- Run ID: `RUN-20260906-CHATGPT-DEV1-G05-ANALYSIS-01`
- Executor: ChatGPT DEV-1
- Model: GPT-5.6 Sol
- Source: `dev/wip/slots-parity`
- Reference candidate: `dev/integration/slots-settings-wave4@e4136c5`
- Output branch: `dev/analysis/g05-slots-ux`

## Goal
Prepare a code-grounded UX cleanup plan for Slots terminology/onboarding without implementing UI changes yet. This task must be repo-only and safe to run in parallel with I05/C03/G03.

Focus on current Slots UI after A01FIX/G02:
- confusing Permanent/Dynamic terminology;
- internal/INI jargon exposed to users;
- empty dynamic slot onboarding;
- clarity of Release vs Reset vs `Использовать общие настройки`;
- current narrow-pane layout debt around `Использовать общие настройки`;
- labels/help text that imply implementation details instead of user intent.

## Required investigation
Using GitHub/repository reads only:
1. Inspect current `SlotsView.vue`, related slot draft/bridge types, and any existing UX copy/tests.
2. Inventory all user-visible strings and controls related to slot type, binding, release/reset, executable/window identity, overrides, empty state, and conversion permanent↔dynamic.
3. For each confusing item, state:
   - current wording/behavior;
   - why it is confusing in user terms;
   - proposed wording/placement/interaction;
   - whether change is copy-only, layout-only, or behavior-affecting.
4. Preserve product semantics already accepted: one configurable show/hide hotkey, fixed dynamic bind hotkey, Apply/Cancel draft semantics, Release semantics, Reset-to-General semantics.
5. Explicitly avoid proposing a full redesign, arbitrary slots, F12 window selector, or architecture changes.
6. Identify smallest implementation scope and likely conflicts with G03/C03.
7. Produce a prioritized implementation checklist split into `must`, `should`, `later`.

## Output
Create `docs/agent-reports/2026-09-06-chatgpt-dev1-g05-analysis.md` with:
- inventory of current UX/copy;
- concrete before→after recommendations;
- minimal file-level implementation scope;
- conflict risk with current correctness branches;
- regression/manual acceptance checklist;
- recommendation `READY_TO_IMPLEMENT`, `NEEDS_ARCH_DECISION`, or `BLOCKED`.

Do not modify production source files in this run. Do not edit `AGENT_BOARD.md` or architect-owned docs.

## GitHub-native completion
Local worktree/tests are intentionally not required for this Run ID. Use GitHub operations only. Create/use `dev/analysis/g05-slots-ux`, commit the report, and verify remote HEAD.

Final response: Run ID, DONE/BLOCKED, branch, final SHA, recommendation, and top 5 UX changes.