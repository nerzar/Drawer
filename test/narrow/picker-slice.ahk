
SetTimer(PickerSmokeDrive, 100)
SetTimer(PickerNativeSmoke, -300)

PickerNativeSmoke() {
    global setUI, setGui
    SettingsShow()
    ; Enter the existing native editor handler, then reenter its commands
    ; while WinWaitClose pumps the queue. No test replacement of the picker.
    SetTimer(PickerNativeInterrupt, 100)
    oldUI := setUI
    SettingsSlotWindowPick(oldUI)
    if oldUI.edits.Count
        throw Error("native picker wrote draft after close")
    FileAppend("smoke.native-picker-safe`n", A_ScriptDir "\bridge.log", "UTF-8")
}

PickerNativeInterrupt() {
    global setUI, setGui, webTrace
    state := SettingsPickerState()
    if !state.active
        return
    SetTimer(PickerNativeInterrupt, 0)
    oldUI := setUI
    owner := setGui.Hwnd
    SettingsSlotWindowPick(oldUI)
    SettingsSave(false)
    SettingsClose(true)
    if (!WinExist("ahk_id " owner) || setUI != oldUI)
        throw Error("native owner destroyed on picker stack")
}

PickerSmokeDrive() {
    global webTrace, webBridge
    static fixture := 0, handled := Map(), closed := false
    if !fixture {
        fixture := Gui(, "Picker fixture")
        fixture.Show("w310 h250 NoActivate")
    }
    log := ""
    try log := FileRead(webTrace, "UTF-8")
    state := SettingsPickerState()
    if (!state.active || !IsObject(webBridge))
        return
    dialog := 0
    for hwnd in WinGetList() {
        if (DllCall("GetWindow", "Ptr", hwnd, "UInt", 4, "Ptr") = state.owner) {
            dialog := hwnd
            break
        }
    }
    if !dialog
        return
    for phase in ["window-success", "window-cancel", "exe-success", "exe-cancel"] {
        if (handled.Has(phase) || !InStr(log, "request smoke." phase))
            continue
        handled[phase] := true
        if InStr(phase, "cancel") {
            PostMessage(0x10, 0, 0, , "ahk_id " dialog)
        } else if (phase = "window-success") {
            lv := GuiCtrlFromHwnd(ControlGetHwnd("SysListView321", "ahk_id " dialog))
            Loop lv.GetCount() {
                if (lv.GetText(A_Index, 1) = "Picker fixture") {
                    lv.Modify(0, "-Select")
                    lv.Modify(A_Index, "Select Focus")
                    ControlClick("Button1", "ahk_id " dialog)
                    break
                }
            }
        } else {
            ControlSetText(A_WinDir "\System32\notepad.exe", "Edit1", "ahk_id " dialog)
            ControlClick("Button1", "ahk_id " dialog)
        }
        return
    }
    if (!closed && InStr(log, "request smoke.close-picker")) {
        closed := true
        webBridge.NativeCloseRequested()
    }
}
