#Requires AutoHotkey v2.0
; Раскладка мониторов глазами AutoHotkey. Номера здесь — те же, что в
; config.ini (monitor=1, monitor=2), и они не обязаны совпадать с
; порядком в настройках Windows, поэтому спрашиваем именно AHK.
;
; Стенд написан под раскладку «монитор 2 слева от монитора 1»: от неё
; зависит, какие края внутренние, а какие внешние, и половина проверок
; инварианта именно это и меряет. На другой раскладке тесты не то чтобы
; падают — они проверяют не то, что написано в их названиях.
;
; Аргумент: <файл отчёта>. Последняя строка — ГОДИТСЯ или НЕ ГОДИТСЯ.

dest := A_Args[1]
out := "мониторов: " MonitorGetCount() "`n"
Loop MonitorGetCount() {
    MonitorGet(A_Index, &l, &t, &r, &b)
    MonitorGetWorkArea(A_Index, &wl, &wt, &wr, &wb)
    out .= Format("  монитор {1}: {2},{3}..{4},{5}   рабочая область {6},{7}..{8},{9}{10}`n",
                  A_Index, l, t, r, b, wl, wt, wr, wb,
                  A_Index = MonitorGetPrimary() ? "   основной" : "")
}

bad := []
if (MonitorGetCount() != 2)
    bad.Push("нужно ровно два монитора, найдено " MonitorGetCount())
else {
    MonitorGet(1, &l1, &t1, &r1, &b1)
    MonitorGet(2, &l2, &t2, &r2, &b2)
    if (r2 > l1 + 1)
        bad.Push("монитор 2 должен лежать слева от монитора 1 (сейчас его правый край " r2 ", левый край монитора 1 " l1 ")")
    Loop 2 {
        MonitorGetWorkArea(A_Index, &wl, &wt, &wr, &wb)
        if (wr - wl < 800 || wb - wt < 600)
            bad.Push("рабочая область монитора " A_Index " меньше 800x600")
    }
}

for b in bad
    out .= "  !! " b "`n"
out .= (bad.Length ? "НЕ ГОДИТСЯ" : "ГОДИТСЯ") "`n"
FileAppend(out, dest, "UTF-8")
ExitApp(bad.Length ? 1 : 0)
