# T01 independent verification — settings-seam determinism

- Status: `READY`
- Run ID: `RUN-20260907-AUTO-ANTIGRAVITY-T01-VERIFY-01`
- Eligible: `ANTIGRAVITY`
- Preferred model: `Gemini 3.8 Flash (Medium)`
- Session: `NEW`
- Base SHA: `6bfa010fbf0ca7e1b47e856b7c13a450ff54b1fa`
- Code SHA under verification: `34efdb62d8fb1dcaa55119f47794c3b269772e9c`
- Source branch: `test/settings-seam-determinism`
- Output branch: `verify/t01-settings-seam-antigravity`

## Goal
Independently verify T01 before any acceptance/promotion. Do not trust the original report without checking repository facts and reproducing bounded gates.

## Required verification
- Fresh `git fetch dev`; read current board and REPORT_FORMAT; claim this Run ID.
- Confirm exact Base -> Code SHA lineage and changed-file scope.
- Inspect the T01 diff and verify the hang fix is test-only/narrow-scope and does not alter production behavior.
- Reproduce bounded x64 and x86 `/Validate` for `src/drawer.ahk` and `test/narrow/settings-seam.ahk` where binaries are available; record exact exit codes.
- Run `test/narrow/settings-seam.ahk` directly at least 5 consecutive times with bounded timeout and record pass counts/exits/durations.
- Run relevant `window-focus-seam.ahk` checks at least 3 times to detect collateral test-harness regressions.
- Verify `src/config.ini` remains untouched and `git diff --check` is clean.
- Explicitly confirm the missing `SettingsSectionSlot` / `SettingsChangedSlots` local helper issue is actually resolved in the test harness and no modal/runtime hang remains.
- Distinguish blockers from non-blocking debt. Do not invent a blocker.

## Verdict
Return one of: `ACCEPT_CANDIDATE`, `NEEDS_FIX`, `BLOCKED_VERIFY`.

## Constraints
Verification/report only. Do not modify production/test code, accept, promote, merge, or delete refs. If a verification defect is found, report it; do not fix it in this Run ID. Push report-only branch, update claim DONE/BLOCKED, verify remote, clean tree.

Report: `docs/agent-reports/2026-09-07-antigravity-t01-verify.md`
