#Requires AutoHotkey v2.0

; ---- Test stubs (narrow-test env — no real windows) ----
; Управляемые из тестов, чтобы прогонять положительные ветки предикатов,
; а не только guard-clauses. Сигнатура HitsMonitor совпадает с production
; (x, y, w, h, skip := 0) — иначе 5-аргументный вызов из focus-модуля
; разошёлся бы с заглушкой незамеченным.
StubService := Map()          ; hwnd -> true, если считать служебным окном
StubMonitorHit := false       ; отдаёт HitsMonitor
IsServiceWindow(hwnd) => StubService.Has(hwnd) && StubService[hwnd]
HitsMonitor(x, y, w, h, skip := 0) => StubMonitorHit

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

; ---- A02S2 FIX (F2/F3): watcher-only forget против полного забвения ----
; Регрессия P17: Hide() снимает watcher до RestoreFocus(), поэтому история
; предыдущего фокуса обязана пережить WatchForget(); стирать её вправе
; только WindowFocusForget() из Release(). Проверяем оба контракта на
; production-функциях в порядке, в котором их зовёт Hide().
WindowFocusSetPrev(204, 600)
WindowFocusState.watched[204] := { hideOnBlur: true }
WatchForget(204)   ; так делает Hide() ПЕРЕД RestoreFocus()
Assert("WatchForget снимает watcher, но сохраняет prevFocus (P17)",
    !WindowFocusState.watched.Has(204) && WindowFocusGetPrev(204) = 600)
; ...и на этом же шаге RestoreFocus смог бы прочитать историю:
Assert("после WatchForget история всё ещё читаема к моменту RestoreFocus",
    WindowFocusGetPrev(204) = 600)
WindowFocusForget(204)   ; так делает Release(): забыть окончательно
Assert("WindowFocusForget стирает историю (контракт Release)",
    WindowFocusGetPrev(204) = 0)

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

; ---- A02S2 FIX (F4): реальная приёмка и дедуп через настоящее окно ----
; Настоящее top-level окно проходит TrackedFore(), поэтому событие
; действительно доходит до ветки приёмки и до дедупа, а не отсекается
; раньше на несуществующем HWND.
probe := Gui("+Owner", "WF Seam Probe")
probe.Show("x-4000 y-4000 w80 h60")   ; за краем: фокус пользователя не трогаем
probeHwnd := probe.Hwnd
WindowFocusInitFore(0)
WindowFocusState.foreWnd  := 0
WindowFocusState.lastFore := 0
acceptedFirst := WindowFocusOnEvent(probeHwnd)
Assert("WindowFocusOnEvent принимает новое отслеживаемое окно и переключает foreWnd",
    acceptedFirst && WindowFocusState.foreWnd = probeHwnd)
Assert("после приёмки lastFore хранит прежний foreWnd (0)",
    WindowFocusState.lastFore = 0)
dedup := WindowFocusOnEvent(probeHwnd)
Assert("WindowFocusOnEvent дедупит повтор того же реального foreWnd",
    !dedup && WindowFocusState.foreWnd = probeHwnd)

; ---- A02S2: Vanished predicate ----
Assert("Vanished(0) = true — нулевой hwnd исчез",
    Vanished(0))
Assert("Vanished(несуществующее) = true",
    Vanished(99999999))
Assert("Vanished(живого окна) = false",
    !Vanished(probeHwnd))

; ---- A02S2: FocusCandidate guards ----
Assert("FocusCandidate(0, skip) = false",
    !FocusCandidate(0, 1))
Assert("FocusCandidate(hwnd, hwnd) = false — skip совпадает",
    !FocusCandidate(5, 5))

; ---- A02S2 FIX (F4): положительный путь FocusCandidate и служебное окно ----
; То же реальное окно попадает на монитор (заглушка управляема), поэтому
; исполняется положительная ветка, а не только guard-clauses.
StubMonitorHit := true
Assert("FocusCandidate(живое окно на мониторе) = true",
    FocusCandidate(probeHwnd, 0))
; Служебное окно (настройки) без service-флага отвергается, со service —
; принимается: это и есть правило возврата фокуса в настройки (16h).
StubService[probeHwnd] := true
Assert("FocusCandidate служебного окна без service = false",
    !FocusCandidate(probeHwnd, 0))
Assert("FocusCandidate служебного окна со service = true (возврат в настройки)",
    FocusCandidate(probeHwnd, 0, true))
; PrevActive допускает настройки (service := true внутри) — если активное
; окно годно как кандидат, оно и возвращается.
StubService.Delete(probeHwnd)
StubMonitorHit := false
probe.Destroy()


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
