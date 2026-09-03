#Requires AutoHotkey v2.0
#SingleInstance Off
Persistent()
SetWinDelay(-1)
SetKeyDelay(15, 15)
SendLevel(1)
CoordMode("Mouse", "Screen")

; Живая колонка «Состояние» в Settings -> Slots (S3). Стенд: main —
; slot1 привязан к mspaint (постоянный), 2..9 динамические.
; У самого Settings хоткея нет намеренно (Р16) — в бою это пункт трея.
; Тестовые хоткеи (открыть / сдампить колонку в файл) run.ps1 вшивает
; в КОПИЮ исходника флагом settingsHk, точно как notify вшивает лог
; TrayTip для набора quiet: ячейку ListView чужого процесса иначе не
; прочитать, а сам приём уже проверен на этом стенде.
; Аргументы: <logfile> <pid ящика> <statuslog>

dest      := A_Args[1]
pid       := Integer(A_Args[2])
statusLog := A_Args[3]
TITLE     := "Drawer — Settings"

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
    Sleep(150)
    return g
}
Away() {
    MouseMove(760, 540)
    Sleep(100)
}

; ---------- кромки: "Settings не получает handle" ----------
HandleCount() {
    global pid
    n := 0
    for h in WinGetList("ahk_class AutoHotkeyGUI ahk_pid " pid) {
        try {
            if (WinGetStyle("ahk_id " h) & 0x10000000)
                n++
        }
    }
    return n
}

; ---------- окно настроек ----------
WaitSettingsGone(ms := 2000) {
    global TITLE
    t0 := A_TickCount
    while (A_TickCount - t0 < ms) {
        if !WinExist(TITLE)
            return true
        Sleep(20)
    }
    return false
}
OpenSettings() {
    global TITLE
    Send("^!+F12")
    if !WinWait(TITLE, , 5)
        return false
    WinActivate(TITLE)
    Sleep(250)
    return true
}
TabHwnd() {
    global TITLE
    for cn in WinGetControls(TITLE) {
        if InStr(cn, "SysTabControl32")
            return ControlGetHwnd(cn, TITLE)
    }
    return 0
}
; Клик по заголовку вкладки which (1=General 2=Slots 3=About). Координаты
; идут от ControlGetPos/WinGetClientPos, а не от догадки про высоту рамки
; окна — она разная на разных темах и DPI.
ClickTab(which) {
    global TITLE
    th := TabHwnd()
    if !th
        return false
    ControlGetPos(&cx, &cy, &cw, &ch, "ahk_id " th)
    WinGetClientPos(&wx, &wy, , , TITLE)
    x := wx + cx + cw * (which * 2 - 1) / 6
    y := wy + cy + 10
    Click(Round(x), Round(y))
    Sleep(150)
    return true
}

; Дамп колонки "Состояние": тестовый хоткей читает ui.slotsLv.GetText()
; изнутри процесса ящика (снаружи ячейку ListView так просто не достать)
; и пишет строки "<n><tab><статус>" в statusLog. Файл удаляется перед
; каждым запросом, чтобы не путать текущий снимок с предыдущим.
Dump() {
    global statusLog
    if FileExist(statusLog)
        FileDelete(statusLog)
    Send("^!+F11")
    t0 := A_TickCount
    while (!FileExist(statusLog) && A_TickCount - t0 < 2000)
        Sleep(20)
    Sleep(80)
    m := Map()
    if FileExist(statusLog) {
        txt := FileRead(statusLog, "UTF-8")
        for line in StrSplit(txt, "`n", "`r") {
            if (line = "")
                continue
            parts := StrSplit(line, "`t")
            if (parts.Length >= 2)
                m[parts[1]] := parts[2]
        }
    }
    return m
}
StatusOf(snap, n) {
    return snap.Has(String(n)) ? snap[String(n)] : "?"
}

; ================= сценарий =================
Out("========== S3: живой статус в Settings -> Slots ==========")
Away()

; ---------- 1. добираем стенд до состояния Parked/Shown ----------
w2 := MakeWin("SS-2", 120, 120)
WinActivate("ahk_id " w2.Hwnd)
Sleep(250)
Send("^!+2")                      ; слот 2: привязка (и показ)
WaitOn(w2.Hwnd, true, 3000)
Sleep(300)
Send("^!2")                       ; убрать — слот 2 остаётся Parked
WaitOn(w2.Hwnd, false, 3000)
Sleep(300)

w3 := MakeWin("SS-3", 220, 160)
WinActivate("ahk_id " w3.Hwnd)
Sleep(250)
Send("^!+3")                      ; слот 3: привязка и показ — остаётся Shown
WaitOn(w3.Hwnd, true, 3000)
Sleep(400)

handlesBefore := HandleCount()

; ---------- 2. Settings открывается при уже Parked/Shown слотах ----------
Check("Settings открылось", OpenSettings())
Check("Settings не получает кромку", HandleCount() = handlesBefore,
      "было " handlesBefore ", стало " HandleCount())

snap := Dump()
Check("слот 2 показан как Parked при открытии", StatusOf(snap, 2) = "припаркован",
      StatusOf(snap, 2))
Check("слот 3 показан как Shown при открытии", StatusOf(snap, 3) = "выдвинут",
      StatusOf(snap, 3))

; ---------- 3. Settings нельзя bind ----------
Send("^!+4")                      ; слот 4 ещё не тронут — попытка вслепую
Sleep(300)
snap := Dump()
Check("bind вслепую по слоту 4 не тронул Settings", StatusOf(snap, 4) = "пусто",
      StatusOf(snap, 4))

; ---------- 4. вкладка Slots -> живой тик ----------
Check("клик по вкладке Slots", ClickTab(2))
Sleep(700)                        ; успеть хотя бы один тик (400 мс)

; ---------- 5. permanent: Parked -> Shown (слот 1, mspaint) ----------
Send("^!1")
Sleep(600)
Send("^!1")
Sleep(600)
snap := Dump()
Check("permanent слот 1: Parked", StatusOf(snap, 1) = "припаркован", StatusOf(snap, 1))
Send("^!1")
Sleep(600)
snap := Dump()
Check("permanent слот 1: Shown", StatusOf(snap, 1) = "выдвинут", StatusOf(snap, 1))

; ---------- 6. dynamic: Empty -> Parked -> Shown (слот 5) ----------
snap := Dump()
Check("слот 5 пуст до привязки", StatusOf(snap, 5) = "пусто", StatusOf(snap, 5))

w5 := MakeWin("SS-5", 260, 200)
WinActivate("ahk_id " w5.Hwnd)
Sleep(250)
Send("^!+5")                      ; привязка (и показ)
WaitOn(w5.Hwnd, true, 3000)
Sleep(600)
Send("^!5")                       ; парковка
WaitOn(w5.Hwnd, false, 3000)
Sleep(600)
snap := Dump()
Check("слот 5: Parked после привязки и парковки", StatusOf(snap, 5) = "припаркован",
      StatusOf(snap, 5))

Send("^!5")                       ; снова показать
WaitOn(w5.Hwnd, true, 3000)
Sleep(600)
snap := Dump()
Check("слот 5: Shown", StatusOf(snap, 5) = "выдвинут", StatusOf(snap, 5))

; ---------- 7. закрытие окна -> Empty, без ложного статуса ----------
w5.Destroy()
Sleep(700)
snap := Dump()
Check("слот 5: закрытие окна -> Empty, без ложного статуса",
      StatusOf(snap, 5) = "пусто", StatusOf(snap, 5))

; ---------- 8. hideOnBlur не сломан присутствием Settings ----------
; слот 3 (hideOnBlur=true) показан ещё до открытия Settings — фокус давно
; не на нём, обычный hideOnBlur должен был его убрать сам, без участия S3.
Check("hideOnBlur слота 3 сработал как обычно, несмотря на Settings",
      WaitOn(w3.Hwnd, false, 3000), "x=" PosOf(w3.Hwnd).x)

; ---------- 9. тик не делает Settings dirty ----------
WinActivate(TITLE)
Sleep(1600)                       ; несколько тиков без единой правки полей
Send("{Escape}")
Check("Escape закрывает Settings без «несохранённых правок» — тик не выставил dirty",
      WaitSettingsGone(2000))

; ---------- 10. второй Settings не создаётся ----------
Check("Settings открылось повторно", OpenSettings())
before := WinGetList(TITLE).Length
Send("^!+F12")
Sleep(400)
Check("повторный вызов не плодит второе окно", WinGetList(TITLE).Length = before,
      "было " before ", стало " WinGetList(TITLE).Length)
WinActivate(TITLE)
Sleep(200)
Send("{Escape}")
WaitSettingsGone(2000)

; ---------- 11. permanent: "приложение не запущено" ----------
; Единственная ветка статуса, которую честно не проверить без временной
; остановки mspaint — а он общий стенд для других наборов. Закрываем и
; поднимаем обратно, что бы ни случилось внутри блока.
try {
    if WinExist("ahk_exe mspaint.exe") {
        WinClose("ahk_exe mspaint.exe")
        WinWaitClose("ahk_exe mspaint.exe", , 3)
        Sleep(300)
        Check("Settings открыто", OpenSettings())
        Check("клик по вкладке Slots", ClickTab(2))
        Sleep(700)
        snap := Dump()
        Check("permanent слот 1 без запущенного приложения",
              StatusOf(snap, 1) = "приложение не запущено", StatusOf(snap, 1))
        Send("{Escape}")
        WaitSettingsGone(2000)
    } else {
        Out("  --  mspaint не найден, ветка «не запущено» пропущена")
    }
} finally {
    if !ProcessExist("mspaint.exe") {
        Run("mspaint.exe")
        WinWait("ahk_exe mspaint.exe", , 5)
        Sleep(500)
    }
}

; ---------- уборка ----------
w2.Destroy(), w3.Destroy()
Send("^!0")
Sleep(600)

Out("ИТОГ setstat: проверок " checks ", провалов " fails)
Sleep(300)
ExitApp(0)
