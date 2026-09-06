# AGENT_BOARD тАФ Drawer autonomous work queue

Blackboard ╨╝╨╡╨╢╨┤╤Г ╨░╤А╤Е╨╕╤В╨╡╨║╤В╨╛╤А╨╛╨╝ ChatGPT ╨╕ coding agents.

**╨Т╨╗╨░╨┤╨╡╨╗╨╡╤Ж ╤Д╨░╨╣╨╗╨░:** ╨░╤А╤Е╨╕╤В╨╡╨║╤В╨╛╤А ChatGPT. Coding agents ╤Н╤В╨╛╤В ╤Д╨░╨╣╨╗ ╨╜╨╡ ╤А╨╡╨┤╨░╨║╤В╨╕╤А╤Г╤О╤В ╨╕ ╨┐╤А╨╕╨╛╤А╨╕╤В╨╡╤В╤Л ╤Б╨░╨╝╨╕ ╨╜╨╡ ╨╝╨╡╨╜╤П╤О╤В.

## ╨Ю╨▒╤Й╨╕╨╣ ╨┐╤А╨╛╤В╨╛╨║╨╛╨╗

1. `git fetch dev`.
2. ╨Я╤А╨╛╤З╨╕╤В╨░╤В╤М ╨░╨║╤В╤Г╨░╨╗╤М╨╜╤Л╨╣ `AGENT_BOARD.md` ╨╕╨╖ `dev/wip/slots-parity`.
3. ╨Я╤А╨╛╤З╨╕╤В╨░╤В╤М `docs/agent-reports/REPORT_FORMAT.md` ╨╕╨╖ `dev/wip/slots-parity`.
4. ╨Т╨╖╤П╤В╤М ╤В╨╛╨╗╤М╨║╨╛ ╨╖╨░╨┤╨░╤З╤Г, ╤З╨╡╨╣ Run ID ╨┤╨░╨╜ ╨╛╨┐╨╡╤А╨░╤В╨╛╤А╨╛╨╝.
5. ╨Я╨╡╤А╨╡╨┤ ╨╕╨╖╨╝╨╡╨╜╨╡╨╜╨╕╤П╨╝╨╕ ╨┐╤А╨╛╨▓╨╡╤А╨╕╤В╤М `git worktree list`, branch, base ╨╕ `git status`.
6. ╨Я╨░╤А╨░╨╗╨╗╨╡╨╗╤М╨╜╤Л╨╡ ╨╖╨░╨┤╨░╤З╨╕ ╨▓╤Б╨╡╨│╨┤╨░ ╤А╨░╨▒╨╛╤В╨░╤О╤В ╨▓ ╨╛╤В╨┤╨╡╨╗╤М╨╜╤Л╤Е sibling-worktree: `C:\Users\nerza\Projects\drawer-agent-worktrees\<task-id>`.
7. Worktree ╨╜╨╡╨╗╤М╨╖╤П ╤Б╨╛╨╖╨┤╨░╨▓╨░╤В╤М ╨▓╨╜╤Г╤В╤А╨╕ ╨┤╤А╤Г╨│╨╛╨│╨╛ repo/worktree. ╨Э╨╡╨╖╨░╨║╨╛╨╝╨╝╨╕╤З╨╡╨╜╨╜╤Г╤О ╤А╨░╨▒╨╛╤В╤Г ╨┤╤А╤Г╨│╨╛╨│╨╛ ╨░╨│╨╡╨╜╤В╨░ ╨╜╨╡╨╗╤М╨╖╤П reset/clean/discard.
8. ╨Т╤Л╨┐╨╛╨╗╨╜╨╕╤В╤М ╨╖╨░╨┤╨░╤З╤Г ╤Ж╨╡╨╗╨╕╨║╨╛╨╝, ╨╜╨╡ ╤А╨░╤Б╤И╨╕╤А╤П╤П scope ╨▒╨╡╨╖ ╨╜╨╡╨╛╨▒╤Е╨╛╨┤╨╕╨╝╨╛╤Б╤В╨╕.
9. VM/full suite ╨╜╨╡ ╤П╨▓╨╗╤П╨╡╤В╤Б╤П default gate; ╤В╨╛╨╗╤М╨║╨╛ ╤А╨░╨╖╤Г╨╝╨╜╤Л╨╡ ╤Ж╨╡╨╗╨╡╨▓╤Л╨╡ ╨┐╤А╨╛╨▓╨╡╤А╨║╨╕, ╨╡╤Б╨╗╨╕ ╨╖╨░╨┤╨░╤З╨░ ╨╜╨╡ ╤В╤А╨╡╨▒╤Г╨╡╤В ╨╕╨╜╨╛╨│╨╛.
10. ╨Я╨╡╤А╨╡╨┤ ╨╖╨░╨▓╨╡╤А╤И╨╡╨╜╨╕╨╡╨╝: factual report ╨┐╨╛ `REPORT_FORMAT.md`, commit, push ╨▓ private remote `dev`, verify remote HEAD = local HEAD, clean tree.
11. ╨Я╤Г╨▒╨╗╨╕╤З╨╜╤Л╨╣ `origin` ╨╜╨╡ ╤В╤А╨╛╨│╨░╤В╤М.
12. `docs/ARCHITECT_STATE.md` coding agents ╨╜╨╡ ╤А╨╡╨┤╨░╨║╤В╨╕╤А╤Г╤О╤В.

╨Х╤Б╨╗╨╕ ╨╡╤Б╤В╤М blocker, ╨╜╨╡╨╛╨┤╨╜╨╛╨╖╨╜╨░╤З╨╜╨╛╨╡ ╨┐╤А╨╛╨┤╤Г╨║╤В╨╛╨▓╨╛╨╡ ╤А╨╡╤И╨╡╨╜╨╕╨╡, ╨║╨╛╨╜╤Д╨╗╨╕╨║╤В ╤Б ╨┐╨░╤А╨░╨╗╨╗╨╡╨╗╤М╨╜╨╛╨╣ ╨╖╨░╨┤╨░╤З╨╡╨╣ ╨╕╨╗╨╕ ╤А╨╕╤Б╨║ ╨┐╨╛╤В╨╡╤А╨╕ ╨┤╨░╨╜╨╜╤Л╤Е: ╤Б╨╛╤Е╤А╨░╨╜╨╕╤В╤М ╨▒╨╡╨╖╨╛╨┐╨░╤Б╨╜╨╛╨╡ ╤Б╨╛╤Б╤В╨╛╤П╨╜╨╕╨╡, push ╨╕ ╨╛╤Б╤В╨░╨╜╨╛╨▓╨╕╤В╤М╤Б╤П ╤Б `BLOCKED` ╨▓ ╨╛╤В╤З╤С╤В╨╡.

## ╨Ш╨┤╨╡╨╜╤В╨╕╤Д╨╕╨║╨░╤Ж╨╕╤П ╨╖╨░╨┐╤Г╤Б╨║╨╛╨▓

╨Ъ╨░╨╢╨┤╨░╤П ╨╖╨░╨┤╨░╤З╨░ ╨┐╨╛╨╗╤Г╤З╨░╨╡╤В **Run ID**. ╨Р╨│╨╡╨╜╤В ╨┐╨╛╨▓╤В╨╛╤А╤П╨╡╤В ╨╡╨│╨╛ ╨▓ factual report ╨╕ ╤Д╨╕╨╜╨░╨╗╤М╨╜╨╛╨╝ ╨╛╤В╨▓╨╡╤В╨╡.

╨Ю╤В╤З╤С╤В ╨╛╨▒╤П╨╖╨░╨╜ ╤Б╨╛╨┤╨╡╤А╨╢╨░╤В╤М: Task ID, Run ID, client, **╤Д╨░╨║╤В╨╕╤З╨╡╤Б╨║╨╕ ╨╕╤Б╨┐╨╛╨╗╤М╨╖╨╛╨▓╨░╨╜╨╜╤Г╤О ╨╝╨╛╨┤╨╡╨╗╤М**, chat/session ID ╨╡╤Б╨╗╨╕ ╨┤╨╛╤Б╤В╤Г╨┐╨╡╨╜, chat title ╨╡╤Б╨╗╨╕ ╨┤╨╛╤Б╤В╤Г╨┐╨╡╨╜, Search anchor, timestamps, worktree, branch, base SHA, final SHA.

**╨Ь╨╛╨┤╨╡╨╗╤М ╨▓ ╨╛╤В╤З╤С╤В╨╡ ╨▒╤А╨░╤В╤М ╨╕╨╖ ╤Д╨░╨║╤В╨╕╤З╨╡╤Б╨║╨╛╨│╨╛ ╨▓╤Л╨▒╨╛╤А╨░ ╨║╨╗╨╕╨╡╨╜╤В╨░/╨╛╨┐╨╡╤А╨░╤В╨╛╤А╨░, ╨░ ╨╜╨╡ ╨║╨╛╨┐╨╕╤А╨╛╨▓╨░╤В╤М ╤Б╨╗╨╡╨┐╨╛ ╨╕╨╖ ╤Б╤В╨░╤А╨╛╨│╨╛ board.** ╨Х╤Б╨╗╨╕ ╨╡╤Б╤В╤М ╤А╨░╤Б╤Е╨╛╨╢╨┤╨╡╨╜╨╕╨╡ тАФ ╤П╨▓╨╜╨╛ ╨╜╨░╨┐╨╕╤Б╨░╤В╤М ╨╡╨│╨╛.

## ╨а╨╡╤Б╤Г╤А╤Б╤Л ╨╝╨╛╨┤╨╡╨╗╨╡╨╣ ╤Б╨╡╨╣╤З╨░╤Б

- Codex GPT quota ╨╕╤Б╤З╨╡╤А╨┐╨░╨╜╨░ ╨┐╨╛╤Б╨╗╨╡ C02; ╨╜╨╛╨▓╤Л╨╡ GPT-╨╖╨░╨┤╨░╤З╨╕ Codex ╨╜╨╡ ╨╜╨░╨╖╨╜╨░╤З╨░╤В╤М ╨┤╨╛ ╤Б╨╛╨╛╨▒╤Й╨╡╨╜╨╕╤П ╨╛╨┐╨╡╤А╨░╤В╨╛╤А╨░ ╨╛ reset.
- OpenCode ╨┐╨╛╨┤╨║╨╗╤О╤З╤С╨╜ ╤З╨╡╤А╨╡╨╖ ╤Б╤В╨╛╤А╨╛╨╜╨╜╨╕╨╣ provider. Gemini 3.8 Flash ╤В╨░╨╝ ╨╜╨╡ ╨╖╨░╤А╨░╨▒╨╛╤В╨░╨╗.
- OpenCode + ╨╖╨░╤П╨▓╨╗╨╡╨╜╨╜╨░╤П provider-╨╝╨╛╨┤╨╡╨╗╤М `GPT 5.6 Luna` ╤Г╤Б╨┐╨╡╤И╨╜╨╛ ╨┐╤А╨╛╤И╤С╨╗ ╤А╨╡╨░╨╗╤М╨╜╤Л╨╣ harness-test ╨╜╨░ I02: worktree/Git/merge/AHK/PowerShell/npm/build/report/push ╨▒╨╡╨╖ ╤А╤Г╤З╨╜╨╛╨╣ Git-╨┐╨╛╨╝╨╛╤Й╨╕.
- ╨Э╨░╨╖╨▓╨░╨╜╨╕╤П ╨╝╨╛╨┤╨╡╨╗╨╡╨╣ ╤Б╤В╨╛╤А╨╛╨╜╨╜╨╡╨│╨╛ provider ╨╜╨╡ ╤Б╤З╨╕╤В╨░╨╡╨╝ ╨┤╨╛╨║╨░╨╖╨░╤В╨╡╨╗╤М╤Б╤В╨▓╨╛╨╝ ╨╛╤Д╨╕╤Ж╨╕╨░╨╗╤М╨╜╨╛╨│╨╛ endpoint; ╨╛╤Ж╨╡╨╜╨╕╨▓╨░╨╡╨╝ ╨┐╤А╨░╨║╤В╨╕╤З╨╡╤Б╨║╨╛╨╡ ╨║╨░╤З╨╡╤Б╤В╨▓╨╛.
- ╨б╨╗╨╡╨┤╤Г╤О╤Й╨╕╨╣ qualification OpenCode: `Qwen 3.8 MAX` ╨╜╨░ G02. ╨Х╤Б╨╗╨╕ Qwen ╨╜╨╡ ╤Б╨┐╤А╨░╨▓╨╗╤П╨╡╤В╤Б╤П/╨╗╨╛╨╝╨░╨╡╤В tool-use тАФ ╤Б╨╛╤Е╤А╨░╨╜╨╕╤В╤М ╨▒╨╡╨╖╨╛╨┐╨░╤Б╨╜╨╛╨╡ ╤Б╨╛╤Б╤В╨╛╤П╨╜╨╕╨╡ ╨╕ ╨╛╤Б╤В╨░╨╜╨╛╨▓╨╕╤В╤М╤Б╤П; ╨╜╨╡ ╨┐╨╡╤А╨╡╨║╨╗╤О╤З╨░╤В╤М ╨╝╨╛╨┤╨╡╨╗╤М ╨▓╨╜╤Г╤В╤А╨╕ ╤В╨╛╨│╨╛ ╨╢╨╡ Run ID.
- Antigravity ╨┤╨╛╤Б╤В╤Г╨┐╨╡╨╜. G04 ╤Д╨░╨║╤В╨╕╤З╨╡╤Б╨║╨╕ ╨▒╤Л╨╗ ╨▓╤Л╨┐╨╛╨╗╨╜╨╡╨╜ ╨╜╨░ Gemini 3.8 Flash High, ╨┐╨╛╤В╨╛╨╝╤Г ╤З╤В╨╛ Sonnet ╨╜╨╡ ╨▒╤Л╨╗ ╨▓╤Л╨▒╤А╨░╨╜ ╨╛╨┐╨╡╤А╨░╤В╨╛╤А╨╛╨╝.
- ╨в╨╡╨║╤Г╤Й╨╕╨╣ Antigravity I03 ╨┤╨╛╨╗╨╢╨╡╨╜ ╤Д╨░╨║╤В╨╕╤З╨╡╤Б╨║╨╕ ╨╕╤Б╨┐╨╛╨╗╤М╨╖╨╛╨▓╨░╤В╤М **Claude Sonnet 4.6 (Thinking)** тАФ ╨┐╨╡╤А╨▓╤Л╨╣ ╨╜╨░╤Б╤В╨╛╤П╤Й╨╕╨╣ qualification run ╤Н╤В╨╛╨│╨╛ ╨┐╤Г╨╗╨░.
- Claude Opus 4.6 Thinking ╨┤╨╡╤А╨╢╨░╤В╤М ╨┤╨╗╤П ╤В╤П╨╢╤С╨╗╤Л╤Е correctness/runtime/architecture escalation.
- Astra ╨╜╨╡ ╨╕╤Б╨┐╨╛╨╗╤М╨╖╨╛╨▓╨░╤В╤М ╨▒╨╡╨╖ ╨╛╤В╨┤╨╡╨╗╤М╨╜╨╛╨│╨╛ ╤А╨╡╤И╨╡╨╜╨╕╤П.

## ╨Ю╨▒╤Й╨╕╨╡ ╤В╨╡╤Е╨╜╨╕╤З╨╡╤Б╨║╨╕╨╡ ╨┐╤А╨░╨▓╨╕╨╗╨░

- Git CLI/remote тАФ ╨╕╤Б╤В╨╛╤З╨╜╨╕╨║ ╨╕╤Б╤В╨╕╨╜╤Л.
- ╨Э╨╡ ╨┐╨╗╨╛╨┤╨╕╤В╤М ╨╜╨╛╨▓╤Л╨╡ ╤Б╨╗╨╛╨╕/harnesses/docs/╨░╨▒╤Б╤В╤А╨░╨║╤Ж╨╕╨╕ ╨▒╨╡╨╖ ╨╜╨╡╨╛╨▒╤Е╨╛╨┤╨╕╨╝╨╛╤Б╤В╨╕.
- `drawer-debug.log` ╨╕ tray action `╨Э╨░╤И╤С╨╗ ╨▒╨░╨│тАж` ╤Б╨╛╤Е╤А╨░╨╜╤П╤В╤М.
- Frontend typecheck: `npm --prefix settings-ui run typecheck`; ╨▓╨╜╨╡╤И╨╜╨╕╨╣ `npx vue-tsc` ╨╜╨╡ ╨╕╤Б╨┐╨╛╨╗╤М╨╖╨╛╨▓╨░╤В╤М ╨║╨░╨║ gate.
- Stable hotkey contract: ╨╛╨┤╨╕╨╜ ╨╜╨░╤Б╤В╤А╨░╨╕╨▓╨░╨╡╨╝╤Л╨╣ show/hide hotkey ╨╜╨░ slot; `Ctrl+Alt+N` default only; `Ctrl+Alt+Shift+N` тАФ fixed dynamic bind.

---

# ╨в╨╡╨║╤Г╤Й╨╡╨╡ ╤Д╨░╨║╤В╨╕╤З╨╡╤Б╨║╨╛╨╡ ╤Б╨╛╤Б╤В╨╛╤П╨╜╨╕╨╡

- Private repo: `nerzar/Drawer.Dev`, remote `dev`.
- Diagnostics base `b2ec249` ╨▓╤А╤Г╤З╨╜╤Г╤О ╨┐╤А╨╕╨╜╤П╤В╨░ ╨┐╨╛╨╗╤М╨╖╨╛╨▓╨░╤В╨╡╨╗╨╡╨╝.
- Wave 1: `dev/integration/slots-settings-wave1@ac63ead`.
- C02: `dev/fix/settings-general-override-atomic@f75dcc6`.
- B01: `dev/fix/integration-production-build@1bd8f6e`.
- **I02 architect-reviewed:** `dev/integration/slots-settings-wave2@4cc0d77`.
- I02 ╤Б╨╛╨┤╨╡╤А╨╢╨╕╤В Wave 1 + C02 + B01. `SettingsDynamicFinal` ╨┐╤А╨╕╤Б╤Г╤В╤Б╤В╨▓╤Г╨╡╤В; duplicate `ApplyDwmTitlebarTheme` ╤Г╨┤╨░╨╗╤С╨╜; production build fixes ╨┐╤А╨╕╤Б╤Г╤В╤Б╤В╨▓╤Г╤О╤В.
- I02 gates: AHK validate green, settings-seam green, frontend 25/25, typecheck/build green, production build green, fresh/rebuild config safety green, embedded assets green.
- `webview-slice` ╨▒╨╛╨╗╤М╤И╨╡ ╨╜╨╡ ╨▒╨╗╨╛╨║╨╕╤А╤Г╨╡╤В╤Б╤П compile duplicate, ╨╜╨╛ ╨╛╤Б╤В╨░╤С╤В╤Б╤П CDP `inject-timeout` ╨┐╨╛╤Б╨╗╨╡ ╤Г╤Б╨┐╨╡╤И╨╜╤Л╤Е boot/getInitialState/dirty-Apply/dispose; ╤Б╤З╨╕╤В╨░╤В╤М environment blocker, ╨┐╨╛╨║╨░ ╨╜╨╡ ╨┤╨╛╨║╨░╨╖╨░╨╜╨╛ ╨╛╨▒╤А╨░╤В╨╜╨╛╨╡.
- G04: `dev/fix/settings-custom-animation-preset@37cb31d`, frontend-only, tests 33/33, typecheck/build green.
- `wip/slots-parity` ╨┐╨╛╨║╨░ orchestration branch; ╨║╨╛╨┤╨╛╨▓╤Г╤О base ╨╜╨╡ ╨┤╨▓╨╕╨│╨░╤В╤М ╨┤╨╛ I03 + architect review + P01.

## ╨Я╤А╨╛╨▓╨╡╤А╨║╨░ I02 ╨░╤А╤Е╨╕╤В╨╡╨║╤В╨╛╤А╨╛╨╝

╨Я╤А╨╛╨▓╨╡╤А╨╡╨╜╨╛ ╨╜╨░ remote:
- branch HEAD `4cc0d77`;
- B01 merge `07c7d10`, C02 ╨▓╤Е╨╛╨┤╨╕╤В ╨▓ ╨╕╤Б╤В╨╛╤А╨╕╤О;
- `src/drawer.ahk` ╤Б╨╛╨┤╨╡╤А╨╢╨╕╤В `SettingsDynamicFinal(...)` ╨╕ ╨╛╨┤╨╜╤Г ╨┐╨╛╨╗╨╜╤Г╤О `ApplyDwmTitlebarTheme(...)`;
- `src/webview/SettingsWebView.ahk` ╨▓╤Л╨╖╤Л╨▓╨░╨╡╤В helper, ╨╜╨╛ duplicate ╨╜╨╡ ╨╛╨▒╤К╤П╨▓╨╗╤П╨╡╤В;
- `build/build.ps1` ╤Б╨╛╨┤╨╡╤А╨╢╨╕╤В `/silent`, PS5.1-compatible ISO-8859-1 check ╨╕ ╤Б╨╛╤Е╤А╨░╨╜╤П╨╡╤В ╤Б╤Г╤Й╨╡╤Б╤В╨▓╤Г╤О╤Й╨╕╨╣ `config.ini`.

---

# DONE / WAITING

## TASK I02 тАФ C02 + B01 integration

**Status:** DONE_ARCH_REVIEWED  
**Run ID:** `RUN-20260906-OPENCODE-I02-02`  
**Client:** OpenCode  
**Actual model selected by operator:** `GPT 5.6 Luna` via APInex UI  
**Branch:** `dev/integration/slots-settings-wave2`  
**Reviewed HEAD:** `4cc0d77`

Metadata note: self-report ╨╛╤И╨╕╨▒╨╛╤З╨╜╨╛ ╨╖╨░╨┐╨╕╤Б╨░╨╗ Gemini 3.8 Flash ╨╕╨╖ stale board. I03 ╨┤╨╛╨▒╨░╨▓╨╗╤П╨╡╤В correction note ╤Б ╨┐╨╛╨┤╤В╨▓╨╡╤А╨╢╨┤╨╡╨╜╨╕╨╡╨╝ ╨╛╨┐╨╡╤А╨░╤В╨╛╤А╨░.

## TASK G04 тАФ custom animation preset `╨б╨▓╨╛╤П`

**Status:** DONE_WAITING_FOR_I03  
**Run ID:** `RUN-20260906-ANTIGRAVITY-G04-01`  
**Client:** Antigravity  
**Actual model:** `Gemini 3.8 Flash (High)`  
**Chat/session ID:** `f5c32174-862b-4f11-9177-8e8771fa41e2`  
**Branch:** `dev/fix/settings-custom-animation-preset`  
**Reviewed HEAD:** `37cb31d`

---

# ACTIVE тАФ ╨┐╨░╤А╨░╨╗╨╗╨╡╨╗╤М╨╜╤Л╨╡ ╨╛╤В╨┤╨╡╨╗╤М╨╜╤Л╨╡ worktree

## TASK I03 тАФ ╨╕╨╜╤В╨╡╨│╤А╨╕╤А╨╛╨▓╨░╤В╤М G04 ╨▓ Wave 2 ╨╕ ╨┐╨╛╨┤╨│╨╛╤В╨╛╨▓╨╕╤В╤М ╨▒╨░╨╖╤Г ╨║ ╤А╤Г╤З╨╜╨╛╨╣ ╨┐╤А╨╕╤С╨╝╨║╨╡

**Status:** ACTIVE  
**Executor:** Antigravity  
**MODEL: Claude Sonnet 4.6 (Thinking) тАФ ╤Д╨░╨║╤В╨╕╤З╨╡╤Б╨║╨╕ ╨▓╤Л╨▒╤А╨░╤В╤М ╨▓ UI**  
**Run ID:** `RUN-20260906-ANTIGRAVITY-I03-01`  
**Base:** `dev/integration/slots-settings-wave2@4cc0d77`  
**Input:** `dev/fix/settings-custom-animation-preset@37cb31d`  
**Branch:** `integration/slots-settings-wave3`  
**Worktree:** `C:\Users\nerza\Projects\drawer-agent-worktrees\I03`

### ╨ж╨╡╨╗╤М

╨Я╨╛╨╗╤Г╤З╨╕╤В╤М clean candidate-base ╨┤╨╗╤П A01: Wave 2 + ╨┐╤А╨╛╨▓╨╡╤А╨╡╨╜╨╜╤Л╨╣ frontend-fix G04 + ╨░╨║╤В╤Г╨░╨╗╤М╨╜╤Л╨╡ orchestration docs. ╨н╤В╨╛ integration/review task, ╨╜╨╡ ╨╜╨╛╨▓╨░╤П feature-wave.

### ╨Ю╨▒╤П╨╖╨░╤В╨╡╨╗╤М╨╜╨╛

1. ╨Э╨╛╨▓╤Л╨╣ sibling-worktree I03 ╨╛╤В exact base `4cc0d77`; ╨╜╨╡ ╤А╨░╨▒╨╛╤В╨░╤В╤М ╨▓ I02/G04/shared checkout.
2. ╨Ш╨╜╤В╨╡╨│╤А╨╕╤А╨╛╨▓╨░╤В╤М G04 ╨┐╨╛ ╤Б╨╝╤Л╤Б╨╗╤Г, ╨╜╨╡ ╨┐╨╡╤А╨╡╨┐╨╕╤Б╤Л╨▓╨░╤В╤М ╨▒╨╡╨╖ ╨┐╤А╨╕╤З╨╕╨╜╤Л.
3. ╨Я╤А╨╛╨▓╨╡╤А╨╕╤В╤М, ╤З╤В╨╛ `animCustom` ╨╛╤Б╤В╨░╤С╤В╤Б╤П ╤В╨╛╨╗╤М╨║╨╛ draft/UI ╤Б╨╛╤Б╤В╨╛╤П╨╜╨╕╨╡╨╝; wire ╨┐╨╛-╨┐╤А╨╡╨╢╨╜╨╡╨╝╤Г `durationMs/steps`.
4. ╨Я╨╛╨┤╤В╤П╨╜╤Г╤В╤М ╨░╨║╤В╤Г╨░╨╗╤М╨╜╤Л╨╡ `AGENT_BOARD.md` ╨╕ `REPORT_FORMAT.md` ╨╕╨╖ `dev/wip/slots-parity`.
5. ╨Т `docs/agent-reports/2026-09-06-opencode-i02.md` ╨┤╨╛╨▒╨░╨▓╨╕╤В╤М correction note: ╨╛╨┐╨╡╤А╨░╤В╨╛╤А ╨┐╨╛╨┤╤В╨▓╨╡╤А╨╢╨┤╨░╨╡╤В ╤Д╨░╨║╤В╨╕╤З╨╡╤Б╨║╨╕ ╨▓╤Л╨▒╤А╨░╨╜╨╜╤Г╤О ╨╝╨╛╨┤╨╡╨╗╤М `GPT 5.6 Luna` ╤З╨╡╤А╨╡╨╖ APInex UI; ╤Б╤В╨░╤А╨░╤П ╤Б╤В╤А╨╛╨║╨░ Gemini ╨▒╤Л╨╗╨░ stale metadata.
6. ╨Э╨╡ ╨▒╤А╨░╤В╤М G02/G03/C03 ╨╕ ╨╜╨╡ ╨╝╨╡╨╜╤П╤В╤М slot/runtime semantics.
7. Diff ╨┤╨╛╨╗╨╢╨╡╨╜ ╤Б╨╛╨┤╨╡╤А╨╢╨░╤В╤М ╤В╨╛╨╗╤М╨║╨╛ I02 + G04 + docs/correction.

### ╨Я╤А╨╛╨▓╨╡╤А╨║╨╕

AHK validate; settings-seam; frontend tests >=33; typecheck; frontend build; production build; quick fresh-config + rebuild-preserves-config. WebView slice ╨╝╨░╨║╤Б╨╕╨╝╤Г╨╝ ╨╛╨┤╨╕╨╜ ╤А╨░╨╖; ╨┐╨╛╨▓╤В╨╛╤А ╤В╨╛╨│╨╛ ╨╢╨╡ CDP timeout ╨╖╨░╤Д╨╕╨║╤Б╨╕╤А╨╛╨▓╨░╤В╤М ╨╕ ╨╜╨╡ ╤А╨╡╤В╤А╨░╨╕╤В╤М ╨▒╨╡╤Б╨║╨╛╨╜╨╡╤З╨╜╨╛. VM/full suite ╨╜╨╡ ╨╖╨░╨┐╤Г╤Б╨║╨░╤В╤М.

╨Я╨╡╤А╨╡╨┤ ╨╖╨░╨▓╨╡╤А╤И╨╡╨╜╨╕╨╡╨╝: factual report, commit, push `dev/integration/slots-settings-wave3`, verify remote HEAD = local HEAD, clean tree. `wip/slots-parity` ╨╜╨╡ ╨┤╨▓╨╕╨│╨░╤В╤М.

## TASK G02 тАФ stale windowClass + picker identity

**Status:** READY_PARALLEL_WITH_I03_WAITING_FOR_A01_INTEGRATION  
**Executor:** OpenCode  
**MODEL: `Qwen 3.8 MAX` тАФ ╤Д╨░╨║╤В╨╕╤З╨╡╤Б╨║╨╕ ╨▓╤Л╨▒╤А╨░╤В╤М ╨▓ OpenCode/APInex UI**  
**Run ID:** `RUN-20260906-OPENCODE-G02-01`  
**Purpose:** ╨▓╤В╨╛╤А╨╛╨╣ qualification run OpenCode, ╤В╨╡╨┐╨╡╤А╤М ╨╜╨░ ╨┤╤А╤Г╨│╨╛╨╣ provider-╨╝╨╛╨┤╨╡╨╗╨╕  
**Base:** `dev/integration/slots-settings-wave2@4cc0d77`  
**Branch:** `fix/settings-picker-identity`  
**Worktree:** `C:\Users\nerza\Projects\drawer-agent-worktrees\G02`

### ╨Я╨╛╤З╨╡╨╝╤Г ╨╝╨╛╨╢╨╜╨╛ ╨┐╨░╤А╨░╨╗╨╗╨╡╨╗╤М╨╜╨╛

I03 ╨╕╨╜╤В╨╡╨│╤А╨╕╤А╤Г╨╡╤В ╤В╨╛╨╗╤М╨║╨╛ G04 (`GeneralView.vue`, `general.ts`, animation test/package test-list + docs). G02 ╨╖╨░╨╜╨╕╨╝╨░╨╡╤В╤Б╤П identity ╨┐╨╛╤Б╤В╨╛╤П╨╜╨╜╨╛╨│╨╛ ╤Б╨╗╨╛╤В╨░ ╨╕ picker flow. **G02 ╨╜╨╡ ╨╕╨╜╤В╨╡╨│╤А╨╕╤А╨╛╨▓╨░╤В╤М ╨▓ candidate-base ╨┤╨╛ A01**, ╨┤╨░╨╢╨╡ ╨╡╤Б╨╗╨╕ ╨╖╨░╨║╨╛╨╜╤З╨╕╤В ╤А╨░╨╜╤М╤И╨╡.

### ╨ж╨╡╨╗╤М

╨г╨▒╤А╨░╤В╤М stale `windowClass` ╨╕ ╤Б╨┤╨╡╨╗╨░╤В╤М identity ╨┐╨╛╤Б╤В╨╛╤П╨╜╨╜╨╛╨│╨╛ ╤Б╨╗╨╛╤В╨░ ╤Б╨╛╨│╨╗╨░╤Б╨╛╨▓╨░╨╜╨╜╤Л╨╝ ╨┐╤А╨╕ ╤А╤Г╤З╨╜╨╛╨╣ ╤Б╨╝╨╡╨╜╨╡ exe, `picker.exe`, `picker.window` ╨╕ dynamicтЖТpermanent, ╨╜╨╡ ╨╝╨╡╨╜╤П╤П ╨╛╨▒╤Й╤Г╤О FindWindow/slot ╨░╤А╤Е╨╕╤В╨╡╨║╤В╤Г╤А╤Г.

### ╨Я╨╛╨┤╤В╨▓╨╡╤А╨┤╨╕╤В╤М ╤В╨╡╨║╤Г╤Й╨╕╨╣ ╨┤╨╡╤Д╨╡╨║╤В

╨Э╨░ Wave 2 `picker.exe` ╨╝╨╡╨╜╤П╨╡╤В `draft.executable`, ╨╜╨╛ ╨╜╨╡ ╨╛╤З╨╕╤Й╨░╨╡╤В `draft.windowClass`; ╤Б╤В╨░╤А╤Л╨╣ `ahk_class` ╨╝╨╛╨╢╨╡╤В ╨╛╤Б╤В╨░╤В╤М╤Б╤П ╨╛╤В ╨┤╤А╤Г╨│╨╛╨│╨╛ ╨┐╤А╨╕╨╗╨╛╨╢╨╡╨╜╨╕╤П/╨╛╨║╨╜╨░ ╨╕ ╨╖╨░╤В╨╡╨╝ ╨┐╨╛╨┐╨░╤Б╤В╤М ╨▓ permanent rule. ╨Э╨╡ ╤Б╤З╨╕╤В╨░╤В╤М ╤Н╤В╨╛ ╨╡╨┤╨╕╨╜╤Б╤В╨▓╨╡╨╜╨╜╤Л╨╝ ╤Б╤Ж╨╡╨╜╨░╤А╨╕╨╡╨╝ тАФ ╨┐╤А╨╛╨▓╨╡╤А╨╕╤В╤М ╨║╨╛╨┤╨╛╨╝ ╨╕ ╤В╨╡╤Б╤В╨░╨╝╨╕.

### ╨Ю╨▒╤П╨╖╨░╤В╨╡╨╗╤М╨╜╨╛╨╡ ╨┐╨╛╨▓╨╡╨┤╨╡╨╜╨╕╨╡

1. ╨Х╤Б╨╗╨╕ ╨┐╨╛╨╗╤М╨╖╨╛╨▓╨░╤В╨╡╨╗╤М **╤А╨╡╨░╨╗╤М╨╜╨╛ ╨╝╨╡╨╜╤П╨╡╤В exe ╨▓╤А╤Г╤З╨╜╤Г╤О**, `windowClass` ╤Б╤В╨░╤А╨╛╨│╨╛ exe ╨╜╨╡ ╨┤╨╛╨╗╨╢╨╡╨╜ ╤В╨╕╤Е╨╛ ╨┐╨╡╤А╨╡╨╢╨╕╤В╤М ╨╕╨╖╨╝╨╡╨╜╨╡╨╜╨╕╨╡.
2. ╨Х╤Б╨╗╨╕ `picker.exe` ╨▓╤Л╨▒╨╕╤А╨░╨╡╤В ╨╜╨╛╨▓╤Л╨╣ executable, stale class ╤Б╤В╨░╤А╨╛╨│╨╛ ╨╛╨║╨╜╨░ ╨╜╨╡ ╨┤╨╛╨╗╨╢╨╡╨╜ ╨╛╤Б╤В╨░╤В╤М╤Б╤П.
3. `picker.window` ╨┤╨╛╨╗╨╢╨╡╨╜ ╤Б╨╛╨│╨╗╨░╤Б╨╛╨▓╨░╨╜╨╜╨╛ ╤Г╤Б╤В╨░╨╜╨╛╨▓╨╕╤В╤М executable + windowClass ╨╕╨╖ ╨╛╨┤╨╜╨╛╨│╨╛ ╨▓╤Л╨▒╤А╨░╨╜╨╜╨╛╨│╨╛ ╨╛╨║╨╜╨░; default/╨┐╤Г╤Б╤В╨╛╨╡ ╨╕╨╝╤П ╨╝╨╛╨╢╨╜╨╛ ╤А╨░╨╖╤Г╨╝╨╜╨╛ ╨╖╨░╤Б╨╡╤П╤В╤М title ╨║╨░╨║ ╤Б╨╡╨╣╤З╨░╤Б.
4. DynamicтЖТPermanent ╨┤╨╛╨╗╨╢╨╡╨╜ ╨╕╤Б╨┐╨╛╨╗╤М╨╖╨╛╨▓╨░╤В╤М ╤З╨╕╤Б╤В╤Л╨╣ identity seed, ╨║╨╛╤В╨╛╤А╤Л╨╣ backend ╤Г╨╢╨╡ ╨╛╤В╨┤╨░╤С╤В ╤З╨╡╤А╨╡╨╖ `permanentDefaults` ╨┤╨╗╤П ╨╢╨╕╨▓╨╛╨│╨╛ dynamic window. ╨Э╨╡ ╨▓╤Л╨┤╤Г╨╝╤Л╨▓╨░╤В╤М exe/class ╨╜╨░ frontend ╨╕ ╨╜╨╡ ╨┐╤А╨╡╨▓╤А╨░╤Й╨░╤В╤М dynamic ╨▓ persistent identity ╨┤╨╛ Apply.
5. ╨Х╤Б╨╗╨╕ ╨╢╨╕╨▓╨╛╨│╨╛ ╨╛╨║╨╜╨░ ╨╜╨╡╤В, ╨╜╨╡ ╨┐╤А╨╕╨┤╤Г╨╝╤Л╨▓╨░╤В╤М ╨▓╨░╨╗╨╕╨┤╨╜╤Л╨╣ permanent identity; ╤Б╤Г╤Й╨╡╤Б╤В╨▓╤Г╤О╤Й╨░╤П backend validation ╨┤╨╛╨╗╨╢╨╜╨░ ╨╛╤Б╤В╨░╤В╤М╤Б╤П ╨╕╤Б╤В╨╛╤З╨╜╨╕╨║╨╛╨╝ ╨╕╤Б╤В╨╕╨╜╤Л.
6. ╨Э╨╡ ╤А╨░╤Б╤И╨╕╤А╤П╤В╤М ╨╖╨░╨┤╨░╤З╤Г ╨┤╨╛ ╨▓╤Л╨▒╨╛╤А╨░ ╨║╨╛╨╜╨║╤А╨╡╤В╨╜╨╛╨│╨╛ permanent-window (`F12`) ╨╕ ╨╜╨╡ ╨┐╨╡╤А╨╡╨┐╨╕╤Б╤Л╨▓╨░╤В╤М `FindWindow`.
7. ╨б╨╛╤Е╤А╨░╨╜╨╕╤В╤М Apply/Cancel draft semantics.

### ╨Ц╤С╤Б╤В╨║╨░╤П ╨│╤А╨░╨╜╨╕╤Ж╨░ ╨┐╨░╤А╨░╨╗╨╗╨╡╨╗╤М╨╜╨╛╤Б╤В╨╕

╨Ь╨╛╨╢╨╜╨╛ ╨╝╨╡╨╜╤П╤В╤М ╨┐╨╛ ╨╜╨╡╨╛╨▒╤Е╨╛╨┤╨╕╨╝╨╛╤Б╤В╨╕: `settings-ui/src/views/SlotsView.vue`, `settings-ui/src/bridge/settings.ts`, `settings-ui/src/bridge/slotDraft.ts`, ╤Б╨▓╤П╨╖╨░╨╜╨╜╤Л╨╡ slot/frontend tests; backend picker/port ╤В╨╛╨╗╤М╨║╨╛ ╨╡╤Б╨╗╨╕ ╤Д╨░╨║╤В╨╕╤З╨╡╤Б╨║╨╕ ╨┤╨╛╨║╨░╨╖╨░╨╜╨╛, ╤З╤В╨╛ frontend-only fix ╨╜╨╡╨┤╨╛╤Б╤В╨░╤В╨╛╤З╨╡╨╜.

**╨Э╨╡ ╨╝╨╡╨╜╤П╤В╤М**, ╨┐╨╛╤В╨╛╨╝╤Г ╤З╤В╨╛ ╤Н╤В╨╕╨╝ ╨▓╨╗╨░╨┤╨╡╨╡╤В I03/G04: `settings-ui/src/views/GeneralView.vue`, `settings-ui/src/bridge/general.ts`, `settings-ui/package.json`, `settings-ui/test/animationPreset.test.ts`. ╨Э╨╡ ╨╝╨╡╨╜╤П╤В╤М `build/build.ps1`, DWM/titlebar, hotkey product contract.

╨Х╤Б╨╗╨╕ ╨╜╤Г╨╢╨╡╨╜ frontend regression, ╨┐╤А╨╡╨┤╨┐╨╛╤З╨╡╤Б╤В╤М ╤Б╤Г╤Й╨╡╤Б╤В╨▓╤Г╤О╤Й╨╕╨╣ test entrypoint/file ╨╕╨╗╨╕ ╨╛╤В╨┤╨╡╨╗╤М╨╜╤Л╨╣ targeted command; **╨╜╨╡ ╨┐╤А╨░╨▓╨╕╤В╤М `settings-ui/package.json` ╨▓ ╤Н╤В╨╛╨╣ ╨┐╨░╤А╨░╨╗╨╗╨╡╨╗╤М╨╜╨╛╨╣ ╨▓╨╡╤В╨║╨╡**.

### ╨Я╤А╨╛╨▓╨╡╤А╨║╨╕

- `npm --prefix settings-ui test`;
- `npm --prefix settings-ui run typecheck`;
- `npm --prefix settings-ui run build`;
- targeted regression ╨┤╨╗╤П stale-class/picker identity;
- ╨╡╤Б╨╗╨╕ ╨╖╨░╤В╤А╨╛╨╜╤Г╤В AHK/backend: AHK validate + settings-seam;
- production build ╨╕ VM/full suite ╨╜╨╡ ╨╜╤Г╨╢╨╜╤Л.

╨Я╨╡╤А╨╡╨┤ ╨╖╨░╨▓╨╡╤А╤И╨╡╨╜╨╕╨╡╨╝: factual report, commit, push `dev/fix/settings-picker-identity`, verify remote HEAD = local HEAD, clean tree. **╨Э╨╡ merge ╨▓ Wave 3 / wip.** ╨Т ╨╛╤В╤З╤С╤В╨╡ ╨╛╤В╨┤╨╡╨╗╤М╨╜╨╛ ╨╛╤Ж╨╡╨╜╨╕╤В╤М OpenCode+Qwen tool-use/╨║╨░╤З╨╡╤Б╤В╨▓╨╛ ╨╛╤В╨╜╨╛╤Б╨╕╤В╨╡╨╗╤М╨╜╨╛ ╨┐╤А╨╡╨┤╤Л╨┤╤Г╤Й╨╡╨│╨╛ Luna run.

---

# NEXT

## TASK P01 тАФ promotion ╨┐╨╛╤Б╨╗╨╡ architect review I03

**Status:** BLOCKED_ON_I03_ARCH_REVIEW

╨Я╨╛╤Б╨╗╨╡ ╨┐╤А╨╛╨▓╨╡╤А╨║╨╕ I03 ╨░╤А╤Е╨╕╤В╨╡╨║╤В╨╛╤А ╨┤╨░╤Б╤В ╨░╨│╨╡╨╜╤В╤Г ╨║╨╛╤А╨╛╤В╨║╤Г╤О promotion-╨╖╨░╨┤╨░╤З╤Г: ╨▒╨╡╨╖╨╛╨┐╨░╤Б╨╜╨╛ ╨┐╤А╨╕╨▓╨╡╤Б╤В╨╕ `dev/wip/slots-parity` ╨╕ ╨╗╨╛╨║╨░╨╗╤М╨╜╤Л╨╣ checkout `C:\Users\nerza\Projects\drawer-settings-integration` ╨║ ╨┐╤А╨╕╨╜╤П╤В╨╛╨╣ candidate-base ╨▒╨╡╨╖ ╨┐╨╛╤В╨╡╤А╨╕ ╤З╤Г╨╢╨╛╨╣ ╤А╨░╨▒╨╛╤В╤Л. ╨Я╨╛╨╗╤М╨╖╨╛╨▓╨░╤В╨╡╨╗╤М Git ╤А╤Г╨║╨░╨╝╨╕ ╨╜╨╡ ╨┤╨╡╨╗╨░╨╡╤В.

## TASK A01 тАФ ╨║╨╛╤А╨╛╤В╨║╨░╤П ╤А╤Г╤З╨╜╨░╤П ╨┐╤А╨╕╤С╨╝╨║╨░

**Status:** BLOCKED_ON_P01  
**Executor:** ╨┐╨╛╨╗╤М╨╖╨╛╨▓╨░╤В╨╡╨╗╤М

╨з╨╡╨╗╨╛╨▓╨╡╤З╨╡╤Б╨║╨╕╨╣ checklist:
- custom show/hide hotkey ╤А╨░╨▒╨╛╤В╨░╨╡╤В ╤Б╤А╨░╨╖╤Г ╨┐╨╛╤Б╨╗╨╡ Apply, ╤Б╤В╨░╤А╤Л╨╣ ╨┐╨╡╤А╨╡╤Б╤В╨░╤С╤В;
- Tab ╨▓╤Л╤Е╨╛╨┤╨╕╤В ╨╕╨╖ hotkey field;
- permanent name ╤А╨╡╨┤╨░╨║╤В╨╕╤А╤Г╨╡╤В╤Б╤П;
- dynamic bind тЖТ ╨║╤А╨╛╨╝╨║╨░ ╤Б╤А╨░╨╖╤Г тЖТ hotkey ╨┐╨╛╨║╨░╨╖╤Л╨▓╨░╨╡╤В/╤Г╨▒╨╕╤А╨░╨╡╤В;
- Release ╨╛╤Б╨▓╨╛╨▒╨╛╨╢╨┤╨░╨╡╤В dynamic slot;
- Reset slot settings ╨▓╨╛╨╖╨▓╤А╨░╤Й╨░╨╡╤В ╨╜╨░╤Б╨╗╨╡╨┤╨╛╨▓╨░╨╜╨╕╨╡ General;
- permanentтЖФdynamic ╤Б ╨╢╨╕╨▓╤Л╨╝ ╨╛╨║╨╜╨╛╨╝ ╨╜╨╡ ╤В╨╡╤А╤П╨╡╤В ╨╛╨║╨╜╨╛;
- permanent app, ╨╖╨░╨┐╤Г╤Й╨╡╨╜╨╜╨╛╨╡ ╨┐╨╛╤Б╨╗╨╡ Drawer, ╤Б╨░╨╝╨╛ ╨┐╨╛╨╗╤Г╤З╨░╨╡╤В ╨║╤А╨╛╨╝╨║╤Г;
- ╤Б╨╕╤Б╤В╨╡╨╝╨╜╤Л╨╣ titlebar ╤В╤С╨╝╨╜╤Л╨╣ ╨╕ About ╨▒╨╡╨╖ mock-╤Н╨╗╨╡╨╝╨╡╨╜╤В╨╛╨▓;
- ┬л╨б╨▓╨╛╤П┬╗ ╤Б╤А╨░╨╖╤Г ╨╛╤В╨║╤А╤Л╨▓╨░╨╡╤В ╨┐╨╛╨╗╤П ╨░╨╜╨╕╨╝╨░╤Ж╨╕╨╕ ╨╕ ╨╜╨╡ ╨╛╤В╨║╨░╤В╤Л╨▓╨░╨╡╤В╤Б╤П ╨┤╨╛ ╨▓╨▓╨╛╨┤╨░.

╨Я╤А╨╕ ╨▒╨░╨│╨╡: tray `╨Э╨░╤И╤С╨╗ ╨▒╨░╨│тАж` тЖТ ╨╜╨╛╨╝╨╡╤А BUG + ╤З╤В╨╛ ╤Б╨┤╨╡╨╗╨░╨╗ + ╤З╤В╨╛ ╨┐╤А╨╛╨╕╨╖╨╛╤И╨╗╨╛.

---

# BACKLOG тАФ Settings correctness

## TASK C03 тАФ partial/retryable/diagnostics correctness
**Status:** BLOCKED_ON_A01_AND_STRONG_MODEL
**Preferred:** Codex after reset / Sonnet / Opus reserve if genuinely hard

Structured partial-save/reload/reconcile ╨┤╨╛╨╗╨╢╨╡╨╜ ╨┤╨╛╤Е╨╛╨┤╨╕╤В╤М ╨┤╨╛ UI; ╨▒╨╡╨╖ ╨╗╨╛╨╢╨╜╨╛╨│╨╛ `╨б╨╛╤Е╤А╨░╨╜╨╡╨╜╨╛`, ╨┐╨╛╤В╨╡╤А╨╕ draft/field diagnostics ╨╕ ╨╕╤Б╤З╨╡╨╖╨╜╨╛╨▓╨╡╨╜╨╕╤П warning ╨┐╨╛╤Б╨╗╨╡ no-op. ╨Ю╨┤╨╕╨╜ persistence path.

## TASK G02 integration
**Status:** BLOCKED_ON_G02_RESULT_AND_A01

╨Х╤Б╨╗╨╕ G02 ╨┐╤А╨╛╤И╤С╨╗ review, ╨╕╨╜╤В╨╡╨│╤А╨╕╤А╨╛╨▓╨░╤В╤М ╨╡╨│╨╛ ╤Г╨╢╨╡ **╨┐╨╛╤Б╨╗╨╡** A01 ╨╛╤В╨┤╨╡╨╗╤М╨╜╨╛╨╣ controlled task; ╨╜╨╡ ╨┐╨╛╨┤╨╝╨╡╤И╨╕╨▓╨░╤В╤М ╨▓ ╤В╨╡╨║╤Г╤Й╤Г╤О candidate-base ╨┐╨╡╤А╨╡╨┤ ╤А╤Г╤З╨╜╨╛╨╣ ╨┐╤А╨╕╤С╨╝╨║╨╛╨╣.

## TASK G03 тАФ live hideOnBlur/blurMs + save lock
**Status:** BLOCKED_ON_A01
**Preferred:** Antigravity Sonnet / OpenCode if runtime tool-use proves stable

╨Я╨╛╤Б╨╗╨╡ Apply runtime-╨╜╨░╤Б╤В╤А╨╛╨╣╨║╨╕ ╤А╨╡╨░╨╗╤М╨╜╨╛ ╨▓╨╗╨╕╤П╤О╤В ╨╜╨░ ╤Г╨╢╨╡ ╨┐╨╛╨║╨░╨╖╨░╨╜╨╜╨╛╨╡ ╨╛╨║╨╜╨╛; blur timer ╨╜╨╡ stale; General inputs ╨╖╨░╤Й╨╕╤Й╨╡╨╜╤Л ╨▓╨╛ ╨▓╤А╨╡╨╝╤П Save.

---

# BACKLOG тАФ UX

## TASK G05 тАФ Slots terminology/onboarding
**Status:** BLOCKED_ON_SETTINGS_CORRECTNESS

╨г╨▒╤А╨░╤В╤М INI/internal jargon; ╤П╤Б╨╜╨╛ ╨╛╨▒╤К╤П╤Б╨╜╨╕╤В╤М Permanent/Dynamic; ╤Е╨╛╤А╨╛╤И╨╕╨╣ empty dynamic onboarding; release/reset ╨╛╤З╨╡╨▓╨╕╨┤╨╜╤Л; ╨▒╨╡╨╖ redesign.

## TASK G06 тАФ navigation/accessibility/polish
**Status:** BLOCKED_ON_SETTINGS_CORRECTNESS

Selected slot ╤Б╨╛╤Е╤А╨░╨╜╤П╨╡╤В╤Б╤П ╨╝╨╡╨╢╨┤╤Г tabs; scrollbar/list behavior; remaining labels/select/contrast/keyboard issues; About follow-up.

---

# BACKLOG тАФ modular architecture ╨┐╨╛╤Б╨╗╨╡ ╤Б╤В╨░╨▒╨╕╨╗╨╕╨╖╨░╤Ж╨╕╨╕

## TASK A02 тАФ windows/focus seam
**Status:** BLOCKED_ON_STABILIZATION_AND_STRONG_MODEL

## TASK A03 тАФ parking/geometries seam
**Status:** BLOCKED_ON_A02

## TASK A04 тАФ handles seam
**Status:** BLOCKED_ON_A02_A03

## TASK A05 тАФ Settings service + tray seams
**Status:** BLOCKED_ON_A02_A04

---

# TEST / RELEASE DEBT

## TASK T01 тАФ stale VM/safe tests
**Status:** PARKED_UNTIL_ARCH_STABLE

## TASK T02 тАФ common VM/test helper
**Status:** PARKED_UNTIL_T01

## TASK R01 тАФ diagnostics production policy
**Status:** BLOCKED_ON_STABILIZATION

Bounded/rotated debug log, dev/release policy, ╤Б╨╛╤Е╤А╨░╨╜╨╕╤В╤М `╨Э╨░╤И╤С╨╗ ╨▒╨░╨│тАж`, ╨▒╨╡╨╖ logging framework.

## TASK R02 тАФ production build acceptance
**Status:** BLOCKED_ON_STABILIZATION

Fresh build, rebuild preserving config, compiled Settings, clean package/version metadata.

## TASK R03 тАФ final human acceptance
**Status:** BLOCKED_ON_1_0_BLOCKERS

---

# FUTURE PRODUCT

## F01 тАФ arbitrary slots
**Status:** FUTURE_PRODUCT_DECISION

## F02 тАФ Add/Delete slot UI
**Status:** BLOCKED_ON_F01

## F03 тАФ handle context menu + tray slot actions
**Status:** BLOCKED_ON_F01_F02

## F04 тАФ reset semantics
**Status:** FUTURE_AFTER_F02

## F12 тАФ concrete permanent-window selection
**Status:** DEFERRED_PRODUCT

## F08 тАФ remove parked window from Alt+Tab
**Status:** DEFERRED_RISKY

## F11 тАФ autostart
**Status:** DEFERRED_UNTIL_DAILY_USE

---

# ╨С╨╗╨╕╨╢╨░╨╣╤И╨╕╨╣ ╨┐╨╛╤А╤П╨┤╨╛╨║

1. ╨Я╨░╤А╨░╨╗╨╗╨╡╨╗╤М╨╜╨╛ ╤Б╨╡╨╣╤З╨░╤Б: I03 ╨▓ Antigravity/Sonnet ╨╕ G02 ╨▓ OpenCode/Qwen, ╨║╨░╨╢╨┤╤Л╨╣ ╨▓ ╤Б╨▓╨╛╤С╨╝ sibling-worktree.
2. ╨Р╤А╤Е╨╕╤В╨╡╨║╤В╨╛╤А ╨┐╤А╨╛╨▓╨╡╤А╤П╨╡╤В I03 remote; ╨╖╨░╤В╨╡╨╝ P01.
3. A01 тАФ ╨║╨╛╤А╨╛╤В╨║╨░╤П ╤А╤Г╤З╨╜╨░╤П ╨┐╤А╨╕╤С╨╝╨║╨░ candidate-base **╨▒╨╡╨╖ G02**.
4. ╨Р╤А╤Е╨╕╤В╨╡╨║╤В╨╛╤А ╨╛╤В╨┤╨╡╨╗╤М╨╜╨╛ ╨┐╤А╨╛╨▓╨╡╤А╤П╨╡╤В G02; ╨┐╨╛╤Б╨╗╨╡ A01 тАФ controlled integration G02, ╨╡╤Б╨╗╨╕ ╤А╨╡╨╖╤Г╨╗╤М╤В╨░╤В ╨┐╤А╨╕╨╜╤П╤В.
5. ╨Ч╨░╤В╨╡╨╝ C03 + G03 ╨┐╨╛ ╨┤╨╛╤Б╤В╤Г╨┐╨╜╤Л╨╝ ╨┐╤Г╨╗╨░╨╝.
6. UX cleanup.
7. Modular architecture.
8. Test/release debt.
9. Future product ╨╛╤В╨┤╨╡╨╗╤М╨╜╨╛.
