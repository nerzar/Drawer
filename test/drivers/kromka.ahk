#Requires AutoHotkey v2.0
#SingleInstance Off
Persistent()
SetWinDelay(-1)
SetKeyDelay(15, 15)
SendLevel(1)
CoordMode("Mouse", "Screen")

; Кромки припаркованных окон. Аргументы: <logfile> <pid ящика>
;
; Размеры кромки — те же константы, что в drawer.ahk. В покое плитка
; вмещает иконку приложения, поэтому она не 5 пикселей, как была.
REST := 22, NEAR := 28, HOVER := 44, LEN := 34, GAP := 8

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

; ---------- окна ящика, которые и есть кромки ----------
Kromki() {
    global pid
    out := []
    for h in WinGetList("ahk_class AutoHotkeyGUI ahk_pid " pid) {
        try {
            if !(WinGetStyle("ahk_id " h) & 0x10000000)
                continue
            WinGetPos(&x, &y, &w, &hh, "ahk_id " h)
            out.Push({ hwnd: h, x: x, y: y, w: w, h: hh,
                       num: NumOf(h), numVis: NumVis(h), icon: HasIcon(h),
                       title: WinGetTitle("ahk_id " h),
                       ex: WinGetExStyle("ahk_id " h) })
        }
    }
    return out
}
; Номер слота лежит в том контроле, у которого непустой текст: иконка
; добавляется первой и текста не имеет, поэтому привязываться к Static1
; больше нельзя.
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
NumOf(h) {
    return (cn := NumCtl(h)) = "" ? "" : ControlGetText(cn, "ahk_id " h)
}
NumVis(h) {
    return (cn := NumCtl(h)) != "" && ControlGetVisible(cn, "ahk_id " h) ? 1 : 0
}
; Иконка — отдельный контрол без текста, поэтому контролов становится два.
HasIcon(h) {
    return WinGetControls("ahk_id " h).Length >= 2 ? 1 : 0
}
ById(num) {
    for k in Kromki() {
        if (k.num = String(num))
            return k
    }
    return 0
}
Count() {
    return Kromki().Length
}
Nums() {
    s := ""
    for k in Kromki()
        s .= (s = "" ? "" : ",") k.num
    return s = "" ? "-" : s
}
WaitCount(n, ms := 2500) {
    t0 := A_TickCount
    while (A_TickCount - t0 < ms) {
        if (Count() = n)
            return true
        Sleep(20)
    }
    return false
}
; Дождаться, пока полоска перестанет менять размер.
WaitStable(num, ms := 2000) {
    Sleep(450)
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
Thick(k, edge) {
    return (edge = "left" || edge = "right") ? k.w : k.h
}
; Сколько пикселей прямоугольника лежит на мониторе, отличном от mi.
OnOther(r, mi) {
    worst := 0
    Loop MonitorGetCount() {
        if (A_Index = mi)
            continue
        MonitorGet(A_Index, &l, &t, &rr, &b)
        if (r.x < rr && r.x + r.w > l && r.y < b && r.y + r.h > t) {
            ov := Min(r.x + r.w, rr) - Max(r.x, l)
            worst := Max(worst, ov > 0 ? ov : 1)
        }
    }
    return worst
}
; q, а не r: MonitorGetWorkArea пишет в &R, а имена в AHK
; регистронезависимы — параметр r затирался бы правой границей монитора.
Inside(q, mi) {
    MonitorGetWorkArea(mi, &L, &T, &R, &B)
    return (q.x >= L && q.x + q.w <= R && q.y >= T && q.y + q.h <= B)
}

; ---------- окна ящика ----------
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
MakeWin(title, x := 200, y := 160) {
    g := Gui("-MinimizeBox", title)
    g.BackColor := "203040"
    g.Add("Text", "cWhite w280 h180", title)
    g.Show("x" x " y" y " w320 h220")
    Sleep(150)
    return g
}
; Привязать окно к слоту и припарковать его.
Park(g, n) {
    WinActivate("ahk_id " g.Hwnd)
    Sleep(250)
    Send("^!+" n)
    Sleep(350)
    Loop 4 {
        if !OnScreen(g.Hwnd) {
            Sleep(300)
            return true
        }
        Send("^!" n)
        if WaitOn(g.Hwnd, false, 1500) {
            Sleep(300)
            return true
        }
        Sleep(300)
    }
    return !OnScreen(g.Hwnd)
}
; что сейчас на экране — для разбора провала
Dump(tag, wins) {
    s := "     " tag ": кромок " Count()
    for k in Kromki()
        s .= " | #" k.num " x=" k.x " y=" k.y " " k.w "x" k.h
    for name, h in wins
        s .= " | " name " x=" PosOf(h).x (OnScreen(h) ? " НА ЭКРАНЕ" : " убрано")
    Out(s)
}
Neutral := 0
Away() {                       ; курсор подальше от всех краёв
    MouseMove(760, 540)
    Sleep(120)
}

; ================= A. Основное =================
Out("========== A. Основное ==========")
Away()
gA := MakeWin("KR-A")
Park(gA, 2)                                   ; монитор 1, правый край
Check("A1. припарковали слот 2 — кромка появилась", WaitCount(1), Count() " шт.")
MonitorGetWorkArea(1, &L1, &T1, &R1, &B1)
k := WaitStable(2)
Check("A2. кромка прижата к правому краю монитора 1 изнутри",
      k && k.x + k.w = R1 && k.w = REST, k ? "x=" k.x " w=" k.w " (R=" R1 ")" : "нет кромки")
Check("A3. длина " LEN " и по центру края",
      k && k.h = LEN && Abs((k.y + k.h // 2) - (T1 + B1) // 2) <= 2,
      k ? "y=" k.y " h=" k.h : "-")
Check("A3b. кромка целиком внутри рабочей области монитора 1", k && Inside(k, 1),
      k ? "x=" k.x ".." k.x + k.w : "-")
Check("A4. в покое номер слота не показан", k && !k.numVis, k ? "видим=" k.numVis : "-")
Check("A4b. в покое видна иконка приложения", k && k.icon, k ? "контролов " (k.icon + 1) : "-")

MouseMove(R1 - 60, (T1 + B1) // 2)            ; подход
k := WaitStable(2)
Check("A5. при подходе курсора кромка подросла", k && k.w >= NEAR - 2 && k.w <= NEAR + 2,
      k ? "w=" k.w : "-")
Check("A6. при подходе номера ещё нет", k && !k.numVis,
      k ? "текст=" k.num " видим=" k.numVis : "-")
Check("A6b. подросшая кромка не вышла за монитор", k && Inside(k, 1) && k.x + k.w = R1,
      k ? "x=" k.x " w=" k.w : "-")

MouseMove(R1 - 3, (T1 + B1) // 2)             ; наведение
k := WaitStable(2)
Check("A7. под курсором кромка ещё шире", k && k.w >= HOVER - 4 && k.w <= HOVER + 2,
      k ? "w=" k.w : "-")
Check("A7b. под курсором показан номер слота, и это 2", k && k.numVis && k.num = "2",
      k ? "текст=" k.num " видим=" k.numVis : "-")

Click()                                        ; A8: щелчок
Check("A8. по щелчку выехало окно слота 2", WaitOn(gA.Hwnd, true, 3000),
      "x=" PosOf(gA.Hwnd).x)
Sleep(500)
Check("A9. после выдвижения кромки нет", WaitCount(0), Count() " шт.")

; ================= B. Жизненный цикл =================
Out("========== B. Жизненный цикл ==========")
Away()
Send("^!2")                                    ; убрать обратно
WaitOn(gA.Hwnd, false, 3000)
Check("B1. убрали — кромка вернулась", WaitCount(1), Count() " шт.")
gA.Destroy()                                   ; окно закрыли
Check("B2. окно закрыли — кромка исчезла", WaitCount(0, 3000), Count() " шт.")

gB := MakeWin("KR-B")
Park(gB, 2)
Check("B3. кромка снова есть", WaitCount(1), Count() " шт.")
Send("^!0")                                    ; очистка динамических слотов
Sleep(600)
Check("B4. Ctrl+Alt+0 — кромок нет", WaitCount(0), Count() " шт.")
gB.Destroy()
Sleep(300)

; ================= C. Несколько слотов =================
Out("========== C. Несколько слотов ==========")
Away()
g2 := MakeWin("KR-2", 100, 100)
g3 := MakeWin("KR-3", 140, 140)
g4 := MakeWin("KR-4", 180, 180)
Check("C0. слоты 2 и 3 припаркованы", Park(g2, 2) && Park(g3, 3))
Check("C1. два припаркованных на одном крае — две кромки", WaitCount(2), Count() " шт.")
a := ById(2), b := ById(3)
Check("C1b. кромки не пересекаются",
      a && b && (a.y + a.h <= b.y || b.y + b.h <= a.y),
      a && b ? "2: y=" a.y "..+" a.h ", 3: y=" b.y : "-")
Check("C1c. слот 4 припаркован", Park(g4, 4))
Check("C2. три припаркованных — три кромки", WaitCount(3), Count() " шт.")
if (Count() != 3)
    Dump("C2", Map("KR-2", g2.Hwnd, "KR-3", g3.Hwnd, "KR-4", g4.Hwnd))
a := ById(2), b := ById(3), c := ById(4)
ok := a && b && c
Check("C2b. порядок сверху вниз по номеру слота", ok && a.y < b.y && b.y < c.y,
      ok ? "2:" a.y " 3:" b.y " 4:" c.y : "-")
Check("C2c. зазоры одинаковые и стопка по центру",
      ok && (b.y - a.y) = (c.y - b.y)
         && Abs((a.y + (c.y + c.h - a.y) // 2) - (T1 + B1) // 2) <= 2,
      ok ? "шаг " (b.y - a.y) " (ждали " (LEN + GAP) ")" : "-")
Check("C2d. все три у правого края монитора 1",
      ok && a.x + a.w = R1 && b.x + b.w = R1 && c.x + c.w = R1, "R=" R1)

mid := ById(3)                                  ; C3: щёлкаем среднюю
if mid {
    MouseMove(mid.x + mid.w - 3, mid.y + mid.h // 2)
    mid := WaitStable(3)
    MouseMove(mid.x + mid.w - 3, mid.y + mid.h // 2)
    Sleep(150)
    Click()
}
Check("C3. щелчок по средней кромке выдвинул именно слот 3",
      WaitOn(g3.Hwnd, true, 3000) && !OnScreen(g2.Hwnd) && !OnScreen(g4.Hwnd),
      "2:" (OnScreen(g2.Hwnd) ? "на экране" : "убрано")
      " 3:" (OnScreen(g3.Hwnd) ? "на экране" : "убрано")
      " 4:" (OnScreen(g4.Hwnd) ? "на экране" : "убрано"))
Sleep(600)
; Главное правило видимости: выдвинутый слот теряет свою кромку, а
; соседние припаркованные — сохраняют. Иначе мышью нельзя перейти с
; выдвинутого окна на другое припаркованное.
Check("C4. у выдвинутого слота 3 кромки нет", !ById(3), Nums())
Check("C4a. кромки слотов 2 и 4 остались", WaitCount(2) && ById(2) && ById(4), Nums())
Send("^!3")
WaitOn(g3.Hwnd, false, 3000)
Sleep(400)
Check("C4b. окно убрали — все три кромки вернулись", WaitCount(3), Count() " шт.")
a2 := ById(2), b2 := ById(3), c2 := ById(4)
Check("C4c. места в стопке не разъехались, пока слот 3 был выдвинут",
      a2 && b2 && c2 && a2.y = a.y && b2.y = b.y && c2.y = c.y,
      a2 && b2 && c2 ? "было " a.y "/" b.y "/" c.y ", стало " a2.y "/" b2.y "/" c2.y : "-")
Send("^!0")
Sleep(600)
g2.Destroy(), g3.Destroy(), g4.Destroy()
Sleep(300)

; ================= D/E. Края и мониторы =================
Out("========== D+E. Края и мониторы ==========")
cases := [ {slot: 2, mon: 1, edge: "right",  inner: false},
           {slot: 5, mon: 1, edge: "left",   inner: true },
           {slot: 6, mon: 1, edge: "top",    inner: false},
           {slot: 7, mon: 1, edge: "bottom", inner: false},
           {slot: 8, mon: 2, edge: "right",  inner: true } ]
for c in cases {
    Away()
    g := MakeWin("KR-" c.slot)
    Park(g, c.slot)
    tag := "M" c.mon "/" c.edge (c.inner ? " (внутренний край)" : "")
    okc := WaitCount(1)
    k := WaitStable(c.slot)
    Check(tag ": кромка появилась", okc && k, Count() " шт.")
    if k {
        MonitorGetWorkArea(c.mon, &L, &T, &R, &B)
        switch c.edge {
        case "right":  fit := (k.x + k.w = R)
        case "left":   fit := (k.x = L)
        case "top":    fit := (k.y = T)
        case "bottom": fit := (k.y + k.h = B)
        }
        Check(tag ": прижата к своему краю", fit,
              "x=" k.x " y=" k.y " w=" k.w " h=" k.h)
        Check(tag ": целиком внутри своего монитора", Inside(k, c.mon), "")
        Check(tag ": ни пикселя на соседнем мониторе", OnOther(k, c.mon) = 0,
              OnOther(k, c.mon) " px")

        ; подвести курсор и проверить, что рост идёт внутрь экрана
        vert := (c.edge = "left" || c.edge = "right")
        cx := vert ? (c.edge = "right" ? R - 60 : L + 60) : k.x + k.w // 2
        cy := vert ? k.y + k.h // 2 : (c.edge = "bottom" ? B - 60 : T + 60)
        MouseMove(cx, cy)
        k2 := WaitStable(c.slot)
        Check(tag ": при подходе выросла", k2 && Thick(k2, c.edge) >= NEAR - 2,
              k2 ? "толщина " Thick(k2, c.edge) : "-")
        Check(tag ": выросла внутрь, монитор не покинула",
              k2 && Inside(k2, c.mon) && OnOther(k2, c.mon) = 0,
              k2 ? "x=" k2.x " y=" k2.y " w=" k2.w " h=" k2.h : "-")

        ; щелчок наводкой ровно в середину кромки
        MouseMove(k2.x + k2.w // 2, k2.y + k2.h // 2)
        Sleep(250)
        k3 := WaitStable(c.slot)
        MouseMove(k3.x + k3.w // 2, k3.y + k3.h // 2)
        Sleep(150)
        Click()
        Check(tag ": щелчок выдвинул окно", WaitOn(g.Hwnd, true, 3000),
              "x=" PosOf(g.Hwnd).x)
        pw := PosOf(g.Hwnd)
        Check(tag ": окно выехало на свой монитор", OnOther(pw, c.mon) = 0,
              OnOther(pw, c.mon) " px")
    }
    Away()
    Send("^!0")
    Sleep(500)
    g.Destroy()
    Sleep(250)
}

; ---- E5: monitor=cursor ----
Out("-- E5. monitor=cursor --")
Away()
g9 := MakeWin("KR-9")
Check("E5-0. слот 9 припаркован", Park(g9, 9), "x=" PosOf(g9.Hwnd).x)
k := WaitStable(9)
if !k
    Dump("E5", Map("KR-9", g9.Hwnd))
MonitorGetWorkArea(1, &L1, &T1, &R1, &B1)
Check("E5. курсор на M1 — кромка на мониторе 1",
      k && Inside(k, 1) && k.x + k.w = R1, k ? "x=" k.x : "-")
MouseMove(-960, 540)                            ; уходим на монитор 2
Sleep(900)
k := WaitStable(9)
MonitorGetWorkArea(2, &L2, &T2, &R2, &B2)
Check("E5b. курсор на M2 — кромка переехала на монитор 2",
      k && Inside(k, 2) && k.x + k.w = R2 && OnOther(k, 2) = 0,
      k ? "x=" k.x " (R2=" R2 ")" : "-")

; ---- F. невмешательство ----
Out("-- F. кромка не лезет в чужие дела --")
k := ById(9)
Check("F1. у кромки пустой заголовок", k && k.title = "", k ? "[" k.title "]" : "-")
Check("F1b. ToolWindow (мимо Alt+Tab)", k && (k.ex & 0x80), k ? Format("0x{:X}", k.ex) : "-")
Check("F1c. WS_EX_NOACTIVATE", k && (k.ex & 0x08000000), k ? Format("0x{:X}", k.ex) : "-")

gN := MakeWin("KR-NEUTRAL", -1600, 400)
WinActivate("ahk_id " gN.Hwnd)
Sleep(400)
before := WinExist("A")
if (k := ById(9)) {
    MouseMove(k.x + k.w - 3, k.y + k.h // 2)
    k := WaitStable(9)
    MouseMove(k.x + k.w - 3, k.y + k.h // 2)
    Sleep(150)
    Click()
}
Check("F2. щелчок по кромке выдвинул слот с activateOnShow=false",
      WaitOn(g9.Hwnd, true, 3000), "x=" PosOf(g9.Hwnd).x)
Sleep(400)
Check("F2b. фокус остался у прежнего окна", WinExist("A") = before,
      "было " before ", стало " WinExist("A"))
Away()
Send("^!0")
Sleep(600)
g9.Destroy(), gN.Destroy()
Sleep(300)

; ---- E6. постоянный слот ----
Out("-- E6. постоянный слот (mspaint, M2/left) --")
Away()
if WinExist("ahk_exe mspaint.exe") {
    ph := WinExist("ahk_exe mspaint.exe")
    WinActivate("ahk_id " ph)
    Sleep(300)
    Loop 3 {
        if !OnScreen(ph)
            break
        Send("^!1")
        WaitOn(ph, false, 3000)
        Sleep(300)
    }
    Check("E6. постоянный слот припаркован", !OnScreen(ph), "x=" PosOf(ph).x)
    Check("E6b. у постоянного слота есть кромка", WaitCount(1), Count() " шт.")
    k := WaitStable(1)
    MonitorGetWorkArea(2, &L2, &T2, &R2, &B2)
    Check("E6c. кромка у левого края монитора 2",
          k && k.x = L2 && Inside(k, 2), k ? "x=" k.x " (L2=" L2 ")" : "-")
    MouseMove(L2 + 3, k.y + k.h // 2)
    Sleep(400)
    k := WaitStable(1)
    MouseMove(k.x + 3, k.y + k.h // 2)
    Sleep(150)
    Click()
    Check("E6d. щелчок выдвинул mspaint", WaitOn(ph, true, 3000), "x=" PosOf(ph).x)
    Away()
    Send("^!1")
    WaitOn(ph, false, 3000)
    Sleep(400)
} else
    Out("  -- mspaint не запущен, постоянный слот не проверен")

Out("ИТОГ кромок: проверок " checks ", провалов " fails)
Sleep(500)
ExitApp(0)
