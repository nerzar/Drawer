#Requires AutoHotkey v2.0
#SingleInstance Off
Persistent()
SetWinDelay(-1)
SetKeyDelay(15, 15)
SendLevel(1)
CoordMode("Mouse", "Screen")

; handles=false: кромок нет вовсе, а всё остальное работает как раньше.
; Проверяется именно отсутствие окон кромок, а не только их невидимость.
; Аргументы: <logfile> <pid ящика>

dest := A_Args[1]
pid  := Integer(A_Args[2])

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
Count() {
    global pid
    n := 0
    for h in WinGetList("ahk_class AutoHotkeyGUI ahk_pid " pid) {
        try {
            if (WinGetStyle("ahk_id " h) & 0x10000000)
                n++
        }
    }
    return n
}
; Ни одной кромки за ms миллисекунд — а не «нет прямо сейчас».
NoneFor(ms) {
    worst := 0, t0 := A_TickCount
    while (A_TickCount - t0 < ms) {
        worst := Max(worst, Count())
        Sleep(25)
    }
    return worst
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

Out("========== handles=false ==========")
MouseMove(760, 540)
Check("сразу после запуска кромок нет", NoneFor(1200) = 0)

gA := MakeWin("OFF-A", 120, 120)
WinActivate("ahk_id " gA.Hwnd)
Sleep(300)
Send("^!+2")                       ; привязать слот 2 (монитор 1, правый край)
Sleep(400)
Send("^!2")                        ; выдвинуть
Check("слот выдвигается как обычно", WaitOn(gA.Hwnd, true, 3000),
      "x=" PosOf(gA.Hwnd).x)
Sleep(300)
Send("^!2")                        ; убрать — вот тут кромка и появилась бы
Check("слот убирается как обычно", WaitOn(gA.Hwnd, false, 3000),
      "x=" PosOf(gA.Hwnd).x)
Check("после парковки кромка не появилась", NoneFor(2000) = 0)

MonitorGetWorkArea(1, &L1, &T1, &R1, &B1)
MouseMove(R1 - 40, (T1 + B1) // 2)     ; курсор туда, где кромка была бы
Check("курсор у края ничего не вызывает", NoneFor(2000) = 0)
MouseMove(R1 - 2, (T1 + B1) // 2)
Check("курсор вплотную к краю ничего не вызывает", NoneFor(1500) = 0)
MouseMove(760, 540)

Send("^!2")                        ; и обратно работает
Check("слот снова выдвигается", WaitOn(gA.Hwnd, true, 3000), "x=" PosOf(gA.Hwnd).x)
Sleep(300)
Send("^!2")
WaitOn(gA.Hwnd, false, 3000)
Sleep(300)

gB := MakeWin("OFF-B", 200, 200)
WinActivate("ahk_id " gB.Hwnd)
Sleep(300)
Send("^!+5")                       ; второй слот, другой край
Sleep(400)
Send("^!5"), WaitOn(gB.Hwnd, true, 3000), Sleep(300)
Send("^!5"), WaitOn(gB.Hwnd, false, 3000), Sleep(400)
Check("два припаркованных слота — всё равно ни одной кромки", NoneFor(2000) = 0)

Send("^!0")                        ; очистка
Sleep(700)
Check("оба окна вернулись на свои места",
      OnScreen(gA.Hwnd) && OnScreen(gB.Hwnd)
      && Abs(PosOf(gA.Hwnd).x - 120) <= 8 && Abs(PosOf(gB.Hwnd).x - 200) <= 8,
      "A x=" PosOf(gA.Hwnd).x " B x=" PosOf(gB.Hwnd).x)
Check("после очистки кромок по-прежнему нет", NoneFor(1200) = 0)

gA.Destroy(), gB.Destroy()
Out("ИТОГ handles=false: проверок " checks ", провалов " fails)
Sleep(400)
ExitApp(0)
