#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent()
SetWinDelay(-1)
CoordMode("Mouse", "Screen")   ; по умолчанию v2 отдаёт координаты активного окна

; =========================== НАСТРОЙКИ ===========================
; Слот — номер от 1 до 9. Хоткеи слота заданы номером и не настраиваются:
;   Ctrl+Alt+N        — выдвинуть / убрать окно слота
;   Ctrl+Alt+Shift+N  — запомнить в слоте текущее активное окно
;   Ctrl+Alt+0        — очистить все динамические слоты
;   Ctrl+Alt+Shift+0  — выход, окна возвращаются на исходные места
;
; Все настройки — в config.ini рядом с программой (образец —
; config.example.ini). Файл читается заново при каждом запуске, сама
; программа его никогда не переписывает. После правки — перезапустить.
configPath := A_ScriptDir "\config.ini"
if !FileExist(configPath) {
    MsgBox("Не найден config.ini рядом с программой:`n" configPath
         "`n`nСкопируйте config.example.ini в config.ini и настройте под себя.",
         "Ящик", 16)
    ExitApp()
}

apps         := []
dynamic      := {}
dynamicSlots := Map()
animMs       := 160
animSteps    := 14
blurMs       := 250
LoadConfig(configPath, &apps, &dynamic, &dynamicSlots, &animMs, &animSteps, &blurMs)
; =================================================================

; Читает config.ini в структуры программы. Числовые и строковые поля
; (monitor, edge, width, animMs…) идут в апп как есть — их as-is уже
; проверяют ResolveMonitor/ComputeGeom при показе и сообщают об ошибке
; через тот же try/catch, что и раньше (N2). Отдельно проверяются
; только activateOnShow/hideOnBlur: непустая строка "false" в AHK
; истинна, поэтому её нужно явно разобрать, а не просто передать дальше.
LoadConfig(path, &apps, &dynamic, &dynamicSlots, &animMs, &animSteps, &blurMs) {
    animMs    := IniRead(path, "general", "animMs", 160)
    animSteps := IniRead(path, "general", "animSteps", 14)
    blurMs    := IniRead(path, "general", "blurMs", 250)

    permSlotNums := Map()
    Loop 9 {
        n := A_Index
        section := "slot" n
        exe := IniRead(path, section, "exe", "")
        if (exe = "")   ; поля нет или оно пустое — слот остаётся динамическим
            continue
        apps.Push({
            slot: n,
            name: IniRead(path, section, "name", "Слот " n),
            exe: exe,
            cls: IniRead(path, section, "cls", ""),
            focusHotkey: IniRead(path, section, "focusHotkey", ""),
            monitor: IniRead(path, section, "monitor", "cursor"),
            edge: IniRead(path, section, "edge", "right"),
            width: IniRead(path, section, "width", 60),
            activateOnShow: IniBool(path, section, "activateOnShow", true),
            hideOnBlur: IniBool(path, section, "hideOnBlur", true)
        })
        permSlotNums[n] := true
    }

    dynamic := {
        name: IniRead(path, "dynamic", "name", "Слот"),
        monitor: IniRead(path, "dynamic", "monitor", "cursor"),
        edge: IniRead(path, "dynamic", "edge", "right"),
        width: IniRead(path, "dynamic", "width", 60),
        activateOnShow: IniBool(path, "dynamic", "activateOnShow", true),
        hideOnBlur: IniBool(path, "dynamic", "hideOnBlur", true)
    }

    Loop 9 {
        n := A_Index
        section := "dynamicSlot" n
        if (IniRead(path, section, , "") = "")   ; секции нет или она пуста
            continue
        if permSlotNums.Has(n) {
            MsgBox("[" section "] задан в config.ini, но слот " n " уже постоянный ([slot" n "]) — динамические настройки для него не действуют", "Ящик")
            continue
        }
        dynamicSlots[n] := {
            name: IniRead(path, section, "name", dynamic.name),
            monitor: IniRead(path, section, "monitor", dynamic.monitor),
            edge: IniRead(path, section, "edge", dynamic.edge),
            width: IniRead(path, section, "width", dynamic.width),
            activateOnShow: IniBool(path, section, "activateOnShow", dynamic.activateOnShow),
            hideOnBlur: IniBool(path, section, "hideOnBlur", dynamic.hideOnBlur)
        }
    }
}

; "true"/"false" — единственный ожидаемый формат. Непустая строка "false"
; сама по себе истинна в AHK, поэтому её нельзя передавать в Opt() как есть.
IniBool(path, section, key, def) {
    v := IniRead(path, section, key, def ? "true" : "false")
    if (v = "true")
        return true
    if (v = "false")
        return false
    MsgBox("config.ini: [" section "] " key "=" v " — ожидается true или false, взято " (def ? "true" : "false"), "Ящик")
    return def
}

managed   := Map()   ; индекс приложения -> hwnd
state     := Map()   ; hwnd -> { orig, geom }
watched   := Map()   ; выдвинутые окна с hideOnBlur: hwnd -> настройки
permSlots := Map()   ; номер слота -> индекс в apps
dynSlots  := Map()   ; номер слота -> hwnd
notified  := Map()   ; текст уведомления -> true, пока оно ещё актуально
foreWnd   := WinExist("A")     ; текущее окно переднего плана
lastFore  := 0                 ; окно, которое было активно до него

; Хоткеи ставятся через клавиатурный хук ($). RegisterHotkey отдаёт
; комбинацию первому, кто её занял: если предыдущий экземпляр ещё не
; умер, новый молча остаётся без клавиш — процесс жив, хоткеи мертвы.
; Хук от этого не зависит.
; Номер слота — секция config.ini (slot1…slot9), поэтому дубликат или
; выход за 1…9 структурно невозможен, в отличие от прежних литералов.
for i, a in apps
    permSlots[a.slot] := i

live := 0
Loop 9 {
    n := A_Index
    try {
        Hotkey(Hooked("^!" n), OnSlot.Bind(n))
        live++
    } catch as e
        MsgBox("Хоткей слота " n " не назначен:`n" e.Message, "Ящик")
    try {
        Hotkey(Hooked("^!+" n), OnSlotBind.Bind(n))
        live++
    } catch as e
        MsgBox("Хоткей назначения слота " n " не назначен:`n" e.Message, "Ящик")
}
for i, a in apps {
    if (Opt(a, "focusHotkey", "") = "")
        continue
    try {
        Hotkey(Hooked(a.focusHotkey), OnFocusHotkey.Bind(i))
        live++
    } catch as e
        MsgBox("Хоткей фокуса " a.focusHotkey " (" a.name ") не назначен:`n" e.Message, "Ящик")
}
try {
    Hotkey(Hooked("^!0"), OnClearHotkey)
    live++
} catch as e
    MsgBox("Хоткей очистки слотов не назначен:`n" e.Message, "Ящик")
try {
    Hotkey(Hooked("^!+0"), (*) => ExitApp())
    live++
} catch as e
    MsgBox("Хоткей выхода не назначен:`n" e.Message, "Ящик")

; Windows активировала окно — Alt+Tab, щелчок по значку на панели задач,
; что угодно ещё. Если это окно ящика и оно припарковано, выдвигаем его.
; Хук пассивный: ничего не перехватывает и не может сломать обычную
; активацию, он только сообщает. Отдельная интеграция с панелью задач
; поэтому не нужна.
foreCb   := CallbackCreate(OnForeground, "F", 7)
foreHook := DllCall("SetWinEventHook", "UInt", 0x0003, "UInt", 0x0003, "Ptr", 0
                  , "Ptr", foreCb, "UInt", 0, "UInt", 0, "UInt", 0, "Ptr")
if !foreHook
    Notify("Активация припаркованных окон работать не будет", "Ящик", 2)

OnExit(Cleanup)
Notify("Хоткеев живо: " live, "Ящик запущен", 1)

Hooked(hk) {
    return (SubStr(hk, 1, 1) = "$") ? hk : "$" hk
}

; Windows ставит каждый TrayTip в свою очередь показа и не знает, что
; такой же уже показан или ждёт своей очереди — быстрые повторные
; нажатия одного хоткея (например, пустого слота) копятся и всплывают
; ещё долго после того, как пользователь перестал жать. Дедуп — по
; тексту с заголовком: номер слота уже часть текста ("Слот 3 пуст"),
; поэтому разные слоты друг другу не мешают сами по себе. Одинаковое
; уведомление можно показать снова, как только пройдёт время, за
; которое прежнее успевает и показаться, и исчезнуть.
Notify(text, title := "Ящик", opt := 1) {
    global notified
    key := title "|" text
    if notified.Has(key)
        return
    notified[key] := true
    SetTimer(() => notified.Delete(key), -4000)
    TrayTip(text, title, opt)
}

; Настройка приложения со значением по умолчанию: запись в apps можно
; писать короткой, не перечисляя всё.
Opt(cfg, name, def) {
    return cfg.HasOwnProp(name) ? cfg.%name% : def
}

; Ошибка на одном окне не должна ронять программу целиком — N2.
OnSlot(n, *) {
    try
        ToggleSlot(n)
    catch as e
        Notify("Сбой: " e.Message, "Ящик", 3)
}

OnSlotBind(n, *) {
    try
        BindSlot(n)
    catch as e
        Notify("Сбой: " e.Message, "Ящик", 3)
}

OnClearHotkey(*) {
    try
        ClearDynamic()
    catch as e
        Notify("Сбой: " e.Message, "Ящик", 3)
}

; Колбэк хука должен возвращать управление немедленно, поэтому вся
; работа уходит в обычный поток через таймер.
;
; Событий приходит больше, чем переключений. Переключатель Alt+Tab по
; дороге отдаёт передний план своим служебным окнам и присылает такое
; событие ещё раз уже после того, как выбранное окно стало активным.
; До срабатывания таймера остаётся последнее событие — то есть мусорное,
; и выбор пользователя терялся. Поэтому служебные окна отсеиваем сразу,
; в самом событии: до таймера доходят только настоящие окна.
OnForeground(hook, event, hwnd, idObject, idChild, thread, time) {
    global foreWnd, lastFore
    if (idObject != 0 || !hwnd) ; OBJID_WINDOW: событие про само окно
        return
    if !TrackedFore(hwnd)       ; служебное окно, а не выбор пользователя
        return
    if (hwnd = foreWnd)         ; то же самое окно, в том числе после нашей
        return                  ; собственной активации
    lastFore := foreWnd
    foreWnd  := hwnd
    SetTimer(ForegroundWork, -1)
}

; Настоящее ли это окно приложения. Переключатель Alt+Tab, панель задач
; и прочая оболочка тоже получают передний план, но выбором пользователя
; это не является. Проверяем в момент события: служебные окна живут доли
; секунды, и через миллисекунду отличить их от закрытого пользователем
; окна уже нельзя.
TrackedFore(hwnd) {
    if !hwnd
        return false
    try {
        if !WinExist("ahk_id " hwnd)
            return false
        if (WinGetTitle("ahk_id " hwnd) = "")
            return false
        cls := WinGetClass("ahk_id " hwnd)
        if (cls = "Progman" || cls = "WorkerW"
            || cls = "Shell_TrayWnd" || cls = "Shell_SecondaryTrayWnd"
            || cls = "XamlExplorerHostIslandWindow" || cls = "MultitaskingViewFrame")
            return false
        return !(WinGetExStyle("ahk_id " hwnd) & 0x00000080)    ; WS_EX_TOOLWINDOW
    }
    return false
}

; Показать имеет право только окно из самого события и только если оно
; припарковано. Цикл «показали — событие — снова показали» гасится не
; флагом, а фактом: после показа окно уже на экране, и повторное
; событие от нашей же активации ничего не делает.
ForegroundWork() {
    global foreWnd, lastFore, state
    Critical()
    hwnd := foreWnd, prev := lastFore
    if (!hwnd || !state.Has(hwnd) || !WinExist("ahk_id " hwnd))
        return
    if !(cfg := SlotOf(hwnd))               ; окно не наше — не трогаем
        return
    try {
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        if HitsMonitor(x, y, w, h)          ; видно на экране — не наше дело
            return
        ; Активация досталась панели по наследству: предыдущее настоящее
        ; окно свернули или закрыли, и Windows отдала фокус следующему в
        ; Z-порядке. Пользователь панель не выбирал — показывать нельзя,
        ; но и оставлять фокус в невидимом окне тоже.
        if Vanished(prev) {
            RedirectFocus(hwnd)
            return
        }
        Show(hwnd, cfg, state[hwnd], false, prev)
    } catch as e
        Notify("Сбой: " e.Message, "Ящик", 3)
}

; Окно перестало быть активным потому, что исчезло, а не потому, что
; пользователь выбрал другое: закрыто, скрыто или свёрнуто.
Vanished(hwnd) {
    if (!hwnd || !WinExist("ahk_id " hwnd))
        return true
    return WinGetMinMax("ahk_id " hwnd) = -1
}

; Каким слотом управляется это окно и с какими настройками.
SlotOf(hwnd) {
    global apps, managed, permSlots, dynSlots
    for n, i in permSlots {
        if (managed.Has(i) && managed[i] = hwnd)
            return apps[i]
    }
    for n, h in dynSlots {
        if (h = hwnd)
            return SlotCfg(n)
    }
    return 0
}

OnFocusHotkey(i, *) {
    try
        FocusApp(i)
    catch as e
        Notify("Сбой: " e.Message, "Ящик", 3)
}

; Слот: постоянный ищет своё приложение по процессу, динамический
; управляет запомненным окном.
ToggleSlot(n) {
    global permSlots, dynSlots
    if permSlots.Has(n) {
        ToggleApp(permSlots[n])
        return
    }
    if !dynSlots.Has(n) {
        Notify("Слот " n " пуст", "Ящик", 2)
        return
    }
    hwnd := dynSlots[n]
    if !WinExist("ahk_id " hwnd) {
        dynSlots.Delete(n)
        Release(hwnd)
        Notify("Окно слота " n " закрыто, слот освобождён", "Ящик", 2)
        return
    }
    ToggleWindow(hwnd, SlotCfg(n))
}

; Назначение слота: запоминается дескриптор конкретного окна, а не
; приложение. Постоянный слот перезаписать нельзя — иначе настройка из
; файла молча потерялась бы до перезапуска.
BindSlot(n) {
    global apps, permSlots, dynSlots
    if permSlots.Has(n) {
        Notify("Слот " n " занят постоянной привязкой: " apps[permSlots[n]].name, "Ящик", 2)
        return
    }
    if !(hwnd := PickActive()) {
        Notify("Активное окно не годится для ящика", "Ящик", 2)
        return
    }
    if (dynSlots.Has(n) && dynSlots[n] != hwnd)
        Release(dynSlots[n])          ; прежнее окно возвращаем на место
    dynSlots[n] := hwnd
    Notify("Слот " n ": " WinGetTitle("ahk_id " hwnd), "Ящик", 1)
}

; Очистка динамических слотов. Постоянные не трогаем, программа
; продолжает работать — это не выход.
ClearDynamic() {
    global dynSlots
    for n, hwnd in dynSlots
        Release(hwnd)
    dynSlots.Clear()
    Notify("Динамические привязки очищены", "Ящик", 1)
}

; Отпустить окно: вернуть на исходное место и забыть о нём. Окна,
; которого уже нет, это не касается — WinMove просто не сработает.
Release(hwnd) {
    global state, watched
    if watched.Has(hwnd)
        watched.Delete(hwnd)
    if !state.Has(hwnd)
        return
    st := state[hwnd]
    if st.orig
        try WinMove(st.orig.x, st.orig.y, st.orig.w, st.orig.h, "ahk_id " hwnd)
    state.Delete(hwnd)
}

; Настройки динамического слота: общие, поверх которых кладутся
; персональные, если для этого номера они заданы.
SlotCfg(n) {
    global dynamic, dynamicSlots
    if !dynamicSlots.Has(n)
        return dynamic
    own := dynamicSlots[n]
    return { name:           Opt(own, "name",           dynamic.name),
             monitor:        Opt(own, "monitor",        dynamic.monitor),
             edge:           Opt(own, "edge",           dynamic.edge),
             width:          Opt(own, "width",          dynamic.width),
             activateOnShow: Opt(own, "activateOnShow", dynamic.activateOnShow),
             hideOnBlur:     Opt(own, "hideOnBlur",     dynamic.hideOnBlur) }
}

; Постоянный слот: окно ищется по настройкам приложения.
ToggleApp(i) {
    global apps
    a := apps[i]
    if !(hwnd := AppWindow(i, a)) {
        Notify("Окно не найдено: " a.name, "Ящик", 2)
        return
    }
    ToggleWindow(hwnd, a)
}

FocusApp(i) {
    global apps
    a := apps[i]
    if !(hwnd := AppWindow(i, a)) {
        Notify("Окно не найдено: " a.name, "Ящик", 2)
        return
    }
    FocusWindow(hwnd, a)
}

; Захваченное окно помним: припаркованное окно поиском по площади
; можно спутать с другим окном того же приложения.
AppWindow(i, a) {
    global managed
    hwnd := (managed.Has(i) && WinExist("ahk_id " managed[i])) ? managed[i] : FindWindow(a)
    if hwnd
        managed[i] := hwnd
    return hwnd
}

; Окно, которое назначается в слот, — активное сейчас. Рабочий стол и
; панель задач не берём: их парковка сломала бы оболочку Windows.
PickActive() {
    if !(hwnd := WinExist("A"))
        return 0
    cls := WinGetClass("ahk_id " hwnd)
    if (cls = "Progman" || cls = "WorkerW"
        || cls = "Shell_TrayWnd" || cls = "Shell_SecondaryTrayWnd")
        return 0
    if (WinGetTitle("ahk_id " hwnd) = "")
        return 0
    WinGetPos(, , &w, &h, "ahk_id " hwnd)
    if (WinGetMinMax("ahk_id " hwnd) = 0 && (w < 200 || h < 200))
        return 0
    return hwnd
}

; Общая часть обоих ящиков: выдвинуть окно или убрать его.
; Critical — чтобы таймер потери фокуса не влез в середину анимации.
ToggleWindow(hwnd, cfg) {
    Critical()
    st := StateOf(hwnd)
    if IsDeployed(hwnd, st)
        Hide(hwnd, st)
    else
        Show(hwnd, cfg, st)
}

; Вернуть фокус. Новой привязки не создаёт; уже выдвинутое окно не
; двигает, поэтому и монитор панели не меняется.
FocusWindow(hwnd, cfg) {
    Critical()
    st := StateOf(hwnd)
    if !IsDeployed(hwnd, st) {
        Show(hwnd, cfg, st, true)
        return
    }
    WinActivate("ahk_id " hwnd)
    Watch(hwnd, cfg)
}

StateOf(hwnd) {
    global state
    if !state.Has(hwnd)
        state[hwnd] := { orig: 0, geom: 0, prev: 0 }
    return state[hwnd]
}

; forceActivate — вызов из хоткея фокуса: он активирует окно даже при
; activateOnShow: false, иначе от него не было бы смысла.
; prev — кому вернуть фокус, когда уберём. Задаётся только показом по
; событию активации: там окно уже стало активным само, и спрашивать об
; этом Windows поздно.
Show(hwnd, cfg, st, forceActivate := false, prev := 0) {
    st.prev := FocusCandidate(prev, hwnd) ? prev : PrevActive(hwnd)
    if (WinGetMinMax("ahk_id " hwnd) != 0)
        WinRestore("ahk_id " hwnd)

    mi := ResolveMonitor(cfg)
    if !st.orig
        st.orig := CaptureOrigin(hwnd, mi)

    st.geom := ComputeGeom(cfg, mi)
    g := st.geom
    WinMove(g.slide ? g.hx : g.sx, g.slide ? g.hy : g.sy, g.w, g.h, "ahk_id " hwnd)

    activate := forceActivate || Opt(cfg, "activateOnShow", true)
    if activate
        WinActivate("ahk_id " hwnd)
    else
        WinMoveTop("ahk_id " hwnd)   ; наверх, но фокус остаётся у пользователя

    if g.slide
        Slide(hwnd, g.hx, g.hy, g.sx, g.sy, g.w, g.h)
    if activate
        Watch(hwnd, cfg)
}

Hide(hwnd, st) {
    global watched
    if watched.Has(hwnd)
        watched.Delete(hwnd)
    wasActive := WinActive("ahk_id " hwnd) ? true : false
    g := st.geom
    if g.slide
        Slide(hwnd, g.sx, g.sy, g.hx, g.hy, g.w, g.h)
    WinMove(g.px, g.py, g.w, g.h, "ahk_id " hwnd)   ; парковка вне всех мониторов
    if wasActive
        RestoreFocus(hwnd, st)
}

; Припаркованное окно не должно остаться активным: ввод уходил бы в
; невидимое окно, а щелчок по значку на панели задач сворачивал бы его
; вместо активации. Возвращаем фокус тому, что работало до показа, а
; если его больше нет — верхнему подходящему окну по Z-порядку.
RestoreFocus(parked, st) {
    if FocusCandidate(st.prev, parked) {
        WinActivate("ahk_id " st.prev)
        return
    }
    RedirectFocus(parked)
}

; Увести фокус с припаркованного окна на верхнее подходящее по Z-порядку.
RedirectFocus(parked) {
    for hwnd in WinGetList() {
        if FocusCandidate(hwnd, parked) {
            WinActivate("ahk_id " hwnd)
            return
        }
    }
}

; Кто был активен перед показом. Само выезжающее окно, оболочка и то,
; что уже спрятано за краем, в кандидаты не годятся.
PrevActive(skip) {
    hwnd := WinExist("A")
    return FocusCandidate(hwnd, skip) ? hwnd : 0
}

; Годится ли окно, чтобы отдать ему фокус. Проверка по факту: окно за
; пределами всех мониторов не годится, кем бы оно ни было припарковано.
FocusCandidate(hwnd, skip) {
    if (!hwnd || hwnd = skip)
        return false
    try {
        if !WinExist("ahk_id " hwnd)
            return false
        if (WinGetMinMax("ahk_id " hwnd) = -1)
            return false
        if !(WinGetStyle("ahk_id " hwnd) & 0x10000000)      ; WS_VISIBLE
            return false
        if (WinGetTitle("ahk_id " hwnd) = "")
            return false
        cls := WinGetClass("ahk_id " hwnd)
        if (cls = "Progman" || cls = "WorkerW"
            || cls = "Shell_TrayWnd" || cls = "Shell_SecondaryTrayWnd")
            return false
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        return HitsMonitor(x, y, w, h)
    }
    return false
}

; Слежение за потерей фокуса. Таймер живёт только пока есть выдвинутое
; окно с hideOnBlur: в покое программа не делает ничего.
Watch(hwnd, cfg) {
    global watched, blurMs
    if !Opt(cfg, "hideOnBlur", true)
        return
    watched[hwnd] := cfg
    SetTimer(WatchBlur, blurMs)
}

; Убираем только то окно, которое выдвинул Ящик и которое он же
; активировал. Обычные окна таймер не трогает.
WatchBlur() {
    global watched, state
    for hwnd in watched.Clone() {
        st := state.Has(hwnd) ? state[hwnd] : 0
        if (!st || !WinExist("ahk_id " hwnd) || !IsDeployed(hwnd, st)) {
            if watched.Has(hwnd)
                watched.Delete(hwnd)
            continue
        }
        if StillFocused(hwnd)
            continue
        try Hide(hwnd, st)
    }
    if !watched.Count
        SetTimer(WatchBlur, 0)
}

; Не потеря фокуса, а всплывающее меню того же приложения: у Qt-программ
; (Telegram и подобных) контекстное меню — отдельное окно верхнего
; уровня, и на миг само становится передним планом, хотя пользователь
; никуда не уходил. У VS Code и Steam меню передний план не перехватывает
; вообще — там первая проверка (WinActive) отвечает сама. Отличаем
; всплывающее окно от честной потери фокуса тем же признаком, что уже
; использует TrackedFore() для служебных окон — WS_EX_TOOLWINDOW, — и
; только если оно принадлежит тому же процессу, что и слот: чужой
; тултип чужого приложения фокусом слота не считается.
StillFocused(hwnd) {
    if WinActive("ahk_id " hwnd)
        return true
    try {
        fore := WinExist("A")
        if !fore
            return false
        if !(WinGetExStyle("ahk_id " fore) & 0x00000080)    ; WS_EX_TOOLWINDOW
            return false
        return WinGetPID("ahk_id " fore) = WinGetPID("ahk_id " hwnd)
    }
    return false
}

; Выдвинуто ли окно на самом деле. Пользователь мог свернуть его,
; перетащить или изменить размер — тогда по хоткею надо показывать
; окно, а не прятать то, что и так не на месте.
IsDeployed(hwnd, st) {
    if !st.geom
        return false
    if (WinGetMinMax("ahk_id " hwnd) != 0)
        return false
    WinGetPos(&x, &y, , , "ahk_id " hwnd)
    return (Abs(x - st.geom.sx) <= 4 && Abs(y - st.geom.sy) <= 4)
}

; Монитор из настройки. Номер отключённого монитора не ошибка:
; работаем на мониторе под курсором, чтобы хоткей не переставал работать.
ResolveMonitor(a) {
    n := MonitorGetCount()
    if (a.monitor != "cursor") {
        if !IsInteger(a.monitor)
            throw ValueError('monitor: ожидается "cursor" или номер монитора, задано: ' a.monitor)
        if (a.monitor >= 1 && a.monitor <= n)
            return a.monitor
    }
    MouseGetPos(&mx, &my)
    Loop n {
        MonitorGet(A_Index, &l, &t, &r, &b)
        if (mx >= l && mx < r && my >= t && my < b)
            return A_Index
    }
    return MonitorGetPrimary()
}

; Геометрия панели: sx,sy — выдвинуто, hx,hy — конец анимации у самого
; края монитора, px,py — парковка за границей виртуального стола.
; Край берётся из настройки как есть и никогда не меняется программой.
ComputeGeom(a, mi) {
    MonitorGetWorkArea(mi, &L, &T, &R, &B)
    vL := SysGet(76), vT := SysGet(77), vW := SysGet(78), vH := SysGet(79)
    pct := Min(100, Max(5, a.width))

    switch a.edge {
    case "right":
        w := Integer((R - L) * pct / 100), h := B - T
        sx := R - w, sy := T, hx := R, hy := T
        px := vL + vW + 20, py := T
    case "left":
        w := Integer((R - L) * pct / 100), h := B - T
        sx := L, sy := T, hx := L - w, hy := T
        px := vL - w - 20, py := T
    case "bottom":
        w := R - L, h := Integer((B - T) * pct / 100)
        sx := L, sy := B - h, hx := L, hy := B
        px := L, py := vT + vH + 20
    case "top":
        w := R - L, h := Integer((B - T) * pct / 100)
        sx := L, sy := T, hx := L, hy := T - h
        px := L, py := vT - h - 20
    default:
        throw ValueError('edge: ожидается "left", "right", "top" или "bottom", задано: ' a.edge)
    }

    ; Анимация уводит окно за край монитора. Если там стоит соседний
    ; монитор, окно проехало бы по нему на виду — тогда анимации нет,
    ; окно паркуется сразу.
    return { sx: sx, sy: sy, hx: hx, hy: hy, px: px, py: py, w: w, h: h,
             slide: !HitsMonitor(hx, hy, w, h, mi) }
}

; Пересекается ли прямоугольник хоть с одним монитором. skip — номер
; монитора, который не учитывать.
HitsMonitor(x, y, w, h, skip := 0) {
    Loop MonitorGetCount() {
        if (A_Index = skip)
            continue
        MonitorGet(A_Index, &l, &t, &r, &b)
        if (x < r && x + w > l && y < b && y + h > t)
            return true
    }
    return false
}

; Исходное положение — то, куда окно вернётся при выходе. Если окно
; осталось припарковано от прошлого экземпляра (программу убили),
; запоминать эти координаты нельзя: выход отправил бы окно за экраны.
CaptureOrigin(hwnd, mi) {
    WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
    if HitsMonitor(x, y, w, h)
        return { x: x, y: y, w: w, h: h }
    MonitorGetWorkArea(mi, &L, &T, &R, &B)
    return { x: L + (R - L) // 10, y: T + (B - T) // 10,
             w: (R - L) * 8 // 10, h: (B - T) * 8 // 10 }
}

; Настоящее окно приложения: видимое, с заголовком, разумного размера.
; Служебные окна JetBrains без заголовка отсеиваются здесь.
FindWindow(a) {
    best := 0, bestArea := -1
    for hwnd in WinGetList("ahk_exe " a.exe) {
        try {
            if !(WinGetStyle("ahk_id " hwnd) & 0x10000000)      ; WS_VISIBLE
                continue
            if (a.cls != "" && WinGetClass("ahk_id " hwnd) != a.cls)
                continue
            if (WinGetTitle("ahk_id " hwnd) = "")
                continue
            WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
            if (WinGetMinMax("ahk_id " hwnd) = 0 && (w < 200 || h < 200))
                continue
            if (w * h > bestArea) {
                bestArea := w * h
                best := hwnd
            }
        }
    }
    return best
}

Slide(hwnd, fromX, fromY, toX, toY, w, h) {
    global animSteps, animMs
    if (animSteps < 1) {
        try WinMove(toX, toY, w, h, "ahk_id " hwnd)
        return
    }
    delay := Max(1, animMs // animSteps)
    Loop animSteps {
        t := A_Index / animSteps
        e := 1 - (1 - t) ** 3
        try WinMove(Round(fromX + (toX - fromX) * e), Round(fromY + (toY - fromY) * e),
                    w, h, "ahk_id " hwnd)
        Sleep(delay)
    }
    try WinMove(toX, toY, w, h, "ahk_id " hwnd)
}

; При выходе возвращаем окна на исходные места, чтобы ничего
; не осталось за пределами экранов.
Cleanup(*) {
    global state, foreHook
    if foreHook
        DllCall("UnhookWinEvent", "Ptr", foreHook)
    for hwnd, st in state {
        if st.orig
            try WinMove(st.orig.x, st.orig.y, st.orig.w, st.orig.h, "ahk_id " hwnd)
    }
}
