#Requires AutoHotkey v2.0
#SingleInstance Off
Persistent()
SetWinDelay(-1)
SetKeyDelay(15, 15)
SendLevel(1)
CoordMode("Mouse", "Screen")

; ГЛАВНЫЙ ИНВАРИАНТ: видимое окно слота никогда не пересекает соседний
; монитор. Опрашиваем положение каждые 2 мс на протяжении показа и уборки
; и требуем, чтобы ни один кадр не задел чужой экран.
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
Visible(h) {
    try
        return (WinGetStyle("ahk_id " h) & 0x10000000) ? true : false
    return false
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
; Пересекает ли окно ЧУЖОЙ монитор (любой, кроме своего mi)
OnOther(h, mi) {
    p := PosOf(h)
    if !Visible(h)
        return 0
    Loop MonitorGetCount() {
        if (A_Index = mi)
            continue
        MonitorGet(A_Index, &l, &t, &r, &b)
        if (p.x < r && p.x + p.w > l && p.y < b && p.y + p.h > t) {
            ; насколько именно залезло — для отчёта
            ov := Min(p.x + p.w, r) - Max(p.x, l)
            return ov > 0 ? ov : 1
        }
    }
    return 0
}
; Следим за окном ms миллисекунд; возвращаем максимальный «залез» на чужой
; монитор и число разных позиций (чтобы отличить анимацию от переноса).
Watch(h, mi, ms) {
    worst := 0, seen := 0, last := ""
    t0 := A_TickCount
    while (A_TickCount - t0 < ms) {
        ov := OnOther(h, mi)
        if (ov > worst)
            worst := ov
        p := PosOf(h)
        cur := p.x "," p.y
        if (cur != last) {
            seen++
            last := cur
        }
        Sleep(2)
    }
    return { worst: worst, seen: seen }
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
    return g
}

; слот -> монитор, край (совпадает с config.ini стенда)
cases := [ {slot: 3, mon: 1, edge: "right",  inner: false},
           {slot: 4, mon: 1, edge: "left",   inner: true },
           {slot: 5, mon: 1, edge: "top",    inner: false},
           {slot: 6, mon: 1, edge: "bottom", inner: false},
           {slot: 7, mon: 2, edge: "right",  inner: true },
           {slot: 8, mon: 2, edge: "left",   inner: false},
           {slot: 2, mon: 2, edge: "top",    inner: false},
           {slot: 9, mon: 2, edge: "bottom", inner: false} ]

Out("========== инвариант: окно не видно на соседнем мониторе ==========")
; По одному слоту за раз. Если держать шесть привязанных окон сразу, они
; мешают друг другу: уборка возвращает фокус соседнему окну, а оно тоже
; слот — и хук честно выдвигает его обратно. К инварианту это отношения
; не имеет, но проверку «убрано за пределы экранов» делает плавающей.
wins := Map()
for c in cases {
    g := MakeWin("INV-" c.slot, 200, 160)
    h := g.Hwnd
    wins[c.slot] := h
    Sleep(200)
    WinActivate("ahk_id " h)
    Sleep(250)
    Send("^!+" c.slot)
    Sleep(400)
    tag := "слот " c.slot " (M" c.mon ", " c.edge (c.inner ? ", внутренний край" : "") ")"

    ; Сначала припарковать. Иначе первые кадры замера показывают окно на
    ; его ИСХОДНОМ месте: тестовые окна создаются на мониторе 1, а для
    ; слотов, привязанных к монитору 2, монитор 1 — «соседний», и замер
    ; засчитывал бы нарушением то, к чему Drawer ещё не прикасался.
    Loop 3 {
        if !OnScreen(h)
            break
        Send("^!" c.slot)
        WaitOn(h, false, 2500)
        Sleep(350)
    }
    Check(tag ": припарковано перед замером", !OnScreen(h), "x=" PosOf(h).x)

    Send("^!" c.slot)
    r1 := Watch(h, c.mon, 900)
    WaitOn(h, true, 2500)
    Sleep(350)
    Check(tag ": показ не задел соседний монитор", r1.worst = 0,
          r1.worst ? "залез на " r1.worst " px" : "0 px")

    Send("^!" c.slot)
    r2 := Watch(h, c.mon, 900)
    Sleep(350)
    Check(tag ": уборка не задела соседний монитор", r2.worst = 0,
          r2.worst ? "залез на " r2.worst " px" : "0 px")
    ; уборка асинхронная (Hide + возврат фокуса), поэтому ждём, а не
    ; смотрим мгновенный снимок
    Check(tag ": убрано за пределы экранов", WaitOn(h, false, 2500), "x=" PosOf(h).x)

    ; на внешних краях анимация обязана быть, на внутренних её быть не может
    if c.inner {
        Check(tag ": перенос без анимации (как и задумано)",
              r1.seen <= 3 && r2.seen <= 3, "показ " r1.seen ", уборка " r2.seen)
    } else {
        Check(tag ": анимация играет", r1.seen > 4 && r2.seen > 4,
              "показ " r1.seen ", уборка " r2.seen)
    }
    Send("^!0")            ; отпустить слот, чтобы окно не мешало следующему
    Sleep(500)
    g.Destroy()
    Sleep(250)
}

; --- главный сценарий из отчёта: M2 + right + hideOnBlur ---
Out("-- M2 + right + hideOnBlur: полный сценарий --")
g7 := MakeWin("INV-M2", 200, 160), h := g7.Hwnd
gN := MakeWin("INV-NEUTRAL", 700, 500), N := gN.Hwnd
Sleep(300)
WinActivate("ahk_id " h), Sleep(250)
Send("^!+7"), Sleep(400)
Send("^!7"), WaitOn(h, true, 3000), Sleep(400)
p := PosOf(h)
MonitorGetWorkArea(2, &L2, &T2, &R2, &B2)
Check("1-2. окно показано и целиком на мониторе 2",
      p.x >= L2 - 2 && p.x + p.w <= R2 + 2, "x=" p.x " ширина " p.w " (M2: " L2 ".." R2 ")")

WinActivate("ahk_id " N)                       ; 3. уходим на другое окно
r := Watch(h, 2, 1400)                          ; 4. ждём hideOnBlur, следя за каждым кадром
Check("3-5. при hideOnBlur окно не появилось на мониторе 1", r.worst = 0,
      r.worst ? "залез на " r.worst " px" : "0 px")
Check("5. окно уехало с экранов", !OnScreen(h), "x=" PosOf(h).x)

MouseMove(-960, 500)                            ; курсор на M2, но monitor задан явно
Send("^!7")                                     ; 6. снова вызываем
r := Watch(h, 2, 900)
WaitOn(h, true, 3000)
Sleep(400)
p := PosOf(h)
Check("6-7. вернулось именно на монитор 2",
      p.x >= L2 - 2 && p.x + p.w <= R2 + 2, "x=" p.x " ширина " p.w)
Check("6-7. возврат не задел монитор 1", r.worst = 0,
      r.worst ? "залез на " r.worst " px" : "0 px")

; --- быстрые переключения и хоткеи во время анимации ---
Out("-- быстрые переключения и хоткеи --")
worst := 0
Loop 10 {
    Send("^!7")
    r := Watch(h, 2, 260)
    if (r.worst > worst)
        worst := r.worst
    WinActivate("ahk_id " N)
    r := Watch(h, 2, 420)
    if (r.worst > worst)
        worst := r.worst
}
Sleep(2500)
Check("10 быстрых циклов: ни разу не показалось на мониторе 1", worst = 0,
      worst ? "худший залез " worst " px" : "0 px")

Send("^!0"), Sleep(600)
Out("ИТОГ инварианта: проверок " checks ", провалов " fails)
Out("")
ExitApp(fails)
