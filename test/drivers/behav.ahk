#Requires AutoHotkey v2.0
#SingleInstance Off
Persistent()
SetWinDelay(-1)
SetKeyDelay(15, 15)
SendLevel(1)
CoordMode("Mouse", "Screen")
MouseMove(960, 500)          ; monitor=cursor -> основной

; Регрессия поведения: слоты, фокус, быстрые переключения, выход.
; Аргументы: <logfile>

dest := A_Args[1]
OnError(Boom)
Boom(e, m) {
    global dest
    FileAppend("ОШИБКА драйвера: " e.Message " @" e.Line "`n", dest, "UTF-8")
    ExitApp(1)
}
Out(s) {
    global dest
    FileAppend(s "`n", dest, "UTF-8")
}
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
    g.Add("Text", "cWhite w300 h200", title)
    g.Show("x" x " y" y " w340 h240")
    return g
}
Big(exe) {
    best := 0, area := -1
    for h in WinGetList("ahk_exe " exe) {
        try {
            if !(WinGetStyle("ahk_id " h) & 0x10000000) || (WinGetTitle("ahk_id " h) = "")
                continue
            WinGetPos(, , &w, &hh, "ahk_id " h)
            if (w * hh > area)
                area := w * hh, best := h
        }
    }
    return best
}

gA := MakeWin("REG-A", 80, 90),  A := gA.Hwnd
gB := MakeWin("REG-B", 80, 400), B := gB.Hwnd
gN := MakeWin("REG-NEUTRAL", 520, 90), N := gN.Hwnd
gQ := MakeWin("REG-QUIET", 520, 400), Q := gQ.Hwnd
Sleep(400)
origA := PosOf(A), origB := PosOf(B), origQ := PosOf(Q)

Out("========== поведение ==========")

; --- 1. привязка цепляет именно активное окно (одно приложение, много окон)
WinActivate("ahk_id " B), Sleep(200)
Send("^!+3"), Sleep(350)
Send("^!3")
okB := WaitOn(B, true, 3000)
Sleep(400)
; A и B — окна ОДНОГО процесса. Слот должен был взять активное (B) и
; не тронуть A: если бы поиск шёл по процессу, поехало бы любое из двух.
movedB := Abs(PosOf(B).x - origB.x) > 50
stillA := (Abs(PosOf(A).x - origA.x) <= 2 && Abs(PosOf(A).y - origA.y) <= 2)
Check("bind взял именно активное окно (два окна одного процесса)",
      okB && movedB && stillA,
      "B поехал=" (movedB ? "да" : "нет") ", A на месте=" (stillA ? "да" : "нет"))
WinActivate("ahk_id " N), Sleep(500), WaitOn(B, false, 3000)

; --- 2. hideOnBlur убирает окно при уходе фокуса
Send("^!3"), WaitOn(B, true, 3000), Sleep(300)
WinActivate("ahk_id " N)
Check("hideOnBlur убрал окно после ухода фокуса", WaitOn(B, false, 3000))

; --- 3. возврат фокуса после уборки
WinActivate("ahk_id " N), Sleep(300)
Send("^!3"), WaitOn(B, true, 3000), Sleep(300)
Send("^!3"), WaitOn(B, false, 3000), Sleep(400)
Check("после уборки фокус не остался на припаркованном окне",
      !WinActive("ahk_id " B), "активно: " WinGetTitle("A"))

; --- 4. activateOnShow=false (слот 9): окно показано, фокус не украден
WinActivate("ahk_id " Q), Sleep(200)
Send("^!+9"), Sleep(350)
WinActivate("ahk_id " N), Sleep(300)
Send("^!9")
shownQ := WaitOn(Q, true, 3000)
Sleep(400)
Check("activateOnShow=false: окно выдвинулось", shownQ)
Check("activateOnShow=false: фокус остался у пользователя",
      WinActive("ahk_id " N), "активно: " WinGetTitle("A"))
Send("^!9"), Sleep(700)

; --- 5. постоянный слот (Paint, слот 1)
paint := Big("mspaint.exe")
if !paint
    Out("  Paint не запущен — постоянный слот пропущен")
else {
    origP := PosOf(paint)
    Send("^!1")
    Check("постоянный слот: показ", WaitOn(paint, true, 3500))
    Sleep(400)
    Send("^!1")
    Check("постоянный слот: уборка", WaitOn(paint, false, 3500))
    Sleep(300)
}

; --- 6. быстрые повторные хоткеи не оставляют окно припаркованным
WinActivate("ahk_id " N), Sleep(400), WaitOn(B, false, 2500)
Loop 12 {
    Send("^!3")
    Sleep(40)
}
Sleep(3500)                                  ; дать очереди анимаций стечь
Send("^!3"), Sleep(200)
st := OnScreen(B)
if !st {
    Send("^!3"), Sleep(1200)
}
Check("слот управляем после 12 быстрых нажатий", WaitOn(B, true, 3000))
Sleep(300)

; --- 7. хоткей ровно во время анимации уборки (гонка WatchBlur)
raceFail := 0
Loop 5 {
    if !OnScreen(B) {
        Send("^!3"), WaitOn(B, true, 2500)
    }
    Sleep(300)
    dx := PosOf(B).x
    WinActivate("ahk_id " N)                 ; провоцируем hideOnBlur
    hit := false, t0 := A_TickCount
    while (A_TickCount - t0 < 1500) {
        if (Abs(PosOf(B).x - dx) > 15) {
            Send("^!3")
            hit := true
            break
        }
        Sleep(4)
    }
    Sleep(900)
    if (hit && !(OnScreen(B) && Abs(PosOf(B).x - dx) <= 6))
        raceFail++
}
Check("показ во время анимации уборки не отменяется", raceFail = 0, raceFail " провалов из 5")

; --- 8. Alt+Tab возвращает припаркованное окно
WinActivate("ahk_id " N), Sleep(500), WaitOn(B, false, 3000)
Check("окно припарковано перед Alt+Tab", !OnScreen(B))
WinActivate("ahk_id " N), Sleep(400)
Send("{Alt down}{Tab}{Alt up}")
Sleep(2000)
Check("Alt+Tab выдвинул припаркованный слот", OnScreen(B), "x=" PosOf(B).x)

; --- 9. Ctrl+Alt+0 отпускает динамические слоты и возвращает окна
Send("^!0")
Sleep(1200)
Check("Ctrl+Alt+0: окно вернулось на исходное место",
      Abs(PosOf(B).x - origB.x) <= 4 && Abs(PosOf(B).y - origB.y) <= 4,
      "стало " PosOf(B).x "," PosOf(B).y "  было " origB.x "," origB.y)
; слот отпущен — хоткей больше не должен ничего двигать
beforeB := PosOf(B)
Send("^!3"), Sleep(1200)
afterB := PosOf(B)
Check("после Ctrl+Alt+0 хоткей слота ничего не двигает",
      Abs(afterB.x - beforeB.x) <= 2 && Abs(afterB.y - beforeB.y) <= 2,
      "было " beforeB.x "," beforeB.y "  стало " afterB.x "," afterB.y)

; --- 10. выход возвращает все окна
WinActivate("ahk_id " A), Sleep(200), Send("^!+4"), Sleep(300)
Send("^!4"), WaitOn(A, true, 3000), Sleep(400)
Send("^!+0")                                  ; штатный выход
Sleep(1800)
Check("выход: окно A вернулось на исходное место",
      Abs(PosOf(A).x - origA.x) <= 4 && Abs(PosOf(A).y - origA.y) <= 4,
      "стало " PosOf(A).x "," PosOf(A).y "  было " origA.x "," origA.y)
Check("выход: ни одно тестовое окно не осталось за экраном",
      OnScreen(A) && OnScreen(B) && OnScreen(Q))

Out("ИТОГ поведения: проверок " checks ", провалов " fails)
Out("")
ExitApp(fails)
