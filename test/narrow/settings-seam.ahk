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
;
; Точка 11 (C5, backend-валидация): копии валидаторов семантического
; входа. Проверяется то, что раньше гарантировали сами контролы: enum
; края, форма монитора, hex акцента, строгий bool и запрет перевода
; строки. Плюс копия IniBool на настоящем временном INI — умолчания и
; диагностика вместо MsgBox.
;
; Точка 12 (C5): статическая проверка, что LoadConfig и IniBool окон не
; открывают, замечания уходят вызывающему, а планы валидируют вход, а не
; передают его в запись как есть.

drawerPath := A_ScriptDir "\..\..\src\drawer.ahk"
slotsPath  := A_ScriptDir "\..\..\src\Slots.ahk"

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
; Точка 2: статическая проверка порядка стадий реконсиляции. После
; выделения реестра слотов она живёт в двух местах: сама
; SettingsReconcileRuntime (перечитать файл -> отдать его реестру) и
; Slots.Apply (проекция файла -> отпускание окон). Проверяются оба, сами
; функции не выполняются.
; ---------------------------------------------------------------
if !FileExist(drawerPath) || !FileExist(slotsPath) {
    Assert("2: src/drawer.ahk и src/Slots.ahk найдены рядом с test/narrow", false)
} else {
    src := FileRead(drawerPath, "UTF-8")
    posFn := InStr(src, "SettingsReconcileRuntime(slotPlan, &diags)")
    Assert("2a: SettingsReconcileRuntime найдена в src/drawer.ahk", posFn > 0)

    body := posFn ? SubStr(src, posFn, 2000) : ""
    posLoadConfig := InStr(body, "LoadConfig(configPath")
    posApply      := InStr(body, "Slots.Apply(cfg, slotPlan.prevPerm)")
    Assert("2b: реконсиляция отдаёт слоты реестру, а не правит структуры сама",
        posApply > 0 && InStr(body, "Release(") = 0)
    Assert("2c: проекция идёт ПОСЛЕ чтения диска (не до, как было багом)",
        posLoadConfig > 0 && posApply > posLoadConfig)

    srcSlots := FileRead(slotsPath, "UTF-8")
    posApplyFn := InStr(srcSlots, "static Apply(cfg, prevPerm := 0) {")
    Assert("2d: Slots.Apply найдена в src/Slots.ahk", posApplyFn > 0)
    bodyApply := posApplyFn ? SubStr(srcSlots, posApplyFn, 1800) : ""

    posProject := InStr(bodyApply, "s.perm     := cfg.perm.Has(n)")
    posGate    := InStr(bodyApply, "if (dynBind[n] && Slots.Get(n).perm) {")
    posRestore := InStr(bodyApply, "for n, hwnd in old.bySlot {")

    Assert("2e: gate 'динамическая привязка + слот стал постоянным' присутствует",
        posGate > 0)
    Assert("2f: gate стоит ПОСЛЕ проекции файла (иначе .perm читает старые данные)",
        posProject > 0 && posGate > posProject)
    Assert("2g: gate стоит ДО восстановления постоянных привязок из снимка",
        posRestore > 0 && posGate < posRestore)
    Assert("2h: динамическая привязка отпускается только под этим gate",
        StrSplit(bodyApply, "Release(dynBind[n])").Length = 2)
    Assert("2i: постоянные привязки берутся только из снимка плана",
        InStr(bodyApply, "old := prevPerm ? prevPerm : { bySlot: Map(), ident: Map() }") > 0
     && InStr(bodyApply, "s.window   := 0") > 0)

    ; PermSnapshot() — сам снимок, который Apply() выше получает готовым.
    ; Раньше он клал в bySlot голый s.window — окно, которое кто-то уже
    ; ЗАХВАТИЛ (SlotCapture/Show). Слот, чьё окно статус находит заново
    ; каждый раз (SlotWindow(), "available"), но никто ещё не показывал и
    ; не сохранял, в снимок не попадал вовсе — и gate/restore из этой
    ; точки выше отработать было не над чем: Apply() ничего не терял, а
    ; терять было нечему СНАЧАЛА. Конверсия такого слота молча теряла
    ; живое окно, хотя список слотов честно показывал его найденным.
    posSnapFn := InStr(srcSlots, "static PermSnapshot() {")
    Assert("2j: PermSnapshot найдена в src/Slots.ahk", posSnapFn > 0)
    bodySnap := posSnapFn ? SubStr(srcSlots, posSnapFn, 500) : ""
    Assert("2k: снимок видит окно через SlotWindow() — тот же путь, что и статус списка",
        InStr(bodySnap, "if (hwnd := SlotWindow(A_Index))") > 0
     && InStr(bodySnap, "bySlot[A_Index] := hwnd") > 0)
    Assert("2l: голого s.window в снимке больше нет — не восстановился обратно",
        InStr(bodySnap, "if s.window") = 0)
}

; ---------------------------------------------------------------
; Точка 3 (C1): стабильный Slot ID. Модель прежнего позиционного списка
; постоянных слотов: появление слота с меньшим номером сдвигало всё, что
; за ним. Сравниваются два способа разрешить слот из уже
; зарегистрированного колбэка — по номеру и по позиции, — и показывается,
; почему позиция идентичностью быть не может. Самого списка в production
; больше нет (точка 4 это и проверяет); модель остаётся регрессионным
; аргументом за номер слота. Окон, фокуса и config.ini проверка не
; касается — это чистая арифметика идентичности.
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
; Точка 4 (C1): в исходниках не осталось ни позиционной идентичности
; слота, ни параллельных структур, которые могли описать один слот
; по-разному. Идентичность — номер, хранилище — одна запись реестра.
; ---------------------------------------------------------------
if !FileExist(drawerPath) || !FileExist(slotsPath) {
    Assert("4: src/drawer.ahk и src/Slots.ahk найдены рядом с test/narrow", false)
} else {
    src4  := FileRead(drawerPath, "UTF-8")
    src4s := FileRead(slotsPath, "UTF-8")
    ; Смотреть надо на код, а не на слова о коде: шапка Slots.ahk
    ; называет прежние структуры, объясняя, почему их больше нет.
    both  := NoComments(src4) . NoComments(src4s)
    Assert("4a: focus-хоткей регистрируется номером слота",
        InStr(src4, "OnFocusHotkey.Bind(a.slot)") > 0)
    Assert("4b: прежней регистрации по позиции в списке нет",
        InStr(src4, "OnFocusHotkey.Bind(i)") = 0)
    Assert("4c: SlotPerm(n) — единственная точка разрешения номера в конфигурацию",
        InStr(src4s, "SlotPerm(n) {") > 0
     && StrSplit(src4s, "Slots.Get(n).perm`r`n}").Length = 2)
    Assert("4d: параллельных структур состояния слота больше нет",
        InStr(both, "permSlots") = 0 && InStr(both, "dynSlots") = 0
     && InStr(both, "managed[") = 0 && InStr(both, "managed.Has(") = 0)
    Assert("4e: запись слота адресуется номером, а не позицией",
        InStr(src4s, "Slots.byNum[n] := Slot(n)") > 0
     && InStr(both, "apps[") = 0)
    Assert("4f: реестр читают только через API — byNum наружу не ходит",
        InStr(src4, "Slots.byNum") = 0)
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
; вместо WinExist/FindWindow/WindowManaged/WindowParked параметрами:
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
; Копия SlotStatus: isManaged/isParked заменяют WindowManaged/WindowParked.
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
    src8s := FileExist(slotsPath) ? FileRead(slotsPath, "UTF-8") : ""
    Assert("8a: SlotStatus(n) — read-only API по номеру слота",
        InStr(src8s, "SlotStatus(n) {") > 0 && InStr(src8s, "SlotWindow(n) {") > 0)
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

    posWin := InStr(src8s, "SlotWindow(n) {")
    bodyWin := posWin ? SubStr(src8s, posWin, 420) : ""
    Assert("8g: SlotWindow не захватывает окно — пишет только SlotCapture",
        posWin > 0 && InStr(bodyWin, "s.window :=") = 0
     && InStr(src8s, "SlotCapture(n) {") > 0)
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
    pR := InStr(src10, "SettingsReconcileRuntime(slotPlan, &diags) {")
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
    pRec := InStr(codeA, "SettingsReconcileRuntime(slotPlan, &diags)")
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
     && InStr(bodySnap, "SettingsBehaviorCopy(SlotDefaults())") > 0)
    Assert("10m: снимок включает живой статус слота, а не только конфиг",
        InStr(bodySnap, "SlotStatus(n)") > 0)

    pSave := InStr(src10, "SettingsSave(closeAfter) {")
    codeSave := pSave ? NoComments(SubStr(src10, pSave, 1800)) : ""
    Assert("10n: native ветвится по коду, а не по непустому тексту",
        pSave > 0 && InStr(codeSave, "if (outcome.code != `"`")") > 0
     && InStr(codeSave, "if (outcome.err != `"`")") = 0)
}

; ---------------------------------------------------------------
; Точка 11 (C5): валидаторы семантического входа. Функции чистые (ни
; глобалов, ни контролов), поэтому проверяются копиями напрямую. Если их
; тела в src/drawer.ahk изменятся, копии нужно обновить вручную.
; ---------------------------------------------------------------
SettingsBad(msg, &err) {
    if (err = "")
        err := msg
    return ""
}
SettingsEdgeIn(v, label, req, &err) {
    if (err != "")
        return ""
    if (v = "")
        return req ? SettingsBad(label ": край не выбран", &err) : ""
    if (v = "left" || v = "right" || v = "top" || v = "bottom")
        return v
    return SettingsBad(label ": ожидается left, right, top или bottom", &err)
}
SettingsMonitorIn(v, label, req, &err) {
    if (err != "")
        return ""
    if (v = "")
        return req ? SettingsBad(label ": монитор не выбран", &err) : ""
    if (v = "cursor")
        return v
    if (IsInteger(v) && Integer(v) >= 1)
        return String(Integer(v))
    return SettingsBad(label ": ожидается cursor или номер монитора от 1", &err)
}
SettingsAccentIn(v, label, &err) {
    if (err != "")
        return ""
    if (RegExMatch(String(v), "^[0-9A-Fa-f]{6}$"))
        return String(v)
    return SettingsBad(label ": ожидаются 6 hex-цифр (RRGGBB)", &err)
}
SettingsBoolIn(v, label, &err) {
    if (err != "")
        return false
    if (v = true || v = 1 || v = "true")
        return true
    if (v = false || v = 0 || v = "false")
        return false
    SettingsBad(label ": ожидается true или false", &err)
    return false
}
SettingsTextIn(v, label, &err) {
    if (err != "")
        return ""
    s := String(v)
    if (InStr(s, "`r") || InStr(s, "`n"))
        return SettingsBad(label ": перевод строки недопустим", &err)
    return s
}

; Та самая ловушка, ради которой существует и IniBool: непустая строка
; "false" в AHK истинна, и без разбора порт записал бы true.
ve := ""
Assert("11a: строка «false» не становится true",
    SettingsBoolIn("false", "L", &ve) = false && ve = "")
ve := ""
Assert("11b: 0 и 1 из чекбокса принимаются как есть",
    SettingsBoolIn(0, "L", &ve) = false && SettingsBoolIn(1, "L", &ve) = true
 && SettingsBoolIn(true, "L", &ve) = true && ve = "")
ve := ""
Assert("11c: посторонняя строка — ошибка, а не молчаливое true",
    SettingsBoolIn("да", "L", &ve) = false && ve != "")
ve := ""
Assert("11d: пропущенный bool — тоже ошибка, а не молчаливый false",
    SettingsBoolIn("", "L", &ve) = false && ve != "")

; Именно на неизвестном крае ComputeGeom бросает ValueError — при
; нажатии хоткея, то есть далеко от Save.
ve := ""
Assert("11e: край вне enum отвергнут до записи",
    SettingsEdgeIn("diagonal", "Край", true, &ve) = "" && ve != "")
ve := ""
Assert("11f: четыре края проходят",
    SettingsEdgeIn("left", "Край", true, &ve) = "left"
 && SettingsEdgeIn("right", "Край", true, &ve) = "right"
 && SettingsEdgeIn("top", "Край", true, &ve) = "top"
 && SettingsEdgeIn("bottom", "Край", true, &ve) = "bottom" && ve = "")
ve := ""
Assert("11g: у General пустой край значит «не менять», у слота — ошибка",
    SettingsEdgeIn("", "Край", false, &ve) = "" && ve = ""
 && SettingsEdgeIn("", "Слот 3: край", true, &ve) = "" && ve != "")

ve := ""
Assert("11h: монитор — cursor или номер; строка отвергнута",
    SettingsMonitorIn("cursor", "M", true, &ve) = "cursor"
 && SettingsMonitorIn("2", "M", true, &ve) = "2" && ve = "")
ve := ""
Assert("11i: нечисловой монитор отвергнут — ResolveMonitor на нём бросает",
    SettingsMonitorIn("abc", "M", true, &ve) = "" && ve != "")
; Форма значения, а не окружение: config.ini переносится между машинами.
ve := ""
Assert("11j: номер монитора не сверяется с числом мониторов машины",
    SettingsMonitorIn("7", "M", true, &ve) = "7" && ve = "")
ve := ""
Assert("11k: ноль и отрицательный номер монитора отвергнуты",
    SettingsMonitorIn("0", "M", true, &ve) = "" && ve != "")

ve := ""
Assert("11l: акцент — ровно шесть hex-цифр",
    SettingsAccentIn("2A2E35", "A", &ve) = "2A2E35" && ve = "")
ve := ""
Assert("11m: не-hex акцент отвергнут",
    SettingsAccentIn("#2A2E35", "A", &ve) = "" && ve != "")

ve := ""
Assert("11n: перевод строки в значении отвергнут — он рвёт INI",
    SettingsTextIn("a`nb", "T", &ve) = "" && ve != "")
ve := ""
Assert("11o: обычный текст проходит без изменений",
    SettingsTextIn("Notepad++", "T", &ve) = "Notepad++" && ve = "")

; Первая ошибка отменяет разбор — та же дисциплина, что у SettingsNum.
ve := ""
SettingsEdgeIn("diagonal", "Край", true, &ve)
firstErr := ve
SettingsMonitorIn("abc", "Монитор", true, &ve)
Assert("11p: первая ошибка не затирается второй", ve = firstErr && ve != "")

; --- IniBool: умолчания и диагностика вместо MsgBox ---
IniBoolCopy(path, section, key, def, &diags) {
    v := IniRead(path, section, key, def ? "true" : "false")
    if (v = "true")
        return true
    if (v = "false")
        return false
    diags.Push("config.ini: [" section "] " key "=" v " — ожидается true или false, взято " (def ? "true" : "false"))
    return def
}

boolIni := A_Temp "\drawer_narrow_bool_test.ini"
try FileDelete(boolIni)
IniWrite("false", boolIni, "dynamic", "hideOnBlur")
IniWrite("ага", boolIni, "dynamic", "activateOnShow")

dg := []
Assert("11q: записанное false читается как false",
    IniBoolCopy(boolIni, "dynamic", "hideOnBlur", true, &dg) = false && dg.Length = 0)
dg := []
Assert("11r: отсутствующий ключ берёт умолчание и молчит",
    IniBoolCopy(boolIni, "dynamic", "нетТакого", true, &dg) = true && dg.Length = 0)
dg := []
Assert("11s: мусор берёт умолчание и оставляет ровно одну диагностику",
    IniBoolCopy(boolIni, "dynamic", "activateOnShow", true, &dg) = true
 && dg.Length = 1 && InStr(dg[1], "ожидается true или false") > 0)
try FileDelete(boolIni)

; ---------------------------------------------------------------
; Точка 12 (C5): статическая проверка src/drawer.ahk.
; ---------------------------------------------------------------
if !FileExist(drawerPath) {
    Assert("12: src/drawer.ahk найден рядом с test/narrow (" drawerPath ")", false)
} else {
    src12 := FileRead(drawerPath, "UTF-8")

    pLoad := InStr(src12, "LoadConfig(path, &diags) {")
    pBool := InStr(src12, "IniBool(path, section, key, def, &diags) {")
    pShow := InStr(src12, "ConfigDiagShow(diags) {")
    pEnd  := InStr(src12, "state     := Map()")
    codeLoad := (pLoad > 0 && pBool > pLoad) ? NoComments(SubStr(src12, pLoad, pBool - pLoad)) : ""
    codeBool := (pBool > 0 && pShow > pBool) ? NoComments(SubStr(src12, pBool, pShow - pBool)) : ""
    codeShow := (pShow > 0 && pEnd > pShow) ? SubStr(src12, pShow, pEnd - pShow) : ""
    Assert("12a: тела LoadConfig, IniBool и ConfigDiagShow найдены",
        codeLoad != "" && codeBool != "" && codeShow != "")

    Assert("12b: LoadConfig окон не открывает — годится для headless",
        InStr(codeLoad, "MsgBox") = 0 && InStr(codeLoad, "diags.Push(") > 0)
    Assert("12c: LoadConfig принимает &diags, обнуляет его при входе и отдаёт конфиг значением",
        InStr(codeLoad, "LoadConfig(path, &diags) {") > 0
     && InStr(codeLoad, "diags := []") > 0
     && InStr(codeLoad, "return { animMs: animMs") > 0)
    Assert("12n: рантайм заполняет ConfigApply, а не сама загрузка",
        InStr(codeLoad, "global ") = 0
     && InStr(src12, "ConfigApply(cfg) {") > 0
     && InStr(src12, "ConfigApply(bootConfig)") > 0)
    Assert("12d: IniBool тоже пишет в diags, а не в окно",
        InStr(codeBool, "MsgBox") = 0 && InStr(codeBool, "diags.Push(") > 0)
    Assert("12e: показ замечаний остался ровно один — ConfigDiagShow",
        InStr(codeShow, "MsgBox(d, `"Ящик`")") > 0)
    Assert("12f: старт и Save показывают их сами",
        InStr(src12, "ConfigDiagShow(cfgDiags)") > 0
     && InStr(src12, "ConfigDiagShow(outcome.diagnostics)") > 0)
    Assert("12g: реконсиляция отдаёт замечания наружу, а не глотает",
        InStr(src12, "SettingsReconcileRuntime(slotPlan, &diags) {") > 0
     && InStr(src12, "outcome.diagnostics := diags") > 0)

    pGP := InStr(src12, "SettingsGeneralPlan(input, &err) {")
    pGPe := InStr(src12, "; UI-adapter: только читает setUI")
    codeGP := (pGP > 0 && pGPe > pGP) ? NoComments(SubStr(src12, pGP, pGPe - pGP)) : ""
    Assert("12h: General-план валидирует каждое поле входа",
        codeGP != "" && InStr(codeGP, "SettingsBoolIn(input.activateOnShow") > 0
     && InStr(codeGP, "SettingsBoolIn(input.handlesEnabled") > 0
     && InStr(codeGP, "SettingsBoolIn(input.noAnim") > 0
     && InStr(codeGP, "SettingsEdgeIn(input.edge") > 0
     && InStr(codeGP, "SettingsMonitorIn(input.monitor") > 0
     && InStr(codeGP, "SettingsAccentIn(input.accent") > 0)
    Assert("12i: сырое значение входа в запись больше не попадает",
        InStr(codeGP, "input.activateOnShow ?") = 0
     && InStr(codeGP, "input.hideOnBlur ?") = 0
     && InStr(codeGP, "input.handlesEnabled ?") = 0
     && InStr(codeGP, "val: input.accent") = 0
     && InStr(codeGP, "val: input.edge") = 0
     && InStr(codeGP, "val: input.monitor") = 0)

    pSW := InStr(src12, "SettingsSlotWrites(n, e, &err, &field?) {")
    pSP := InStr(src12, "SettingsSlotsPlan(edits, &err) {")
    codeSW := (pSW > 0 && pSP > pSW) ? NoComments(SubStr(src12, pSW, pSP - pSW)) : ""
    Assert("12j: правка слота проходит те же проверки, что и General",
        codeSW != "" && InStr(codeSW, "SettingsTextIn(e.name") > 0
     && InStr(codeSW, "SettingsHotkeyIn(e.focusHotkey") > 0
     && InStr(codeSW, "SettingsMonitorIn(String(e.monitor)") > 0
     && InStr(codeSW, "SettingsEdgeIn(e.edge") > 0
     && InStr(codeSW, "SettingsBoolIn(e.activateOnShow") > 0)
    Assert("12k: у слота край и монитор обязательны — пустой monitor= ломает ResolveMonitor",
        InStr(codeSW, "монитор`", true, &err)") > 0
     && InStr(codeSW, "край`", true, &err)") > 0)
    Assert("12l: сырое e.* в запись больше не попадает",
        InStr(codeSW, "val: e.cls") = 0 && InStr(codeSW, "val: e.edge") = 0
     && InStr(codeSW, "e.activateOnShow ?") = 0
     && InStr(codeSW, "val: e.focusHotkey") = 0)

    pSPe := InStr(src12, "; UI-adapter: тонкая обёртка")
    codeSP := (pSP > 0 && pSPe > pSP) ? NoComments(SubStr(src12, pSP, pSPe - pSP)) : ""
    Assert("12m: номер и тип слота проверяются до записи",
        codeSP != "" && InStr(codeSP, "n < 1 || n > 9") > 0
     && InStr(codeSP, "e.kind != `"perm`" && e.kind != `"dyn`"") > 0)

    pVal := InStr(src12, "SettingsEdgeIn(v, label, req, &err) {")
    pVale := InStr(src12, "; Пустая строка означает «этот ключ писать не надо»")
    codeVal := (pVal > 0 && pVale > pVal) ? NoComments(SubStr(src12, pVal, pVale - pVal)) : ""
    Assert("12n: валидаторы не знают ни контролов, ни setUI — их зовёт и порт",
        codeVal != "" && InStr(codeVal, "ui.") = 0 && InStr(codeVal, "setUI") = 0
     && InStr(codeVal, "Gui") = 0 && InStr(codeVal, "MsgBox") = 0)
}

; ---------------------------------------------------------------
; Точка 13: slot.bind и slot.release
; Проверяются guards, отсутствие второго пути выполнения и то, что
; HWND не передаётся в результат ответа порта.
; ---------------------------------------------------------------

; Копия чистой логики SlotBind/SlotRelease для проверки guards модели
SlotBindModel(permSlots, dynSlots, pickerActive, activeHwnd, n) {
    if (n < 1 || n > 9)
        return { ok: false, code: "validation_error", message: "Номер слота должен быть 1…9" }
    if pickerActive
        return { ok: false, code: "busy", message: "Открыт picker" }
    if permSlots.Has(n)
        return { ok: false, code: "slot_is_permanent", message: "Слот " n " занят постоянной привязкой" }
    if !activeHwnd
        return { ok: false, code: "no_eligible_active_window", message: "Активное окно не годится для ящика" }
    dynSlots[n] := activeHwnd
    return { ok: true, code: "", message: "Слот " n " привязан", hwnd: activeHwnd }
}

SlotReleaseModel(permSlots, dynSlots, pickerActive, n) {
    if (n < 1 || n > 9)
        return { ok: false, code: "validation_error", message: "Номер слота должен быть 1…9" }
    if pickerActive
        return { ok: false, code: "busy", message: "Открыт picker" }
    if permSlots.Has(n)
        return { ok: false, code: "slot_is_permanent", message: "Слот " n " — постоянный, его нельзя освободить" }
    if !dynSlots.Has(n)
        return { ok: false, code: "not_bound", message: "Слот " n " не привязан к окну" }
    dynSlots.Delete(n)
    return { ok: true, code: "", message: "Слот " n " освобождён" }
}

mPerm := Map(1, true), mDyn := Map(4, 9999)
Assert("13a: SlotBind с n < 1 отвергнут validation_error",
    SlotBindModel(mPerm, mDyn, false, 1234, 0).code = "validation_error")
Assert("13b: SlotBind с n > 9 отвергнут validation_error",
    SlotBindModel(mPerm, mDyn, false, 1234, 10).code = "validation_error")
Assert("13c: SlotBind во время picker отвергнут busy",
    SlotBindModel(mPerm, mDyn, true, 1234, 4).code = "busy")
Assert("13d: SlotBind на постоянном слоте отвергнут slot_is_permanent",
    SlotBindModel(mPerm, mDyn, false, 1234, 1).code = "slot_is_permanent")
Assert("13e: SlotBind без активного подходящего окна отвергнут no_eligible_active_window",
    SlotBindModel(mPerm, mDyn, false, 0, 4).code = "no_eligible_active_window")
Assert("13f: SlotBind успешен при наличии активного окна",
    SlotBindModel(mPerm, mDyn, false, 1234, 4).ok = true && mDyn[4] = 1234)

Assert("13g: SlotRelease с n < 1 отвергнут validation_error",
    SlotReleaseModel(mPerm, mDyn, false, 0).code = "validation_error")
Assert("13h: SlotRelease с n > 9 отвергнут validation_error",
    SlotReleaseModel(mPerm, mDyn, false, 10).code = "validation_error")
Assert("13i: SlotRelease во время picker отвергнут busy",
    SlotReleaseModel(mPerm, mDyn, true, 4).code = "busy")
Assert("13j: SlotRelease на постоянном слоте отвергнут slot_is_permanent",
    SlotReleaseModel(mPerm, mDyn, false, 1).code = "slot_is_permanent")
Assert("13k: SlotRelease на пустом dynamic слоте отвергнут not_bound",
    SlotReleaseModel(mPerm, mDyn, false, 5).code = "not_bound")
Assert("13l: SlotRelease успешен на занятом dynamic слоте",
    SlotReleaseModel(mPerm, mDyn, false, 4).ok = true && !mDyn.Has(4))

; Статические проверки исходников
if FileExist(drawerPath) && FileExist(slotsPath) {
    src13 := FileRead(drawerPath, "UTF-8")
    Assert("13m: в src/Slots.ahk определены SlotBind и SlotRelease",
        InStr(FileRead(slotsPath, "UTF-8"), "SlotBind(n) {") > 0
     && InStr(FileRead(slotsPath, "UTF-8"), "SlotRelease(n) {") > 0)
    Assert("13n: BindSlot делегирует в SlotBind",
        InStr(src13, "res := SlotBind(n)") > 0)
    Assert("13o: ReleaseSlot делегирует в SlotRelease",
        InStr(src13, "res := SlotRelease(n)") > 0)

    portPath := A_ScriptDir "\..\..\src\webview\SettingsPort.ahk"
    srcPort := FileRead(portPath, "UTF-8")
    Assert("13p: DrawerSettingsPort вызывает единые SlotBind и SlotRelease",
        InStr(srcPort, "res := SlotBind(slotNumber)") > 0
     && InStr(srcPort, "res := SlotRelease(slotNumber)") > 0)
    Assert("13q: HWND не передаётся в результат порта на wire",
        InStr(srcPort, '"slot", slotNumber') > 0
     && InStr(srcPort, '"status", this._StatusDto') > 0
     && InStr(srcPort, '"state", this.StateDto()') > 0
     && InStr(srcPort, '"hwnd"') = 0)

    bridgePath := A_ScriptDir "\..\..\src\webview\SettingsJsonBridge.ahk"
    srcBridge := FileRead(bridgePath, "UTF-8")
    Assert("13r: SettingsJsonBridge маршрутизирует slot.bind и slot.release в порт",
        InStr(srcBridge, 'case "slot.bind":') > 0
     && InStr(srcBridge, 'outcome := this._port.Bind(Request.payload)') > 0
     && InStr(srcBridge, 'case "slot.release":') > 0
     && InStr(srcBridge, 'outcome := this._port.Release(Request.payload)') > 0)
    Assert("13s: slot.bind и slot.release блокируются во время picker",
        InStr(srcBridge, '"slot.bind", "slot.release"') > 0)

    ; Подмена активного окна нужна только тесту, и жить она обязана в
    ; харнессе: харнесс правит копию drawer.ahk, а отгружаемый exe не
    ; должен нести глобал, которым обходится выбор целевого окна.
    Assert("14a: в production нет подмены активного окна",
        InStr(src13, "slotActiveWindowOverride") = 0)
    Assert('14b: PickActive берёт окно у WinExist("A") напрямую',
        InStr(src13, 'PickActive() {`r`n    if !(hwnd := WinExist("A"))') > 0)

    harnessPath := A_ScriptDir "\webview-slice.ps1"
    if FileExist(harnessPath) {
        srcHarness := FileRead(harnessPath, "UTF-8")
        Assert("14c: подмена активного окна живёт в харнессе",
            InStr(srcHarness, "smokeActiveWindow ? smokeActiveWindow : WinExist") > 0)
        Assert("14d: харнесс падает, если якорь PickActive уехал",
            InStr(srcHarness, "Не нашёл якорь PickActive") > 0)
    }
}

; ---------------------------------------------------------------
; Точка 15: адрес поля в ответе об ошибке
; Ошибка обязана назвать поле, к которому форме вести человека, и
; назвать его по-русски. Оба списка имён — один, иначе сообщение
; backend и подпись из порта разойдутся.
if FileExist(drawerPath) {
    src15 := FileRead(drawerPath, "UTF-8")
    Assert("15a: имена полей слота живут в одном месте",
        InStr(src15, "SettingsSlotFieldLabel(n, key := `"`") {") > 0)

    pPlan := InStr(src15, "SettingsSlotsPlan(edits, &err) {")
    pPlanEnd := InStr(src15, "; Отказ плана одним видом")
    codePlan := (pPlan > 0 && pPlanEnd > pPlan) ? NoComments(SubStr(src15, pPlan, pPlanEnd - pPlan)) : ""
    Assert("15b: каждый выход плана несёт адрес поля",
        codePlan != "" && StrSplit(codePlan, "return {").Length = 2
     && InStr(codePlan, "prevPerm: Slots.PermSnapshot(), field: `"`"") > 0
     && InStr(src15, "SettingsSlotsPlanFail(field) {") > 0)
    Assert("15c: неназванный контрол превращается в адрес слота",
        InStr(codePlan, "field := `"slots.`" n") > 0)
    Assert("15d: exe и размер окна называют свой контрол",
        InStr(src15, "field := `"slots.`" n `".executable`"") > 0
     && InStr(src15, "field := `"slots.`" n `".widthPercent`"") > 0)

    portPath := A_ScriptDir "\..\..\src\webview\SettingsPort.ahk"
    if FileExist(portPath) {
        srcPort := FileRead(portPath, "UTF-8")
        Assert("15e: порт отдаёт форме адрес поля от плана, а не пустой",
            InStr(srcPort, "return this._Invalid(err, slotPlan.field)") > 0)
        Assert("15f: в сообщении стоит название поля, а не его путь",
            InStr(srcPort, "this._FieldLabel(path), path, &err, &field)") > 0
         && InStr(srcPort, "`" path, path, &err, &field)") = 0)
        Assert("15g: подписи полей слота порт берёт у backend, своего списка не заводит",
            InStr(srcPort, "SettingsSlotFieldLabel(m[1], m[2])") > 0
         && InStr(srcPort, "`"файл (exe)`"") = 0
         && InStr(srcPort, "`"горячая клавиша`"") = 0)
    }
}

; ---------------------------------------------------------------
; Точка 16: смена рода слота, надстройка динамического, фокус и кромка
; Статические проверки: все четыре поведения живут в путях, которые
; трогают настоящие окна и config.ini, и проверяются здесь по исходнику.
if FileExist(drawerPath) {
    src16 := FileRead(drawerPath, "UTF-8")

    pDyn := InStr(src16, "SettingsDynSlotWrites(n, e, &err, &field?) {")
    pPlan16 := InStr(src16, "SettingsSlotsPlan(edits, &err) {")
    codeDyn := (pDyn > 0 && pPlan16 > pDyn) ? NoComments(SubStr(src16, pDyn, pPlan16 - pDyn)) : ""
    Assert("16a: надстройка динамического слота пишет только отличия от общих",
        codeDyn != "" && InStr(codeDyn, "if (c.val = c.shared) {") > 0
     && InStr(codeDyn, "keyDeletes.Push({ sec: sec, key: c.key })") > 0)
    Assert("16b: у надстройки только пять ключей поведения — ни имени, ни exe",
        codeDyn != "" && InStr(codeDyn, "e.name") = 0 && InStr(codeDyn, "e.exe") = 0
     && InStr(codeDyn, "e.focusHotkey") = 0)
    Assert("16c: опустевшая надстройка сносится секцией",
        InStr(codeDyn, "empty: kept = 0") > 0)

    pPlanEnd16 := InStr(src16, "; Отказ плана одним видом")
    codePlan16 := (pPlan16 > 0 && pPlanEnd16 > pPlan16)
                  ? NoComments(SubStr(src16, pPlan16, pPlanEnd16 - pPlan16)) : ""
    Assert("16d: [slotN] сносится только у слота, который был постоянным",
        codePlan16 != "" && InStr(src16, "if SlotPerm(n)`r`n                    deletes.Push(n)") > 0)
    Assert("16e: надстройку под снос называет план; списка touched больше нет",
        InStr(codePlan16, "dynDeletes.Push(n)") > 0
     && InStr(src16, "for n in slotPlan.dynDeletes {") > 0
     && InStr(src16, "slotPlan.touched") = 0)
    Assert("16f: удаление ключа надстройки сверяется чтением",
        InStr(src16, "for d in slotPlan.keyDeletes {") > 0
     && InStr(src16, "SettingsReadKey(configPath, d.sec, d.key) != `"`"") > 0)
    Assert("16g: номер слота берётся из имени секции, а не по позиции",
        InStr(src16, "SettingsSectionSlot(sec) {") > 0
     && InStr(src16, "Integer(SubStr(w.sec, 5))") = 0)

    Assert("16h: фокус возвращается в настройки, если пользователь был там",
        InStr(src16, "FocusCandidate(hwnd, skip, service := false) {") > 0
     && InStr(src16, "return FocusCandidate(hwnd, skip, true) ? hwnd : 0") > 0
     && InStr(src16, "if FocusCandidate(st.prev, parked, true) {") > 0)
    Assert("16i: наугад из Z-порядка настройки по-прежнему не выбираются",
        InStr(src16, "RedirectFocus(parked) {`r`n    for hwnd in WinGetList() {`r`n        if FocusCandidate(hwnd, parked) {") > 0)

    Assert("16j: кромку получает каждый слот группы, а не только припаркованный",
        InStr(src16, "if !g.parked`r`n                continue") = 0
     && InStr(src16, "HandleDrop(") = 0)
    Assert("16k: выезд окна пересобирает кромки, а не сносит свою",
        InStr(src16, "окно выехало — кромка остаётся на месте") > 0)

    Assert("16l: иконка окна считается один раз на окно",
        InStr(src16, "if iconUriCache.Has(hwnd)") > 0
     && InStr(src16, "iconUriCache[hwnd] := uri") > 0)
    Assert("16m: поток для PNG создаётся на HGLOBAL — иначе его нечем прочитать",
        InStr(src16, "CreateStreamOnHGlobal") > 0
     && InStr(src16, "DllCall(`"shlwapi\SHCreateMemStream`"") = 0)
}

; ---------------------------------------------------------------
; Точка 17: проекция config.ini на реестр слотов (Slots.Apply). Раньше
; эти правила были размазаны по SettingsReconcileRuntime и проверялись
; только статически — по строкам исходника. Настоящая функция трогает
; окна (Release -> WinMove), поэтому здесь копия её решающей части:
; вместо окон номера, вместо Release() список отпущенных.
;
; Проверяется ровно то, ради чего снимок берётся ДО диска и ради чего
; переход в постоянные подтверждается перечитанным файлом.
; ---------------------------------------------------------------

; prevPermKind — Map n -> true, если слот БЫЛ постоянным до Apply
; prevWindow   — Map n -> hwnd: кэш постоянного либо привязка динамического
; newPerm      — Map n -> { exe, cls }: что говорит ПЕРЕЧИТАННЫЙ файл
; snap         — { bySlot, ident }: снимок плана, сделанный до записи
ApplyModel(prevPermKind, prevWindow, newPerm, snap) {
    released := [], window := Map(), dynBind := Map()
    Loop 9 {
        n := A_Index
        dynBind[n] := (prevPermKind.Has(n) || !prevWindow.Has(n)) ? 0 : prevWindow[n]
        window[n] := 0
    }
    Loop 9 {
        n := A_Index
        if (dynBind[n] && newPerm.Has(n)) {
            released.Push(dynBind[n])
            dynBind[n] := 0
        }
    }
    Loop 9 {
        n := A_Index
        if dynBind[n]
            window[n] := dynBind[n]
    }
    for n, hwnd in snap.bySlot {
        id := snap.ident.Has(n) ? snap.ident[n] : 0
        if (newPerm.Has(n) && id && id.exe = newPerm[n].exe && id.cls = newPerm[n].cls)
            window[n] := hwnd
        ; Слот явно обращён в динамический (конверсией через Settings) —
        ; живое окно не отпускаем домой, а передаём его тем же слотом
        ; дальше, уже динамической привязкой.
        else if !newPerm.Has(n)
            window[n] := hwnd
        else
            released.Push(hwnd)
    }
    return { window: window, released: released }
}

Snap(bySlot, ident) {
    return { bySlot: bySlot, ident: ident }
}

; Постоянный слот 3 с неизменными exe/cls: окно остаётся за слотом и
; домой не уезжает.
r := ApplyModel(Map(3, true), Map(3, 8001),
                Map(3, { exe: "a.exe", cls: "" }),
                Snap(Map(3, 8001), Map(3, { exe: "a.exe", cls: "" })))
Assert("17a: неизменная identity сохраняет захваченное окно",
    r.window[3] = 8001 && r.released.Length = 0)

; Сменился exe — прежнее окно ящику больше не принадлежит.
r := ApplyModel(Map(3, true), Map(3, 8001),
                Map(3, { exe: "b.exe", cls: "" }),
                Snap(Map(3, 8001), Map(3, { exe: "a.exe", cls: "" })))
Assert("17b: смена exe возвращает прежнее окно домой",
    r.window[3] = 0 && r.released.Length = 1 && r.released[1] = 8001)

; То же самое для класса окна: cls — часть identity, а не подсказка.
r := ApplyModel(Map(3, true), Map(3, 8001),
                Map(3, { exe: "a.exe", cls: "Other" }),
                Snap(Map(3, 8001), Map(3, { exe: "a.exe", cls: "" })))
Assert("17c: смена cls тоже возвращает окно домой",
    r.window[3] = 0 && r.released.Length = 1)

; Слот перестал быть постоянным (conversion Permanent -> Dynamic) и у
; него было живое окно. Раньше оно безусловно уезжало домой — тем же
; путём, что и смена exe/cls, — и постоянный слот с живым приложением
; после конверсии выглядел так, будто окно закрыли. Пользователь менял
; только то, как слот ищет своё окно, а не отказывался от него: слот
; остаётся с тем же окном, но уже динамической привязкой.
r := ApplyModel(Map(3, true), Map(3, 8001), Map(),
                Snap(Map(3, 8001), Map(3, { exe: "a.exe", cls: "" })))
Assert("17d: конверсия в динамический передаёт живое окно тем же слотом",
    r.window[3] = 8001 && r.released.Length = 0)

; Слот стал постоянным, и перечитанный файл это подтверждает: живая
; динамическая привязка снимается — постоянный и динамический не бывают
; одним слотом одновременно.
r := ApplyModel(Map(), Map(4, 9001),
                Map(4, { exe: "a.exe", cls: "" }),
                Snap(Map(), Map()))
Assert("17e: подтверждённый переход в постоянные отпускает динамическую привязку",
    r.window[4] = 0 && r.released.Length = 1 && r.released[1] = 9001)

; Тот же намеренный переход, но запись не долетела до диска: файл
; по-прежнему называет слот динамическим. Привязку трогать нельзя —
; ровно эта защита и появилась в a39f543.
r := ApplyModel(Map(), Map(4, 9001), Map(), Snap(Map(), Map()))
Assert("17f: неподтверждённый переход привязку не трогает (partial failure)",
    r.window[4] = 9001 && r.released.Length = 0)

; Динамический слот, которого правка вообще не касалась, переживает
; перечитывание файла.
r := ApplyModel(Map(), Map(7, 9002), Map(), Snap(Map(), Map()))
Assert("17g: чужая динамическая привязка переживает перечитывание",
    r.window[7] = 9002 && r.released.Length = 0)

; Окно, захваченное постоянным слотом уже ПОСЛЕ снимка, плану неизвестно:
; кэш сбрасывается, но домой окно не отправляется — это была не потеря
; хозяина, а просто устаревший кэш (прежняя managed.Clear()).
r := ApplyModel(Map(3, true), Map(3, 8005),
                Map(3, { exe: "a.exe", cls: "" }),
                Snap(Map(), Map(3, { exe: "a.exe", cls: "" })))
Assert("17h: захват мимо снимка сбрасывается, но окно домой не уезжает",
    r.window[3] = 0 && r.released.Length = 0)

; General-only Save: правок слотов нет, снимок всё равно взят — и все
; постоянные привязки остаются на местах.
r := ApplyModel(Map(1, true, 5, true), Map(1, 8001, 5, 8005),
                Map(1, { exe: "a.exe", cls: "" }, 5, { exe: "b.exe", cls: "" }),
                Snap(Map(1, 8001, 5, 8005),
                     Map(1, { exe: "a.exe", cls: "" }, 5, { exe: "b.exe", cls: "" })))
Assert("17i: Save без правок слотов ничего не отпускает и ничего не теряет",
    r.window[1] = 8001 && r.window[5] = 8005 && r.released.Length = 0)

; Один слот конвертируется, соседний того же рода не задет: окно
; конвертированного слота остаётся при нём динамической привязкой.
r := ApplyModel(Map(2, true, 5, true), Map(2, 8002, 5, 8005),
                Map(5, { exe: "b.exe", cls: "" }),
                Snap(Map(2, 8002, 5, 8005),
                     Map(2, { exe: "a.exe", cls: "" }, 5, { exe: "b.exe", cls: "" })))
Assert("17j: конвертация одного слота не трогает соседний",
    r.window[2] = 8002 && r.window[5] = 8005 && r.released.Length = 0)

; Слот конвертируется, но живого окна у него не было (applicationNotRunning) —
; released остаётся пустым, а не получает 0 или мусор: snap.bySlot не
; заводит запись без окна (см. Slots.PermSnapshot — "if s.window").
r := ApplyModel(Map(6, true), Map(), Map(), Snap(Map(), Map(6, { exe: "c.exe", cls: "" })))
Assert("17k: конвертация слота без живого окна ничего не отпускает",
    r.window[6] = 0 && r.released.Length = 0)
; ---------------------------------------------------------------
; Точка 18: контракт хоткея постоянного слота.
;
; Хоткей — единственное поле слота, значение которого нельзя проверить
; сравнением с набором: синтаксис клавиши разбирает сам AutoHotkey. До
; появления этой проверки поле принимало любой текст, и «Ctrl + Alt + 2»
; — понятная человеку запись, но не синтаксис AutoHotkey — уезжала в
; config.ini как есть. Hotkey() бросал уже при СЛЕДУЮЩЕМ запуске, по
; одному модальному сообщению на слот, а до тех пор ничто на ошибку не
; указывало: слот выглядел так, будто хоткей у него сбросился.
;
; По итогам ручной приёмки поле стало человекочитаемым: пользователь
; вводит "Ctrl + Alt + F2", а не "^!F2", и проверяются конфликты с
; хоткеями ящика и с чужим focusHotkey — не только синтаксис.
;
; Здесь копии HotkeyModSymbol/HotkeyHumanToAhk/HotkeyAhkToHuman/
; SettingsHotkeyConflict/SettingsHotkeyIn. Последняя не чистая —
; регистрирует хоткей, — но регистрирует в контекст, который никогда не
; истинен, и сразу выключенным, поэтому на host безопасна: сработать он
; не может. SettingsHotkeyConflict в проде читает SlotPermList() (реестр);
; здесь вместо реестра — параметр others (Map номер -> focusHotkey), иначе
; copy тянула бы за собой Slots.ahk целиком ради одной проверки. Если тела
; в src/drawer.ahk изменятся, копии нужно обновить вручную — как и копии в
; точках 1, 5, 7, 9, 17.
; ---------------------------------------------------------------

HookedCopy(hk) {
    return (SubStr(hk, 1, 1) = "$") ? hk : "$" hk
}
SettingsBadCopy(msg, &err) {
    if (err = "")
        err := msg
    return ""
}
HotkeyModSymbolCopy(word) {
    switch StrLower(word) {
        case "ctrl", "control": return "^"
        case "alt": return "!"
        case "shift": return "+"
        case "win", "windows", "super": return "#"
    }
    return ""
}
HotkeyHumanToAhkCopy(s, &err) {
    err := ""
    s := Trim(s)
    if (s = "")
        return ""
    parts := StrSplit(s, "+")
    hasModWord := false
    for p in parts
        if (HotkeyModSymbolCopy(Trim(p)) != "")
            hasModWord := true
    if !hasModWord
        return s
    hasCtrl := false, hasAlt := false, hasShift := false, hasWin := false, key := ""
    for p in parts {
        t := Trim(p)
        if (t = "")
            return SettingsBadCopy("пустая часть сочетания", &err)
        switch HotkeyModSymbolCopy(t) {
            case "^":
                if hasCtrl
                    return SettingsBadCopy("повтор модификатора: " t, &err)
                hasCtrl := true
            case "!":
                if hasAlt
                    return SettingsBadCopy("повтор модификатора: " t, &err)
                hasAlt := true
            case "+":
                if hasShift
                    return SettingsBadCopy("повтор модификатора: " t, &err)
                hasShift := true
            case "#":
                if hasWin
                    return SettingsBadCopy("повтор модификатора: " t, &err)
                hasWin := true
            default:
                if (key != "")
                    return SettingsBadCopy("в сочетании может быть только одна клавиша: " t, &err)
                key := t
        }
    }
    if (key = "")
        return SettingsBadCopy("нужна клавиша, не только модификаторы", &err)
    return (hasCtrl ? "^" : "") (hasAlt ? "!" : "") (hasShift ? "+" : "") (hasWin ? "#" : "") key
}
HotkeyAhkToHumanCopy(ahk) {
    if (ahk = "" || InStr("$*~", SubStr(ahk, 1, 1)))
        return ahk
    s := ahk, out := ""
    while (s != "" && InStr("^!+#", SubStr(s, 1, 1))) {
        c := SubStr(s, 1, 1)
        out .= (c = "^" ? "Ctrl" : c = "!" ? "Alt" : c = "+" ? "Shift" : "Win") "+"
        s := SubStr(s, 2)
    }
    return out . s
}
SettingsHotkeyConflictCopy(ahk, n, others) {
    want := HookedCopy(ahk)
    Loop 9 {
        if (HookedCopy("^!" A_Index) = want)
            return "показать/убрать слот " A_Index
        if (HookedCopy("^!+" A_Index) = want)
            return "назначить слот " A_Index
    }
    if (HookedCopy("^!0") = want)
        return "очистить динамические слоты"
    if (HookedCopy("^!+0") = want)
        return "выход"
    for slotN, hk in others {
        if (slotN = n)
            continue
        if (hk != "" && HookedCopy(hk) = want)
            return "слот " slotN
    }
    return ""
}
SettingsHotkeyInCopy(v, live, label, n, others, &err) {
    static never := (*) => false
    if (err != "")
        return ""
    s := String(v)
    if (InStr(s, "`r") || InStr(s, "`n"))
        return SettingsBadCopy(label ": перевод строки недопустим", &err)
    human := Trim(s)
    if (human = "")
        return human
    herr := ""
    ahk := HotkeyHumanToAhkCopy(human, &herr)
    if (herr != "")
        return SettingsBadCopy(label ": " human " — " herr ". Например Ctrl + Alt + F2", &err)
    if (ahk = live)
        return ahk
    ok := true
    HotIf never
    try {
        Hotkey(HookedCopy(ahk), (*) => 0, "Off")
    } catch {
        ok := false
    } finally {
        HotIf
    }
    if !ok
        return SettingsBadCopy(label ": " human " — не сочетание клавиш AutoHotkey."
                             . " Например Ctrl + Alt + F2", &err)
    if (conflict := SettingsHotkeyConflictCopy(ahk, n, others))
        return SettingsBadCopy(label ": " human " уже занято — " conflict, &err)
    return ahk
}
HotkeyOk(s, live := "", n := 0, others := 0) {
    err := ""
    SettingsHotkeyInCopy(s, live, "хоткей", n, others ? others : Map(), &err)
    return err = ""
}

; Настоящий хоткей программы, назначенный ДО проверок: ни одна проверка
; не имеет права его сломать (18f).
Hotkey(HookedCopy("^!F9"), (*) => 0)

good := true
for s in ["^!F2", "^2", "^!#1", "~$+F3", "#Space", "*^!Numpad1", "F13", "vk41", "^!+#F5"]
    good := good && HotkeyOk(s)
Assert("18a: синтаксис AutoHotkey принимается насквозь (модификаторы, F-клавиши, vk, префиксы)", good)

; Человеческая запись — с точностью до пробелов и регистра модификатора.
good := true
for s in ["Ctrl + Alt + F4", "ctrl+alt+f4", "Control + Alt + F4", " Alt + Ctrl + F4 "]
    good := good && HotkeyOk(s)
Assert("18a2: человеческие модификаторы (Ctrl/Control, любой регистр, любой их порядок) принимаются", good)

bad := true
for s in ["нечто", "^!F99", "Ctrl + Alt + Bla", "Ctrl+Alt+Bla", "Ctrl + Alt + Alt + F2"]
    bad := bad && !HotkeyOk(s)
Assert("18b: незнакомое имя клавиши или повтор модификатора — отказ по синтаксису", bad)

err18 := ""
SettingsHotkeyInCopy("Ctrl + Alt + Bla", "", "Слот 2: хоткей", 0, Map(), &err18)
Assert("18b2: причина отказа — не название клавиши, а не «занято», и назван годный пример",
    InStr(err18, "не сочетание клавиш AutoHotkey") > 0 && InStr(err18, "Ctrl + Alt + F2") > 0)

err18 := ""
Assert("18c: пустой хоткей — это «хоткея нет», а не ошибка",
    SettingsHotkeyInCopy("", "", "хоткей", 0, Map(), &err18) = "" && err18 = "")

err18 := ""
Assert("18d: пробелы по краям снимаются, а не отвергаются",
    SettingsHotkeyInCopy("  ^!F3  ", "", "хоткей", 0, Map(), &err18) = "^!F3" && err18 = "")

err18 := ""
SettingsHotkeyInCopy("Ctrl + Alt + Bla", "", "Слот 2: хоткей", 0, Map(), &err18)
Assert("18e: отказ называет и поле, и годный пример человеческой записью",
    InStr(err18, "Слот 2: хоткей") > 0 && InStr(err18, "Ctrl + Alt + F2") > 0)

reg18 := true
try
    Hotkey(HookedCopy("^!F9"), "On")
catch
    reg18 := false
Assert("18f: проверка безвредна — уже назначенный хоткей остался управляемым", reg18)

; Испорченное (или занятое) значение, уже лежащее в config.ini, не должно
; запирать правку соседних полей: точечная запись его и так не трогает.
; live — то, что реально хранит config.ini: синтаксис AutoHotkey, не
; человеческий текст.
Assert("18r: неизменённое (по факту) значение проходит, менять соседнее поле не мешает",
    HotkeyOk("Ctrl + Alt + 2", "^!2"))
Assert("18s: но стоит его тронуть — и отказ приходит сразу (теперь как конфликт, раз синтаксис годный)",
    !HotkeyOk("Ctrl + Alt + 3", "^!2"))

; --- конфликт с зарезервированными хоткеями ящика ----------------------
Assert("18t: Ctrl+Alt+N — уже основной хоткей слота N, в любой записи",
    !HotkeyOk("Ctrl + Alt + 2") && !HotkeyOk("^!5") && !HotkeyOk("Ctrl+Alt+9"))
Assert("18u: Ctrl+Alt+Shift+N — уже хоткей назначения слота N",
    !HotkeyOk("Ctrl + Alt + Shift + 3"))
Assert("18v: Ctrl+Alt+0 и Ctrl+Alt+Shift+0 — очистка и выход, тоже заняты",
    !HotkeyOk("Ctrl + Alt + 0") && !HotkeyOk("Ctrl + Alt + Shift + 0"))

err18 := ""
SettingsHotkeyInCopy("Ctrl + Alt + 2", "", "Слот 1: хоткей", 1, Map(), &err18)
Assert("18w: отказ конфликта называет то, с чем совпало, а не только «занято»",
    InStr(err18, "уже занято") > 0 && InStr(err18, "показать/убрать слот 2") > 0)

; --- конфликт с чужим focusHotkey ---------------------------------------
others18 := Map(2, "^!F6")
Assert("18x: совпадение с чужим focusHotkey — тоже конфликт",
    !HotkeyOk("Ctrl + Alt + F6", "", 1, others18))
Assert("18y: совпадение со своим же текущим значением — не конфликт (себя исключаем из обхода)",
    HotkeyOk("Ctrl + Alt + F6", "", 2, others18))

; --- HotkeyAhkToHuman: обратное преобразование для показа --------------
Assert("18z: модификаторы показываются словами, порядок — как в значении",
    HotkeyAhkToHumanCopy("^!F2") = "Ctrl+Alt+F2" && HotkeyAhkToHumanCopy("^!#1") = "Ctrl+Alt+Win+1"
 && HotkeyAhkToHumanCopy("F13") = "F13" && HotkeyAhkToHumanCopy("") = "")
Assert("18aa: экзотика с $/*/~ не переводится — показывается синтаксисом AutoHotkey как есть",
    HotkeyAhkToHumanCopy("~$+F3") = "~$+F3" && HotkeyAhkToHumanCopy("*^!Numpad1") = "*^!Numpad1")

e18 := ""
Assert("18ab: round-trip — что показали (HotkeyAhkToHuman), то и сохранится тем же значением",
    HotkeyHumanToAhkCopy(HotkeyAhkToHumanCopy("^!#1"), &e18) = "^!#1" && e18 = "")
e18 := ""
Assert("18ac: экзотика без распознанных слов-модификаторов проходит насквозь без разбора",
    HotkeyHumanToAhkCopy("~$+F3", &e18) = "~$+F3" && e18 = "")

; --- запись и чтение [slotN] focusHotkey на настоящем INI ------------
hkIni := A_Temp "\drawer-seam-hotkey.ini"
try FileDelete(hkIni)
IniWrite("^!F2", hkIni, "slot1", "focusHotkey")
IniWrite("notepad.exe", hkIni, "slot1", "exe")
Assert("18g: focusHotkey переживает запись и чтение config.ini",
    IniRead(hkIni, "slot1", "focusHotkey", "") = "^!F2")
IniWrite("^!F4 ", hkIni, "slot1", "focusHotkey")
Assert("18h: IniRead снимает окружающие пробелы — поэтому значение обрезают до записи",
    IniRead(hkIni, "slot1", "focusHotkey", "") = "^!F4")
; Слот без ключа — это слот без хоткея, а не слот с мусором.
Assert("18i: отсутствующий ключ читается пустым значением",
    IniRead(hkIni, "slot1", "нетТакого", "") = "")
try FileDelete(hkIni)

; --- статические проверки исходников ---------------------------------
if !FileExist(drawerPath) || !FileExist(slotsPath) {
    Assert("18: src/drawer.ahk и src/Slots.ahk найдены рядом с test/narrow", false)
} else {
    src18 := FileRead(drawerPath, "UTF-8")
    src18s := FileRead(slotsPath, "UTF-8")

    pSW18 := InStr(src18, "SettingsSlotWrites(n, e, &err, &field?) {")
    pSP18 := InStr(src18, "SettingsSlotsPlan(edits, &err) {")
    codeSW18 := (pSW18 > 0 && pSP18 > pSW18) ? NoComments(SubStr(src18, pSW18, pSP18 - pSW18)) : ""
    Assert("18j: план проверяет хоткей синтаксисом и номером слота, а не как обычный текст",
        codeSW18 != "" && InStr(codeSW18, "SettingsHotkeyIn(e.focusHotkey, SettingsLiveSlot(n, `"focusHotkey`")") > 0
     && InStr(codeSW18, ", n, &err)") > 0 && InStr(codeSW18, "SettingsTextIn(e.focusHotkey") = 0)
    Assert("18k: отказ несёт адрес контрола, а форме есть куда вести",
        InStr(codeSW18, "field := `"slots.`" n `".focusHotkey`"") > 0)

    pHK := InStr(src18, "SettingsHotkeyIn(v, live, label, n, &err) {")
    bodyHK := pHK ? NoComments(SubStr(src18, pHK, 1600)) : ""
    Assert("18l: своего разбора клавиши не заводится — спрашивается AutoHotkey",
        pHK > 0 && InStr(bodyHK, "Hotkey(Hooked(s)") > 0)
    Assert("18l2: перед проверкой синтаксиса человеческий ввод переводится в AHK",
        InStr(bodyHK, "HotkeyHumanToAhk(human, &herr)") > 0)
    Assert("18l3: после годного синтаксиса спрашивается конфликт с чужим хоткеем",
        InStr(bodyHK, "SettingsHotkeyConflict(s, n)") > 0)
    Assert("18m: проверка выключена и в контексте, который никогда не истинен",
        InStr(bodyHK, "HotIf never") > 0 && InStr(bodyHK, "`"Off`"") > 0
     && InStr(bodyHK, "static never := (*) => false") > 0)
    Assert("18n: контекст возвращается на место при любом исходе",
        InStr(bodyHK, "finally") > 0)

    ; Регистрация при старте берёт значение из реестра — того же, который
    ; наполняет LoadConfig, — а не из формы и не из отдельного списка.
    Assert("18o: хоткей при старте регистрируется значением из реестра",
        InStr(src18, "for a in SlotPermList() {") > 0
     && InStr(src18, "Hotkey(Hooked(a.focusHotkey), OnFocusHotkey.Bind(a.slot))") > 0)
    Assert("18p: focusHotkey читается из [slotN] и живёт в записи слота",
        InStr(src18, "focusHotkey: IniRead(path, section, `"focusHotkey`", `"`")") > 0
     && InStr(src18, "focusHotkey: Opt(a, `"focusHotkey`", `"`")") > 0)
    Assert("18q: засев формы берёт хоткей у самого слота, а не выдумывает его",
        InStr(src18, "focusHotkey: a.focusHotkey") > 0
     && InStr(src18s, "perm     := 0") > 0)

    ; Форма показывает и принимает человеческую запись; синтаксис
    ; AutoHotkey нигде, кроме config.ini, наружу не течёт. Один конвертер
    ; на обе поверхности (native Edit и WebView DTO) — источник истины один.
    portPath18 := A_ScriptDir "\..\..\src\webview\SettingsPort.ahk"
    Assert("18ab2: native показывает хоткей человеческой записью, не сырым config-значением",
        InStr(src18, "ui.eFocus.Value := HotkeyAhkToHuman(Opt(cfg, `"focusHotkey`", `"`"))") > 0)
    if FileExist(portPath18) {
        srcPort18 := FileRead(portPath18, "UTF-8")
        Assert("18ac2: WebView DTO тоже переводит хоткей в человеческую запись, вторым конвертером не заводится",
            InStr(srcPort18, "HotkeyAhkToHuman(String(Opt(cfg, `"focusHotkey`", `"`")))") > 0)
    }

    ; Основной хоткей слота (Ctrl+Alt+N) — не focusHotkey, и форма не
    ; должна выдавать дополнительный хоткей за единственный.
    Assert("18ad: панель постоянного слота отдельно показывает основной Ctrl+Alt+N",
        InStr(src18, "ui.primaryHotkey.Text := `"Основной: Ctrl + Alt + `" ef.n") > 0)

    ; --- SlotsSeedManaged: кромка постоянного слота без первого toggle ---
    pSeed := InStr(src18, "SlotsSeedManaged() {")
    bodySeed := pSeed ? NoComments(SubStr(src18, pSeed, 900)) : ""
    Assert("18ae: SlotsSeedManaged считает геометрию тем же путём, что и Show(), но окно не двигает",
        bodySeed != "" && InStr(bodySeed, "ResolveMonitorForExisting(a, hwnd)") > 0
     && InStr(bodySeed, "CaptureOrigin(hwnd, mi)") > 0
     && InStr(bodySeed, "ComputeGeom(a, mi)") > 0
     && InStr(bodySeed, "WinMove") = 0 && InStr(bodySeed, "WinActivate") = 0)
    Assert("18af: уже managed окно SlotsSeedManaged не трогает",
        InStr(bodySeed, "WindowManaged(hwnd)") > 0)

    ; --- ResolveMonitorForExisting: монитор уже стоящего окна, не курсора ---
    ; До фикса засев брал ResolveMonitor(a) — курсор в момент СТАРТА
    ; DRAWER, никак не связанный с тем, где уже висит окно постоянного
    ; слота. Кромка вставала на случайный монитор, и первый реальный показ
    ; уводил окно за ней, вместо чистого тумблера на месте (Р24, слот 3
    ; GitHub Desktop). Явно заданный номер монитора эта подмена не трогает
    ; — там решение уже принял пользователь.
    pRme := InStr(src18, "ResolveMonitorForExisting(a, hwnd) {")
    bodyRme := pRme ? NoComments(SubStr(src18, pRme, 900)) : ""
    Assert("18aj: ResolveMonitorForExisting найдена в src/drawer.ahk",
        pRme > 0)
    Assert("18ak: явный номер монитора идёт мимо подмены, как решил пользователь",
        InStr(bodyRme, "if (a.monitor != `"cursor`")") > 0
     && InStr(bodyRme, "return ResolveMonitor(a)") > 0)
    Assert("18al: monitor=cursor у уже стоящего окна решает площадь пересечения с монитором, не MouseGetPos",
        InStr(bodyRme, "WinGetPos(") > 0 && InStr(bodyRme, "MonitorGetCount()") > 0
     && InStr(bodyRme, "MouseGetPos") = 0)
    Assert("18am: окно ни на одном мониторе (например, осталось припарковано от убитого процесса) — тот же откат на курсор",
        StrSplit(bodyRme, "return ResolveMonitor(a)").Length = 3)
    ; Вызов при старте — отдельной строкой, а не сразу за Slots.Apply(
    ; bootConfig): state/handles ещё не объявлены в этой точке файла
    ; (они ниже, глобальными присваиваниями), и вызов раньше свалился бы.
    Assert("18ag: вызывается при старте, до первой пересборки кромок",
        InStr(src18, "SlotsSeedManaged()`r`nSetTimer(HandlesSync, -1)") > 0)
    Assert("18ah: и в SettingsReconcileRuntime — после каждого Save, не только при старте",
        InStr(src18, "Slots.Apply(cfg, slotPlan.prevPerm)`r`n    SlotsSeedManaged()") > 0)

    ; --- Permanent -> Dynamic конверсией через native Settings ------------
    ; До фикса ui.edits[r.n] := { kind: "dyn" } не нёс width/edge/monitor/
    ; activateOnShow/hideOnBlur, и SettingsDynSlotWrites() падал на первом
    ; же e.width — Save конверсии из native был всегда сломан, не только
    ; терял окно. dSeed := SlotCfg(r.n) — тот же засев, каким уже
    ; пользуется SettingsEffective() для уже динамического слота (ef.kind
    ; = "dyn"): дублировать его вторым набором умолчаний не нужно.
    pConv := InStr(src18, "SettingsConvertClick(ui) {")
    pConvEnd := InStr(src18, "SettingsSlotExePick(ui) {")
    bodyConv := (pConv > 0 && pConvEnd > pConv) ? NoComments(SubStr(src18, pConv, pConvEnd - pConv)) : ""
    Assert("18ai: конверсия в динамический засевает все пять полей поведения, не только kind",
        bodyConv != "" && InStr(bodyConv, "SlotCfg(r.n)") > 0
     && InStr(bodyConv, "width: d.width, edge: d.edge, monitor: d.monitor") > 0
     && InStr(bodyConv, "activateOnShow: d.activateOnShow, hideOnBlur: d.hideOnBlur") > 0)
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
