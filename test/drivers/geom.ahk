#Requires AutoHotkey v2.0
#SingleInstance Off
Persistent()
SetWinDelay(-1)
SetKeyDelay(15, 15)
SendLevel(1)
CoordMode("Mouse", "Screen")

; Регрессия по геометрии: каждый слот настроен на свой монитор и край.
; Для каждого проверяем, что выдвинутая позиция совпадает с расчётной,
; анимация играет и в обе стороны, а убранное окно уходит со всех экранов.
;
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
; Считаем разные позиции по ОБЕИМ осям: для краёв top/bottom окно едет
; по Y, и трекер только по X показал бы «анимации нет» там, где она есть.
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
; Ожидаемая выдвинутая позиция — та же формула, что в ComputeGeom.
Expect(mi, edge, pct) {
    MonitorGetWorkArea(mi, &L, &T, &R, &B)
    switch edge {
    case "right":
        w := Integer((R - L) * pct / 100), h := B - T
        return { x: R - w, y: T, w: w, h: h }
    case "left":
        w := Integer((R - L) * pct / 100), h := B - T
        return { x: L, y: T, w: w, h: h }
    case "bottom":
        w := R - L, h := Integer((B - T) * pct / 100)
        return { x: L, y: B - h, w: w, h: h }
    case "top":
        w := R - L, h := Integer((B - T) * pct / 100)
        return { x: L, y: T, w: w, h: h }
    }
}

MakeWin(title, x, y) {
    g := Gui("-MinimizeBox", title)
    g.BackColor := "203040"
    g.Add("Text", "cWhite w300 h200", title)
    g.Show("x" x " y" y " w340 h240")
    return g
}

; слот -> монитор, край (совпадает с config.ini стенда)
; inner — край смотрит на соседний монитор: карман лежит на его
; территории, поэтому анимации там нет и быть не может.
cases := [ {slot: 3, mon: 1, edge: "right",  inner: false},
           {slot: 4, mon: 1, edge: "left",   inner: true },
           {slot: 5, mon: 1, edge: "top",    inner: false},
           {slot: 6, mon: 1, edge: "bottom", inner: false},
           {slot: 7, mon: 2, edge: "right",  inner: true },
           {slot: 8, mon: 2, edge: "left",   inner: false} ]

Out("========== геометрия: монитор x край ==========")
wins := Map()
for c in cases {
    g := MakeWin("REG-" c.slot, 60 + (c.slot - 3) * 40, 60 + (c.slot - 3) * 30)
    wins[c.slot] := g.Hwnd
    Sleep(120)
    WinActivate("ahk_id " g.Hwnd)
    Sleep(150)
    Send("^!+" c.slot)
    Sleep(300)
}
Out("  привязано окон: " wins.Count)

for c in cases {
    h := wins[c.slot]
    want := Expect(c.mon, c.edge, 50)

    Send("^!" c.slot)
    moved := Track(h, 700)
    Sleep(350)
    p := PosOf(h)
    okPos := (Abs(p.x - want.x) <= 4 && Abs(p.y - want.y) <= 4
           && Abs(p.w - want.w) <= 4 && Abs(p.h - want.h) <= 4)
    Check("слот " c.slot " (монитор " c.mon ", " c.edge "): позиция",
          okPos, "получено " p.x "," p.y " " p.w "x" p.h "  ждали " want.x "," want.y " " want.w "x" want.h)
    Send("^!" c.slot)
    moved2 := Track(h, 700)
    Sleep(350)
    if c.inner {
        Check("слот " c.slot ": внутренний край — перенос без анимации",
              moved <= 3 && moved2 <= 3, "показ " moved ", уборка " moved2)
    } else {
        Check("слот " c.slot ": анимация в обе стороны",
              moved > 4 && moved2 > 4, "показ " moved ", уборка " moved2)
    }
    Check("слот " c.slot ": убрано за пределы экранов", !OnScreen(h))
    Sleep(150)
}

Out("ИТОГ геометрии: проверок " checks ", провалов " fails)
Out("")
Send("^!0")
Sleep(400)
ExitApp(fails)
