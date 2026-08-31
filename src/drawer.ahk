#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent()
SetWinDelay(-1)
CoordMode("Mouse", "Screen")   ; по умолчанию v2 отдаёт координаты активного окна

; =========================== НАСТРОЙКИ ===========================
; Слот — номер от 1 до 9. Хоткеи слота заданы номером и не настраиваются:
;   Ctrl+Alt+N        — выдвинуть / убрать окно слота
;   Ctrl+Alt+Shift+N  — запомнить в слоте текущее активное окно
;   Ctrl+Alt+0        — очистить все динамические слоты
;   Ctrl+Alt+Shift+0  — выход, окна возвращаются на исходные места
;
; Постоянные слоты: приложение ищется по процессу при каждом нажатии,
; переживает перезапуск программы, назначить в такой слот другое окно
; нельзя.
;
; slot           — номер слота, 1…9
; name           — как приложение называется в уведомлениях
; exe            — имя процесса
; cls            — класс окна; "" если не важен
; focusHotkey    — вернуть фокус: выдвинуть, если спрятано, и активировать.
;                  "" — выключено. Сочетания Ctrl+Alt+Shift+N заняты
;                  назначением слотов, поэтому по умолчанию Ctrl+Alt+Win+N
; monitor        — "cursor" (монитор под курсором) или номер монитора: 1, 2, 3…
; edge           — сторона выезда: "left", "right", "top", "bottom"
; width          — размер панели в процентах от рабочей области монитора:
;                  для left/right это ширина, для top/bottom — высота
; activateOnShow — делать окно активным при выезде
; hideOnBlur     — убирать окно, когда фокус ушёл в другое окно.
;                  Работает только вместе с activateOnShow: окно, которое
;                  не получало фокуса, не может его потерять
apps := [
    { slot: 1, name: "VS Code",  exe: "Code.exe",       cls: "Chrome_WidgetWin_1",
      focusHotkey: "^!#1",
      monitor: "cursor", edge: "right", width: 60,
      activateOnShow: true, hideOnBlur: true },
    { slot: 2, name: "PhpStorm", exe: "phpstorm64.exe", cls: "SunAwtFrame",
      focusHotkey: "^!#2",
      monitor: "cursor", edge: "right", width: 60,
      activateOnShow: true, hideOnBlur: true }
]

; Динамические слоты: свободные номера, в которые окно назначается на
; ходу. Запоминается дескриптор конкретного окна, а не приложение.
; Привязки живут до очистки или до перезапуска программы.
dynamic := { name: "Слот",
             monitor: "cursor", edge: "right", width: 60,
             activateOnShow: true, hideOnBlur: true }

; Персональные настройки отдельного слота, если понадобятся. Поля, не
; указанные здесь, берутся из dynamic. Пример:
;   dynamicSlots[5] := { edge: "left", width: 40 }
dynamicSlots := Map()

animMs     := 160     ; длительность анимации, мс
animSteps  := 14      ; 0 — выключить анимацию
blurMs     := 250     ; как часто проверять потерю фокуса, мс
; =================================================================

managed   := Map()   ; индекс приложения -> hwnd
state     := Map()   ; hwnd -> { orig, geom }
watched   := Map()   ; выдвинутые окна с hideOnBlur: hwnd -> настройки
permSlots := Map()   ; номер слота -> индекс в apps
dynSlots  := Map()   ; номер слота -> hwnd

; Хоткеи ставятся через клавиатурный хук ($). RegisterHotkey отдаёт
; комбинацию первому, кто её занял: если предыдущий экземпляр ещё не
; умер, новый молча остаётся без клавиш — процесс жив, хоткеи мертвы.
; Хук от этого не зависит.
for i, a in apps {
    if !(a.slot >= 1 && a.slot <= 9)
        MsgBox("У " a.name " номер слота " a.slot ", а слоты только 1…9", "Ящик")
    else if permSlots.Has(a.slot)
        MsgBox("Слот " a.slot " занят дважды: " apps[permSlots[a.slot]].name " и " a.name, "Ящик")
    else
        permSlots[a.slot] := i
}

live := 0
Loop 9 {
    n := A_Index
    try {
        Hotkey(Hooked("^!" n), OnSlot.Bind(n))
        live++
    } catch as e
        MsgBox("Хоткей слота " n " не назначен:`n" e.Message, "Ящик")
    try {
        Hotkey(Hooked("^!+" n), OnSlotBind.Bind(n))
        live++
    } catch as e
        MsgBox("Хоткей назначения слота " n " не назначен:`n" e.Message, "Ящик")
}
for i, a in apps {
    if (Opt(a, "focusHotkey", "") = "")
        continue
    try {
        Hotkey(Hooked(a.focusHotkey), OnFocusHotkey.Bind(i))
        live++
    } catch as e
        MsgBox("Хоткей фокуса " a.focusHotkey " (" a.name ") не назначен:`n" e.Message, "Ящик")
}
try {
    Hotkey(Hooked("^!0"), OnClearHotkey)
    live++
} catch as e
    MsgBox("Хоткей очистки слотов не назначен:`n" e.Message, "Ящик")
try {
    Hotkey(Hooked("^!+0"), (*) => ExitApp())
    live++
} catch as e
    MsgBox("Хоткей выхода не назначен:`n" e.Message, "Ящик")

OnExit(Cleanup)
TrayTip("Хоткеев живо: " live, "Ящик запущен", 1)

Hooked(hk) {
    return (SubStr(hk, 1, 1) = "$") ? hk : "$" hk
}

; Настройка приложения со значением по умолчанию: запись в apps можно
; писать короткой, не перечисляя всё.
Opt(cfg, name, def) {
    return cfg.HasOwnProp(name) ? cfg.%name% : def
}

; Ошибка на одном окне не должна ронять программу целиком — N2.
OnSlot(n, *) {
    try
        ToggleSlot(n)
    catch as e
        TrayTip("Сбой: " e.Message, "Ящик", 3)
}

OnSlotBind(n, *) {
    try
        BindSlot(n)
    catch as e
        TrayTip("Сбой: " e.Message, "Ящик", 3)
}

OnClearHotkey(*) {
    try
        ClearDynamic()
    catch as e
        TrayTip("Сбой: " e.Message, "Ящик", 3)
}

OnFocusHotkey(i, *) {
    try
        FocusApp(i)
    catch as e
        TrayTip("Сбой: " e.Message, "Ящик", 3)
}

; Слот: постоянный ищет своё приложение по процессу, динамический
; управляет запомненным окном.
ToggleSlot(n) {
    global permSlots, dynSlots
    if permSlots.Has(n) {
        ToggleApp(permSlots[n])
        return
    }
    if !dynSlots.Has(n) {
        TrayTip("Слот " n " пуст", "Ящик", 2)
        return
    }
    hwnd := dynSlots[n]
    if !WinExist("ahk_id " hwnd) {
        dynSlots.Delete(n)
        Release(hwnd)
        TrayTip("Окно слота " n " закрыто, слот освобождён", "Ящик", 2)
        return
    }
    ToggleWindow(hwnd, SlotCfg(n))
}

; Назначение слота: запоминается дескриптор конкретного окна, а не
; приложение. Постоянный слот перезаписать нельзя — иначе настройка из
; файла молча потерялась бы до перезапуска.
BindSlot(n) {
    global apps, permSlots, dynSlots
    if permSlots.Has(n) {
        TrayTip("Слот " n " занят постоянной привязкой: " apps[permSlots[n]].name, "Ящик", 2)
        return
    }
    if !(hwnd := PickActive()) {
        TrayTip("Активное окно не годится для ящика", "Ящик", 2)
        return
    }
    if (dynSlots.Has(n) && dynSlots[n] != hwnd)
        Release(dynSlots[n])          ; прежнее окно возвращаем на место
    dynSlots[n] := hwnd
    TrayTip("Слот " n ": " WinGetTitle("ahk_id " hwnd), "Ящик", 1)
}

; Очистка динамических слотов. Постоянные не трогаем, программа
; продолжает работать — это не выход.
ClearDynamic() {
    global dynSlots
    for n, hwnd in dynSlots
        Release(hwnd)
    dynSlots.Clear()
    TrayTip("Динамические привязки очищены", "Ящик", 1)
}

; Отпустить окно: вернуть на исходное место и забыть о нём. Окна,
; которого уже нет, это не касается — WinMove просто не сработает.
Release(hwnd) {
    global state, watched
    if watched.Has(hwnd)
        watched.Delete(hwnd)
    if !state.Has(hwnd)
        return
    st := state[hwnd]
    if st.orig
        try WinMove(st.orig.x, st.orig.y, st.orig.w, st.orig.h, "ahk_id " hwnd)
    state.Delete(hwnd)
}

; Настройки динамического слота: общие, поверх которых кладутся
; персональные, если для этого номера они заданы.
SlotCfg(n) {
    global dynamic, dynamicSlots
    if !dynamicSlots.Has(n)
        return dynamic
    own := dynamicSlots[n]
    return { name:           Opt(own, "name",           dynamic.name),
             monitor:        Opt(own, "monitor",        dynamic.monitor),
             edge:           Opt(own, "edge",           dynamic.edge),
             width:          Opt(own, "width",          dynamic.width),
             activateOnShow: Opt(own, "activateOnShow", dynamic.activateOnShow),
             hideOnBlur:     Opt(own, "hideOnBlur",     dynamic.hideOnBlur) }
}

; Постоянный слот: окно ищется по настройкам приложения.
ToggleApp(i) {
    global apps
    a := apps[i]
    if !(hwnd := AppWindow(i, a)) {
        TrayTip("Окно не найдено: " a.name, "Ящик", 2)
        return
    }
    ToggleWindow(hwnd, a)
}

FocusApp(i) {
    global apps
    a := apps[i]
    if !(hwnd := AppWindow(i, a)) {
        TrayTip("Окно не найдено: " a.name, "Ящик", 2)
        return
    }
    FocusWindow(hwnd, a)
}

; Захваченное окно помним: припаркованное окно поиском по площади
; можно спутать с другим окном того же приложения.
AppWindow(i, a) {
    global managed
    hwnd := (managed.Has(i) && WinExist("ahk_id " managed[i])) ? managed[i] : FindWindow(a)
    if hwnd
        managed[i] := hwnd
    return hwnd
}

; Окно, которое назначается в слот, — активное сейчас. Рабочий стол и
; панель задач не берём: их парковка сломала бы оболочку Windows.
PickActive() {
    if !(hwnd := WinExist("A"))
        return 0
    cls := WinGetClass("ahk_id " hwnd)
    if (cls = "Progman" || cls = "WorkerW"
        || cls = "Shell_TrayWnd" || cls = "Shell_SecondaryTrayWnd")
        return 0
    if (WinGetTitle("ahk_id " hwnd) = "")
        return 0
    WinGetPos(, , &w, &h, "ahk_id " hwnd)
    if (WinGetMinMax("ahk_id " hwnd) = 0 && (w < 200 || h < 200))
        return 0
    return hwnd
}

; Общая часть обоих ящиков: выдвинуть окно или убрать его.
; Critical — чтобы таймер потери фокуса не влез в середину анимации.
ToggleWindow(hwnd, cfg) {
    Critical()
    st := StateOf(hwnd)
    if IsDeployed(hwnd, st)
        Hide(hwnd, st)
    else
        Show(hwnd, cfg, st)
}

; Вернуть фокус. Новой привязки не создаёт; уже выдвинутое окно не
; двигает, поэтому и монитор панели не меняется.
FocusWindow(hwnd, cfg) {
    Critical()
    st := StateOf(hwnd)
    if !IsDeployed(hwnd, st) {
        Show(hwnd, cfg, st, true)
        return
    }
    WinActivate("ahk_id " hwnd)
    Watch(hwnd, cfg)
}

StateOf(hwnd) {
    global state
    if !state.Has(hwnd)
        state[hwnd] := { orig: 0, geom: 0 }
    return state[hwnd]
}

; forceActivate — вызов из хоткея фокуса: он активирует окно даже при
; activateOnShow: false, иначе от него не было бы смысла.
Show(hwnd, cfg, st, forceActivate := false) {
    if (WinGetMinMax("ahk_id " hwnd) != 0)
        WinRestore("ahk_id " hwnd)

    mi := ResolveMonitor(cfg)
    if !st.orig
        st.orig := CaptureOrigin(hwnd, mi)

    st.geom := ComputeGeom(cfg, mi)
    g := st.geom
    WinMove(g.slide ? g.hx : g.sx, g.slide ? g.hy : g.sy, g.w, g.h, "ahk_id " hwnd)

    activate := forceActivate || Opt(cfg, "activateOnShow", true)
    if activate
        WinActivate("ahk_id " hwnd)
    else
        WinMoveTop("ahk_id " hwnd)   ; наверх, но фокус остаётся у пользователя

    if g.slide
        Slide(hwnd, g.hx, g.hy, g.sx, g.sy, g.w, g.h)
    if activate
        Watch(hwnd, cfg)
}

Hide(hwnd, st) {
    global watched
    if watched.Has(hwnd)
        watched.Delete(hwnd)
    g := st.geom
    if g.slide
        Slide(hwnd, g.sx, g.sy, g.hx, g.hy, g.w, g.h)
    WinMove(g.px, g.py, g.w, g.h, "ahk_id " hwnd)   ; парковка вне всех мониторов
}

; Слежение за потерей фокуса. Таймер живёт только пока есть выдвинутое
; окно с hideOnBlur: в покое программа не делает ничего.
Watch(hwnd, cfg) {
    global watched, blurMs
    if !Opt(cfg, "hideOnBlur", true)
        return
    watched[hwnd] := cfg
    SetTimer(WatchBlur, blurMs)
}

; Убираем только то окно, которое выдвинул Ящик и которое он же
; активировал. Обычные окна таймер не трогает.
WatchBlur() {
    global watched, state
    for hwnd in watched.Clone() {
        st := state.Has(hwnd) ? state[hwnd] : 0
        if (!st || !WinExist("ahk_id " hwnd) || !IsDeployed(hwnd, st)) {
            watched.Delete(hwnd)
            continue
        }
        if WinActive("ahk_id " hwnd)
            continue
        try Hide(hwnd, st)
    }
    if !watched.Count
        SetTimer(WatchBlur, 0)
}

; Выдвинуто ли окно на самом деле. Пользователь мог свернуть его,
; перетащить или изменить размер — тогда по хоткею надо показывать
; окно, а не прятать то, что и так не на месте.
IsDeployed(hwnd, st) {
    if !st.geom
        return false
    if (WinGetMinMax("ahk_id " hwnd) != 0)
        return false
    WinGetPos(&x, &y, , , "ahk_id " hwnd)
    return (Abs(x - st.geom.sx) <= 4 && Abs(y - st.geom.sy) <= 4)
}

; Монитор из настройки. Номер отключённого монитора не ошибка:
; работаем на мониторе под курсором, чтобы хоткей не переставал работать.
ResolveMonitor(a) {
    n := MonitorGetCount()
    if (a.monitor != "cursor") {
        if !IsInteger(a.monitor)
            throw ValueError('monitor: ожидается "cursor" или номер монитора, задано: ' a.monitor)
        if (a.monitor >= 1 && a.monitor <= n)
            return a.monitor
    }
    MouseGetPos(&mx, &my)
    Loop n {
        MonitorGet(A_Index, &l, &t, &r, &b)
        if (mx >= l && mx < r && my >= t && my < b)
            return A_Index
    }
    return MonitorGetPrimary()
}

; Геометрия панели: sx,sy — выдвинуто, hx,hy — конец анимации у самого
; края монитора, px,py — парковка за границей виртуального стола.
; Край берётся из настройки как есть и никогда не меняется программой.
ComputeGeom(a, mi) {
    MonitorGetWorkArea(mi, &L, &T, &R, &B)
    vL := SysGet(76), vT := SysGet(77), vW := SysGet(78), vH := SysGet(79)
    pct := Min(100, Max(5, a.width))

    switch a.edge {
    case "right":
        w := Integer((R - L) * pct / 100), h := B - T
        sx := R - w, sy := T, hx := R, hy := T
        px := vL + vW + 20, py := T
    case "left":
        w := Integer((R - L) * pct / 100), h := B - T
        sx := L, sy := T, hx := L - w, hy := T
        px := vL - w - 20, py := T
    case "bottom":
        w := R - L, h := Integer((B - T) * pct / 100)
        sx := L, sy := B - h, hx := L, hy := B
        px := L, py := vT + vH + 20
    case "top":
        w := R - L, h := Integer((B - T) * pct / 100)
        sx := L, sy := T, hx := L, hy := T - h
        px := L, py := vT - h - 20
    default:
        throw ValueError('edge: ожидается "left", "right", "top" или "bottom", задано: ' a.edge)
    }

    ; Анимация уводит окно за край монитора. Если там стоит соседний
    ; монитор, окно проехало бы по нему на виду — тогда анимации нет,
    ; окно паркуется сразу.
    return { sx: sx, sy: sy, hx: hx, hy: hy, px: px, py: py, w: w, h: h,
             slide: !HitsMonitor(hx, hy, w, h, mi) }
}

; Пересекается ли прямоугольник хоть с одним монитором. skip — номер
; монитора, который не учитывать.
HitsMonitor(x, y, w, h, skip := 0) {
    Loop MonitorGetCount() {
        if (A_Index = skip)
            continue
        MonitorGet(A_Index, &l, &t, &r, &b)
        if (x < r && x + w > l && y < b && y + h > t)
            return true
    }
    return false
}

; Исходное положение — то, куда окно вернётся при выходе. Если окно
; осталось припарковано от прошлого экземпляра (программу убили),
; запоминать эти координаты нельзя: выход отправил бы окно за экраны.
CaptureOrigin(hwnd, mi) {
    WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
    if HitsMonitor(x, y, w, h)
        return { x: x, y: y, w: w, h: h }
    MonitorGetWorkArea(mi, &L, &T, &R, &B)
    return { x: L + (R - L) // 10, y: T + (B - T) // 10,
             w: (R - L) * 8 // 10, h: (B - T) * 8 // 10 }
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

Slide(hwnd, fromX, fromY, toX, toY, w, h) {
    global animSteps, animMs
    if (animSteps < 1) {
        try WinMove(toX, toY, w, h, "ahk_id " hwnd)
        return
    }
    delay := Max(1, animMs // animSteps)
    Loop animSteps {
        t := A_Index / animSteps
        e := 1 - (1 - t) ** 3
        try WinMove(Round(fromX + (toX - fromX) * e), Round(fromY + (toY - fromY) * e),
                    w, h, "ahk_id " hwnd)
        Sleep(delay)
    }
    try WinMove(toX, toY, w, h, "ahk_id " hwnd)
}

; При выходе возвращаем окна на исходные места, чтобы ничего
; не осталось за пределами экранов.
Cleanup(*) {
    global state
    for hwnd, st in state {
        if st.orig
            try WinMove(st.orig.x, st.orig.y, st.orig.w, st.orig.h, "ahk_id " hwnd)
    }
}
