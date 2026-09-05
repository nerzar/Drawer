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
;
; Точка 3 (C1, стабильный Slot ID): модель пересборки apps из LoadConfig.
; Сравнивает разрешение слота по номеру и по индексу и показывает, какой
; именно промах снят. Ни окон, ни config.ini не касается.
;
; Точка 4 (C1): статическая проверка, что apps-index-идентичности в
; src/drawer.ahk больше нет — ни в регистрации хоткея, ни в ключах managed.

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
; Точка 3 (C1): стабильный Slot ID. LoadConfig пересобирает apps в
; порядке номеров слотов, поэтому позиция в массиве — не идентичность:
; появление постоянного слота с меньшим номером сдвигает всё, что за ним.
; Здесь моделируется ровно эта пересборка и сравниваются два способа
; разрешить слот из уже зарегистрированного колбэка: по номеру (как
; сейчас) и по индексу (как было до C1). Окон, фокуса и config.ini
; проверка не касается — это чистая арифметика идентичности.
; ---------------------------------------------------------------

; Тот же порядок, которым apps наполняется в LoadConfig: Loop 9 по
; возрастанию номера, постоянные слоты пушатся подряд.
BuildSlots(slotNums) {
    apps := [], permSlots := Map()
    for n in slotNums
        apps.Push({ slot: n, name: "app" n })
    for i, a in apps
        permSlots[a.slot] := i
    return { apps: apps, permSlots: permSlots }
}

; Как разрешает колбэк после C1: держит номер, спрашивает permSlots в
; момент нажатия. Копия PermApp() из src/drawer.ahk.
ResolveBySlot(m, n) {
    return m.permSlots.Has(n) ? m.apps[m.permSlots[n]] : 0
}
; Как разрешал колбэк до C1: держит индекс, снятый при регистрации.
ResolveByIndex(m, i) {
    return (i >= 1 && i <= m.apps.Length) ? m.apps[i] : 0
}

before := BuildSlots([2, 5])
boundSlot  := 5                         ; focusHotkey стоит на слоте 5
boundIndex := before.permSlots[5]       ; ...и до C1 запоминался как индекс 2
Assert("3a: до пересборки оба способа дают слот 5",
    ResolveBySlot(before, boundSlot).slot = 5
 && ResolveByIndex(before, boundIndex).slot = 5)

; Слот 1 стал постоянным: индексы 2 и 5 съехали на единицу.
after := BuildSlots([1, 2, 5])
Assert("3b: после conversion раннего слота колбэк по НОМЕРУ по-прежнему слот 5",
    ResolveBySlot(after, boundSlot).slot = 5)
Assert("3c: колбэк по ИНДЕКСУ попадает в чужой слот (баг, который снят C1)",
    ResolveByIndex(after, boundIndex).slot = 2)

; Слот 5 перестал быть постоянным: по номеру — молчание, по индексу —
; снова чужой слот.
gone := BuildSlots([1, 2])
Assert("3d: слот перестал быть постоянным -> по номеру ничего не делаем",
    ResolveBySlot(gone, boundSlot) = 0)
Assert("3e: по индексу тот же колбэк попал бы в слот 2",
    ResolveByIndex(gone, boundIndex).slot = 2)

; managed переживает пересборку только с ключом-номером.
managedBySlot := Map(),  managedBySlot[5] := 4242
managedByIndex := Map(), managedByIndex[boundIndex] := 4242
Assert("3f: managed по номеру находит окно слота 5 и после пересборки",
    managedBySlot.Has(5) && managedBySlot[5] = 4242)
Assert("3g: managed по индексу после пересборки отдал бы окно слота 5 слоту 2",
    managedByIndex.Has(after.permSlots[2]) && managedByIndex[after.permSlots[2]] = 4242)

; ---------------------------------------------------------------
; Точка 4 (C1): исходник src/drawer.ahk не содержит прежней
; apps-index-идентичности.
; ---------------------------------------------------------------
if !FileExist(drawerPath) {
    Assert("4: src/drawer.ahk найден рядом с test/narrow", false)
} else {
    src4 := FileRead(drawerPath, "UTF-8")
    Assert("4a: focus-хоткей регистрируется номером слота",
        InStr(src4, "OnFocusHotkey.Bind(a.slot)") > 0)
    Assert("4b: прежней регистрации по индексу apps нет",
        InStr(src4, "OnFocusHotkey.Bind(i)") = 0)
    Assert("4c: PermApp(n) — единственная точка разрешения номера в запись apps",
        InStr(src4, "PermApp(n) {") > 0)
    Assert("4d: managed нигде не индексируется индексом apps",
        InStr(src4, "managed[i]") = 0 && InStr(src4, "managed.Has(i)") = 0)
    Assert("4e: apps[...] читается только внутри PermApp",
        StrSplit(src4, "apps[permSlots[n]]").Length = 2
     && InStr(src4, "apps[permSlots[r.n]]") = 0
     && InStr(src4, "apps[i]") = 0)
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
