#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent()
SetWinDelay(-1)

; =========================== НАСТРОЙКИ ===========================
; exe    — имя процесса
; cls    — класс окна; "" если не важен
; side   — предпочитаемый край: "right" или "left".
;          Если с этой стороны стоит другой монитор, программа выберет
;          противоположный край сама — иначе спрятанное окно было бы видно.
; width  — ширина панели в процентах от рабочей области монитора
apps := [
    { name: "VS Code",  exe: "Code.exe",       cls: "Chrome_WidgetWin_1", side: "right", width: 60 },
    { name: "PhpStorm", exe: "phpstorm64.exe", cls: "SunAwtFrame",        side: "right", width: 60 }
]

animMs    := 160    ; длительность анимации, мс
animSteps := 14     ; 0 — выключить анимацию
; =================================================================

managed := Map()    ; индекс приложения -> hwnd
state   := Map()    ; hwnd -> состояние

^!1::Toggle(1)
^!2::Toggle(2)
^!3::Toggle(3)
^!0::ExitApp()          ; выход: окна вернутся на исходные места

OnExit(Cleanup)

Toggle(i) {
    global apps, managed, state
    if (i > apps.Length)
        return
    a := apps[i]

    ; Захваченное окно помним: после того как оно спрятано,
    ; поиском по видимым окнам его уже не найти.
    hwnd := 0
    if (managed.Has(i) && WinExist("ahk_id " managed[i]))
        hwnd := managed[i]
    else
        hwnd := FindWindow(a)

    if !hwnd {
        TrayTip("Окно не найдено: " a.name, "Ящик", 2)
        return
    }
    managed[i] := hwnd

    if !state.Has(hwnd) {
        WinGetPos(&ox, &oy, &ow, &oh, "ahk_id " hwnd)
        state[hwnd] := { shown: false, ox: ox, oy: oy, ow: ow, oh: oh, geom: 0 }
    }
    st := state[hwnd]

    if IsShown(hwnd, st) {
        g := st.geom
        if g.slide
            Slide(hwnd, g.sx, g.hx, g.y, g.w, g.h)
        try WinMove(g.park, g.y, g.w, g.h, "ahk_id " hwnd)   ; за пределы всех мониторов
        st.shown := false
        return
    }

    if (WinGetMinMax("ahk_id " hwnd) != 0)
        WinRestore("ahk_id " hwnd)

    GetWorkArea(&L, &T, &R, &B)
    side := a.side
    if HasNeighbor(side, L, T, R, B)
        side := (side = "right") ? "left" : "right"
    doSlide := !HasNeighbor(side, L, T, R, B)   ; соседа нет — анимация уходит за настоящий край

    w  := Integer((R - L) * a.width / 100)
    h  := B - T
    sx := (side = "right") ? R - w : L
    hx := (side = "right") ? R     : L - w
    ; Точка парковки заведомо вне всех мониторов, в ту же сторону, куда уезжает окно.
    vL := SysGet(76), vW := SysGet(78)
    park := (side = "right") ? vL + vW + 20 : vL - w - 20
    st.geom := { sx: sx, hx: hx, y: T, w: w, h: h, slide: doSlide, park: park }

    WinMove(doSlide ? hx : sx, T, w, h, "ahk_id " hwnd)
    WinActivate("ahk_id " hwnd)
    if doSlide
        Slide(hwnd, hx, sx, T, w, h)
    st.shown := true
}

; Выдвинуто ли окно на самом деле. Пользователь мог свернуть его руками
; или перетащить — тогда сохранённое состояние врёт, и по хоткею надо
; показывать окно, а не прятать уже спрятанное.
IsShown(hwnd, st) {
    if !st.shown
        return false
    if (WinGetMinMax("ahk_id " hwnd) != 0)
        return false
    WinGetPos(&x, , &w, , "ahk_id " hwnd)
    vL := SysGet(76), vW := SysGet(78)
    if (x >= vL + vW || x + w <= vL)        ; целиком за пределами мониторов
        return false
    return true
}

; Настоящее окно приложения: видимое, с заголовком, разумного размера.
; Служебные окна JetBrains без заголовка отсеиваются здесь.
FindWindow(a) {
    best := 0, bestArea := -1
    for hwnd in WinGetList("ahk_exe " a.exe) {
        try {
            if !(WinGetStyle("ahk_id " hwnd) & 0x10000000)      ; WS_VISIBLE
                continue
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

; Есть ли монитор, примыкающий к указанному краю текущего.
HasNeighbor(side, L, T, R, B) {
    Loop MonitorGetCount() {
        MonitorGet(A_Index, &l, &t, &r, &b)
        if (l = L && r = R)                       ; это мы сами
            continue
        if (b <= T || t >= B)                     ; не пересекается по вертикали
            continue
        if (side = "right" && l >= R)
            return true
        if (side = "left" && r <= L)
            return true
    }
    return false
}

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
        e := 1 - (1 - t) ** 3
        try WinMove(Round(fromX + (toX - fromX) * e), y, w, h, "ahk_id " hwnd)
        Sleep(delay)
    }
    try WinMove(toX, y, w, h, "ahk_id " hwnd)
}

; При выходе возвращаем окна на исходные места, чтобы ничего
; не осталось за пределами экранов.
Cleanup(*) {
    global state
    for hwnd, st in state
        try WinMove(st.ox, st.oy, st.ow, st.oh, "ahk_id " hwnd)
}
