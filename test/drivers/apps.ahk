#Requires AutoHotkey v2.0
#SingleInstance Off
Persistent()
SetWinDelay(-1)
SetKeyDelay(15, 15)
SendLevel(1)
CoordMode("Mouse", "Screen")
MouseMove(960, 500)

; Регрессия на настоящих приложениях: VS Code (постоянный слот 1),
; Telegram, Steam, браузер. Плюс контекстное меню Telegram.
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
Big(exe) {
    best := 0, area := -1
    for h in WinGetList("ahk_exe " exe) {
        try {
            if !(WinGetStyle("ahk_id " h) & 0x10000000) || (WinGetTitle("ahk_id " h) = "")
                continue
            WinGetPos(, , &w, &hh, "ahk_id " h)
            if (w * hh > area)
                area := w * hh, best := h
        }
    }
    return best
}

Out("========== настоящие приложения ==========")
; Полноэкранное окно (во весь монитор при MinMax=0 — например видео на
; YouTube) не годится: оно само возвращает свою геометрию и не двигается
; ни этой версией, ни версией до правок. Берём обычное.
NotFullscreen(exe) {
    for h in WinGetList("ahk_exe " exe) {
        try {
            if !(WinGetStyle("ahk_id " h) & 0x10000000) || (WinGetTitle("ahk_id " h) = "")
                continue
            if (WinGetMinMax("ahk_id " h) = -1)
                continue
            WinGetPos(, , &w, &hh, "ahk_id " h)
            full := false
            Loop MonitorGetCount() {
                MonitorGet(A_Index, &l, &t, &r, &b)
                if (WinGetMinMax("ahk_id " h) = 0 && Abs(w - (r - l)) <= 4 && Abs(hh - (b - t)) <= 4)
                    full := true
            }
            if !full
                return h
        }
    }
    return 0
}
code := Big("Code.exe"), tg := Big("Telegram.exe")
st   := Big("steamwebhelper.exe"), br := NotFullscreen("chrome.exe")
Out("  VS Code=" code "  Telegram=" tg "  Steam=" st "  Chrome=" br)
if (!code || !tg) {
    Out("  нет VS Code или Telegram — прогон прерван")
    ExitApp(1)
}
if (st && WinGetMinMax("ahk_id " st) = -1) {
    WinRestore("ahk_id " st)
    Sleep(700)
}
; Steam сидит в трее без окна — сам его не поднимаю, беру браузер.
third  := st ? st : br
thirdN := st ? "Steam" : "Chrome"
if !third {
    Out("  ни Steam, ни браузера — третье приложение не проверяется")
}

orig := Map()
orig[code] := PosOf(code), orig[tg] := PosOf(tg)
if third
    orig[third] := PosOf(third)

WinActivate("ahk_id " tg), Sleep(300), Send("^!+3"), Sleep(400)
if third {
    WinActivate("ahk_id " third), Sleep(300), Send("^!+4"), Sleep(400)
}
Out("  Telegram -> слот 3, " thirdN " -> слот 4, VS Code -> постоянный слот 1")

; --- каждый слот показывается с анимацией и убирается ---
plan := [["^!1", code, "VS Code"], ["^!3", tg, "Telegram"]]
if third
    plan.Push(["^!4", third, thirdN])
for item in plan {
    hk := item[1], h := item[2], nm := item[3]
    ; Привести к припаркованному состоянию. OnScreen сам по себе не годится:
    ; обычное неприпаркованное окно тоже «на экране», и одно нажатие его
    ; сперва выдвигает, а не прячет.
    Loop 3 {
        if !OnScreen(h)
            break
        Send(hk)
        WaitOn(h, false, 2500)
        Sleep(350)
    }
    Check(nm ": удалось припарковать перед тестом", !OnScreen(h), "x=" PosOf(h).x)

    Send(hk)
    moved := Track(h, 900)
    ok := WaitOn(h, true, 2500)
    Sleep(400)
    p := PosOf(h)
    Check(nm ": показ", ok, "x=" p.x " y=" p.y " " p.w "x" p.h)
    Check(nm ": анимация показа", moved > 4, "разных позиций " moved)
    Sleep(500)
    Send(hk)
    moved2 := Track(h, 900)
    Sleep(400)
    Check(nm ": уборка с анимацией", moved2 > 4, "разных позиций " moved2)
    Check(nm ": убрано за пределы экранов", !OnScreen(h), "x=" PosOf(h).x)
    Sleep(500)
}

; --- Telegram: контекстное меню не должно прятать панель ---
if !OnScreen(tg) {
    Send("^!3"), WaitOn(tg, true, 3500)
}
Sleep(900)
p := PosOf(tg)
MouseMove(p.x + p.w // 2, p.y + p.h // 2)
Sleep(200)
Click("Right")
Sleep(1600)
Check("Telegram: ПКМ не убрал панель", OnScreen(tg))
Send("{Escape}")
Sleep(500)

; --- быстрые чередующиеся хоткеи ---
Loop 20 {
    Send("^!1"), Sleep(45)
    Send("^!3"), Sleep(45)
    Send("^!4"), Sleep(45)
}
Sleep(4000)
Check("после быстрых хоткеев все окна живы",
      WinExist("ahk_id " code) && WinExist("ahk_id " tg) && (!third || WinExist("ahk_id " third)))

; --- быстрые переключения окон ---
Loop 20 {
    WinActivate("ahk_id " code), Sleep(45)
    WinActivate("ahk_id " tg),   Sleep(45)
    if third
        WinActivate("ahk_id " third), Sleep(45)
}
Sleep(2500)
Check("после быстрых переключений все окна живы",
      WinExist("ahk_id " code) && WinExist("ahk_id " tg) && (!third || WinExist("ahk_id " third)))

; --- выход возвращает окна ---
Send("^!+0")
Sleep(2500)
allBack := true, bad := ""
for h, o in orig {
    if !OnScreen(h) {
        allBack := false
        bad .= WinGetTitle("ahk_id " h) " "
    }
}
Check("после выхода все окна на экране", allBack, bad)

Out("ИТОГ приложений: проверок " checks ", провалов " fails)
Out("")
ExitApp(fails)
