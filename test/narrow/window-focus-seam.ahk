#Requires AutoHotkey v2.0
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
