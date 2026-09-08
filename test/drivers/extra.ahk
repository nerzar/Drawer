#Requires AutoHotkey v2.0
#SingleInstance Off
Persistent()
SetWinDelay(-1)
SetKeyDelay(15, 15)
SendLevel(1)
CoordMode("Mouse", "Screen")

; Три места, где кромка встречается с уже существующей механикой ящика:
; автоуборка по потере фокуса, перепривязка слота и выход.
; Аргументы: <logfile> <pid ящика>

dest := A_Args[1]
pid  := Integer(A_Args[2])
#Include DrawerControl.ahk

Out(s) {
    global dest
    FileAppend(s "`n", dest, "UTF-8")
}
OnError((e, m) => (Out("ОШИБКА: " e.Message " @" e.Line), ExitApp(1)))
fails := 0, checks := 0
Check(name, ok, extra := "") {
    global fails, checks
    checks++
    if !ok
        fails++
    Out("  " (ok ? "ok  " : "БАГ ") name (extra != "" ? "   [" extra "]" : ""))
}
Kromki() {
    global pid
    out := []
    for h in WinGetList("ahk_class AutoHotkeyGUI ahk_pid " pid) {
        try {
            if !(WinGetStyle("ahk_id " h) & 0x10000000)
                continue
            WinGetPos(&x, &y, &w, &hh, "ahk_id " h)
            out.Push({ hwnd: h, x: x, y: y, w: w, h: hh,
                       num: ControlGetText("Static1", "ahk_id " h) })
        }
    }
    return out
}
Count() {
    return Kromki().Length
}
WaitCount(n, ms := 3000) {
    t0 := A_TickCount
    while (A_TickCount - t0 < ms) {
        if (Count() = n)
            return true
        Sleep(20)
    }
    return false
}
Nums() {
    s := ""
    for k in Kromki()
        s .= (s = "" ? "" : ",") k.num
    return s = "" ? "-" : s
}
PosOf(h) {
    try {
        WinGetPos(&x, &y, &w, &hh, "ahk_id " h)
        return { x: x, y: y, w: w, h: hh }
    }
    return { x: -999999, y: 0, w: 0, h: 0 }
}
OnScreen(h) {
    p := PosOf(h)
    Loop MonitorGetCount() {
        MonitorGet(A_Index, &l, &t, &r, &b)
        if (p.x < r && p.x + p.w > l && p.y < b && p.y + p.h > t)
            return true
    }
    return false
}
WaitOn(h, want, ms := 3000) {
    t0 := A_TickCount
    while (A_TickCount - t0 < ms) {
        if (OnScreen(h) = want)
            return true
        Sleep(10)
    }
    return false
}
MakeWin(title, x, y) {
    g := Gui("-MinimizeBox", title)
    g.BackColor := "203040"
    g.Add("Text", "cWhite w280 h180", title)
    g.Show("x" x " y" y " w320 h220")
    Sleep(200)
    return g
}
MouseMove(760, 540)

; ---------- G1. hideOnBlur паркует окно — кромка появляется ----------
Out("========== G. Стыки с механикой ящика ==========")
gA := MakeWin("EX-A", 120, 120)
gN := MakeWin("EX-NEUTRAL", 600, 600)
WinActivate("ahk_id " gA.Hwnd)
Sleep(300)
Send("^!+2")                       ; слот 2: hideOnBlur=true
Sleep(350)
Send("^!2")                        ; выдвинуть
WaitOn(gA.Hwnd, true, 3000)
Sleep(300)
Check("G1. окно выдвинуто, кромок нет", OnScreen(gA.Hwnd) && WaitCount(0),
      Count() " шт.")
WinActivate("ahk_id " gN.Hwnd)     ; уводим фокус — сработает hideOnBlur
Check("G1b. hideOnBlur убрал окно", WaitOn(gA.Hwnd, false, 4000),
      "x=" PosOf(gA.Hwnd).x)
Check("G1c. после автоуборки кромка появилась", WaitCount(1), Nums())

; ---------- G2. перепривязка слота ----------
gB := MakeWin("EX-B", 200, 200)
WinActivate("ahk_id " gB.Hwnd)
Sleep(300)
origA := PosOf(gA.Hwnd)
Send("^!+2")                       ; тот же слот 2 -> другое окно
Sleep(600)
Check("G2. прежнее окно вернулось на своё место",
      OnScreen(gA.Hwnd) && Abs(PosOf(gA.Hwnd).x - 120) <= 8,
      "x=" PosOf(gA.Hwnd).x " (было припарковано на " origA.x ")")
Check("G2b. кромки прежнего окна больше нет", WaitCount(0), Nums())

; ---------- G3. выход при живых кромках ----------
WinActivate("ahk_id " gB.Hwnd)
Sleep(250)
Send("^!2")                        ; выдвинуть B
WaitOn(gB.Hwnd, true, 3000)
Sleep(300)
WinActivate("ahk_id " gN.Hwnd)     ; hideOnBlur припаркует
WaitOn(gB.Hwnd, false, 4000)
Sleep(400)

gC := MakeWin("EX-C", 300, 300)
WinActivate("ahk_id " gC.Hwnd)
Sleep(300)
Send("^!+5")                       ; слот 5, hideOnBlur=false
Sleep(350)
Send("^!5")
WaitOn(gC.Hwnd, true, 3000)
Sleep(300)
Send("^!5")
WaitOn(gC.Hwnd, false, 3000)
Sleep(500)
Check("G3. перед выходом живы две кромки", WaitCount(2), Nums())
Check("G3b. оба окна припаркованы", !OnScreen(gB.Hwnd) && !OnScreen(gC.Hwnd),
      "B x=" PosOf(gB.Hwnd).x " C x=" PosOf(gC.Hwnd).x)

DrawerExit(pid)                    ; выход ящика через OnExit(Cleanup)
Sleep(2000)
Check("G4. окно B вернулось на исходное место",
      OnScreen(gB.Hwnd) && Abs(PosOf(gB.Hwnd).x - 200) <= 8, "x=" PosOf(gB.Hwnd).x)
Check("G4b. окно C вернулось на исходное место",
      OnScreen(gC.Hwnd) && Abs(PosOf(gC.Hwnd).x - 300) <= 8, "x=" PosOf(gC.Hwnd).x)
Check("G4c. после выхода не осталось ни одной кромки", Count() = 0, Nums())
Check("G4d. процесс ящика завершился", !ProcessExist(pid), "pid " pid)

Out("ИТОГ стыков: проверок " checks ", провалов " fails)
Sleep(400)
gA.Destroy(), gB.Destroy(), gC.Destroy(), gN.Destroy()
ExitApp(0)
