#Requires AutoHotkey v2.0

; Политика и состояние слежения за фокусом, история предыдущего фокуса
; и наблюдение переднего плана. Физическое перемещение окон, геометрия
; парковки и кромки остаются в drawer.ahk.
class WindowFocusState {
    static watched   := Map()
    static prevFocus := Map()   ; hwnd -> prevHwnd
    static foreWnd   := 0       ; текущее окно переднего плана
    static lastFore  := 0       ; окно, бывшее активным до него
}

WindowFocusOpt(obj, key, def) {
    return IsObject(obj) && obj.HasOwnProp(key) ? obj.%key% : def
}

WindowFocusShouldActivate(cfg, forceActivate := false) {
    return forceActivate || WindowFocusOpt(cfg, "activateOnShow", true)
}

WindowWatchEligible(cfg, alreadyWatched := false) {
    return WindowFocusOpt(cfg, "hideOnBlur", true)
}

; candidates уже содержат по одной authoritative cfg для каждого живого
; выдвинутого HWND. SlotOf/SlotBound остаются ответственностью live adapter.
WindowWatchReconcile(priorWatched, candidates) {
    desired := Map()
    for item in candidates {
        hwnd := item.hwnd
        if desired.Has(hwnd)
            continue
        if WindowWatchEligible(item.cfg, priorWatched.Has(hwnd))
            desired[hwnd] := item.cfg
    }
    return desired
}

WindowWatchPeriod(watched, blurMs) {
    return watched.Count ? blurMs : 0
}

WindowWatched(hwnd) {
    return WindowFocusState.watched.Has(hwnd)
}

; ----------------- Focus history (prevFocus) -----------------

WindowFocusSetPrev(hwnd, prevHwnd) {
    if !hwnd
        return
    if prevHwnd
        WindowFocusState.prevFocus[hwnd] := prevHwnd
    else if WindowFocusState.prevFocus.Has(hwnd)
        WindowFocusState.prevFocus.Delete(hwnd)
}

WindowFocusGetPrev(hwnd) {
    return (hwnd && WindowFocusState.prevFocus.Has(hwnd)) ? WindowFocusState.prevFocus[hwnd] : 0
}

; ----------------- Foreground observation state -----------------

WindowFocusGetFore() {
    return WindowFocusState.foreWnd
}

WindowFocusGetLastFore() {
    return WindowFocusState.lastFore
}

WindowFocusInitFore(activeHwnd := 0) {
    WindowFocusState.foreWnd  := activeHwnd ? activeHwnd : (WinExist("A") || 0)
    WindowFocusState.lastFore := 0
}

; Фильтрация и дедупликация foreground-события.
; Возвращает true, если событие принято и переключило состояние (нужен таймер),
; и false, если отсеяно (служебное, чужой idObject или то же самое окно).
WindowFocusOnEvent(eventHwnd, idObject := 0) {
    if (idObject != 0 || !eventHwnd)
        return false
    if !TrackedFore(eventHwnd)
        return false
    if (eventHwnd = WindowFocusState.foreWnd)
        return false
    WindowFocusState.lastFore := WindowFocusState.foreWnd
    WindowFocusState.foreWnd  := eventHwnd
    return true
}

; ----------------- Focus & Watcher life cycle -----------------

; Полное забвение окна: и blur-watcher, и история предыдущего фокуса.
; Только для Release() — окно возвращается на исходное место и перестаёт
; быть нашим, помнить его прежний фокус больше незачем.
WindowFocusForget(hwnd) {
    if !hwnd
        return
    if WindowFocusState.watched.Has(hwnd)
        WindowFocusState.watched.Delete(hwnd)
    if WindowFocusState.prevFocus.Has(hwnd)
        WindowFocusState.prevFocus.Delete(hwnd)
}

; Снять только blur-watcher, сохранив историю предыдущего фокуса. Это и
; есть контракт A02S1 seam: Hide() и WatchBlur() убирают окно за край, но
; фокус ещё предстоит вернуть тому, кто работал до показа, поэтому
; prevFocus здесь трогать нельзя — его прочитает RestoreFocus следом.
; Историю чистит только WindowFocusForget из Release().
WatchForget(hwnd) {
    if WindowFocusState.watched.Has(hwnd)
        WindowFocusState.watched.Delete(hwnd)
}

Watch(hwnd, cfg) {
    global blurMs
    if !WindowFocusOpt(cfg, "hideOnBlur", true)
        return
    WindowFocusState.watched[hwnd] := cfg
    SetTimer(WatchBlur, blurMs)
}

; Проверка и, если нужно, Hide для одного watched-окна — общее тело для
; периодического WatchBlur и немедленного вызова из ForegroundWork при
; потере переднего плана (см. её вызов там). Один и тот же lifecycle,
; два триггера: событие даёт мгновенную реакцию, таймер остаётся
; страховкой на случаи без EVENT_SYSTEM_FOREGROUND (например, клик по
; пустому рабочему столу).
WatchBlurCheck(hwnd) {
    global state
    if !WindowFocusState.watched.Has(hwnd)
        return
    st := state.Has(hwnd) ? state[hwnd] : 0
    if (!st || !WinExist("ahk_id " hwnd) || !IsDeployed(hwnd, st)) {
        WatchForget(hwnd)
        return
    }
    if StillFocused(hwnd)
        return
    try Hide(hwnd, st)
}

WatchBlur() {
    Critical()
    watched := WindowFocusState.watched
    for hwnd in watched.Clone()
        WatchBlurCheck(hwnd)
    if !watched.Count
        SetTimer(WatchBlur, 0)
}

; Live adapter сохраняет permanent-first authority SlotOf(hwnd), фильтрует
; только живые выдвинутые окна и перевзводит таймер с текущим blurMs.
WatchSync() {
    global state, blurMs
    watched := WindowFocusState.watched
    candidates := []
    seen := Map()
    for item in SlotBound() {
        hwnd := item.hwnd
        if seen.Has(hwnd)
            continue
        seen[hwnd] := true
        st := state.Has(hwnd) ? state[hwnd] : 0
        if (!st || !WinExist("ahk_id " hwnd) || !IsDeployed(hwnd, st))
            continue
        cfg := SlotOf(hwnd)
        if cfg
            candidates.Push({ hwnd: hwnd, cfg: cfg })
    }
    WindowFocusState.watched := WindowWatchReconcile(watched, candidates)
    SetTimer(WatchBlur, WindowWatchPeriod(WindowFocusState.watched, blurMs))
}

; ----------------- Window Focus Predicates & Actions -----------------

; Настоящее ли это окно приложения. Переключатель Alt+Tab, панель задач
; и прочая оболочка тоже получают передний план, но выбором пользователя
; это не является.
TrackedFore(hwnd) {
    if !hwnd
        return false
    if IsServiceWindow(hwnd)     ; окно настроек ящик за смену окна не считает (Р18)
        return false
    try {
        if !WinExist("ahk_id " hwnd)
            return false
        if (WinGetTitle("ahk_id " hwnd) = "")
            return false
        cls := WinGetClass("ahk_id " hwnd)
        if (cls = "Progman" || cls = "WorkerW"
            || cls = "Shell_TrayWnd" || cls = "Shell_SecondaryTrayWnd"
            || cls = "XamlExplorerHostIslandWindow" || cls = "MultitaskingViewFrame")
            return false
        return !(WinGetExStyle("ahk_id " hwnd) & 0x00000080)    ; WS_EX_TOOLWINDOW
    }
    return false
}

; Не потеря фокуса, а всплывающее меню того же приложения: у Qt-программ
; (Telegram и подобных) контекстное меню — отдельное окно верхнего
; уровня, и на миг само становится передним планом, хотя пользователь
; никуда не уходил. У VS Code и Steam меню передний план не перехватывает
; вообще — там первая проверка (WinActive) отвечает сама. Отличаем
; всплывающее окно от честной потери фокуса тем же признаком, что уже
; использует TrackedFore() для служебных окон — WS_EX_TOOLWINDOW, — и
; только если оно принадлежит тому же процессу, что и слот: чужой
; тултип чужого приложения фокусом слота не считается.
StillFocused(hwnd) {
    if WinActive("ahk_id " hwnd)
        return true
    try {
        fore := WinExist("A")
        if !fore
            return false
        ; Уход в настройки — не потеря фокуса: иначе окно уезжало бы за
        ; край ровно в тот момент, когда пользователь открыл его настройки.
        ; Механика та же, что ниже для всплывающих меню.
        if IsServiceWindow(fore)
            return true
        if !(WinGetExStyle("ahk_id " fore) & 0x00000080)    ; WS_EX_TOOLWINDOW
            return false
        return WinGetPID("ahk_id " fore) = WinGetPID("ahk_id " hwnd)
    }
    return false
}

; Окно перестало быть активным потому, что исчезло, а не потому, что
; пользователь выбрал другое: закрыто, скрыто или свёрнуто.
Vanished(hwnd) {
    if (!hwnd || !WinExist("ahk_id " hwnd))
        return true
    return WinGetMinMax("ahk_id " hwnd) = -1
}

; Годится ли окно, чтобы отдать ему фокус. Проверка по факту: окно за
; пределами всех мониторов не годится, кем бы оно ни было припарковано.
;
; service — можно ли отдать фокус собственному окну настроек. По умолчанию
; нельзя: наугад выбирать настройки из Z-порядка значило бы вытаскивать их
; поверх работы. Но если пользователь нажал хоткей, СТОЯ в настройках, то
; вернуть фокус туда — единственно верное: иначе слот уезжает, а вместо
; настроек наверх выходит случайное чужое окно, и открытая форма пропадает.
FocusCandidate(hwnd, skip, service := false) {
    if (!hwnd || hwnd = skip)
        return false
    if (!service && IsServiceWindow(hwnd))
        return false
    try {
        if !WinExist("ahk_id " hwnd)
            return false
        if (WinGetMinMax("ahk_id " hwnd) = -1)
            return false
        if !(WinGetStyle("ahk_id " hwnd) & 0x10000000)      ; WS_VISIBLE
            return false
        if (WinGetTitle("ahk_id " hwnd) = "")
            return false
        cls := WinGetClass("ahk_id " hwnd)
        if (cls = "Progman" || cls = "WorkerW"
            || cls = "Shell_TrayWnd" || cls = "Shell_SecondaryTrayWnd")
            return false
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        return HitsMonitor(x, y, w, h)
    }
    return false
}

; Кто был активен перед показом. Само выезжающее окно, оболочка и то,
; что уже спрятано за краем, в кандидаты не годятся.
PrevActive(skip) {
    hwnd := WinExist("A")
    ; Настройки здесь допустимы: пользователь в них и стоял.
    return FocusCandidate(hwnd, skip, true) ? hwnd : 0
}

; Увести фокус с припаркованного окна на верхнее подходящее по Z-порядку.
RedirectFocus(parked) {
    for hwnd in WinGetList() {
        if FocusCandidate(hwnd, parked) {
            WinActivate("ahk_id " hwnd)
            return
        }
    }
}

; Припаркованное окно не должно остаться активным: ввод уходил бы в
; невидимое окно, а щелчок по значку на панели задач сворачивал бы его
; вместо активации. Возвращаем фокус тому, что работало до показа, а
; если его больше нет — верхнему подходящему окну по Z-порядку.
RestoreFocus(parked) {
    prev := WindowFocusGetPrev(parked)
    if FocusCandidate(prev, parked, true) {
        WinActivate("ahk_id " prev)
        return
    }
    RedirectFocus(parked)
}
