#Requires AutoHotkey v2.0
#SingleInstance Off
Persistent()
SetWinDelay(-1)
SetKeyDelay(15, 15)
SendLevel(1)
CoordMode("Mouse", "Screen")
MouseMove(960, 500)

; Браузер как слот: берём обычное (не полноэкранное) окно Chrome.
; Полноэкранное окно YouTube сюда не годится — оно само возвращает свою
; геометрию и не двигается ни этой версией, ни версией до правок.
;
; Аргументы: <logfile>

dest := A_Args[1]
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
Track(h, ms) {
    seen := 0, last := ""
    t0 := A_TickCount
    while (A_TickCount - t0 < ms) {
        p := PosOf(h)
        cur := p.x "," p.y
        if (cur != last) {
            seen++
            last := cur
        }
        Sleep(3)
    }
    return seen
}

; окно во весь монитор с MinMax=0 — это полноэкранный режим, пропускаем
target := 0
for h in WinGetList("ahk_exe chrome.exe") {
    try {
        if !(WinGetStyle("ahk_id " h) & 0x10000000) || (WinGetTitle("ahk_id " h) = "")
            continue
        if (WinGetMinMax("ahk_id " h) = -1)
            continue
        WinGetPos(&x, &y, &w, &hh, "ahk_id " h)
        full := false
        Loop MonitorGetCount() {
            MonitorGet(A_Index, &l, &t, &r, &b)
            if (WinGetMinMax("ahk_id " h) = 0 && Abs(w - (r - l)) <= 4 && Abs(hh - (b - t)) <= 4)
                full := true
        }
        if full
            continue
        target := h
        break
    }
}
Out("========== браузер ==========")
if !target {
    Out("  подходящего окна Chrome нет — пункт не проверен")
    ExitApp(0)
}
Out("  окно: " SubStr(WinGetTitle("ahk_id " target), 1, 50)
  . "  MinMax=" WinGetMinMax("ahk_id " target) "  " PosOf(target).w "x" PosOf(target).h)
orig := PosOf(target)

WinActivate("ahk_id " target), Sleep(500)
Check("окно браузера активировано", WinActive("ahk_id " target))
Send("^!+6"), Sleep(700)

Loop 3 {
    if !OnScreen(target)
        break
    Send("^!6")
    WaitOn(target, false, 3000)
    Sleep(400)
}
Check("браузер припаркован", !OnScreen(target), "x=" PosOf(target).x)

Send("^!6")
moved := Track(target, 900)
ok := WaitOn(target, true, 3000)
Sleep(500)
p := PosOf(target)
Check("браузер: показ", ok, "x=" p.x " y=" p.y " " p.w "x" p.h)
Check("браузер: анимация показа", moved > 4, "разных позиций " moved)

Send("^!6")
moved2 := Track(target, 900)
Sleep(500)
Check("браузер: уборка с анимацией", moved2 > 4, "разных позиций " moved2)
Check("браузер: убрано за пределы экранов", !OnScreen(target), "x=" PosOf(target).x)

Send("^!+0")                       ; выход возвращает окно
Sleep(2000)
back := PosOf(target)
Check("после выхода браузер вернулся на экран", OnScreen(target),
      "было " orig.x "," orig.y "  стало " back.x "," back.y)

Out("ИТОГ браузера: проверок " checks ", провалов " fails)
Out("")
ExitApp(fails)
