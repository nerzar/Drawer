# Git structure cleanup — factual report

Date: 2026-09-05
Workspace: `C:\Users\nerza\Projects\drawer-settings-integration`
Branch: `wip/slots-parity`
Accepted baseline commit: `6762e5b`

---

## 1. Summary

Cleaned up the Git worktree and branch topology of Drawer according to specified rules:
- **Zero data loss**: all unique commits and uncommitted changes from dirty worktrees were preserved and pushed to private storage (`Drawer.Dev`, remote `dev`) under `archive/...`.
- **Public repo safety**: `nerzar/Drawer` (`origin`) was not modified, force-pushed, or altered in any way.
- **Worktree reduction**: reduced 7 worktrees down to the minimum necessary:
  - `C:/Users/nerza/Projects/drawer` (main repository root, on `main` tracking `origin/main`).
  - `C:/Users/nerza/Projects/drawer-settings-integration` (active working directory, on `wip/slots-parity` tracking `dev/wip/slots-parity`).
- **Branch reduction**: deleted 10 obsolete/merged local branches after confirming remote archival.

---

## 2. Worktrees State

### Before cleanup (7 worktrees)
```text
C:/Users/nerza/Projects/drawer                           8848cb8 [feature/settings-window-redesign] (DIRTY)
C:/Users/nerza/.codex/worktrees/aa02/drawer              a50161e [codex/production-picker-c6]
C:/Users/nerza/.codex/worktrees/b2b2/drawer              08af34f [codex/c0-architecture-docs]
C:/Users/nerza/Projects/drawer-master                    95d495b [feature/settings-vue-frontend]
C:/Users/nerza/Projects/drawer-settings-integration      6762e5b [wip/slots-parity]
C:/Users/nerza/Projects/drawer-webview2-settings-review  047c1b8 [claude/webview2-settings-review]
C:/Users/nerza/Projects/drawer-webview2-settings-spike   9d3b11e [codex/webview2-settings-spike]
```

### After cleanup (2 worktrees)
```text
C:/Users/nerza/Projects/drawer                       d1ff04a [main]
C:/Users/nerza/Projects/drawer-settings-integration  6762e5b [wip/slots-parity]
```

### Worktree removal details
1. `C:/Users/nerza/.codex/worktrees/aa02/drawer`: unlinked from Git via `git worktree remove`. The directory contents were deleted; the empty folder path is temporarily held open by the running background `codex` process (PID 18796) and will be removed once that process terminates.
2. `C:/Users/nerza/.codex/worktrees/b2b2/drawer`: unlinked and completely deleted.
3. `C:/Users/nerza/Projects/drawer-master`: unlinked and completely deleted.
4. `C:/Users/nerza/Projects/drawer-webview2-settings-review`: unlinked and completely deleted.
5. `C:/Users/nerza/Projects/drawer-webview2-settings-spike`: unlinked and completely deleted.

---

## 3. Dirty Worktree Handling (`C:/Users/nerza/Projects/drawer`)

Before cleanup, `C:/Users/nerza/Projects/drawer` had uncommitted test/VM changes:
- `modified: test/run.ps1`
- `modified: test/vm/README.md`
- `modified: test/vm/new-vm.ps1`
- `untracked: test/vm-transfer/check-drawer.ps1`
- `untracked: test/vm-transfer/diag.ps1`

Action taken:
1. All modified and untracked files were staged and committed cleanly as commit `7b598d4`:
   `wip(test): vmware test orchestrator and vm-transfer scripts`
2. The commit was pushed to `Drawer.Dev` (`dev`) under branch `archive/feature/settings-window-redesign`.
3. The main worktree was then switched to `main` (`git checkout -b main --track origin/main`), leaving it clean.

---

## 4. Archival to `Drawer.Dev` (remote `dev`)

All unique branches and histories were pushed to `https://github.com/nerzar/Drawer.Dev.git`:

| Archived Branch Ref on `dev` | Source Local Branch | Commit SHA | Description |
|---|---|---|---|
| `archive/feature/settings-window-redesign` | `feature/settings-window-redesign` | `7b598d4` | Redesign base + committed VMware test work & vm-transfer scripts |
| `archive/claude/webview2-settings-review` | `claude/webview2-settings-review` | `047c1b8` | WebView2 settings review spike (lifecycle, protocol, ADR review) |
| `archive/codex/webview2-settings-spike` | `codex/webview2-settings-spike` | `9d3b11e` | WebView2 settings spike line |
| `archive/codex/c0-architecture-docs` | `codex/c0-architecture-docs` | `08af34f` | C0 architecture gate sync |
| `archive/codex/production-picker-c6` | `codex/production-picker-c6` | `a50161e` | Production pickers with C6 lifecycle guards |
| `archive/codex/editable-permanent-slots` | `codex/editable-permanent-slots` | `0dfc3fe` | Edit permanent slots through canonical slotEdits |
| `archive/codex/slots-readonly-live-status` | `codex/slots-readonly-live-status` | `6a37138` | Connect read-only slots and live status to backend |
| `archive/feature/settings-vue-frontend` | `feature/settings-vue-frontend` | `95d495b` | Vue 3 / Vite settings frontend spike |
| `archive/master` | `master` | `93fd531` | Previous master architecture doc commit |
| `archive/integration/settings-webview2` | `integration/settings-webview2` | `50bfcdc` | Settings webview2 integration line (ancestor of wip/slots-parity) |

---

## 5. Local Branch Cleanup

After confirming remote archival, the following 10 local branches were safely deleted:
- `claude/webview2-settings-review`
- `codex/c0-architecture-docs`
- `codex/editable-permanent-slots`
- `codex/production-picker-c6`
- `codex/slots-readonly-live-status`
- `codex/webview2-settings-spike`
- `feature/settings-vue-frontend`
- `feature/settings-window-redesign`
- `integration/settings-webview2`
- `master`

### Remaining Local Branches
```text
+ main             d1ff04a (C:/Users/nerza/Projects/drawer) [origin/main] Update README.md
* wip/slots-parity 6762e5b [dev/wip/slots-parity] docs: record completed Slots parity milestone
```

### Configured Remotes
```text
dev     https://github.com/nerzar/Drawer.Dev.git (fetch)
dev     https://github.com/nerzar/Drawer.Dev.git (push)
origin  https://github.com/nerzar/Drawer.git (fetch)
origin  https://github.com/nerzar/Drawer.git (push)
```

---

## 6. Verification and Invariant Checks

1. **Current accepted worktree status**:
   - Directory: `C:\Users\nerza\Projects\drawer-settings-integration`
   - Active branch: `wip/slots-parity`
   - HEAD commit before this report: `6762e5b`
   - Working tree: clean (only this report pending commit)
2. **Main repository worktree**:
   - Directory: `C:\Users\nerza\Projects\drawer`
   - Active branch: `main` (tracking `origin/main` at `d1ff04a`)
   - Untracked files present: `.idea/`, `.tools/`, `dist/` (build and IDE local caches, preserved intact)
3. **Public repo safety**:
   - `origin` remained untouched; no commits or tags overwritten or modified.
