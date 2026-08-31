#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent()
SetWinDelay(-1)

; =========================== НАСТРОЙКИ ===========================
; exe    — имя процесса
; cls    — класс окна; "" если не важен
; side   — "right" или "left": из-за какого края выезжает
; width  — ширина панели в процентах от рабочей области монитора
apps := [
    { name: "VS Code",  exe: "Code.exe",       cls: "Chrome_WidgetWin_1", side: "right", width: 60 },
    { name: "PhpStorm", exe: "phpstorm64.exe", cls: "SunAwtFrame",        side: "right", width: 60 }
]

animMs    := 160    ; длительность анимации, мс
animSteps := 14     ; 0 — выключить анимацию
; =================================================================

state := Map()      ; hwnd -> состояние окна

^!1::Toggle(1)
^!2::Toggle(2)
^!3::Toggle(3)

OnExit(Cleanup)

Toggle(i) {
    global apps, state
    if (i > apps.Length)
        return

    a := apps[i]
    hwnd := FindWindow(a)
    if !hwnd {
        TrayTip("Окно не найдено: " a.name, "Ящик", 2)
        return
    }

    if !state.Has(hwnd) {
        WinGetPos(&ox, &oy, &ow, &oh, "ahk_id " hwnd)
        state[hwnd] := { shown: false, ox: ox, oy: oy, ow: ow, oh: oh, geom: 0 }
    }
    st := state[hwnd]

    ; Уезжаем: геометрия уже посчитана при выезде.
    if st.shown {
        g := st.geom
        Slide(hwnd, g.sx, g.hx, g.y, g.w, g.h)
        st.shown := false
        return
    }

    ; Свёрнутое или развёрнутое окно двигать нельзя — приводим к обычному.
    if (WinGetMinMax("ahk_id " hwnd) != 0)
        WinRestore("ahk_id " hwnd)

    GetWorkArea(&L, &T, &R, &B)
    w  := Integer((R - L) * a.width / 100)
    h  := B - T
    sx := (a.side = "right") ? R - w : L          ; позиция на экране
    hx := (a.side = "right") ? R     : L - w      ; позиция за краем
    st.geom := { sx: sx, hx: hx, y: T, w: w, h: h }

    WinMove(hx, T, w, h, "ahk_id " hwnd)
    WinActivate("ahk_id " hwnd)
    Slide(hwnd, hx, sx, T, w, h)
    st.shown := true
}

; Настоящее окно приложения: с заголовком и разумного размера.
; Служебные окна JetBrains без заголовка отсеиваются здесь — на них падал WTQ.
FindWindow(a) {
    best := 0, bestArea := -1
    for hwnd in WinGetList("ahk_exe " a.exe) {
        try {
            if (a.cls != "" && WinGetClass("ahk_id " hwnd) != a.cls)
                continue
            if (WinGetTitle("ahk_id " hwnd) = "")
                continue
            WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
            if (WinGetMinMax("ahk_id " hwnd) = 0 && (w < 200 || h < 200))
                continue
            if (w * h > bestArea) {
                bestArea := w * h
                best := hwnd
            }
        }
    }
    return best
}

; Рабочая область монитора, на котором сейчас курсор.
GetWorkArea(&L, &T, &R, &B) {
    MouseGetPos(&mx, &my)
    Loop MonitorGetCount() {
        MonitorGetWorkArea(A_Index, &l, &t, &r, &b)
        if (mx >= l && mx < r && my >= t && my < b) {
            L := l, T := t, R := r, B := b
            return
        }
    }
    MonitorGetWorkArea(MonitorGetPrimary(), &L, &T, &R, &B)
}

Slide(hwnd, fromX, toX, y, w, h) {
    global animSteps, animMs
    if (animSteps < 1) {
        try WinMove(toX, y, w, h, "ahk_id " hwnd)
        return
    }
    delay := Max(1, animMs // animSteps)
    Loop animSteps {
        t := A_Index / animSteps
        e := 1 - (1 - t) ** 3                     ; плавное замедление к концу
        try WinMove(Round(fromX + (toX - fromX) * e), y, w, h, "ahk_id " hwnd)
        Sleep(delay)
    }
    try WinMove(toX, y, w, h, "ahk_id " hwnd)
}

; При выходе возвращаем окна туда, где они были. Без этого закрытие
; программы оставило бы окно за краем экрана — так вело себя WTQ.
Cleanup(*) {
    global state
    for hwnd, st in state
        try WinMove(st.ox, st.oy, st.ow, st.oh, "ahk_id " hwnd)
}
