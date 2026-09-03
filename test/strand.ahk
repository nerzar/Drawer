#Requires AutoHotkey v2.0
; Осталось ли после тестов окно за пределами всех экранов. Ящик паркует
; окна далеко за виртуальным столом, и если он умер не по своей воле,
; чужое окно останется там навсегда — руками его не достать.
; Аргумент: <файл отчёта>.

out := ""
for h in WinGetList() {
    try {
        if !(WinGetStyle("ahk_id " h) & 0x10000000)     ; WS_VISIBLE
            continue
        if (WinGetTitle("ahk_id " h) = "")
            continue
        if (WinGetMinMax("ahk_id " h) = -1)             ; свёрнутое не в счёт
            continue
        WinGetPos(&x, &y, &w, &hh, "ahk_id " h)
        on := false
        Loop MonitorGetCount() {
            MonitorGet(A_Index, &l, &t, &r, &b)
            if (x < r && x + w > l && y < b && y + hh > t)
                on := true
        }
        if !on
            out .= "  " WinGetTitle("ahk_id " h) " [" WinGetProcessName("ahk_id " h) "] x=" x " y=" y "`n"
    }
}
FileAppend(out = "" ? "нет окон за пределами экранов`n" : "ОКНА ЗА ЭКРАНАМИ:`n" out, A_Args[1], "UTF-8")
ExitApp(out = "" ? 0 : 1)
