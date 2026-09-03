#Requires AutoHotkey v2.0
#SingleInstance Off
Persistent()
SetWinDelay(-1)
SetKeyDelay(15, 15)
SendLevel(1)
CoordMode("Mouse", "Screen")

; Все девять слотов, точность привязки к конкретному окну и переход
; между припаркованными окнами мышью. Стенд: девять динамических слотов
; на одном крае, hideOnBlur=false — чтобы окна не убирались сами и было
; видно, кто именно поехал.
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

; ---------- кромки ----------
; Номер слота лежит в контроле, где текст — одна цифра. Проверять на
; «непустой текст» нельзя: у Picture-контрола текстом оказывается строка
; "HICON:...", которую ему передали при создании.
NumCtl(h) {
    for cn in WinGetControls("ahk_id " h) {
        try {
            if (ControlGetText(cn, "ahk_id " h) ~= "^[1-9]$")
                return cn
        }
    }
    return ""
}
Kromki() {
    global pid
    out := []
    for h in WinGetList("ahk_class AutoHotkeyGUI ahk_pid " pid) {
        try {
            if !(WinGetStyle("ahk_id " h) & 0x10000000)
                continue
            WinGetPos(&x, &y, &w, &hh, "ahk_id " h)
            cn := NumCtl(h)
            out.Push({ hwnd: h, x: x, y: y, w: w, h: hh,
                       num: cn = "" ? "" : ControlGetText(cn, "ahk_id " h),
                       icon: WinGetControls("ahk_id " h).Length >= 2 ? 1 : 0 })
        }
    }
    return out
}
ById(num) {
    for k in Kromki() {
        if (k.num = String(num))
            return k
    }
    return 0
}
Count() => Kromki().Length
; Внутренний for перекрывает A_Index внешнего Loop — поэтому просто
; спрашиваем ById по каждому номеру, без второго цикла.
Nums() {
    s := ""
    Loop 9 {
        if ById(A_Index)
            s .= (s = "" ? "" : ",") A_Index
    }
    return s = "" ? "-" : s
}
WaitCount(n, ms := 3000) {
    t0 := A_TickCount
    while (A_TickCount - t0 < ms) {
        if (Count() = n)
            return true
        Sleep(25)
    }
    return false
}
WaitStable(num, ms := 2500) {
    Sleep(400)
    last := "", same := 0, t0 := A_TickCount
    while (A_TickCount - t0 < ms) {
        k := ById(num)
        cur := k ? (k.x "," k.y "," k.w "," k.h) : "-"
        same := (cur = last) ? same + 1 : 0
        last := cur
        if (same >= 4)
            return k
        Sleep(30)
    }
    return ById(num)
}

; ---------- окна ----------
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
    Sleep(120)
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
Away() {
    MouseMove(760, 540)
    Sleep(100)
}
; Щёлкнуть по кромке слота n. Возвращает false, если кромки нет.
ClickHandle(n) {
    if !(k := ById(n))
        return false
    MouseMove(k.x + k.w // 2, k.y + k.h // 2)
    k := WaitStable(n)
    if !k
        return false
    MouseMove(k.x + k.w // 2, k.y + k.h // 2)
    Sleep(120)
    Click()
    return true
}

; ================= 1. все девять слотов =================
Out("========== 1. все девять слотов ==========")
Away()
wins := Map()
allParked := true
Loop 9 {
    n := A_Index
    g := MakeWin("S9-" n, 60 + n * 24, 60 + n * 18)
    wins[n] := g
    if !Park(g, n)
        allParked := false
}
Check("все девять слотов привязаны и припаркованы", allParked)
Check("девять кромок", WaitCount(9), Count() " шт.: " Nums())
Check("номера кромок 1..9", Nums() = "1,2,3,4,5,6,7,8,9", Nums())

; кромки в стопке не пересекаются и идут по возрастанию номера
prev := 0, order := true, apart := true
Loop 9 {
    k := ById(A_Index)
    if !k {
        order := false
        continue
    }
    if (prev && k.y <= prev.y)
        order := false
    if (prev && k.y < prev.y + prev.h)
        apart := false
    prev := k
}
Check("кромки идут сверху вниз по номеру слота", order)
Check("кромки не перекрывают друг друга", apart)

; каждый хоткей двигает СВОЁ окно и только его
badSlot := 0, badOther := 0
Loop 9 {
    n := A_Index
    Send("^!" n)
    if !WaitOn(wins[n].Hwnd, true, 3500)
        badSlot := n
    Sleep(150)
    ; никто больше не выехал
    Loop 9 {
        if (A_Index != n && OnScreen(wins[A_Index].Hwnd))
            badOther := A_Index
    }
    Send("^!" n)
    WaitOn(wins[n].Hwnd, false, 3500)
    Sleep(150)
}
Check("хоткей каждого из девяти слотов выдвигает своё окно", badSlot = 0,
      badSlot ? "не сработал слот " badSlot : "1..9")
Check("при этом не выезжает ни одно чужое окно", badOther = 0,
      badOther ? "лишним выехал слот " badOther : "")
Check("после прохода снова девять кромок", WaitCount(9), Nums())

; ================= 2. щелчок по кромке =================
Out("========== 2. щелчок по кромке — тот же слот ==========")
badClick := 0, noHandle := 0
for n in [1, 5, 9, 3] {
    Away()
    if !ClickHandle(n) {
        noHandle := n
        continue
    }
    if !WaitOn(wins[n].Hwnd, true, 3500)
        badClick := n
    Sleep(200)
    Check("  слот " n ": кромка исчезла, соседние остались",
          !ById(n) && Count() = 8, Count() " шт.: " Nums())
    Away()
    Send("^!" n)
    WaitOn(wins[n].Hwnd, false, 3500)
    Sleep(250)
}
Check("щелчок по кромке выдвигает именно свой слот", badClick = 0 && noHandle = 0,
      badClick ? "промах на слоте " badClick : (noHandle ? "нет кромки у слота " noHandle : "1,5,9,3"))

Send("^!0")
Sleep(800)
for n, g in wins
    g.Destroy()
Sleep(300)

; ================= 3. точная привязка окна =================
Out("========== 3. привязка к конкретному окну ==========")
Away()
; Три окна одного процесса и с почти одинаковыми заголовками: если бы
; ящик искал окно по приложению или по заголовку, он бы промахнулся.
a := MakeWin("SAME-APP", 100, 100)
b := MakeWin("SAME-APP", 150, 150)
c := MakeWin("SAME-APP", 200, 200)
Sleep(200)
Check("три окна одного процесса созданы",
      WinGetPID("ahk_id " a.Hwnd) = WinGetPID("ahk_id " b.Hwnd)
      && WinGetPID("ahk_id " b.Hwnd) = WinGetPID("ahk_id " c.Hwnd),
      "pid " WinGetPID("ahk_id " a.Hwnd))

WinActivate("ahk_id " b.Hwnd)          ; привязываем СРЕДНЕЕ
Sleep(300)
Send("^!+4")
Sleep(400)
Send("^!4")
Check("выехало именно привязанное окно", WaitOn(b.Hwnd, true, 3500)
      && PosOf(b.Hwnd).x >= 900, "b x=" PosOf(b.Hwnd).x)
Check("два других окна не сдвинулись",
      Abs(PosOf(a.Hwnd).x - 100) <= 8 && Abs(PosOf(c.Hwnd).x - 200) <= 8,
      "a x=" PosOf(a.Hwnd).x " c x=" PosOf(c.Hwnd).x)
Send("^!4")
WaitOn(b.Hwnd, false, 3500)
Sleep(300)
Check("припарковано именно оно", !OnScreen(b.Hwnd) && OnScreen(a.Hwnd) && OnScreen(c.Hwnd),
      "b x=" PosOf(b.Hwnd).x)
k := ById(4)
Check("кромка у него одна", Count() = 1 && k, Count() " шт.")

; перепривязка на другое окно того же процесса
WinActivate("ahk_id " c.Hwnd)
Sleep(300)
Send("^!+4")
Sleep(700)
Check("перепривязка вернула прежнее окно на место",
      OnScreen(b.Hwnd) && Abs(PosOf(b.Hwnd).x - 150) <= 8, "b x=" PosOf(b.Hwnd).x)
Send("^!4")
Check("теперь ездит новое окно", WaitOn(c.Hwnd, true, 3500) && PosOf(c.Hwnd).x >= 900,
      "c x=" PosOf(c.Hwnd).x)
Send("^!4")
WaitOn(c.Hwnd, false, 3500)
Sleep(400)
Check("кромка по-прежнему одна и это слот 4", Count() = 1 && ById(4), Nums())

Send("^!0")
Sleep(700)
a.Destroy(), b.Destroy(), c.Destroy()
Sleep(300)

Out("ИТОГ слотов: проверок " checks ", провалов " fails)
Sleep(400)
ExitApp(0)
