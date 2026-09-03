#Requires AutoHotkey v2.0
#SingleInstance Off
Persistent()
SetWinDelay(-1)
SetKeyDelay(15, 15)
SendLevel(1)
CoordMode("Mouse", "Screen")

; Гипотеза: когда выдвинутое окно закрывают, Windows отдаёт передний план
; следующему окну по Z-порядку. Если им оказывается ДРУГОЕ припаркованное
; окно слота, ящик честно считает это выбором пользователя и выдвигает
; его. Со стороны это выглядит как «окно выехало само».
;
; Здесь это не утверждается, а измеряется: шесть одинаковых попыток,
; после каждой записывается, кто стал передним планом и выехал ли сосед.
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
WaitOn(h, want, ms := 3500) {
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
    Sleep(150)
    return g
}
Park(g, n) {
    WinActivate("ahk_id " g.Hwnd)
    Sleep(220)
    Send("^!+" n)
    Sleep(320)
    Loop 4 {
        if !OnScreen(g.Hwnd) {
            Sleep(200)
            return true
        }
        Send("^!" n)
        if WaitOn(g.Hwnd, false, 1500) {
            Sleep(200)
            return true
        }
        Sleep(250)
    }
    return !OnScreen(g.Hwnd)
}
Name(h) {
    if !h
        return "нет"
    try
        return "«" WinGetTitle("ahk_id " h) "» [" WinGetProcessName("ahk_id " h) "]"
    return "hwnd " h
}
MouseMove(760, 540)

; ---------- А. закрытие выдвинутого окна ----------
Out("========== А. закрываем выдвинутое окно, сосед припаркован ==========")
popped := 0, tries := 12
Loop tries {
    i := A_Index
    a := MakeWin("GH-SLEEP-" i, 140, 140)      ; сосед, слот 5 (M1/left)
    n := MakeWin("GH-NEUTRAL-" i, 700, 600)    ; обычное окно, не слот
    if !Park(a, 5) {
        Out("  попытка " i ": сосед не припарковался, пропускаю")
        a.Destroy(), n.Destroy()
        continue
    }
    b := MakeWin("GH-LIVE-" i, 260, 260)       ; жертва, слот 6 (M1/top)
    Park(b, 6)
    Send("^!6")
    WaitOn(b.Hwnd, true, 3500)
    Sleep(400)
    before := WinExist("A")
    b.Destroy()                                ; закрываем выдвинутое
    Sleep(1600)
    after := WinExist("A")
    popped_now := OnScreen(a.Hwnd)
    if popped_now
        popped++
    Out("  попытка " i ": сосед " (popped_now ? "ВЫЕХАЛ САМ" : "остался припаркован")
        "   передний план: " Name(after) "   до закрытия: " Name(before))
    Send("^!0")
    Sleep(700)
    a.Destroy(), n.Destroy()
    Sleep(250)
}
Check("закрытие выдвинутого окна не выдвигает соседний слот",
      popped = 0, popped " из " tries " попыток сосед выехал сам")

; ---------- Б. сворачивание выдвинутого окна ----------
Out("========== Б. сворачиваем выдвинутое окно, сосед припаркован ==========")
popped2 := 0
Loop 4 {
    i := A_Index
    a := MakeWin("GM-SLEEP-" i, 140, 140)
    n := MakeWin("GM-NEUTRAL-" i, 700, 600)
    if !Park(a, 5) {
        a.Destroy(), n.Destroy()
        continue
    }
    b := MakeWin("GM-LIVE-" i, 260, 260)
    Park(b, 6)
    Send("^!6")
    WaitOn(b.Hwnd, true, 3500)
    Sleep(400)
    WinMinimize("ahk_id " b.Hwnd)
    Sleep(1600)
    popped_now := OnScreen(a.Hwnd)
    if popped_now
        popped2++
    Out("  попытка " i ": сосед " (popped_now ? "ВЫЕХАЛ САМ" : "остался припаркован")
        "   передний план: " Name(WinExist("A")))
    Send("^!0")
    Sleep(700)
    a.Destroy(), b.Destroy(), n.Destroy()
    Sleep(250)
}
Check("сворачивание выдвинутого окна не выдвигает соседний слот",
      popped2 = 0, popped2 " из 4 попыток сосед выехал сам")

Out("ИТОГ проверки самопроизвольного показа: проверок " checks ", провалов " fails)
Sleep(400)
ExitApp(0)
