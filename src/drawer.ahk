#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent()
SetWinDelay(-1)
CoordMode("Mouse", "Screen")   ; по умолчанию v2 отдаёт координаты активного окна

; Единственное место, где записана версия: build.ps1 читает её отсюда и
; так называет папку и архив релиза. Иначе номер расходится между кодом,
; сборкой и тем, что видит тестер.
VERSION := "0.1.2-beta"

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
handlesOn    := true
LoadConfig(configPath, &apps, &dynamic, &dynamicSlots, &animMs, &animSteps, &blurMs, &handlesOn)
; =================================================================

; Читает config.ini в структуры программы. Числовые и строковые поля
; (monitor, edge, width, animMs…) идут в апп как есть — их as-is уже
; проверяют ResolveMonitor/ComputeGeom при показе и сообщают об ошибке
; через тот же try/catch, что и раньше (N2). Отдельно проверяются
; только activateOnShow/hideOnBlur: непустая строка "false" в AHK
; истинна, поэтому её нужно явно разобрать, а не просто передать дальше.
LoadConfig(path, &apps, &dynamic, &dynamicSlots, &animMs, &animSteps, &blurMs, &handlesOn) {
    animMs    := IniRead(path, "general", "animMs", 160)
    animSteps := IniRead(path, "general", "animSteps", 14)
    blurMs    := IniRead(path, "general", "blurMs", 250)
    ; По умолчанию включено: в конфиге, написанном до появления кромок,
    ; строки нет, и поведение должно остаться таким же, как без неё.
    handlesOn := IniBool(path, "general", "handles", true)

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
handles   := Map()   ; номер слота -> кромка припаркованного окна
handleMode := 0      ; режим опроса кромок: 0 нет, 1 редкий, 2 частый
handleSync := 0      ; тактов до следующей полной пересборки кромок
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

; Кромка: толщина плитки в покое, при подходе курсора и под курсором,
; длина вдоль края и зазор в стопке. В покое плитка вмещает иконку
; приложения, поэтому тоньше 22 быть не может.
HANDLE_REST  := 22
HANDLE_NEAR  := 28
HANDLE_HOVER := 44
HANDLE_LEN   := 34
HANDLE_GAP   := 8
HANDLE_ICON  := 18
HANDLE_ROUND := 6
; Опознаётся кромка иконкой, поэтому сама плитка нарочно неяркая:
; спокойный тёмный цвет, чуть светлее под курсором.
HANDLE_BG     := "2A2E35"
HANDLE_BG_HOT := "3A414D"
HANDLE_FG     := "D6DAE2"
; Зона подхода: насколько курсор должен приблизиться поперёк края и
; насколько может отойти вдоль него.
HANDLE_PERP  := 130
HANDLE_ALONG := 70
; Длительность перехода между состояниями.
HANDLE_ANIM  := 140
; Периоды опроса и как часто редкий такт пересобирает набор кромок.
; Редкий такт дешёвый — только положение курсора, — поэтому он короткий:
; именно он задаёт задержку до начала роста, и раньше она читалась как
; рывок. Полная пересборка идёт раз в HANDLE_SYNC тактов.
HANDLE_SLOW  := 50
HANDLE_FAST  := 16
HANDLE_SYNC  := 4
OnMessage(0x0201, HandleClick)      ; WM_LBUTTONDOWN

OnExit(Cleanup)
; Единственное уведомление, которое ящик показывает сам по себе. Здесь же
; версия: иначе тестер не может сказать, какая у него сборка.
Notify("Запущен. Хоткеев: " live, "Ящик " VERSION, 1)

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
    if !dynSlots.Has(n)          ; нечего показывать — молчим
        return
    hwnd := dynSlots[n]
    if !WinExist("ahk_id " hwnd) {
        dynSlots.Delete(n)       ; окно закрыли — слот просто освобождается
        Release(hwnd)
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
    Notify("Слот " n " → " WinGetTitle("ahk_id " hwnd), "Ящик", 1)
}

; Очистка динамических слотов. Постоянные не трогаем, программа
; продолжает работать — это не выход.
ClearDynamic() {
    global dynSlots
    for n, hwnd in dynSlots
        Release(hwnd)
    dynSlots.Clear()
    SetTimer(HandlesSync, -1)
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
    SetTimer(HandlesSync, -1)    ; окно больше не наше — кромки у него нет
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

; Постоянный слот: окно ищется по настройкам приложения. Приложение не
; запущено — показывать нечего, молчим: это то же самое, что нажать на
; пустой слот.
ToggleApp(i) {
    global apps
    a := apps[i]
    if !(hwnd := AppWindow(i, a))
        return
    ToggleWindow(hwnd, a)
}

FocusApp(i) {
    global apps
    a := apps[i]
    if !(hwnd := AppWindow(i, a))
        return
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
    HandleDrop(hwnd)             ; кромка слота уступает место самому окну
    st.prev := FocusCandidate(prev, hwnd) ? prev : PrevActive(hwnd)
    if (WinGetMinMax("ahk_id " hwnd) != 0)
        WinRestore("ahk_id " hwnd)

    mi := ResolveMonitor(cfg)
    if !st.orig
        st.orig := CaptureOrigin(hwnd, mi)

    st.geom := ComputeGeom(cfg, mi)
    g := st.geom
    ; На внутреннем крае ставим окно сразу на место: заход через карман
    ; (hx) хотя бы на кадр показал бы его на соседнем мониторе.
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
    ; На внутреннем крае уезжаем сразу на парковку, минуя карман: он лежит
    ; на территории соседнего монитора.
    if g.slide
        Slide(hwnd, g.sx, g.sy, g.hx, g.hy, g.w, g.h)
    WinMove(g.px, g.py, g.w, g.h, "ahk_id " hwnd)   ; парковка вне всех мониторов
    if wasActive
        RestoreFocus(hwnd, st)
    SetTimer(HandlesSync, -1)    ; окно припарковано — кромка возвращается
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
; Critical — по той же причине, что и в ToggleWindow, только с другой
; стороны: Hide идёт через Slide со Sleep внутри, а Sleep — это место,
; где AHK запускает другой поток. Без Critical хоткей или показ по
; событию активации успевали целиком отработать посередине уборки, и
; уже показанное окно тут же допрятывалось остатком старой анимации.
WatchBlur() {
    global watched, state
    Critical()
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

    ; Карман — место, откуда окно выезжает и куда уезжает: полоса шириной
    ; в само окно сразу за выбранным краем монитора. У внешнего края там
    ; пусто, и окно можно везти через неё на виду. У внутреннего края —
    ; того, что смотрит на соседний монитор, — эта полоса физически
    ; принадлежит соседу, и любой кадр анимации показал бы окно на чужом
    ; экране. Своей территории для разгона там нет вовсе: окно шириной w
    ; помещается в монитор целиком только в одной позиции — уже
    ; выдвинутой, — поэтому «проехать хотя бы часть пути» невозможно.
    ;
    ; Значит выбор бинарный: либо окно видно на соседе, либо анимации
    ; нет. Инвариант важнее: на внутреннем крае показ и уборка идут
    ; мгновенным переносом, минуя карман. Окно при этом никогда не
    ; отображается за пределами своего монитора.
    ;
    ; Проверять достаточно полностью убранное положение: за время
    ; анимации окно занимает объединение от sx до hx+w, и часть, выходящая
    ; за монитор, — это ровно прямоугольник (hx, hy, w, h).
    ;
    ; Обрезка окна регионом (SetWindowRgn) позволила бы анимировать и
    ; здесь, но замерено: 14 обновлений региона стоят 218 мс при бюджете
    ; анимации 160 мс, а если процесс умрёт посреди анимации, чужое окно
    ; останется обрезанным навсегда. Цена выше пользы.
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
    HandlesDestroyAll()
    if foreHook
        DllCall("UnhookWinEvent", "Ptr", foreHook)
    for hwnd, st in state {
        if st.orig
            try WinMove(st.orig.x, st.orig.y, st.orig.w, st.orig.h, "ahk_id " hwnd)
    }
}

; ============================== КРОМКА ==============================
; Припаркованное окно лежит целиком за пределами всех мониторов —
; ухватиться за него мышью не за что, слот виден только по хоткею.
; Кромка — собственное окошко ящика: маленькая плитка с иконкой
; приложения у выбранного края выбранного монитора. При подходе курсора
; она подрастает, под курсором показывает номер слота, по щелчку слот
; выдвигается.
;
; Настоящее окно кромка не трогает вообще. Щелчок вызывает тот же
; OnSlot(), что и Ctrl+Alt+N, поэтому парковка, IsDeployed, hideOnBlur,
; анимация и возврат фокуса работают ровно как раньше и о кромке ничего
; не знают. Слой односторонний: кромка читает состояние ящика, ящик о
; кромке знает пятью строчками — «этот слот выдвигается» и «состояние
; слотов изменилось».
;
; Кромка есть у каждого припаркованного слота и только у него. Выдвинутый
; слот кромки не имеет — он и так на экране. Соседние слоты своих кромок
; при этом не теряют: в том и смысл, чтобы мышью перейти с выдвинутого
; окна на другое припаркованное, не трогая клавиатуру.
;
; Кромка всегда рисуется ВНУТРИ своего монитора: от рабочей области
; (MonitorGetWorkArea) и внутрь экрана. У внутреннего края — того, что
; смотрит на соседний монитор, — она поэтому тоже остаётся у себя и на
; соседа не попадает ни одним пикселем. Рабочая область, а не весь
; монитор, — потому что в ней уже учтена панель задач.
;
; Окно кромки: без заголовка, ToolWindow (мимо Alt+Tab),
; WS_EX_NOACTIVATE (щелчок не отбирает фокус у активной программы) и с
; пустым заголовком. Пустой заголовок важен отдельно: FocusCandidate(),
; PickActive() и TrackedFore() уже отсеивают окна без заголовка и
; служебные окна, так что для остального кода ящика кромок не
; существует — ни в Alt+Tab, ни в возврате фокуса, ни в привязке слота.

; Слоты по порядку номеров: номер, окно и его настройки. Порядок задаёт
; и порядок кромок в стопке, поэтому массив, а не Map.
HandleSlots() {
    global apps, managed, permSlots, dynSlots
    out := []
    Loop 9 {
        n := A_Index
        if permSlots.Has(n) {
            i := permSlots[n]
            if !(managed.Has(i) && WinExist("ahk_id " managed[i]))
                continue
            out.Push({ n: n, hwnd: managed[i], cfg: apps[i] })
        } else if dynSlots.Has(n) {
            if !WinExist("ahk_id " dynSlots[n])
                continue
            out.Push({ n: n, hwnd: dynSlots[n], cfg: SlotCfg(n) })
        }
    }
    return out
}

; Управляет ли ящик этим окном: геометрия посчитана, значит слот хоть раз
; показывали и его место в стопке кромок уже занято.
HandleManaged(hwnd) {
    global state
    return state.Has(hwnd) && state[hwnd].geom
}

; Припарковано ли окно слота — тот же признак, на котором держится весь
; ящик: окно не пересекается ни с одним монитором.
HandleParked(hwnd) {
    if !HandleManaged(hwnd)
        return false
    try {
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        return !HitsMonitor(x, y, w, h)
    }
    return false
}

; Место кромки в покое: idx-я из count штук у края edge монитора mi.
; Стопка компактная и стоит по центру края, порядок задаёт номер слота,
; поэтому одно и то же сочетание слотов всегда даёт одну и ту же
; раскладку.
HandleBase(mi, edge, idx, count) {
    global HANDLE_REST, HANDLE_LEN, HANDLE_GAP
    MonitorGetWorkArea(mi, &L, &T, &R, &B)
    total := count * HANDLE_LEN + (count - 1) * HANDLE_GAP
    switch edge {
    case "right":
        y := (T + B) // 2 - total // 2 + idx * (HANDLE_LEN + HANDLE_GAP)
        return { x: R - HANDLE_REST, y: y, w: HANDLE_REST, h: HANDLE_LEN }
    case "left":
        y := (T + B) // 2 - total // 2 + idx * (HANDLE_LEN + HANDLE_GAP)
        return { x: L, y: y, w: HANDLE_REST, h: HANDLE_LEN }
    case "bottom":
        x := (L + R) // 2 - total // 2 + idx * (HANDLE_LEN + HANDLE_GAP)
        return { x: x, y: B - HANDLE_REST, w: HANDLE_LEN, h: HANDLE_REST }
    case "top":
        x := (L + R) // 2 - total // 2 + idx * (HANDLE_LEN + HANDLE_GAP)
        return { x: x, y: T, w: HANDLE_LEN, h: HANDLE_REST }
    }
    return 0        ; край задан с ошибкой — про неё скажет ComputeGeom
}

; Та же кромка, но толщиной t. Растёт всегда внутрь экрана: внешняя
; грань остаётся ровно на границе рабочей области.
HandleGrown(b, edge, t) {
    global HANDLE_REST
    switch edge {
    case "right":  return { x: b.x + HANDLE_REST - t, y: b.y, w: t, h: b.h }
    case "left":   return { x: b.x, y: b.y, w: t, h: b.h }
    case "bottom": return { x: b.x, y: b.y + HANDLE_REST - t, w: b.w, h: t }
    case "top":    return { x: b.x, y: b.y, w: b.w, h: t }
    }
    return 0
}

; Иконка приложения — наша собственная копия, которую можно смело отдать
; контролу. Сначала спрашиваем окно (WM_GETICON), потом его класс, и
; только если и там пусто — вытаскиваем из exe. Первые два способа
; отдают чужой хэндл, принадлежащий приложению: разрушать его нельзя,
; поэтому наружу уходит копия. Замерено на восьми настоящих окнах: у
; Chrome и VS Code иконка приходит от класса, у Telegram-подобных и
; Explorer — из WM_GETICON.
HandleIcon(hwnd) {
    src := 0, mine := false
    for kind in [2, 0, 1] {           ; ICON_SMALL2, ICON_SMALL, ICON_BIG
        try {
            src := SendMessage(0x7F, kind, 0, , "ahk_id " hwnd, , , , 300)
            if src
                break
        }
    }
    if !src {
        for idx in [-34, -14] {       ; GCLP_HICONSM, GCLP_HICON
            src := DllCall("GetClassLongPtrW", "Ptr", hwnd, "Int", idx, "Ptr")
            if src
                break
        }
    }
    if !src {
        try {
            big := 0, small := 0
            DllCall("shell32\ExtractIconExW", "Str", ProcessGetPath(WinGetPID("ahk_id " hwnd)),
                    "Int", 0, "Ptr*", &big, "Ptr*", &small, "UInt", 1, "UInt")
            if big
                DllCall("DestroyIcon", "Ptr", big)
            src := small, mine := true
        }
    }
    if !src
        return 0
    copy := DllCall("CopyIcon", "Ptr", src, "Ptr")
    if mine
        DllCall("DestroyIcon", "Ptr", src)
    return copy
}

; Пересобрать набор кромок по текущему состоянию ящика. Вызывается
; редким таймером и после каждого события, которое может его изменить.
HandlesSync() {
    global handles, handlesOn
    if !handlesOn {                   ; кромки выключены в config.ini
        HandlesDestroyAll()
        return
    }
    slots := HandleSlots()

    ; Раскладка считается по группам «монитор + край». У слота с
    ; monitor=cursor монитор определяет тот же ResolveMonitor, что и при
    ; показе, поэтому кромка стоит там, куда окно и выедет.
    ;
    ; В стопку идут ВСЕ слоты этого края, которыми ящик управляет, а не
    ; только припаркованные: тогда место выдвинутого слота остаётся за
    ; ним и соседние кромки не прыгают, пока он ездит туда-обратно.
    groups := Map()
    for s in slots {
        if !HandleManaged(s.hwnd)
            continue
        try
            mi := ResolveMonitor(s.cfg)
        catch
            continue
        edge := Opt(s.cfg, "edge", "right")
        key := mi "|" edge
        if !groups.Has(key)
            groups[key] := []
        groups[key].Push({ n: s.n, hwnd: s.hwnd, mi: mi, edge: edge,
                           parked: HandleParked(s.hwnd) })
    }

    ; А кромку получает только припаркованный: выдвинутое окно и так на
    ; экране, кромка ему не нужна. Соседи свои сохраняют.
    keep := Map()
    for key, grp in groups {
        for i, g in grp {
            if !g.parked
                continue
            if !(b := HandleBase(g.mi, g.edge, i - 1, grp.Length))
                continue
            keep[g.n] := { hwnd: g.hwnd, mi: g.mi, edge: g.edge, base: b }
        }
    }

    for n, hd in handles.Clone() {
        if (!keep.Has(n) || keep[n].hwnd != hd.hwnd)
            HandleDestroy(n)          ; слот сменил окно — иконка уже не та
    }
    for n, k in keep {
        if !handles.Has(n) {
            HandleCreate(n, k)
            continue
        }
        hd := handles[n]
        hd.mi := k.mi, hd.edge := k.edge, hd.base := k.base
        HandleApply(hd)
    }
    HandleTimer()
}

HandleCreate(n, k) {
    global handles, HANDLE_REST, HANDLE_ICON, HANDLE_BG, HANDLE_FG
    g := Gui("-Caption +AlwaysOnTop +ToolWindow -DPIScale +E0x08000000", "")
    g.BackColor := HANDLE_BG
    g.MarginX := 0, g.MarginY := 0
    g.SetFont("s9 bold c" HANDLE_FG, "Segoe UI")
    ; 0x100 — SS_NOTIFY: без него щелчок по контролу не доходит до окна.
    ; HICON без звёздочки — контрол забирает хэндл себе и освобождает его
    ; при Destroy (проверено); поэтому отдаём копию, а не чужую иконку.
    pic := 0
    if (ic := HandleIcon(k.hwnd)) {
        try
            pic := g.Add("Picture", "x0 y0 w" HANDLE_ICON " h" HANDLE_ICON
                                    " BackgroundTrans 0x100", "HICON:" ic)
        catch {
            DllCall("DestroyIcon", "Ptr", ic)
            pic := 0
        }
    }
    txt := g.Add("Text", "x0 y0 w10 h15 Center BackgroundTrans 0x100", String(n))
    hd := { n: n, hwnd: k.hwnd, mi: k.mi, edge: k.edge, base: k.base,
            gui: g, pic: pic, txt: txt,
            thick: HANDLE_REST, from: HANDLE_REST, to: HANDLE_REST, t0: 0,
            rect: 0, label: -1, alpha: -1, hot: -1, ipos: "" }
    handles[n] := hd
    ; Вид доводится до покоя ДО показа: иначе в первом кадре успевает
    ; мигнуть номер слота, которому в плитке такой толщины ещё не место.
    hd.rect := HandleGrown(k.base, k.edge, HANDLE_REST)
    txt.Visible := false
    HandleFace(hd, HANDLE_REST)
    r := hd.rect
    g.Show(Format("NoActivate x{1} y{2} w{3} h{4}", r.x, r.y, r.w, r.h))
    HandleRound(hd)
}

; Скруглённые углы. Регион задан в координатах окна и при изменении
; размера не тянется, поэтому ставится заново на каждый новый размер.
; Замерено на своём окне: 0,32 мс за вызов — в кадр анимации помещается.
HandleRound(hd) {
    global HANDLE_ROUND
    r := hd.rect
    try WinSetRegion("0-0 w" r.w " h" r.h " R" HANDLE_ROUND "-" HANDLE_ROUND,
                     "ahk_id " hd.gui.Hwnd)
}

; Куда кромка едет теперь. Переход всегда идёт от текущей толщины, а не
; от той, на которой закончился прошлый: если курсор ушёл посреди роста,
; кромка поедет обратно с того места, где была, без скачка.
HandleAim(hd, target) {
    if (hd.to = target)
        return
    hd.from := hd.thick
    hd.to := target
    hd.t0 := A_TickCount
}

; Поставить окошко кромки на место по её текущей толщине.
HandleApply(hd) {
    t := Round(hd.thick)
    if !(r := HandleGrown(hd.base, hd.edge, t))
        return
    p := hd.rect
    if (!p || r.x != p.x || r.y != p.y || r.w != p.w || r.h != p.h) {
        try hd.gui.Move(r.x, r.y, r.w, r.h)
        hd.rect := r
        if (!p || r.w != p.w || r.h != p.h)
            HandleRound(hd)
    }
    HandleFace(hd, t)
}

; Внешний вид по толщине. В покое — только иконка приложения: она и есть
; опознавательный знак, подписи там лишние. Под курсором рядом с иконкой
; проявляется номер слота, плитка светлеет и становится непрозрачной.
; Иконка всегда прижата к внешней грани, номер растёт внутрь экрана —
; поэтому при изменении толщины иконка стоит на месте.
HandleFace(hd, t) {
    global HANDLE_REST, HANDLE_HOVER, HANDLE_ICON, HANDLE_BG, HANDLE_BG_HOT
    r := hd.rect
    pad := (HANDLE_REST - HANDLE_ICON) // 2

    if hd.pic {
        switch hd.edge {
        case "right":  ix := r.w - HANDLE_ICON - pad, iy := (r.h - HANDLE_ICON) // 2
        case "left":   ix := pad,                    iy := (r.h - HANDLE_ICON) // 2
        case "bottom": ix := (r.w - HANDLE_ICON) // 2, iy := r.h - HANDLE_ICON - pad
        default:       ix := (r.w - HANDLE_ICON) // 2, iy := pad
        }
        if ((at := ix "," iy) != hd.ipos) {
            hd.ipos := at
            try hd.pic.Move(ix, iy)
        }
    }

    ; Номер — только под курсором: при подходе места под него ещё нет.
    on := (t >= HANDLE_HOVER - 8) ? 1 : 0
    if (on != hd.label) {
        hd.label := on
        try hd.txt.Visible := on ? true : false
    }
    if on {
        free := (hd.edge = "left" || hd.edge = "right") ? r.w - HANDLE_REST
                                                        : r.h - HANDLE_REST
        switch hd.edge {
        case "right":  try hd.txt.Move(2, (r.h - 15) // 2, Max(8, free - 4), 15)
        case "left":   try hd.txt.Move(HANDLE_REST + 2, (r.h - 15) // 2, Max(8, free - 4), 15)
        case "bottom": try hd.txt.Move(0, 2, r.w, 15)
        default:       try hd.txt.Move(0, Max(0, r.h - 17), r.w, 15)
        }
    }

    if (on != hd.hot) {
        hd.hot := on
        try {
            hd.gui.BackColor := on ? HANDLE_BG_HOT : HANDLE_BG
            DllCall("InvalidateRect", "Ptr", hd.gui.Hwnd, "Ptr", 0, "Int", 1)
        }
    }

    ; Прозрачность ведётся за толщиной непрерывно, а не тремя ступенями:
    ; ступени были заметны как мигание посреди перехода. Округление до
    ; восьмёрки — чтобы не звать WinSetTransparent на каждый пиксель.
    k := (t - HANDLE_REST) / Max(1, HANDLE_HOVER - HANDLE_REST)
    a := 205 + Round(50 * Min(1, Max(0, k)) / 8) * 8
    if (a != hd.alpha) {
        hd.alpha := a
        try WinSetTransparent(Min(255, a), "ahk_id " hd.gui.Hwnd)
    }
}

HandleDestroy(n) {
    global handles
    if !handles.Has(n)
        return
    try handles[n].gui.Destroy()      ; иконку контрол освобождает сам
    handles.Delete(n)
}

; Слот выдвигается — его кромка должна исчезнуть до того, как окно
; поедет. Кромки остальных слотов остаются на местах: с них и берётся
; переход мышью на соседнее припаркованное окно.
HandleDrop(hwnd) {
    global handles
    for n, hd in handles.Clone() {
        if (hd.hwnd = hwnd)
            HandleDestroy(n)
    }
    HandleTimer()
    SetTimer(HandlesSync, -1)
}

HandlesDestroyAll() {
    global handles
    for n, hd in handles.Clone()
        HandleDestroy(n)
    HandleTimer()
}

; Опроса нет, пока нет ни одной кромки: в покое кромка не стоит ничего.
; fast = -1 — сохранить текущий режим.
HandleTimer(fast := -1) {
    global handles, handleMode, HANDLE_SLOW, HANDLE_FAST
    if (fast = -1)
        fast := (handleMode = 2)
    want := !handles.Count ? 0 : (fast ? 2 : 1)
    if (want = handleMode)
        return
    handleMode := want
    SetTimer(HandleTick, want = 0 ? 0 : (want = 2 ? HANDLE_FAST : HANDLE_SLOW))
}

; Мышь опрашивается, а не перехватывается хуком: хук на мышь — это
; глобальный перехват всего ввода ради одной плитки у края.
;
; Редкий такт делает только дешёвое — читает положение курсора; полная
; пересборка набора кромок идёт раз в HANDLE_SYNC тактов. Поэтому редкий
; период можно держать коротким: именно он определяет, через сколько
; кромка начнёт расти, и раньше эта задержка и читалась как рывок.
HandleTick() {
    global handles, handleSync, HANDLE_SYNC, HANDLE_ANIM
    if !handles.Count {
        HandleTimer(false)
        return
    }
    MouseGetPos(&mx, &my)
    live := false
    for n, hd in handles {
        HandleAim(hd, HandleTarget(hd, mx, my))
        if (hd.thick = hd.to)
            continue
        ; Переход по времени, а не «доля пути за такт»: длительность
        ; тогда не зависит от того, успевает ли таймер, и одинакова для
        ; роста и для возврата.
        p := Min(1, (A_TickCount - hd.t0) / HANDLE_ANIM)
        e := 1 - (1 - p) ** 3
        hd.thick := (p >= 1) ? hd.to : hd.from + (hd.to - hd.from) * e
        HandleApply(hd)
        live := true
    }
    if live {
        HandleTimer(true)
        return
    }
    HandleTimer(false)
    if (++handleSync >= HANDLE_SYNC) {
        handleSync := 0
        HandlesSync()
    }
}

; Какой толщины кромка должна быть при таком положении курсора. Зона
; подхода отсчитывается от покоящегося положения, чтобы она не ездила
; вслед за самой плиткой и та не дёргалась на границе зоны.
HandleTarget(hd, mx, my) {
    global HANDLE_REST, HANDLE_NEAR, HANDLE_HOVER, HANDLE_PERP, HANDLE_ALONG
    if (r := hd.rect) {
        if (mx >= r.x - 1 && mx <= r.x + r.w && my >= r.y - 1 && my <= r.y + r.h)
            return HANDLE_HOVER
    }
    b := hd.base
    dx := Max(b.x - mx, mx - (b.x + b.w), 0)
    dy := Max(b.y - my, my - (b.y + b.h), 0)
    vert := (hd.edge = "left" || hd.edge = "right")
    if (vert ? (dx <= HANDLE_PERP && dy <= HANDLE_ALONG)
             : (dy <= HANDLE_PERP && dx <= HANDLE_ALONG))
        return HANDLE_NEAR
    return HANDLE_REST
}

; Щелчок по кромке. Работа уходит в таймер: показ идёт со Sleep внутри,
; а обработчик сообщения обязан вернуть управление сразу. Вызывается
; ровно тот же OnSlot(), что висит на Ctrl+Alt+N, — другого пути показа
; у кромки нет.
HandleClick(wParam, lParam, msg, hwnd) {
    global handles
    for n, hd in handles {
        if (hwnd = hd.gui.Hwnd || hwnd = hd.txt.Hwnd
            || (hd.pic && hwnd = hd.pic.Hwnd)) {
            SetTimer(OnSlot.Bind(n), -1)
            return 0
        }
    }
}
