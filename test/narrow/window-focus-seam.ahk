#Requires AutoHotkey v2.0

; ---- Test stubs (narrow-test env — no real windows) ----
IsServiceWindow(hwnd) => false    ; stub: no service windows in unit context
HitsMonitor(x, y, w, h) => false  ; stub: no monitors in unit context

#Include ..\..\src\WindowFocus.ahk

results := []
Assert(name, cond) {
    global results
    results.Push([name, cond])
}

Reconcile(prior, candidates, blurMs, &period) {
    desired := WindowWatchReconcile(prior, candidates)
    period := WindowWatchPeriod(desired, blurMs)
    return desired
}

Assert("forceActivate побеждает activateOnShow=false",
    WindowFocusShouldActivate({ activateOnShow: false }, true))
Assert("обычный non-activating Show не активирует окно",
    !WindowFocusShouldActivate({ activateOnShow: false }))

prior := Map()
period := -1
desired := Reconcile(prior,
    [{ hwnd: 101, cfg: { hideOnBlur: true, activateOnShow: false } }], 250, &period)
Assert("non-activating Show не получает watcher при reconcile",
    !desired.Has(101) && period = 0)

focusedCfg := { hideOnBlur: true, activateOnShow: false, marker: "updated" }
prior := Map(101, { hideOnBlur: true, activateOnShow: false })
desired := Reconcile(prior, [{ hwnd: 101, cfg: focusedCfg }], 400, &period)
Assert("FocusWindow watcher сохраняется и получает актуальный cfg",
    desired.Has(101) && desired[101].marker = "updated" && period = 400)

prior := Map(101, { hideOnBlur: true })
desired := Reconcile(prior,
    [{ hwnd: 101, cfg: { hideOnBlur: false, activateOnShow: true } }], 250, &period)
Assert("hideOnBlur true -> false удаляет watcher и гасит таймер",
    !desired.Has(101) && period = 0)

prior := Map()
desired := Reconcile(prior,
    [{ hwnd: 101, cfg: { hideOnBlur: true, activateOnShow: true } }], 100, &period)
Assert("hideOnBlur false -> true добавляет активируемое окно",
    desired.Has(101) && period = 100)

desired := Reconcile(desired,
    [{ hwnd: 101, cfg: { hideOnBlur: true, activateOnShow: true } }], 2000, &period)
Assert("blurMs перевзводится в обе стороны",
    desired.Has(101) && period = 2000)

prior := Map(101, { hideOnBlur: true }, 102, { hideOnBlur: true })
desired := Reconcile(prior,
    [{ hwnd: 102, cfg: { hideOnBlur: true, activateOnShow: true } }], 350, &period)
Assert("stale watcher удаляется независимо от валидного",
    !desired.Has(101) && desired.Has(102) && desired.Count = 1 && period = 350)

; Live adapter передаёт сюда уже authoritative permanent-first cfg.
prior := Map(101, { hideOnBlur: true })
desired := Reconcile(prior,
    [{ hwnd: 101, cfg: { hideOnBlur: false, activateOnShow: true } }], 250, &period)
Assert("authoritative permanent cfg снимает duplicate-HWND watcher",
    !desired.Has(101) && period = 0)

; ---- A02S2: focus history (SetPrev / GetPrev / Forget) ----
WindowFocusSetPrev(201, 300)
Assert("SetPrev записывает prevFocus для HWND",
    WindowFocusGetPrev(201) = 300)

WindowFocusSetPrev(201, 0)
Assert("SetPrev(0) очищает запись prevFocus",
    WindowFocusGetPrev(201) = 0)

WindowFocusSetPrev(202, 400)
WindowFocusForget(202)
Assert("Forget удаляет prevFocus",
    WindowFocusGetPrev(202) = 0)

WindowFocusSetPrev(203, 500)
WindowFocusState.watched[203] := { hideOnBlur: true }
WindowFocusForget(203)
Assert("Forget удаляет и watched, и prevFocus",
    !WindowFocusState.watched.Has(203) && WindowFocusGetPrev(203) = 0)

; ---- A02S2: foreground observation (WindowFocusOnEvent) ----
WindowFocusInitFore(0)

; zero hwnd → rejected
Assert("WindowFocusOnEvent отвергает hwnd=0",
    !WindowFocusOnEvent(0))

; non-zero idObject → rejected
Assert("WindowFocusOnEvent отвергает idObject≠0",
    !WindowFocusOnEvent(99, 1))

; TrackedFore(non-existent hwnd) = false in unit env → rejected
Assert("WindowFocusOnEvent отвергает несуществующее окно",
    !WindowFocusOnEvent(99999))

; If accepted, same hwnd again → dedup (not re-accepted)
WindowFocusState.foreWnd := 0   ; reset
; We can only test dedup once a real hwnd is in state
WindowFocusState.foreWnd := 777
Assert("WindowFocusOnEvent отвергает повтор текущего foreWnd",
    !WindowFocusOnEvent(777))

; ---- A02S2: Vanished predicate ----
Assert("Vanished(0) = true — нулевой hwnd исчез",
    Vanished(0))
Assert("Vanished(несуществующее) = true",
    Vanished(99999999))

; ---- A02S2: FocusCandidate guards ----
Assert("FocusCandidate(0, skip) = false",
    !FocusCandidate(0, 1))
Assert("FocusCandidate(hwnd, hwnd) = false — skip совпадает",
    !FocusCandidate(5, 5))


out := ""
allOk := true
for result in results {
    ok := result[2]
    allOk := allOk && ok
    out .= (ok ? "OK   " : "FAIL ") result[1] "`n"
}
out .= allOk ? "`nВСЕ ПРОВЕРКИ ПРОШЛИ`n" : "`nЕСТЬ ПРОВАЛЫ`n"
try FileAppend(out, "*")
ExitApp(allOk ? 0 : 1)
