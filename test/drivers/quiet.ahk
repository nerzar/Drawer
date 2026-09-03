#Requires AutoHotkey v2.0
#SingleInstance Off
Persistent()
SetWinDelay(-1)
SetKeyDelay(15, 15)
SendLevel(1)
CoordMode("Mouse", "Screen")
MouseMove(960, 500)

; Проверка тишины. Ящик запущен в инструментированной сборке: его Notify()
; пишет в notify.log ровно то, что показал бы пользователю. Прогоняем
; обычную работу и смотрим, что в логе.
;
; Аргументы: <logfile> <notify.log ящика>

dest := A_Args[1]
nlog := A_Args[2]
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
Lines() {
    global nlog
    if !FileExist(nlog)
        return []
    res := []
    for l in StrSplit(FileRead(nlog, "UTF-8"), "`n") {
        if (Trim(l) != "")
            res.Push(Trim(l))
    }
    return res
}
Mark() {
    return Lines().Length
}
Since(n) {
    res := [], all := Lines()
    i := n + 1
    while (i <= all.Length) {
        res.Push(all[i])
        i++
    }
    return res
}
MakeWin(title, x, y) {
    g := Gui("-MinimizeBox", title)
    g.BackColor := "203040"
    g.Add("Text", "cWhite w300 h200", title)
    g.Show("x" x " y" y " w340 h240")
    return g
}
OnScreen(h) {
    try {
        WinGetPos(&x, &y, &w, &hh, "ahk_id " h)
        Loop MonitorGetCount() {
            MonitorGet(A_Index, &l, &t, &r, &b)
            if (x < r && x + w > l && y < b && y + hh > t)
                return true
        }
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

gA := MakeWin("QUIET-A", 80, 90),  A := gA.Hwnd
gB := MakeWin("QUIET-B", 80, 400), B := gB.Hwnd
gN := MakeWin("QUIET-N", 520, 90), N := gN.Hwnd
Sleep(400)

Out("========== тишина уведомлений ==========")
start := Lines()
Out("  при запуске ящик сказал: " (start.Length ? start.Length " строк(и)" : "ничего"))
for l in start
    Out("      " l)
Check("при запуске ровно одно уведомление", start.Length = 1)
Check("в нём есть версия", start.Length && InStr(start[1], "0.1."), start.Length ? start[1] : "")

; --- 1. привязка: одно короткое уведомление ---
m := Mark()
WinActivate("ahk_id " B), Sleep(250)
Send("^!+3"), Sleep(700)
got := Since(m)
Check("успешный bind -> ровно одно уведомление", got.Length = 1, got.Length ? got[1] : "ничего")

; --- 2. повторные одинаковые привязки не копятся ---
m := Mark()
Loop 8 {
    Send("^!+3")
    Sleep(60)
}
Sleep(800)
got := Since(m)
Check("8 быстрых одинаковых bind -> не больше одного", got.Length <= 1, got.Length " шт.")

; --- 3. разные привязки уведомляют каждая ---
m := Mark()
WinActivate("ahk_id " A), Sleep(250), Send("^!+4"), Sleep(700)
WinActivate("ahk_id " N), Sleep(250), Send("^!+5"), Sleep(700)
got := Since(m)
Check("две разные привязки -> два уведомления", got.Length = 2, got.Length " шт.")
for l in got
    Out("      " l)

; --- 4. обычная работа молчит ---
m := Mark()
Send("^!3"), WaitOn(B, true, 3000), Sleep(400)      ; показ
Send("^!3"), WaitOn(B, false, 3000), Sleep(400)     ; уборка
Send("^!4"), Sleep(900)                              ; показ другого
WinActivate("ahk_id " N), Sleep(900)                 ; hideOnBlur
Send("^!7"), Sleep(700)                              ; пустой слот
Send("^!7"), Sleep(700)                              ; он же ещё раз
Send("^!8"), Sleep(700)                              ; другой пустой слот
Loop 8 {
    Send("^!3")
    Sleep(60)
}
Sleep(3000)
WinActivate("ahk_id " A), Sleep(200)
WinActivate("ahk_id " N), Sleep(200)
WinActivate("ahk_id " B), Sleep(200)
Send("^!0"), Sleep(900)                              ; очистка динамических
got := Since(m)
Check("обычная работа полностью молчит", got.Length = 0, got.Length " уведомлений")
for l in got
    Out("      лишнее: " l)

; --- 5. выход молчит ---
m := Mark()
Send("^!+0"), Sleep(1800)
got := Since(m)
Check("выход молчит", got.Length = 0, got.Length " уведомлений")

Out("ИТОГ тишины: проверок " checks ", провалов " fails)
Out("")
ExitApp(fails)
