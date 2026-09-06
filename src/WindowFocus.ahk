#Requires AutoHotkey v2.0

; Политика и состояние слежения за фокусом. Физическое перемещение окон,
; геометрия парковки и кромки остаются в drawer.ahk.
class WindowFocusState {
    static watched := Map()
}

WindowFocusOpt(obj, key, def) {
    return IsObject(obj) && obj.HasOwnProp(key) ? obj.%key% : def
}

WindowFocusShouldActivate(cfg, forceActivate := false) {
    return forceActivate || WindowFocusOpt(cfg, "activateOnShow", true)
}

WindowWatchEligible(cfg, alreadyWatched := false) {
    return WindowFocusOpt(cfg, "hideOnBlur", true)
        && (alreadyWatched || WindowFocusOpt(cfg, "activateOnShow", true))
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

Watch(hwnd, cfg) {
    global blurMs
    if !WindowFocusOpt(cfg, "hideOnBlur", true)
        return
    WindowFocusState.watched[hwnd] := cfg
    SetTimer(WatchBlur, blurMs)
}

WatchForget(hwnd) {
    if WindowFocusState.watched.Has(hwnd)
        WindowFocusState.watched.Delete(hwnd)
}

WatchBlur() {
    global state
    Critical()
    watched := WindowFocusState.watched
    for hwnd in watched.Clone() {
        st := state.Has(hwnd) ? state[hwnd] : 0
        if (!st || !WinExist("ahk_id " hwnd) || !IsDeployed(hwnd, st)) {
            WatchForget(hwnd)
            continue
        }
        if StillFocused(hwnd)
            continue
        try Hide(hwnd, st)
    }
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
