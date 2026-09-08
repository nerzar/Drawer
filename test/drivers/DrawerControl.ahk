#Requires AutoHotkey v2.0

; Gracefully close one exact Drawer/AutoHotkey process through its hidden
; script main window. WinClose sends WM_CLOSE, so production OnExit(Cleanup)
; still runs; no product hotkey is repurposed for test teardown.
DrawerExit(drawerPid, waitMs := 5000) {
    if !drawerPid || !ProcessExist(drawerPid)
        return true

    detectHidden := A_DetectHiddenWindows
    try {
        DetectHiddenWindows(true)
        if (mainHwnd := WinExist("ahk_class AutoHotkey ahk_pid " drawerPid))
            WinClose(mainHwnd)

        deadline := A_TickCount + waitMs
        while ProcessExist(drawerPid) && A_TickCount < deadline
            Sleep(50)
        return !ProcessExist(drawerPid)
    } finally {
        DetectHiddenWindows(detectHidden)
    }
}
