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
;
; Точка 5 (C2, реестр служебных окон): копия IsServiceWindow с
; подставленными вместо WinExist/класса параметрами. Проверяются снятие
; мёртвой записи (hwnd переиспользуется) и правило собственного диалога.
;
; Точка 6 (C2): статическая проверка, что ядро не знает имён окон
; настроек и что регистрация снимается на всех путях разрушения.
;
; Точка 7 (C3, структурный статус): копия SlotWindow/SlotStatus с
; подставленными вместо WinAPI параметрами. Проверяются пять состояний
; контракта и то, что просмотр статуса не пишет в managed.
;
; Точка 8 (C3): статическая проверка, что статус нигде не разбирается из
; русской строки, а сами подписи остались дословными — на них стоят
; проверки набора setstat.
;
; Точка 9 (C4, Save outcome): копия решающей логики SettingsApplyPlan со
; стадиями-параметрами — какой outcome получается при каком исходе
; persistence и reload. Плюс сверка значения на настоящем временном INI
; и чистые SettingsChangedSlots/SettingsRestartRequired.
;
; Точка 10 (C4): статическая проверка, что каждый провал persistence
; несёт код контракта, удаление [dynamicSlotN] сверяется, реконсиляция
; вызвана под try и state отдаётся только после успешного reload.

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
; Точка 5 (C2): реестр служебных окон. Правило снятия мёртвой записи и
; условие «пока ящик не открыл ничего своего, чужой диалог ему не
; принадлежит» проверяются на копии IsServiceWindow, где обращения к
; настоящим окнам заменены параметрами: настоящие WinExist/WinGetClass
; требовали бы окон и фокуса, а проверяется здесь не они, а само правило.
; ---------------------------------------------------------------

; Копия ServiceWindowAdd/Drop из src/drawer.ahk.
SvcAdd(reg, hwnd) {
    if hwnd
        reg[hwnd] := true
}
SvcDrop(reg, hwnd) {
    if reg.Has(hwnd)
        reg.Delete(hwnd)
}
; Копия IsServiceWindow: alive заменяет WinExist, ownDialog — проверку
; «#32770 нашего процесса». Порядок ветвей повторён один в один.
SvcIs(reg, hwnd, alive, ownDialog := false) {
    if !hwnd
        return false
    if reg.Has(hwnd) {
        if (alive.Has(hwnd) && alive[hwnd])
            return true
        reg.Delete(hwnd)
    }
    if !reg.Count
        return false
    return ownDialog
}

reg := Map(), alive := Map()
alive[1001] := true, alive[1002] := true

Assert("5a: пустой реестр — своих окон нет",
    SvcIs(reg, 1001, alive) = false)

SvcAdd(reg, 1001)
Assert("5b: зарегистрированное живое окно — служебное",
    SvcIs(reg, 1001, alive) = true)
Assert("5c: чужое окно служебным не становится",
    SvcIs(reg, 1002, alive) = false)

; Второе своё окно (диалог выбора; на его месте окажется host WebView2):
; ядро не меняется, регистрируется ещё один hwnd.
SvcAdd(reg, 1002)
Assert("5d: второе своё окно тоже служебное, ядро не правилось",
    SvcIs(reg, 1002, alive) = true)
SvcDrop(reg, 1002)
Assert("5e: снятое с учёта окно перестаёт быть служебным",
    SvcIs(reg, 1002, alive) = false && SvcIs(reg, 1001, alive) = true)

; hwnd переиспользуется Windows: мёртвая запись обязана сняться, иначе
; чужое окно с тем же номером молча считалось бы своим.
alive[1001] := false
Assert("5f: запись о мёртвом окне снимается при первом же вопросе",
    SvcIs(reg, 1001, alive) = false && reg.Has(1001) = false)
alive[1001] := true
Assert("5g: тот же hwnd после переиспользования уже не служебный",
    SvcIs(reg, 1001, alive) = false)

; Правило собственного диалога (MsgBox о несохранённых правках) работает
; только пока у ящика открыто хоть одно своё окно — это условие было и
; до C2, в виде «нет окна настроек, значит нет».
regEmpty := Map()
Assert("5h: при пустом реестре свой диалог служебным не считается",
    SvcIs(regEmpty, 2001, alive, true) = false)
regOpen := Map(), SvcAdd(regOpen, 1001)
alive[1001] := true
Assert("5i: при открытом своём окне свой диалог считается служебным",
    SvcIs(regOpen, 2001, alive, true) = true)
Assert("5j: чужой диалог при открытом своём окне служебным не считается",
    SvcIs(regOpen, 2001, alive, false) = false)

; ---------------------------------------------------------------
; Точка 6 (C2): ядро больше не знает имён окон настроек, а каждое своё
; окно регистрируется и снимается с учёта.
; ---------------------------------------------------------------
if !FileExist(drawerPath) {
    Assert("6: src/drawer.ahk найден рядом с test/narrow", false)
} else {
    src6 := FileRead(drawerPath, "UTF-8")
    posIs := InStr(src6, "IsServiceWindow(hwnd) {")
    bodyIs := posIs ? SubStr(src6, posIs, 1200) : ""
    Assert("6a: IsServiceWindow найдена", posIs > 0)
    Assert("6b: IsServiceWindow не знает setGui/setPickerGui",
        InStr(bodyIs, "setGui") = 0 && InStr(bodyIs, "setPickerGui") = 0)
    Assert("6c: IsServiceWindow спрашивает реестр",
        InStr(bodyIs, "serviceWindows.Has(hwnd)") > 0)
    Assert("6d: мёртвая запись снимается внутри IsServiceWindow",
        InStr(bodyIs, "serviceWindows.Delete(hwnd)") > 0)
    Assert("6e: глобального setPickerGui больше нет нигде",
        InStr(src6, "setPickerGui") = 0)
    ; Окно настроек и диалог выбора: по регистрации на каждое и по
    ; снятию на каждый путь разрушения (штатный, повторное открытие
    ; после исчезнувшего окна, снос диалога вместе с родителем).
    Assert("6f: свои окна регистрируются (настройки + диалог выбора)",
        StrSplit(src6, "ServiceWindowAdd(").Length - 1 >= 3)
    Assert("6g: регистрация снимается на всех путях разрушения",
        StrSplit(src6, "ServiceWindowDrop(").Length - 1 >= 4)
}

; ---------------------------------------------------------------
; Точка 7 (C3): структурный статус слота. Пять состояний контракта и
; правило «просмотр статуса не захватывает окно». SlotWindow/SlotStatus
; обращаются к настоящим окнам, поэтому здесь копия с подставленными
; вместо WinExist/FindWindow/HandleManaged/HandleParked параметрами:
; проверяется порядок ветвей и набор состояний, а не сами WinAPI.
; ---------------------------------------------------------------

; Копия SlotWindow: alive заменяет WinExist, found — результат FindWindow.
SlotWindowCopy(managed, permSlots, dynSlots, n, alive, found) {
    if permSlots.Has(n) {
        if (managed.Has(n) && alive.Has(managed[n]) && alive[managed[n]])
            return managed[n]
        return found.Has(n) ? found[n] : 0
    }
    return (dynSlots.Has(n) && alive.Has(dynSlots[n]) && alive[dynSlots[n]])
         ? dynSlots[n] : 0
}
; Копия SlotStatus: isManaged/isParked заменяют HandleManaged/HandleParked.
SlotStatusCopy(isPerm, hwnd, titles, isManaged, isParked) {
    if !hwnd
        return { state: isPerm ? "applicationNotRunning" : "empty", title: "" }
    title := titles.Has(hwnd) ? titles[hwnd] : ""
    if !isManaged
        return { state: "available", title: title }
    return { state: isParked ? "parked" : "shown", title: title }
}

titles := Map(7001, "Блокнот", 7002, "Проводник")

Assert("7a: динамический слот без окна -> empty, без title",
    SlotStatusCopy(false, 0, titles, false, false).state = "empty"
 && SlotStatusCopy(false, 0, titles, false, false).title = "")
Assert("7b: постоянный слот без окна -> applicationNotRunning",
    SlotStatusCopy(true, 0, titles, false, false).state = "applicationNotRunning")
Assert("7c: окно есть, ящик его ещё не показывал -> available + title",
    SlotStatusCopy(true, 7001, titles, false, false).state = "available"
 && SlotStatusCopy(true, 7001, titles, false, false).title = "Блокнот")
Assert("7d: окно за пределами мониторов -> parked + title",
    SlotStatusCopy(false, 7002, titles, true, true).state = "parked"
 && SlotStatusCopy(false, 7002, titles, true, true).title = "Проводник")
Assert("7e: окно на экране -> shown + title",
    SlotStatusCopy(false, 7002, titles, true, false).state = "shown")

; Ровно пять состояний контракта, ни одного лишнего.
seen := Map()
for c in [SlotStatusCopy(false, 0, titles, false, false)
        , SlotStatusCopy(true, 0, titles, false, false)
        , SlotStatusCopy(true, 7001, titles, false, false)
        , SlotStatusCopy(false, 7002, titles, true, true)
        , SlotStatusCopy(false, 7002, titles, true, false)]
    seen[c.state] := true
Assert("7f: набор состояний ровно тот, что в integration-контракте",
    seen.Count = 5 && seen.Has("empty") && seen.Has("applicationNotRunning")
 && seen.Has("available") && seen.Has("parked") && seen.Has("shown"))

; Просмотр статуса не захватывает окно: managed только читается.
managed := Map(), permSlots := Map(), dynSlots := Map()
permSlots[1] := 1
alive := Map(7001, true)
found := Map(1, 7001)          ; FindWindow нашёл окно, managed пуст
before := managed.Count
hwnd := SlotWindowCopy(managed, permSlots, dynSlots, 1, alive, found)
Assert("7g: окно найдено, но в managed ничего не записано",
    hwnd = 7001 && managed.Count = before && managed.Count = 0)

; Уже захваченное окно берётся из managed без повторного поиска.
managed[1] := 7001
Assert("7h: живое managed-окно возвращается без FindWindow",
    SlotWindowCopy(managed, permSlots, Map(), 1, alive, Map()) = 7001)
alive[7001] := false
Assert("7i: мёртвое managed-окно уступает результату поиска",
    SlotWindowCopy(managed, permSlots, Map(), 1, alive, Map(1, 7002)) = 7002)

; ---------------------------------------------------------------
; Точка 8 (C3): в src/drawer.ahk статус нигде не разбирается обратно из
; русской строки, а сами подписи остались дословными — на них стоят
; проверки набора setstat.
; ---------------------------------------------------------------
if !FileExist(drawerPath) {
    Assert("8: src/drawer.ahk найден рядом с test/narrow", false)
} else {
    src8 := FileRead(drawerPath, "UTF-8")
    Assert("8a: SlotStatus(n) — read-only API по номеру слота",
        InStr(src8, "SlotStatus(n) {") > 0 && InStr(src8, "SlotWindow(n) {") > 0)
    Assert("8b: прежней SettingsSlotStatus(r) нет",
        InStr(src8, "SettingsSlotStatus") = 0)

    posColor := InStr(src8, "SettingsStatusColor(state) {")
    bodyColor := posColor ? SubStr(src8, posColor, 240) : ""
    Assert("8c: индикатор ветвится по enum, а не по подписи",
        posColor > 0 && InStr(bodyColor, "empty") > 0
     && InStr(bodyColor, "applicationNotRunning") > 0
     && InStr(bodyColor, "пусто") = 0)

    posTxt := InStr(src8, "SettingsStatusText(st) {")
    bodyTxt := posTxt ? SubStr(src8, posTxt, 600) : ""
    Assert("8d: локализатор найден", posTxt > 0)
    Assert("8e: подписи setstat сохранены дословно",
        InStr(bodyTxt, "`"пусто`"") > 0
     && InStr(bodyTxt, "`"приложение не запущено`"") > 0
     && InStr(bodyTxt, "`"окно: `"") > 0
     && InStr(bodyTxt, "`"припаркован`"") > 0
     && InStr(bodyTxt, "`"выдвинут`"") > 0)
    Assert("8f: подписи живут только в локализаторе",
        StrSplit(src8, "`"припаркован`"").Length = 2
     && StrSplit(src8, "`"выдвинут`"").Length = 2)

    posWin := InStr(src8, "SlotWindow(n) {")
    bodyWin := posWin ? SubStr(src8, posWin, 420) : ""
    Assert("8g: SlotWindow не пишет в managed",
        posWin > 0 && InStr(bodyWin, "managed[n] :=") = 0)
}

; ---------------------------------------------------------------
; Точка 9 (C4): контракт outcome. Настоящий SettingsApplyPlan трогает
; диск и рантайм, а вопрос «какой outcome при каком исходе стадий» —
; чистая арифметика, поэтому решающая часть скопирована со стадиями,
; подставленными параметрами. Если ветвление в src/drawer.ahk изменится,
; эту копию нужно обновить вручную — как и копии в точках 1, 5, 7.
; ---------------------------------------------------------------
ApplyOutcomeCopy(hasWork, persistOk, persistCode, mayHavePersisted, reloadOk) {
    o := { saved: false, code: "", retryable: false, mayHavePersisted: false,
           runtimeReloaded: false, hasState: false }
    if !hasWork
        return o
    o.mayHavePersisted := mayHavePersisted
    reloadErr := false
    if mayHavePersisted {
        if reloadOk
            o.runtimeReloaded := true
        else
            reloadErr := true
    }
    o.hasState := o.runtimeReloaded
    if !persistOk {
        o.code := persistCode
        o.retryable := !o.mayHavePersisted || o.runtimeReloaded
        return o
    }
    if reloadErr {
        o.code := "internal_error"
        return o
    }
    o.saved := true
    return o
}

; Менять нечего: до диска дело не доходит, даже если стадиям подсунуть
; «файл тронут» — ранний выход обязан случиться раньше их результатов.
o := ApplyOutcomeCopy(false, true, "", true, true)
Assert("9a: no-op — ни saved, ни кода, ни тронутого файла",
    o.saved = false && o.code = "" && o.mayHavePersisted = false
 && o.runtimeReloaded = false && o.hasState = false)

o := ApplyOutcomeCopy(true, true, "", true, true)
Assert("9b: полный успех — saved, пустой код, перечитано, state есть",
    o.saved = true && o.code = "" && o.runtimeReloaded = true
 && o.hasState = true)

; Первый же IniWrite бросил: файл не изменён, рантайм канонический.
o := ApplyOutcomeCopy(true, false, "write_failed", false, true)
Assert("9c: провал ДО первой мутации — reload не нужен, state не отдаём",
    o.code = "write_failed" && o.mayHavePersisted = false
 && o.runtimeReloaded = false && o.hasState = false)
Assert("9d: провал до мутации повторяем — рантайм не расходился с файлом",
    o.retryable = true)

; Часть записана, реконсиляция удалась: rollback не обещан, но клиент
; знает актуальное состояние и может повторить.
o := ApplyOutcomeCopy(true, false, "write_failed", true, true)
Assert("9e: частичная запись + успешный reload — partial с актуальным state",
    o.code = "write_failed" && o.saved = false && o.mayHavePersisted = true
 && o.runtimeReloaded = true && o.hasState = true && o.retryable = true)

; Часть записана, перечитать не вышло — единственный случай, когда
; повтор запрещён: применённое состояние никому не известно.
o := ApplyOutcomeCopy(true, false, "verify_failed", true, false)
Assert("9f: частичная запись + неудачный reload — без state и без повтора",
    o.code = "verify_failed" && o.mayHavePersisted = true
 && o.runtimeReloaded = false && o.hasState = false && o.retryable = false)

; Диск записан и сверен, но LoadConfig бросил — успехом это не считается.
o := ApplyOutcomeCopy(true, true, "", true, false)
Assert("9g: запись прошла, reload упал — internal_error, а не success",
    o.saved = false && o.code = "internal_error" && o.hasState = false
 && o.retryable = false)

Assert("9h: saved не бывает без успешного reload",
    ApplyOutcomeCopy(true, true, "", true, false).saved = false
 && ApplyOutcomeCopy(true, true, "", true, true).saved = true)

; --- changedSlots / restartRequired: чистые функции, копии из src ---
ChangedSlotsCopy(writes, deletes) {
    seen := Map()
    for w in writes
        seen[Integer(SubStr(w.sec, 5))] := true
    for n in deletes
        seen[n] := true
    out := []
    Loop 9
        if seen.Has(A_Index)
            out.Push(A_Index)
    return out
}
RestartRequiredCopy(writes) {
    out := []
    for w in writes
        if (w.key = "focusHotkey")
            out.Push(Integer(SubStr(w.sec, 5)))
    return out
}
Join(a) {
    s := ""
    for v in a
        s .= (s = "" ? "" : ",") v
    return s
}

wr := [{ sec: "slot7", key: "exe", val: "a.exe" },
       { sec: "slot2", key: "name", val: "N" },
       { sec: "slot2", key: "width", val: "60" },
       { sec: "slot2", key: "focusHotkey", val: "^!t" }]
Assert("9i: changedSlots — номера по возрастанию, писать можно и не по порядку",
    Join(ChangedSlotsCopy(wr, [5])) = "2,5,7")
Assert("9j: слот с двумя изменёнными ключами попадает в список один раз",
    Join(ChangedSlotsCopy([{ sec: "slot2", key: "name", val: "N" },
                           { sec: "slot2", key: "edge", val: "left" }], [])) = "2")
Assert("9k: restartRequired — только focusHotkey, а не любая правка слота",
    Join(RestartRequiredCopy(wr)) = "2")
Assert("9l: правки без focusHotkey рестарта не требуют",
    RestartRequiredCopy([{ sec: "slot3", key: "width", val: "70" }]).Length = 0)

; --- сверка значения на настоящем временном INI (окон не касается) ---
SettingsVerifyValue(path, sec, key, want, &detail) {
    got := ""
    try
        got := IniRead(path, sec, key, "")
    catch as e {
        detail := " — не прочитать: " e.Message
        return false
    }
    if (got = want)
        return true
    detail := " — в файле «" got "», ожидалось «" want "»"
    return false
}

verIni := A_Temp "\drawer_narrow_verify_test.ini"
try FileDelete(verIni)
IniWrite("60", verIni, "dynamic", "width")

d := ""
Assert("9m: записанное значение совпало — сверка проходит",
    SettingsVerifyValue(verIni, "dynamic", "width", "60", &d) = true)
d := ""
Assert("9n: в файле другое значение — сверка не проходит и говорит, что там",
    SettingsVerifyValue(verIni, "dynamic", "width", "70", &d) = false
 && InStr(d, "в файле «60»") > 0)
d := ""
Assert("9o: ключа в файле нет — это тоже провал сверки, а не молчаливое «ок»",
    SettingsVerifyValue(verIni, "dynamic", "edge", "left", &d) = false)

IniWrite("Слот 4", verIni, "dynamicSlot4", "name")
Assert("9p: живая [dynamicSlotN] не считается удалённой",
    SettingsVerifyDeleted(verIni, "dynamicSlot4") = false)
IniDelete(verIni, "dynamicSlot4")
Assert("9q: после удаления [dynamicSlotN] сверка подтверждает отсутствие",
    SettingsVerifyDeleted(verIni, "dynamicSlot4") = true)
try FileDelete(verIni)

; ---------------------------------------------------------------
; Точка 10 (C4): статическая проверка src/drawer.ahk.
; ---------------------------------------------------------------

; Тело без строк-комментариев: статическая проверка должна смотреть на
; код, а не на слова о коде — иначе комментарий «не вызывает LoadConfig()»
; провалил бы проверку «LoadConfig здесь не вызывается».
NoComments(body) {
    out := ""
    for line in StrSplit(body, "`n", "`r")
        if (SubStr(Trim(line), 1, 1) != ";")
            out .= line "`n"
    return out
}

if !FileExist(drawerPath) {
    Assert("10: src/drawer.ahk найден рядом с test/narrow (" drawerPath ")", false)
} else {
    src10 := FileRead(drawerPath, "UTF-8")

    pP := InStr(src10, "SettingsPersistVerified(generalWrites, slotPlan, &outcome) {")
    pR := InStr(src10, "SettingsReconcileRuntime(slotPlan) {")
    codeP := (pP > 0 && pR > pP) ? NoComments(SubStr(src10, pP, pR - pP)) : ""
    Assert("10a: тело SettingsPersistVerified найдено", codeP != "")

    Assert("10b: каждый провал persistence идёт через код контракта",
        InStr(codeP, "SettingsPersistFail(&outcome, `"write_failed`"") > 0
     && InStr(codeP, "SettingsPersistFail(&outcome, `"verify_failed`"") > 0
     && InStr(codeP, "outcome.err :=") = 0
     && InStr(codeP, "outcome.ok := false") = 0)

    Assert("10c: удаление [dynamicSlotN] теперь сверяется",
        InStr(codeP, "Проверка не прошла: [dynamicSlot") > 0
     && InStr(codeP, "Не удалить [dynamicSlot") > 0)
    Assert("10d: голого try IniDelete(dynamicSlot) без catch больше нет",
        InStr(codeP, "if !delSet.Has(n)") = 0)

    Assert("10e: persistence по-прежнему ничего не знает о рантайме",
        InStr(codeP, "LoadConfig(") = 0 && InStr(codeP, "Release(") = 0)

    pA := InStr(src10, "SettingsApplyPlan(generalWrites, slotPlan, &outcome) {")
    pS := InStr(src10, "SettingsSnapshot() {")
    bodyA := (pA > 0 && pS > pA) ? SubStr(src10, pA, pS - pA) : ""
    codeA := bodyA != "" ? NoComments(bodyA) : ""
    Assert("10f: тело SettingsApplyPlan найдено", codeA != "")

    pTry := InStr(codeA, "try {")
    pRec := InStr(codeA, "SettingsReconcileRuntime(slotPlan)")
    Assert("10g: реконсиляция вызвана под try — исключение не уходит в GUI-колбэк",
        pTry > 0 && pRec > pTry && InStr(codeA, "reloadErr := e.Message") > 0)

    pTryP := InStr(codeA, "try")
    pCall := InStr(codeA, "SettingsPersistVerified(")
    Assert("10h: persistence тоже вызвана под try, с internal_error в запасе",
        pTryP > 0 && pCall > pTryP && pCall < pTry
     && InStr(codeA, "`"internal_error`"") > 0)

    pIf := InStr(codeA, "if outcome.runtimeReloaded")
    pSt := InStr(codeA, "outcome.state := SettingsStateSnapshot()")
    Assert("10i: state отдаётся только после успешного reload",
        pIf > 0 && pSt > pIf && (pSt - pIf) < 60
     && StrSplit(codeA, "outcome.state :=").Length = 2)

    Assert("10j: outcome несёт весь контракт partial failure",
        InStr(codeA, "mayHavePersisted: false") > 0
     && InStr(codeA, "runtimeReloaded: false") > 0
     && InStr(codeA, "changedSlots: []") > 0
     && InStr(codeA, "restartRequired: []") > 0
     && InStr(codeA, "retryable: false") > 0)

    Assert("10k: повтор запрещён только при тронутом диске без reload",
        InStr(codeA, "outcome.retryable := !outcome.mayHavePersisted || outcome.runtimeReloaded") > 0)

    pSnap := InStr(src10, "SettingsStateSnapshot() {")
    pCh := InStr(src10, "SettingsChangedSlots(slotPlan) {")
    bodySnap := (pSnap > 0 && pCh > pSnap) ? SubStr(src10, pSnap, pCh - pSnap) : ""
    Assert("10l: снимок копирует настройки, а не отдаёт живой глобал",
        bodySnap != "" && InStr(bodySnap, "SettingsBehaviorCopy(SlotCfg(n))") > 0
     && InStr(bodySnap, "SettingsBehaviorCopy(dynamic)") > 0)
    Assert("10m: снимок включает живой статус слота, а не только конфиг",
        InStr(bodySnap, "SlotStatus(n)") > 0)

    pSave := InStr(src10, "SettingsSave(closeAfter) {")
    codeSave := pSave ? NoComments(SubStr(src10, pSave, 1800)) : ""
    Assert("10n: native ветвится по коду, а не по непустому тексту",
        pSave > 0 && InStr(codeSave, "if (outcome.code != `"`")") > 0
     && InStr(codeSave, "if (outcome.err != `"`")") = 0)
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
