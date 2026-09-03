#Requires AutoHotkey v2.0
#SingleInstance Off
Persistent()
SetWinDelay(-1)
SetKeyDelay(15, 15)
SendLevel(1)
CoordMode("Mouse", "Screen")

; Жизненный цикл окна под кромкой: максимизация, изменение размера,
; закрытие, полноэкранное окно поверх кромки, курсор между мониторами.
; Стенд kromka: слоты по всем краям и обоим мониторам, hideOnBlur=false.
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
WaitCount(n, ms := 3000) {
    t0 := A_TickCount
    while (A_TickCount - t0 < ms) {
        if (Count() = n)
            return true
        Sleep(25)
    }
    return false
}
WaitHandle(num, want, ms := 3000) {
    t0 := A_TickCount
    while (A_TickCount - t0 < ms) {
        if ((ById(num) ? true : false) = want)
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
Away() {
    MouseMove(760, 540)
    Sleep(100)
}
; Какое окно верхнего уровня лежит в этой точке экрана.
TopAt(x, y) {
    h := DllCall("WindowFromPoint", "Int64", (y << 32) | (x & 0xFFFFFFFF), "Ptr")
    if !h
        return 0
    return DllCall("GetAncestor", "Ptr", h, "UInt", 2, "Ptr")   ; GA_ROOT
}

; ================= 1. максимизация и размер =================
Out("========== 1. максимизация, разворачивание, размер ==========")
Away()
g := MakeWin("LIFE-A", 150, 150)
Check("окно припарковано", Park(g, 3), "x=" PosOf(g.Hwnd).x)
Check("кромка есть", WaitHandle(3, true), Nums())

Send("^!3")
Check("выдвинулось", WaitOn(g.Hwnd, true, 3500), "x=" PosOf(g.Hwnd).x)
Sleep(300)
WinMaximize("ahk_id " g.Hwnd)
Sleep(500)
Check("окно развёрнуто пользователем", WinGetMinMax("ahk_id " g.Hwnd) = 1,
      "MinMax=" WinGetMinMax("ahk_id " g.Hwnd))
Send("^!3")                     ; хоткей по развёрнутому окну
Sleep(900)
Check("хоткей по развёрнутому окну ставит его на место слота, а не прячет",
      OnScreen(g.Hwnd) && WinGetMinMax("ahk_id " g.Hwnd) = 0,
      "x=" PosOf(g.Hwnd).x " MinMax=" WinGetMinMax("ahk_id " g.Hwnd))
Send("^!3")
Check("после этого убирается", WaitOn(g.Hwnd, false, 3500), "x=" PosOf(g.Hwnd).x)
Check("кромка вернулась", WaitHandle(3, true), Nums())

Send("^!3")
WaitOn(g.Hwnd, true, 3500)
Sleep(300)
WinMove(300, 300, 500, 400, "ahk_id " g.Hwnd)      ; пользователь утащил и уменьшил
Sleep(400)
Send("^!3")
Sleep(900)
Check("хоткей по утащенному окну возвращает его в слот",
      OnScreen(g.Hwnd) && PosOf(g.Hwnd).x >= 900,
      "x=" PosOf(g.Hwnd).x " " PosOf(g.Hwnd).w "x" PosOf(g.Hwnd).h)
Send("^!3")
WaitOn(g.Hwnd, false, 3500)
Sleep(400)

WinMinimize("ahk_id " g.Hwnd)                       ; свёрнутое припаркованное
Sleep(600)
Check("свёрнутое припаркованное окно кромку не потеряло", WaitHandle(3, true), Nums())
Send("^!3")
Sleep(1000)
Check("хоткей разворачивает и выдвигает его",
      OnScreen(g.Hwnd) && WinGetMinMax("ahk_id " g.Hwnd) = 0,
      "x=" PosOf(g.Hwnd).x " MinMax=" WinGetMinMax("ahk_id " g.Hwnd))
Send("^!3")
WaitOn(g.Hwnd, false, 3500)
Sleep(400)

; ================= 2. закрытие окна =================
Out("========== 2. закрытие окна, у которого есть кромка ==========")
g2 := MakeWin("LIFE-B", 200, 200)
Check("второй слот припаркован", Park(g2, 5), "x=" PosOf(g2.Hwnd).x)
Check("две кромки", WaitCount(2), Nums())
g.Destroy()                                          ; закрываем первое
Check("кромка закрытого окна исчезла", WaitHandle(3, false), Nums())
Check("кромка второго осталась", ById(5) ? true : false, Nums())
Send("^!3")                                          ; хоткей по мёртвому слоту
Sleep(600)
Check("хоткей по мёртвому слоту ничего не ломает", ById(5) ? true : false, Nums())

; закрытие окна, пока оно выдвинуто
g3 := MakeWin("LIFE-C", 260, 260)
Park(g3, 6)
Sleep(300)
Send("^!6")
WaitOn(g3.Hwnd, true, 3500)
Sleep(300)
g3.Destroy()
Sleep(900)
Check("закрытие выдвинутого окна не оставило кромку", !ById(6), Nums())
Check("кромка соседнего слота цела", ById(5) ? true : false, Nums())

; ================= 3. полноэкранное окно =================
Out("========== 3. полноэкранное окно поверх кромки ==========")
Away()
k := ById(5)
Check("есть кромка для проверки", k != 0, Nums())
if k {
    cx := k.x + k.w // 2, cy := k.y + k.h // 2
    Check("в покое сверху именно кромка", TopAt(cx, cy) = k.hwnd,
          "сверху " TopAt(cx, cy) ", кромка " k.hwnd)
    MonitorGet(1, &fl, &ft, &fr, &fb)
    fs := Gui("-Caption +AlwaysOnTop -MinimizeBox", "LIFE-FULL")
    fs.BackColor := "101418"
    fs.Show("x" fl " y" ft " w" (fr - fl) " h" (fb - ft) " NoActivate")
    Sleep(700)
    Check("полноэкранное окно занимает весь монитор 1",
          PosOf(fs.Hwnd).w >= (fr - fl) - 2, PosOf(fs.Hwnd).w "x" PosOf(fs.Hwnd).h)
    k2 := ById(5)
    Check("кромка на месте и при полноэкранном окне", k2 != 0, Nums())
    if k2
        Out("      кто сверху в точке кромки: "
            (TopAt(k2.x + k2.w // 2, k2.y + k2.h // 2) = k2.hwnd ? "кромка"
             : (TopAt(k2.x + k2.w // 2, k2.y + k2.h // 2) = fs.Hwnd ? "ПОЛНОЭКРАННОЕ ОКНО"
                : "что-то третье")))
    fs.Destroy()
    Sleep(500)
    k3 := ById(5)
    Check("после закрытия полноэкранного кромка снова сверху",
          k3 && TopAt(k3.x + k3.w // 2, k3.y + k3.h // 2) = k3.hwnd,
          k3 ? "сверху " TopAt(k3.x + k3.w // 2, k3.y + k3.h // 2) : "-")

    ; То же, но окно БЕЗ AlwaysOnTop — так ведёт себя большинство
    ; приложений в безрамочном полноэкранном режиме.
    fs2 := Gui("-Caption -MinimizeBox", "LIFE-FULL2")
    fs2.BackColor := "101418"
    fs2.Show("x" fl " y" ft " w" (fr - fl) " h" (fb - ft) " NoActivate")
    Sleep(700)
    k4 := ById(5)
    Check("кромка на месте и при обычном полноэкранном окне", k4 != 0, Nums())
    Check("над обычным полноэкранным окном кромка остаётся сверху",
          k4 && TopAt(k4.x + k4.w // 2, k4.y + k4.h // 2) = k4.hwnd,
          k4 ? (TopAt(k4.x + k4.w // 2, k4.y + k4.h // 2) = fs2.Hwnd
                ? "сверху полноэкранное окно" : "сверху что-то третье") : "-")
    fs2.Destroy()
    Sleep(400)
}

Send("^!0")
Sleep(700)
g2.Destroy()
Sleep(300)

; ================= 4. курсор между мониторами =================
Out("========== 4. курсор между мониторами ==========")
Away()
w1 := MakeWin("LIFE-M1", 150, 150)      ; слот 2: монитор 1, правый край
w2 := MakeWin("LIFE-M2", 220, 220)      ; слот 8: монитор 2, правый край (внутренний)
w3 := MakeWin("LIFE-CUR", 290, 290)     ; слот 9: monitor=cursor
Check("три слота на разных мониторах припаркованы",
      Park(w1, 2) && Park(w2, 8) && Park(w3, 9))
Check("три кромки", WaitCount(3), Nums())

MonitorGetWorkArea(1, &L1, &T1, &R1, &B1)
MonitorGetWorkArea(2, &L2, &T2, &R2, &B2)
OnMon(k, mi) {
    MonitorGetWorkArea(mi, &l, &t, &r, &b)
    return k && k.x >= l && k.x + k.w <= r && k.y >= t && k.y + k.h <= b
}
bad := "", swept := 0
Loop 12 {
    ; проезд курсора через границу мониторов в обе стороны
    x := Mod(A_Index, 2) ? -600 : 600
    MouseMove(x, 500)
    ; полная пересборка кромок идёт раз в несколько тактов опроса —
    ; замерять раньше значит замерять ещё не переехавшую кромку
    Sleep(420)
    swept++
    if !OnMon(ById(2), 1)
        bad .= (bad = "" ? "" : "; ") "слот 2 ушёл с монитора 1"
    if !OnMon(ById(8), 2)
        bad .= (bad = "" ? "" : "; ") "слот 8 ушёл с монитора 2"
    k9 := ById(9)
    want := (x < 0) ? 2 : 1
    if (k9 && !OnMon(k9, want))
        bad .= (bad = "" ? "" : "; ") "слот 9 не на мониторе под курсором"
}
Check(swept " проездов курсора через границу: кромки остались на своих мониторах",
      bad = "", bad = "" ? "" : bad)
Away()
Sleep(500)
Check("после проездов кромок по-прежнему три", WaitCount(3), Nums())
Check("ни одна кромка не застряла увеличенной",
      (k := ById(2)) && k.w <= 24, k ? "толщина " k.w : "-")

Send("^!0")
Sleep(800)
w1.Destroy(), w2.Destroy(), w3.Destroy()
Sleep(300)

Out("ИТОГ жизненного цикла: проверок " checks ", провалов " fails)
Sleep(400)
ExitApp(0)
