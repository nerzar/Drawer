#Requires AutoHotkey v2.0
#SingleInstance Off
Persistent()
SetWinDelay(-1)
SetKeyDelay(10, 10)
SendLevel(1)
CoordMode("Mouse", "Screen")

; Нагрузка и оболочка: девять припаркованных окон, быстрые хоткеи,
; быстрое переключение между слотами, длительная работа, попадание
; кромки в Alt+Tab. Стенд nine: девять динамических слотов на одном
; крае, hideOnBlur=false.
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
                       num: cn = "" ? "" : ControlGetText(cn, "ahk_id " h) })
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
Nums() {
    s := ""
    Loop 9 {
        if ById(A_Index)
            s .= (s = "" ? "" : ",") A_Index
    }
    return s = "" ? "-" : s
}
WaitCount(n, ms := 4000) {
    t0 := A_TickCount
    while (A_TickCount - t0 < ms) {
        if (Count() = n)
            return true
        Sleep(25)
    }
    return false
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
    Sleep(110)
    return g
}
Park(g, n) {
    WinActivate("ahk_id " g.Hwnd)
    Sleep(200)
    Send("^!+" n)
    Sleep(300)
    Loop 4 {
        if !OnScreen(g.Hwnd) {
            Sleep(180)
            return true
        }
        Send("^!" n)
        if WaitOn(g.Hwnd, false, 1500) {
            Sleep(180)
            return true
        }
        Sleep(220)
    }
    return !OnScreen(g.Hwnd)
}
Away() {
    MouseMove(760, 540)
    Sleep(100)
}
; Ящик выполняет хоткеи по очереди: анимация идёт под Critical, и нажатие,
; пришедшее посреди неё, ждёт своей очереди. После шквала нажатий окно
; продолжает ездить ещё какое-то время. Ждём, пока оно встанет, и
; возвращаем, сколько это заняло, — это измерение, а не утверждение.
Settle(h, quietMs := 1500, capMs := 30000) {
    t0 := A_TickCount, last := "", quiet := A_TickCount
    while (A_TickCount - t0 < capMs) {
        p := PosOf(h)
        cur := p.x "," p.y
        if (cur != last) {
            last := cur
            quiet := A_TickCount
        } else if (A_TickCount - quiet >= quietMs)
            return A_TickCount - t0
        Sleep(50)
    }
    return -1
}
; Привести слот в припаркованное состояние, дожидаясь очереди.
ParkNow(h, n) {
    Loop 4 {
        Settle(h, 600, 12000)
        if !OnScreen(h)
            return true
        Send("^!" n)
        Sleep(200)
    }
    Settle(h, 600, 12000)
    return !OnScreen(h)
}
; Годится ли окно для Alt+Tab по правилам самой Windows. Кромка не
; должна проходить эту проверку ни при каком стечении обстоятельств.
IsAltTab(hwnd) {
    if !DllCall("IsWindowVisible", "Ptr", hwnd)
        return false
    root := DllCall("GetAncestor", "Ptr", hwnd, "UInt", 3, "Ptr")   ; GA_ROOTOWNER
    if (root != hwnd)
        return false
    try {
        if (WinGetTitle("ahk_id " hwnd) = "")
            return false
        if (WinGetExStyle("ahk_id " hwnd) & 0x00000080)             ; WS_EX_TOOLWINDOW
            return false
    }
    return true
}

; ================= 1. девять припаркованных окон =================
Out("========== 1. девять припаркованных окон ==========")
Away()
wins := Map()
allParked := true
Loop 9 {
    n := A_Index
    g := MakeWin("LOAD-" n, 40 + n * 26, 40 + n * 20)
    wins[n] := g
    if !Park(g, n)
        allParked := false
}
Check("все девять припаркованы", allParked)
Check("девять кромок", WaitCount(9), Count() " шт.: " Nums())
stranded := 0
Loop 9 {
    if OnScreen(wins[A_Index].Hwnd)
        stranded++
}
Check("ни одно из девяти окон не осталось на экране", stranded = 0, stranded " на экране")

; ================= 2. кромка и Alt+Tab =================
Out("========== 2. кромка и переключение окон ==========")
inTab := ""
for k in Kromki() {
    if IsAltTab(k.hwnd)
        inTab .= (inTab = "" ? "" : ",") k.num
}
Check("ни одна кромка не годится для Alt+Tab по правилам Windows",
      inTab = "", inTab = "" ? "проверено кромок: " Count() : "в списке: " inTab)

pinned := MakeWin("LOAD-NEUTRAL", 500, 500)
WinActivate("ahk_id " pinned.Hwnd)
Sleep(300)
hitHandle := 0, hitDrawer := 0
Loop 10 {
    Send("!{Tab}")
    Sleep(260)
    f := WinExist("A")
    for k in Kromki() {
        if (f = k.hwnd)
            hitHandle++
    }
    try {
        if (f && WinGetPID("ahk_id " f) = pid)
            hitDrawer++
    }
}
Check("10 x Alt+Tab: фокус ни разу не попал на кромку", hitHandle = 0, hitHandle " раз")
Check("10 x Alt+Tab: активным ни разу не стал сам ящик", hitDrawer = 0, hitDrawer " раз")
Check("после Alt+Tab кромки на месте", WaitCount(9), Nums())

; ================= 3. быстрые хоткеи =================
Out("========== 3. быстрые повторные хоткеи ==========")
Away()
Loop 24 {
    Send("^!4")
    Sleep(40)
}
drain := Settle(wins[4].Hwnd, 1500, 30000)
Check("24 быстрых нажатия: очередь разобралась и окно встало", drain >= 0,
      drain < 0 ? "окно не остановилось за 30 с" : "успокоилось за " drain " мс")
Check("после шквала окно либо в слоте, либо за экраном, но не посередине",
      !OnScreen(wins[4].Hwnd) || PosOf(wins[4].Hwnd).x >= 1100,
      "x=" PosOf(wins[4].Hwnd).x)
Check("слот после шквала нажатий управляем и паркуется",
      ParkNow(wins[4].Hwnd, 4), "x=" PosOf(wins[4].Hwnd).x)
Sleep(600)
Check("кромка слота 4 вернулась", ById(4) ? true : false, Nums())
Send("^!4")
Check("и слот снова выдвигается", WaitOn(wins[4].Hwnd, true, 3500),
      "x=" PosOf(wins[4].Hwnd).x)
ParkNow(wins[4].Hwnd, 4)
Sleep(600)
Check("все девять кромок целы после шквала", WaitCount(9), Nums())

; ================= 4. быстрое переключение между слотами =================
Out("========== 4. быстрое переключение между слотами ==========")
Away()
Loop 3 {
    for n in [1, 2, 3, 5, 7, 9] {
        Send("^!" n)
        Sleep(70)
        Send("^!" n)
        Sleep(70)
    }
}
; ждём, пока разберётся очередь по каждому из задействованных слотов
for n in [1, 2, 3, 5, 7, 9]
    Settle(wins[n].Hwnd, 1200, 30000)
Sleep(500)
onScr := "", ghost := 0
Loop 9 {
    n := A_Index
    if OnScreen(wins[n].Hwnd)
        onScr .= (onScr = "" ? "" : ",") n
}
Loop 9 {
    n := A_Index
    p := PosOf(wins[n].Hwnd)
    ; окно не должно застрять на полпути: либо в слоте, либо за экраном
    if (OnScreen(wins[n].Hwnd) && p.x < 900)
        ghost++
}
Check("после 36 быстрых переключений ни одно окно не застряло на полпути",
      ghost = 0, ghost ? ghost " окон в промежуточном положении" : "на экране: "
      (onScr = "" ? "нет" : onScr))
; приводим всё в припаркованное состояние
notParked := ""
Loop 9 {
    n := A_Index
    if !ParkNow(wins[n].Hwnd, n)
        notParked .= (notParked = "" ? "" : ",") n
}
Sleep(800)
Check("все девять удалось припарковать обратно", notParked = "",
      notParked = "" ? "" : "не паркуются: " notParked)
Check("все девять снова припаркованы и с кромками", WaitCount(9), Nums())

; ================= 5. длительная работа =================
Out("========== 5. длительная работа с девятью кромками ==========")
Away()
before := Count()
t0 := A_TickCount
sweeps := 0, lost := 0, stuck := 0
MonitorGetWorkArea(1, &L1, &T1, &R1, &B1)
while (A_TickCount - t0 < 45000) {
    ; курсор ездит вдоль края и через границу мониторов
    MouseMove(R1 - 8, T1 + 100 + Mod(sweeps * 37, B1 - T1 - 200))
    Sleep(120)
    MouseMove(760, 540)
    Sleep(120)
    MouseMove(-600, 500)
    Sleep(120)
    sweeps++
    if (Count() != before)
        lost++
}
Away()
Sleep(900)
Check("45 секунд езды курсором: набор кромок не изменился", lost = 0,
      sweeps " проездов, отклонений " lost ", сейчас " Count() " шт.")
fat := ""
for k in Kromki() {
    if (k.w > 24)
        fat .= (fat = "" ? "" : ",") k.num
}
Check("ни одна кромка не застряла раскрытой", fat = "",
      fat = "" ? "все в покое" : "раскрыты: " fat)
Check("окна по-прежнему припаркованы", WaitCount(9), Nums())
alive := 0
Loop 9 {
    if WinExist("ahk_id " wins[A_Index].Hwnd)
        alive++
}
Check("все девять окон живы", alive = 9, alive " из 9")

; ================= 6. выход =================
Out("========== 6. очистка ==========")
Send("^!0")
Sleep(1200)
back := 0
Loop 9 {
    if OnScreen(wins[A_Index].Hwnd)
        back++
}
Check("Ctrl+Alt+0 вернул все девять окон на экран", back = 9, back " из 9")
Check("кромок не осталось", WaitCount(0), Nums())

for n, g in wins
    g.Destroy()
pinned.Destroy()
Sleep(300)

Out("ИТОГ нагрузки: проверок " checks ", провалов " fails)
Sleep(400)
ExitApp(0)
