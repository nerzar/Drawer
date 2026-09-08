#Requires AutoHotkey v2.0
#SingleInstance Off
Persistent()
SetWinDelay(-1)
SetKeyDelay(15, 15)
SendLevel(1)
CoordMode("Mouse", "Screen")

; Перезапуски: ящик убит с припаркованными окнами, приложение закрыто и
; открыто заново, handles=false -> true. Стенд kromka: слот 1 постоянный
; (mspaint, монитор 2, левый край), остальные динамические.
; Аргументы: <logfile> <pid ящика> <папка стенда>
; Рядом со стендом лежат config.ini и launch.txt с командой запуска ящика:
; передавать команду аргументом нельзя — вложенные кавычки не переживают.

dest := A_Args[1]
pid  := Integer(A_Args[2])
dir  := A_Args[3]
#Include DrawerControl.ahk
cmd  := FileExist(dir "\launch.txt")
        ? Trim(FileRead(dir "\launch.txt", "UTF-8"), " `t`r`n") : ""

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
Count() => Kromki().Length
Nums() {
    s := ""
    for k in Kromki()
        s .= (s = "" ? "" : ",") k.num
    return s = "" ? "-" : s
}
WaitCount(n, ms := 4000) {
    t0 := A_TickCount
    while (A_TickCount - t0 < ms) {
        if (Count() = n)
            return true
        Sleep(30)
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
WaitOn(h, want, ms := 4000) {
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
; Запустить новый экземпляр и дождаться, пока он начнёт отвечать на хоткеи.
StartBox() {
    global cmd, pid
    Run(cmd, , , &np)
    pid := np
    Sleep(2500)
    return np
}
KillBox(p) {
    ProcessClose(p)
    ProcessWaitClose(p, 5)
    Sleep(800)
}

; ================= 1. ящик убит с припаркованными окнами =================
Out("========== 1. ящик убит, окна остались припаркованными ==========")
Away()
g := MakeWin("RST-A", 180, 180)
Check("окно припарковано", Park(g, 3), "x=" PosOf(g.Hwnd).x)
Check("кромка есть", WaitCount(1), Nums())
parkedX := PosOf(g.Hwnd).x

KillBox(pid)                       ; жёстко, как при падении
Check("после убийства ящика окно осталось за экраном (ожидаемо)",
      !OnScreen(g.Hwnd), "x=" PosOf(g.Hwnd).x)
Check("кромок не осталось — они умерли вместе с процессом",
      WaitCount(0, 2000), Nums())

; ================= 2. новый экземпляр над брошенными окнами =================
Out("========== 2. новый экземпляр поверх брошенных окон ==========")
StartBox()
Check("новый экземпляр запустился", ProcessExist(pid) != 0, "pid " pid)
Check("кромок у него нет — про чужие окна он ничего не знает",
      WaitCount(0, 2500), Nums())
Check("брошенное окно так и лежит за экраном", !OnScreen(g.Hwnd),
      "x=" PosOf(g.Hwnd).x " (было " parkedX ")")

; окно за экраном нельзя активировать мышью, но привязать хоткеем можно,
; если сделать его активным программно — так поступил бы и пользователь
; через Alt+Tab
WinActivate("ahk_id " g.Hwnd)
Sleep(400)
Send("^!+3")
Sleep(500)
Send("^!3")
Check("новый ящик выдвинул брошенное окно на экран", WaitOn(g.Hwnd, true, 4000),
      "x=" PosOf(g.Hwnd).x)
Send("^!3")
WaitOn(g.Hwnd, false, 4000)
Sleep(400)
Check("и снова припарковал", !OnScreen(g.Hwnd), "x=" PosOf(g.Hwnd).x)

; Главное: выход не должен отправить окно ещё дальше за экран. Исходные
; координаты у брошенного окна были за пределами мониторов, и записывать
; их как «место возврата» нельзя.
DrawerExit(pid)
Sleep(2500)
Check("после выхода окно оказалось НА ЭКРАНЕ, а не за его пределами",
      OnScreen(g.Hwnd), "x=" PosOf(g.Hwnd).x " " PosOf(g.Hwnd).w "x" PosOf(g.Hwnd).h)

; ================= 3. handles=false -> true =================
Out("========== 3. handles=false -> true ==========")
Check("папка стенда и команда запуска на месте",
      dir != "" && FileExist(dir "\config.ini") && cmd != "", dir " | " cmd)
if (dir != "" && FileExist(dir "\config.ini")) {
    IniWrite("false", dir "\config.ini", "general", "handles")
    Check("в config.ini записано handles=false",
          IniRead(dir "\config.ini", "general", "handles", "?") = "false")
    StartBox()
    Away()
    Check("экземпляр с handles=false запустился", ProcessExist(pid) != 0, "pid " pid)
    g2 := MakeWin("RST-B", 240, 240)
    Check("окно припарковано", Park(g2, 3), "x=" PosOf(g2.Hwnd).x)
    Check("кромок нет", WaitCount(0, 2500), Nums())
    MonitorGetWorkArea(1, &L1, &T1, &R1, &B1)
    MouseMove(R1 - 10, (T1 + B1) // 2)
    Sleep(1200)
    Check("курсор у края ничего не вызвал", Count() = 0, Nums())
    Away()
    DrawerExit(pid)
    Sleep(2000)

    IniWrite("true", dir "\config.ini", "general", "handles")
    Check("в config.ini записано handles=true",
          IniRead(dir "\config.ini", "general", "handles", "?") = "true")
    StartBox()
    Away()
    Check("экземпляр с handles=true запустился", ProcessExist(pid) != 0, "pid " pid)
    Check("окно вернулось на место при выходе прошлого экземпляра",
          OnScreen(g2.Hwnd), "x=" PosOf(g2.Hwnd).x)
    Check("окно снова припарковано", Park(g2, 3), "x=" PosOf(g2.Hwnd).x)
    Check("после включения настройки кромка появилась", WaitCount(1, 3000), Nums())
    Send("^!0")
    Sleep(800)
    g2.Destroy()
    Sleep(300)
}

; ================= 4. перезапуск приложения постоянного слота =================
Out("========== 4. перезапуск приложения постоянного слота ==========")
Away()
if !WinExist("ahk_exe mspaint.exe") {
    Run("mspaint.exe")
    WinWait("ahk_exe mspaint.exe", , 10)
    Sleep(1500)
}
if WinExist("ahk_exe mspaint.exe") {
    ph := WinExist("ahk_exe mspaint.exe")
    WinActivate("ahk_id " ph)
    Sleep(400)
    Loop 3 {
        if !OnScreen(ph)
            break
        Send("^!1")
        WaitOn(ph, false, 4000)
        Sleep(300)
    }
    Check("постоянный слот припаркован", !OnScreen(ph), "x=" PosOf(ph).x)
    Check("у постоянного слота есть кромка", WaitCount(1, 3000), Nums())

    Send("^!1")                          ; вернём на экран, потом закроем
    WaitOn(ph, true, 4000)
    Sleep(400)
    WinClose("ahk_id " ph)
    Sleep(2500)
    Check("приложение закрыто", !WinExist("ahk_exe mspaint.exe"),
          WinExist("ahk_exe mspaint.exe") ? "окно ещё есть" : "закрыто")
    Check("кромка закрытого приложения исчезла", WaitCount(0, 3000), Nums())
    Send("^!1")                          ; хоткей по незапущенному приложению
    Sleep(800)
    Check("хоткей по незапущенному приложению ничего не ломает",
          Count() = 0 && ProcessExist(pid), Nums())

    Run("mspaint.exe")                   ; запускаем заново
    WinWait("ahk_exe mspaint.exe", , 15)
    Sleep(2000)
    ph2 := WinExist("ahk_exe mspaint.exe")
    Check("приложение запущено заново", ph2 != 0 && ph2 != ph,
          "было " ph ", стало " ph2)
    WinActivate("ahk_id " ph2)
    Sleep(400)
    Send("^!1")
    Sleep(1500)
    Check("постоянный слот нашёл новое окно приложения",
          OnScreen(ph2) && PosOf(ph2).x < 0, "x=" PosOf(ph2).x)
    Send("^!1")
    WaitOn(ph2, false, 4000)
    Sleep(500)
    Check("и припарковал его", !OnScreen(ph2), "x=" PosOf(ph2).x)
    Check("кромка нового окна появилась", WaitCount(1, 3000), Nums())
    Send("^!1")
    WaitOn(ph2, true, 4000)
    Sleep(400)
} else
    Out("  -- mspaint не удалось запустить, постоянный слот не проверен")

g.Destroy()
Sleep(300)
Out("ИТОГ перезапусков: проверок " checks ", провалов " fails)
Sleep(400)
ExitApp(0)
