#Requires AutoHotkey v2.0
; Узкие regression-тесты для Settings save seam (SettingsVerifyDeleted,
; SettingsReconcileRuntime) — в отличие от test/drivers/*, НЕ трогают
; окна/мышь/фокус и не запускают drawer.ahk целиком: safe/all наборы из
; test/run.ps1 требуют изолированной VM (см. test/README.md), а эти
; проверки достаточно узкие, чтобы гонять их прямо на хосте.
;
; Запуск:
;   AutoHotkey64.exe test\narrow\settings-seam.ahk
; Код возврата 0 — всё зелено; результат также печатается в stdout.
;
; Точка 1 (SettingsVerifyDeleted): копия текущей реализации из
; src/drawer.ahk — функция чистая (без глобалов), поэтому тестируется
; напрямую, без #Include всего drawer.ahk. Если сигнатура/тело функции в
; src/drawer.ahk изменятся, эту копию нужно обновить вручную.
;
; Точка 2 (SettingsReconcileRuntime): LoadConfig/Release/HandleRepaintAll
; трогают реальный рантайм и требуют настоящих окон, поэтому вместо
; выполнения функции проверяется её исходный текст — конкретный gate и
; порядок стадий, а не поведение вслепую.

drawerPath := A_ScriptDir "\..\..\src\drawer.ahk"

results := []
Assert(name, cond) {
    global results
    results.Push([name, cond])
}

; ---------------------------------------------------------------
; Точка 1
; ---------------------------------------------------------------
SettingsVerifyDeleted(path, sec) {
    try
        return IniRead(path, sec, , "") = ""
    catch
        return false
}

scratchIni := A_Temp "\drawer_narrow_seam_test.ini"
try FileDelete(scratchIni)

Assert("1a: секции никогда не было -> true (удалена)",
    SettingsVerifyDeleted(scratchIni, "slot9") = true)

IniWrite("notepad.exe", scratchIni, "slot3", "exe")
IniWrite("Слот 3", scratchIni, "slot3", "name")
Assert("1b: секция записана и жива -> false (НЕ удалена)",
    SettingsVerifyDeleted(scratchIni, "slot3") = false)

IniDelete(scratchIni, "slot3")
Assert("1c: секция удалена IniDelete -> true (удалена)",
    SettingsVerifyDeleted(scratchIni, "slot3") = true)

IniWrite("chrome.exe", scratchIni, "slot4", "exe")
Assert("1d: соседняя секция цела после чужого IniDelete",
    IniRead(scratchIni, "slot4", "exe", "") = "chrome.exe")

try FileDelete(scratchIni)

; ---------------------------------------------------------------
; Точка 2: статическая проверка исходника src/drawer.ahk — правильный
; gate у Release() и правильный порядок стадий внутри
; SettingsReconcileRuntime (сама функция не выполняется).
; ---------------------------------------------------------------
if !FileExist(drawerPath) {
    Assert("2: src/drawer.ahk найден рядом с test/narrow (" drawerPath ")", false)
} else {
    src := FileRead(drawerPath, "UTF-8")
    posFn := InStr(src, "SettingsReconcileRuntime(slotPlan)")
    Assert("2a: SettingsReconcileRuntime найдена в src/drawer.ahk", posFn > 0)

    body := posFn ? SubStr(src, posFn, 2000) : ""
    posLoadConfig  := InStr(body, "LoadConfig(configPath")
    posPermRebuild := InStr(body, "permSlots.Clear()")
    posGate        := InStr(body, "dynSlots.Has(n) && permSlots.Has(n)")
    posManagedClr  := InStr(body, "managed.Clear()")

    Assert("2b: gate 'dynSlots.Has(n) && permSlots.Has(n)' присутствует",
        posGate > 0)
    Assert("2c: gate стоит ПОСЛЕ LoadConfig (не до диска, как было багом)",
        posLoadConfig > 0 && posGate > posLoadConfig)
    Assert("2d: gate стоит ПОСЛЕ пересборки permSlots (иначе permSlots.Has(n) читает старые данные)",
        posPermRebuild > 0 && posGate > posPermRebuild)
    Assert("2e: gate стоит ДО очистки managed (порядок стадий не перепутан)",
        posManagedClr > 0 && posGate < posManagedClr)
    Assert("2f: старого безусловного 'if dynSlots.Has(n) {' (без && permSlots.Has(n)) в функции нет",
        InStr(body, "if dynSlots.Has(n) {") = 0)
}

; ---------------------------------------------------------------
out := ""
allOk := true
for r in results {
    ok := r[2]
    allOk := allOk && ok
    out .= (ok ? "OK   " : "FAIL ") r[1] "`n"
}
out .= allOk ? "`nВСЕ ПРОВЕРКИ ПРОШЛИ`n" : "`nЕСТЬ ПРОВАЛЫ`n"
FileAppend(out, "*")   ; stdout
ExitApp(allOk ? 0 : 1)
