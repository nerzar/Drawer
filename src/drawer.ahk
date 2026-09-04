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
; Все настройки — в config.ini рядом с программой. Файл читается при
; запуске; окно Settings записывает только явно изменённые ключи после
; нажатия «Применить» или «ОК».
configPath := A_ScriptDir "\config.ini"
if !FileExist(configPath) {
    MsgBox("Не найден config.ini рядом с программой:`n" configPath
         "`n`nВерните config.ini из архива программы или создайте его заново.",
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
; (monitor, edge, width, animMs…) идут в приложение как есть — их
; проверяют ResolveMonitor/ComputeGeom при показе. Отдельно проверяются
; только activateOnShow/hideOnBlur: непустая строка "false" в AHK
; истинна, поэтому её нужно явно разобрать, а не просто передать дальше.
LoadConfig(path, &apps, &dynamic, &dynamicSlots, &animMs, &animSteps, &blurMs, &handlesOn) {
    ; Функцию должно быть можно вызвать повторно: настройки перечитывают
    ; конфиг после записи тем же вызовом, которым программа поднимается.
    ; Без сброса apps.Push() дописал бы второй комплект постоянных слотов
    ; к прежнему, а dynamicSlots сохранил бы секции, которых в файле уже
    ; нет: обе структуры заполняются добавлением, а не заменой.
    apps         := []
    dynamicSlots := Map()

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
setGui    := 0       ; окно настроек, пока оно открыто
setUI     := 0       ; его контролы и значения, с которыми окно открылось
setPickerGui := 0    ; окно выбора существующего окна (S4), пока оно открыто
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
; именно он задаёт задержку до начала роста. Полная пересборка идёт раз в
; HANDLE_SYNC тактов.
HANDLE_SLOW  := 50
HANDLE_FAST  := 16
HANDLE_SYNC  := 4
OnMessage(0x0201, HandleClick)      ; WM_LBUTTONDOWN

; Единственный собственный пункт в меню трея. Хоткея у настроек нет
; намеренно: клавиши заданы номером слота и не используются для настроек.
A_TrayMenu.Insert("1&", "Settings", (*) => SettingsShow())

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

; Ошибка на одном окне не должна ронять программу целиком.
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
    if IsServiceWindow(hwnd)     ; окно настроек ящик за смену окна не считает (Р18)
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
    if IsServiceWindow(hwnd)     ; собственное окно настроек — не окно слота (Р18)
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
    if IsServiceWindow(hwnd)     ; фокус пользователя настройкам не отдаём
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
        ; Уход в настройки — не потеря фокуса: иначе окно уезжало бы за
        ; край ровно в тот момент, когда пользователь открыл его настройки.
        ; Механика та же, что ниже для всплывающих меню.
        if IsServiceWindow(fore)
            return true
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
            if IsServiceWindow(hwnd)     ; exe=Drawer.exe не должен ловить настройки
                continue
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
; анимация и возврат фокуса работают через общий путь и о кромке ничего
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
; кромка начнёт расти.
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

; ============================= НАСТРОЙКИ =============================
; Окно настроек — оболочка над config.ini. Оно пишет файл только по
; «Применить» или «ОК»; закрытие окна и выход из программы не сохраняют
; изменения.
;
; Значения берутся из тех же глобалов, которыми ящик пользуется прямо
; сейчас (animMs, apps, dynamic…), а настройки слота — из того же
; SlotCfg(), который спрашивает хоткей. Поэтому окно не может показывать
; одно, пока программа делает другое.
;
; Отдельный вопрос — «откуда взялось значение». В загруженных структурах
; отсутствующий ключ и ключ со значением, равным умолчанию, неразличимы:
; IniRead подставляет умолчание молча. Поэтому наличие ключа спрашивается
; у файла ещё раз — тем же IniRead, но без значения по умолчанию: он
; бросает исключение, если ключа нет. Второго разбора конфига при этом не
; появляется. Разобранные значения по-прежнему приходят только из
; LoadConfig; у файла спрашивается ровно «есть такой ключ или нет».
;
; Связь с остальным ящиком — пять вызовов IsServiceWindow(): в
; PickActive, TrackedFore, FocusCandidate, StillFocused и FindWindow.
; Больше про настройки код ящика ничего не знает.

; Своё окно настроек. Кромки обходятся без такой проверки: у них пустой
; заголовок и ToolWindow, и отборы ящика отсеивают их сами. Настройкам
; так нельзя — это обычное окно с заголовком и фокусом, иначе им нельзя
; пользоваться. Значит исключение приходится назвать явно.
IsServiceWindow(hwnd) {
    global setGui, setPickerGui
    if !hwnd
        return false
    ; Диалог выбора окна — тоже своё окно ящика: иначе фокус на нём
    ; мог бы попасть в PickActive() и привязаться Ctrl+Alt+Shift+N.
    if (setPickerGui && hwnd = setPickerGui.Hwnd)
        return true
    if !setGui
        return false
    try {
        if (hwnd = setGui.Hwnd)
            return true
        ; Собственный диалог настроек — вопрос про несохранённые правки.
        ; Для ящика это продолжение того же служебного окна: пока висит
        ; вопрос, пользователь никуда не уходил, и выдвинутый слот уезжать
        ; не должен. Без этого WatchBlur, который тикает и во время
        ; MsgBox, видит обычное окно переднего плана и убирает слот.
        ; Свой диалог отличается от чужого процессом: окно настроек по
        ; определению наше, значит и сравнивать не с чем иным.
        return WinGetClass("ahk_id " hwnd) = "#32770"
            && WinGetPID("ahk_id " hwnd) = WinGetPID("ahk_id " setGui.Hwnd)
    }
    return false
}

; Ошибка в настройках не должна ронять ящик — та же защита, что у
; хоткеев.
SettingsShow() {
    try
        SettingsOpen()
    catch as e
        Notify("Настройки не открылись: " e.Message, "Ящик", 3)
}

; Поля слота — в том же порядке, в каком они описаны в config.ini.
SettingsFields() {
    return ["name", "exe", "cls", "monitor", "edge", "width",
            "activateOnShow", "hideOnBlur", "focusHotkey"]
}

SettingsIsBool(key) {
    return (key = "activateOnShow" || key = "hideOnBlur")
}

; Есть ли ключ в файле. IniRead без значения по умолчанию бросает
; исключение — это и есть ответ.
IniHas(path, section, key) {
    try {
        IniRead(path, section, key)
        return true
    }
    return false
}

; Первая секция из списка, где ключ действительно есть; "" — ключа нет
; нигде и значение пришло из умолчаний LoadConfig.
SettingsFrom(sections, key) {
    global configPath
    for s in sections {
        if IniHas(configPath, s, key)
            return s
    }
    return ""
}

; Что написать в графе «источник». Третий случай — «≠ файл»: ключ в
; файле есть, но значение там уже другое, потому что config.ini правили
; после запуска. Ящик работает по старому, и молчать об этом нельзя,
; иначе окно припишет файлу то, чего в нём сейчас нет.
SettingsSrc(sections, key, live, isBool) {
    global configPath
    if !(s := SettingsFrom(sections, key))
        return "по умолчанию"
    want := isBool ? (live ? "true" : "false") : String(live)
    return (IniRead(configPath, s, key, "") = want) ? "[" s "]" : "[" s "] ≠ файл"
}

; Значение поля для показа. Поля может не быть вовсе: у динамического
; слота нет ни exe, ни cls, ни focusHotkey. Подставить туда пустую
; строку значило бы выдумать отсутствующую настройку.
SettingsVal(cfg, key) {
    if !cfg.HasOwnProp(key)
        return "—"
    v := cfg.%key%
    if SettingsIsBool(key)
        return v ? "true" : "false"
    return (v = "") ? "(пусто)" : String(v)
}

; Строки списка: сначала общие настройки динамических слотов, затем
; девять номеров. cfg — тот самый объект, который ящик спросит при
; нажатии хоткея, поэтому показанное и работающее разойтись не могут.
SettingsRows() {
    global apps, permSlots, dynamicSlots, dynamic
    rows := [{ n: 0, kind: "def", cfg: dynamic, sections: ["dynamic"] }]
    Loop 9 {
        n := A_Index
        if permSlots.Has(n) {
            rows.Push({ n: n, kind: "perm", cfg: apps[permSlots[n]],
                        sections: ["slot" n] })
            continue
        }
        rows.Push({ n: n, kind: "dyn", cfg: SlotCfg(n),
                    sections: dynamicSlots.Has(n)
                              ? ["dynamicSlot" n, "dynamic"] : ["dynamic"] })
    }
    return rows
}

SettingsKind(r) {
    if (r.kind = "def")
        return "[dynamic]"
    return (r.kind = "perm") ? "постоянный" : "динамический"
}

; Тот же поиск, что у AppWindow(), но без записи в managed: открытие
; настроек не должно менять, какое окно приложения слот схватит по
; следующему хоткею — иначе беглый взгляд на статус подменял бы выбор,
; который иначе сделал бы FindWindow() в момент реального нажатия.
SettingsAppPeek(i, a) {
    global managed
    return (managed.Has(i) && WinExist("ahk_id " managed[i])) ? managed[i] : FindWindow(a)
}

; ------------------------------ ВЫБОР ------------------------------
; Окна-кандидаты для постоянного слота: тот же отбор, что уже применяют
; PickActive()/FindWindow() к одному окну, — здесь по всем сразу. Второго
; критерия «годится/не годится» не заводится.
SettingsWindowCandidates() {
    out := []
    for hwnd in WinGetList() {
        try {
            if IsServiceWindow(hwnd)
                continue
            if !(WinGetStyle("ahk_id " hwnd) & 0x10000000)      ; WS_VISIBLE
                continue
            if (WinGetExStyle("ahk_id " hwnd) & 0x00000080)     ; WS_EX_TOOLWINDOW
                continue
            title := WinGetTitle("ahk_id " hwnd)
            if (title = "")
                continue
            cls := WinGetClass("ahk_id " hwnd)
            if (cls = "Progman" || cls = "WorkerW"
                || cls = "Shell_TrayWnd" || cls = "Shell_SecondaryTrayWnd"
                || cls = "XamlExplorerHostIslandWindow" || cls = "MultitaskingViewFrame")
                continue
            WinGetPos(, , &w, &h, "ahk_id " hwnd)
            if (WinGetMinMax("ahk_id " hwnd) = 0 && (w < 200 || h < 200))
                continue
            out.Push({ hwnd: hwnd, title: title, exe: WinGetProcessName("ahk_id " hwnd), cls: cls })
        }
    }
    return out
}

; Диалог выбора окна для постоянного слота. Только подставляет exe/cls в
; текстовые поля — привязка постоянного слота остаётся по процессу,
; диалог не запоминает hwnd и не заводит нового способа биндинга.
; Возвращает {exe,cls,title} или 0 при отмене.
;
; Модальность условная: хоткеи ящика — глобальный хук, кликом их не
; запереть, поэтому пока диалог открыт, он зарегистрирован как служебное
; окно через setPickerGui — иначе Ctrl+Alt+Shift+N мог бы привязать сам
; диалог вместо того окна, которое пользователь пришёл выбирать.
SettingsPickWindow() {
    global setPickerGui, setGui
    cands := SettingsWindowCandidates()
    result := { picked: 0 }

    g := Gui("+Owner" setGui.Hwnd " -MinimizeBox", "Ящик — выбор окна")
    g.SetFont("s9", "Segoe UI")
    g.Add("Text", "x12 y10 w460 h20",
          cands.Length ? "Окно, которое сейчас открыто:" : "Подходящих окон не найдено.")
    lv := g.Add("ListView", "x12 y32 w460 h280 -Multi +Report", ["Заголовок", "Процесс"])
    for c in cands
        lv.Add("", c.title, c.exe)
    lv.ModifyCol(1, 320), lv.ModifyCol(2, 130)
    if cands.Length
        lv.Modify(1, "Select Focus")

    ok     := g.Add("Button", "x300 y320 w82 h28 Default", "Выбрать")
    cancel := g.Add("Button", "x392 y320 w80 h28", "Отмена")
    ok.Enabled := cands.Length > 0

    finish(use) {
        global setPickerGui
        if use {
            row := lv.GetNext(0)
            if (row && row <= cands.Length)
                result.picked := cands[row]
        }
        setPickerGui := 0
        g.Destroy()
    }
    ok.OnEvent("Click", (*) => finish(true))
    cancel.OnEvent("Click", (*) => finish(false))
    lv.OnEvent("DoubleClick", (*) => finish(true))
    g.OnEvent("Close", (*) => finish(false))
    g.OnEvent("Escape", (*) => finish(false))

    setPickerGui := g
    g.Show("w484 h360")
    WinWaitClose("ahk_id " g.Hwnd)
    return result.picked
}

; Диалог выбора .exe. Возвращает голое имя файла с расширением — ровно
; то, что ожидает exe= и с чем WinGetProcessName/ahk_exe сравнивают
; строкой; полный путь для этого поля не годится.
SettingsPickExe() {
    path := FileSelect("1", A_ProgramFiles, "Ящик — выбор приложения", "Исполняемые файлы (*.exe)")
    if (path = "")
        return ""
    SplitPath(path, &fileName)
    return fileName
}

; Статус слота — те же признаки, на которых стоит остальная программа
; (HandleManaged/HandleParked), просто текстом. Второго источника
; истины не заводится: постоянный слот ищется как для хоткея, но
; результат никуда не пишется; динамический берётся из dynSlots как есть.
SettingsSlotStatus(r) {
    global permSlots, dynSlots, apps
    if (r.kind = "def")
        return ""
    if (r.kind = "perm") {
        i := permSlots[r.n]
        if !(hwnd := SettingsAppPeek(i, apps[i]))
            return "приложение не запущено"
    } else {
        if !(dynSlots.Has(r.n) && WinExist("ahk_id " dynSlots[r.n]))
            return "пусто"
        hwnd := dynSlots[r.n]
    }
    if !HandleManaged(hwnd)
        return "окно: " WinGetTitle("ahk_id " hwnd)
    return HandleParked(hwnd) ? "припаркован" : "выдвинут"
}

; ----------------------------- ПРАВКИ ------------------------------
; Буфер несохранённых правок вкладки Slots — setUI.edits, Map номер слота
; -> { kind: "perm", ...девять полей... } либо { kind: "dyn" } (слот
; готовится лишиться [slotN]). Ничего из этого не пишется в файл до
; «Применить»/«ОК» — тот же принцип, что уже держит форму General.
;
; Состояние эта правка не трогает: SettingsSlotStatus() по-прежнему
; спрашивает permSlots/dynSlots/managed напрямую, а не буфер, — колонка
; «Состояние» показывает, что происходит на самом деле, а не то, что
; вот-вот будет записано.

; Строка с учётом несохранённых правок: то, что показывает панель «Слот»
; и колонки Тип/Имя/Край/Монитор/Ширина. Без правки — сама r без изменений.
; Берёт ui параметром, а не глобальным setUI: во время самого открытия
; окна (SettingsOpen -> SettingsFillRow(ui,1)) setUI ещё не присвоен.
SettingsEffective(ui, r) {
    global dynamicSlots
    if !r.n || !ui.edits.Has(r.n)
        return r
    e := ui.edits[r.n]
    if (e.kind = "dyn")
        return { n: r.n, kind: "dyn", cfg: SlotCfg(r.n),
                 sections: dynamicSlots.Has(r.n) ? ["dynamicSlot" r.n, "dynamic"] : ["dynamic"],
                 pending: true }
    return { n: r.n, kind: "perm", cfg: e, sections: ["slot" r.n], pending: true }
}

; Первая правка поля слота n заводит буфер, заполненный ТЕКУЩИМ
; состоянием слота — дальше в нём меняется только то поле, которое
; действительно тронули, а не всё сразу.
SettingsEditSeed(n) {
    global permSlots, apps
    if permSlots.Has(n) {
        a := apps[permSlots[n]]
        return { kind: "perm", name: a.name, exe: a.exe, cls: a.cls,
                 monitor: a.monitor, edge: a.edge, width: a.width,
                 activateOnShow: a.activateOnShow, hideOnBlur: a.hideOnBlur,
                 focusHotkey: a.focusHotkey }
    }
    d := SlotCfg(n)
    return { kind: "perm", name: "Слот " n, exe: "", cls: "",
             monitor: d.monitor, edge: d.edge, width: d.width,
             activateOnShow: d.activateOnShow, hideOnBlur: d.hideOnBlur,
             focusHotkey: "" }
}

; Обработчик правки одного поля панели «Слот». populating гасит вызов,
; пока панель сама заполняет контролы при переключении строки списка —
; иначе один клик по строке выглядел бы как правка всех девяти полей.
SettingsSlotEdited(ui, key, val) {
    if ui.populating
        return
    n := ui.editingSlot
    if !n
        return
    if !ui.edits.Has(n)
        ui.edits[n] := SettingsEditSeed(n)
    ui.edits[n].%key% := val
}

; Пересчитать колонку «Состояние» во всех строках. Слот 0 ([dynamic]) в
; список не входит — это не слот, а общие настройки. Ошибка на одном окне
; пропускает только его и не трогает таймер.
SettingsSlotsTick() {
    global setUI
    if !(ui := setUI)
        return
    for idx, r in ui.slotsRows {
        if (r.kind = "def")
            continue
        try
            ui.slotsLv.Modify(idx, "Col7", SettingsSlotStatus(r))
    }
}

; Таймер живёт, только пока видна вкладка Slots — тот же приём, что у
; таймера кромок: в покое ничего не опрашивается. tabValue приходит прямо
; из события Tab3, отдельно проверять setGui не нужно: раз событие
; пришло, окно ещё живо.
SettingsSlotsTimer(active) {
    SetTimer(SettingsSlotsTick, active = 2 ? 400 : 0)
}

; Техническая подпись справа от поля: имя ключа в config.ini и, если
; ключа в файле нет, пометка об этом. Имя ключа вторично по размеру и
; цвету — человек читает подпись слева, а имя нужно тому, кто полезет в
; файл руками. Отсутствие ключа показываем честно: значение взято из
; умолчаний программы, и пока его не изменили, писать его в файл не
; будем.
SettingsHint(g, x, y, section, key) {
    global configPath
    txt := key . (IniHas(configPath, section, key) ? "" : "  ·  по умолчанию")
    g.SetFont("s8 c808080")
    g.Add("Text", "x" x " y" (y + 2) " w172 h18", txt)
    g.SetFont("s9 cDefault")
}

; Сторона выезда. Список закрыт четырьмя значениями, но значение из
; файла может быть и посторонним — тогда добавляем его пятым пунктом и
; не трогаем: молча подменять чужую настройку нельзя.
SettingsEdgeItems() {
    return ["Слева", "Справа", "Сверху", "Снизу"]
}
SettingsEdgeKeys() {
    return ["left", "right", "top", "bottom"]
}
SettingsEdgePick(ddl, cur) {
    for i, k in SettingsEdgeKeys() {
        if (cur = k) {
            ddl.Choose(i)
            return ""            ; значение штатное, запоминать нечего
        }
    }
    ddl.Add(["в файле: " cur])
    ddl.Choose(5)
    return cur                   ; вернём как есть, если пользователь не менял
}

; Монитор: «за курсором» плюс номера подключённых. Номер из файла,
; которого сейчас нет (монитор отключили), тоже показываем отдельным
; пунктом — программа в этом случае работает на мониторе под курсором,
; но настройку менять за пользователя не должна.
SettingsMonItems() {
    out := ["Следовать за курсором"]
    Loop MonitorGetCount()
        out.Push("Монитор " A_Index)
    return out
}
SettingsMonPick(ddl, cur) {
    if (cur = "cursor") {
        ddl.Choose(1)
        return ""
    }
    if (IsInteger(cur) && cur >= 1 && cur <= MonitorGetCount()) {
        ddl.Choose(cur + 1)
        return ""
    }
    ddl.Add(["в файле: " cur])
    ddl.Choose(MonitorGetCount() + 2)
    return cur
}

; Анимация задана двумя числами, но выбирать их по отдельности человеку
; незачем: значимы не миллисекунды, а плавность. Пресеты — только способ
; показа тех же двух ключей, новых настроек не появляется. Пара, не
; совпавшая ни с одним пресетом, показывается как «Своя» вместе с
; настоящими числами: молча округлять чужие значения нельзя.
SettingsAnimPresets() {
    return [{ name: "Быстрая",  ms: 100, steps: 10 },
            { name: "Обычная",  ms: 160, steps: 14 },
            { name: "Плавная",  ms: 260, steps: 20 }]
}
SettingsAnimItems() {
    out := ["Без анимации"]
    for p in SettingsAnimPresets()
        out.Push(p.name)
    out.Push("Своя")
    return out
}
SettingsAnimPick(ui, ms, steps) {
    if (steps = 0) {
        ui.anim.Choose(1)
        SettingsAnimToggle(ui)
        return
    }
    for i, p in SettingsAnimPresets() {
        if (ms = p.ms && steps = p.steps) {
            ui.anim.Choose(i + 1)
            SettingsAnimToggle(ui)
            return
        }
    }
    ui.anim.Choose(SettingsAnimPresets().Length + 2)
    SettingsAnimToggle(ui)
}
; Числа редактируются только в режиме «Своя»; в остальных они показывают,
; во что превратится выбор.
SettingsAnimToggle(ui := 0) {
    global setUI
    if !(ui := ui ? ui : setUI)
        return
    own := (ui.anim.Value = SettingsAnimPresets().Length + 2)
    ui.animMs.Enabled := own
    ui.animSteps.Enabled := own
    if own
        return
    if (ui.anim.Value = 1) {
        ui.animSteps.Value := "0"
        return
    }
    p := SettingsAnimPresets()[ui.anim.Value - 1]
    ui.animMs.Value := String(p.ms)
    ui.animSteps.Value := String(p.steps)
}

; Панель под списком: все поля выбранного слота и источник каждого.
SettingsFill(box, valc, srcc, r) {
    box.Text := (r.kind = "def")
              ? "Общие настройки динамических слотов — [dynamic]"
              : (r.kind = "perm")
              ? "Слот " r.n " — постоянный, [slot" r.n "]"
              : "Слот " r.n " — динамический"
    for i, key in SettingsFields() {
        valc[i].Text := SettingsVal(r.cfg, key)
        srcc[i].Text := r.cfg.HasOwnProp(key)
                      ? SettingsSrc(r.sections, key, r.cfg.%key%,
                                    SettingsIsBool(key))
                      : "нет у слота"
    }
}

; Те же девять полей, но в редактируемых контролах панели «Слот» —
; только для постоянного (или готовящегося им стать) слота. populating
; гасит Change на время программного заполнения, чтобы переключение
; строки списка не выглядело как правка каждого поля.
SettingsFillEditable(ui, ef) {
    cfg := ef.cfg
    ui.populating := true
    ui.eName.Value := Opt(cfg, "name", "")
    ui.eExe.Value  := Opt(cfg, "exe", "")
    ui.eCls.Value  := Opt(cfg, "cls", "")
    SettingsEdgePick(ui.eEdge, Opt(cfg, "edge", "right"))
    SettingsMonPick(ui.eMon, Opt(cfg, "monitor", "cursor"))
    ui.eWidth.Value := String(Opt(cfg, "width", 60))
    ui.eAct.Value   := Opt(cfg, "activateOnShow", true) ? 1 : 0
    ui.eBlur.Value  := Opt(cfg, "hideOnBlur", true) ? 1 : 0
    ui.eFocus.Value := Opt(cfg, "focusHotkey", "")
    ui.editingSlot  := ef.n
    ui.box.Text := "Слот " ef.n " — постоянный, [slot" ef.n "]"
                 . (ef.HasOwnProp("pending") ? "  ·  не сохранено" : "")
    ui.populating := false
}

; Показывает панель «Слот» для строки idx: постоянному (или готовящемуся
; им стать) слоту — редактируемые поля, иначе — прежний вид только для
; чтения, без единой правки исходного пути SettingsFill().
SettingsFillRow(ui, idx) {
    r  := ui.slotsRows[idx]
    ef := SettingsEffective(ui, r)
    editable := r.n && (ef.kind = "perm")

    for c in ui.roCtl
        c.Visible := !editable
    for c in ui.editCtl
        c.Visible := editable

    if editable
        SettingsFillEditable(ui, ef)
    else
        SettingsFill(ui.box, ui.valc, ui.srcc, r)

    if r.n {
        ui.convert.Visible := true
        ui.convert.Text := editable ? "Сделать динамическим…" : "Сделать постоянным…"
    } else
        ui.convert.Visible := false
}

; Кнопка смены типа слота. Само переключение только готовит буфер правок
; (ui.edits) — на диск ничего не уходит до «Применить»/«ОК», как и у
; остальной формы. При уходе в динамический показывается предупреждение:
; секция удаляется явной командой и с предупреждением про комментарии.
SettingsConvertClick(ui) {
    idx := ui.slotsLv.GetNext(0)
    if !idx
        return
    r := ui.slotsRows[idx]
    if !r.n
        return
    ef := SettingsEffective(ui, r)
    if (ef.kind = "perm") {
        if (MsgBox("Слот " r.n " станет динамическим: секция [slot" r.n "] будет"
                  . " удалена вместе с комментариями внутри неё, если они там были."
                  . " Действие войдёт в силу после «Применить» или «ОК». Продолжить?",
                  "Ящик", 0x24) != "Yes")
            return
        ui.edits[r.n] := { kind: "dyn" }
    } else
        ui.edits[r.n] := SettingsEditSeed(r.n)
    SettingsFillRow(ui, idx)
    SettingsSlotsColumns(ui, idx)
}

; Обзор .exe и выбор существующего окна — оба лишь подставляют значения
; в поля exe/cls (и, если имя ещё не тронуто, в name); привязка
; постоянного слота остаётся по процессу, никакого hwnd не хранится.
SettingsSlotExePick(ui) {
    if ui.populating || !ui.editingSlot
        return
    exe := SettingsPickExe()
    if (exe = "")
        return
    ui.populating := true
    ui.eExe.Value := exe
    ui.populating := false
    SettingsSlotEdited(ui, "exe", exe)
}
SettingsSlotWindowPick(ui) {
    if ui.populating || !ui.editingSlot
        return
    w := SettingsPickWindow()
    if !w
        return
    n := ui.editingSlot
    auto := (Trim(ui.eName.Value) = "" || Trim(ui.eName.Value) = "Слот " n)
    ui.populating := true
    ui.eExe.Value := w.exe
    ui.eCls.Value := w.cls
    if auto
        ui.eName.Value := w.title
    ui.populating := false
    SettingsSlotEdited(ui, "exe", w.exe)
    SettingsSlotEdited(ui, "cls", w.cls)
    if auto
        SettingsSlotEdited(ui, "name", w.title)
}

; Колонки Тип/Имя/Край/Монитор/Ширина одной строки списка — по
; эффективному состоянию (с учётом буфера правок). Состояние (Col7) сюда
; не входит: его считает SettingsSlotStatus() по настоящей строке, и
; периодическое обновление использует её же.
SettingsSlotsColumns(ui, idx) {
    r  := ui.slotsRows[idx]
    ef := SettingsEffective(ui, r)
    lv := ui.slotsLv
    lv.Modify(idx, "Col2", SettingsKind(ef))
    lv.Modify(idx, "Col3", SettingsVal(ef.cfg, "name"))
    lv.Modify(idx, "Col4", SettingsVal(ef.cfg, "edge"))
    lv.Modify(idx, "Col5", SettingsVal(ef.cfg, "monitor"))
    lv.Modify(idx, "Col6", SettingsVal(ef.cfg, "width"))
}

; После сохранения список мог не совпасть с диском построчно сразу в
; нескольких местах (типы и поля нескольких слотов) — перечитывается
; целиком, как при открытии окна, а не точечными правками по одной строке.
SettingsSlotsRefreshAll(ui) {
    rows := SettingsRows()
    ui.slotsRows := rows
    loop rows.Length
        SettingsSlotsColumns(ui, A_Index)
    for idx, r in rows
        ui.slotsLv.Modify(idx, "Col7", SettingsSlotStatus(r))
    sel := ui.slotsLv.GetNext(0)
    if sel
        SettingsFillRow(ui, sel)
}

SettingsOpen() {
    global setGui, setUI, VERSION, configPath
    global animMs, animSteps, blurMs, handlesOn, dynamic

    ; Окно одно. Повторный вызов из трея поднимает уже открытое, а не
    ; заводит второе: два окна показывали бы один и тот же файл и
    ; разошлись бы при первой же правке.
    if setGui {
        try {
            if WinExist("ahk_id " setGui.Hwnd) {
                WinActivate("ahk_id " setGui.Hwnd)
                return
            }
        }
        setGui := 0
    }

    g := Gui("-MaximizeBox", "Drawer — Settings")
    g.SetFont("s9", "Segoe UI")
    tab := g.Add("Tab3", "x8 y8 w544 h430", ["General", "Slots", "About"])

    tab.UseTab(1)
    ui := {}

    ; ---- умолчания динамических слотов: секция [dynamic] ----
    ; Заголовок и подсказка говорят ровно то, что происходит в файле:
    ; постоянные слоты сюда не заглядывают, у них свои значения в
    ; [slotN], и менять их отсюда нельзя. Иначе первая же правка выглядит
    ; как «настройка не работает».
    g.Add("GroupBox", "x20 y44 w520 h190", "Поведение по умолчанию")
    g.SetFont("c606060")
    g.Add("Text", "x36 y66 w488 h30",
          "Действует на динамические слоты — те, что назначаются "
        . "Ctrl+Alt+Shift+N. У постоянных слотов ([slotN] в config.ini) "
        . "свои значения, и эти настройки их не меняют.")
    g.SetFont("cDefault")

    g.Add("Text", "x36 y99 w140 h20", "Размер окна")
    ui.width := g.Add("Edit", "x180 y96 w54 h22 Number Limit3",
                      String(Opt(dynamic, "width", 60)))
    g.Add("Text", "x240 y99 w120 h20", "% экрана")
    SettingsHint(g, 364, 99, "dynamic", "width")

    g.Add("Text", "x36 y127 w140 h20", "Сторона выезда")
    ui.edge := g.Add("DropDownList", "x180 y124 w150", SettingsEdgeItems())
    SettingsEdgePick(ui.edge, Opt(dynamic, "edge", "right"))
    SettingsHint(g, 364, 127, "dynamic", "edge")

    g.Add("Text", "x36 y155 w140 h20", "Монитор")
    ui.mon := g.Add("DropDownList", "x180 y152 w150", SettingsMonItems())
    SettingsMonPick(ui.mon, Opt(dynamic, "monitor", "cursor"))
    SettingsHint(g, 364, 155, "dynamic", "monitor")

    ui.act := g.Add("CheckBox", "x180 y182 w344 h20", "Активировать окно при открытии")
    ui.act.Value := Opt(dynamic, "activateOnShow", true) ? 1 : 0
    ui.blur := g.Add("CheckBox", "x180 y206 w344 h20",
                     "Убирать окно, когда фокус ушёл в другое")
    ui.blur.Value := Opt(dynamic, "hideOnBlur", true) ? 1 : 0

    ; ---- внешний вид: [general] handles ----
    g.Add("GroupBox", "x20 y244 w520 h52", "Внешний вид")
    ui.handles := g.Add("CheckBox", "x36 y266 w300 h20",
                        "Кромки у края экрана")
    ui.handles.Value := handlesOn ? 1 : 0
    SettingsHint(g, 364, 266, "general", "handles")

    ; ---- анимация: два ключа, но выбирается одним списком ----
    g.Add("GroupBox", "x20 y306 w520 h64", "Анимация")
    g.Add("Text", "x36 y331 w140 h20", "Плавность")
    ui.anim := g.Add("DropDownList", "x180 y328 w150", SettingsAnimItems())
    ui.animMs := g.Add("Edit", "x340 y328 w52 h22 Number Limit4", String(animMs))
    g.Add("Text", "x396 y331 w24 h20", "мс")
    ui.animSteps := g.Add("Edit", "x424 y328 w52 h22 Number Limit3", String(animSteps))
    g.Add("Text", "x480 y331 w56 h20", "шагов")
    SettingsAnimPick(ui, animMs, animSteps)
    ui.anim.OnEvent("Change", (*) => SettingsAnimToggle())

    ; ---- дополнительно: blurMs ----
    g.Add("GroupBox", "x20 y380 w520 h50", "Дополнительно")
    g.Add("Text", "x36 y403 w200 h20", "Проверка потери фокуса")
    ui.blurMs := g.Add("Edit", "x240 y400 w54 h22 Number Limit5", String(blurMs))
    g.SetFont("c606060")
    g.Add("Text", "x300 y403 w236 h20", "мс — как часто спрашивать")
    g.SetFont("cDefault")

    tab.UseTab(2)
    ; Под списком остаётся место для смены типа и полей выбранного слота.
    lv := g.Add("ListView", "x20 y44 w520 h134 -Multi +Report",
                ["Слот", "Тип", "Имя", "Край", "Монитор", "Ширина", "Состояние"])
    rows := SettingsRows()
    for r in rows {
        lv.Add("", r.n ? r.n : "—", SettingsKind(r),
               SettingsVal(r.cfg, "name"),    SettingsVal(r.cfg, "edge"),
               SettingsVal(r.cfg, "monitor"), SettingsVal(r.cfg, "width"),
               SettingsSlotStatus(r))
    }
    lv.ModifyCol(1, 44), lv.ModifyCol(2, 90), lv.ModifyCol(3, 100)
    lv.ModifyCol(4, 56), lv.ModifyCol(5, 64), lv.ModifyCol(6, 56)
    lv.ModifyCol(7, 110)
    ; Живая колонка: опрашивается, только пока видна эта вкладка — тот же
    ; расчёт, что у кромок. Tab3 сам присылает свой Value в событии.
    ui.slotsLv := lv, ui.slotsRows := rows
    ui.edits := Map(), ui.populating := false, ui.editingSlot := 0
    tab.OnEvent("Change", (ctrl, *) => SettingsSlotsTimer(ctrl.Value))

    ui.convert := g.Add("Button", "x20 y184 w220 h24", "Сделать постоянным…")
    ui.convert.OnEvent("Click", (*) => SettingsConvertClick(ui))

    box  := g.Add("GroupBox", "x20 y212 w520 h208", "Слот")
    valc := [], srcc := []
    for i, key in SettingsFields() {
        y := 234 + (i - 1) * 20
        g.Add("Text", "x36 y" y " w118 h18", key)
        valc.Push(g.Add("Text", "x158 y" y " w160 h18", ""))
        g.SetFont("c606060")
        srcc.Push(g.Add("Text", "x324 y" y " w206 h18", ""))
        g.SetFont("cDefault")
    }
    ui.box := box, ui.valc := valc, ui.srcc := srcc
    ui.roCtl := []
    for c in valc
        ui.roCtl.Push(c)
    for c in srcc
        ui.roCtl.Push(c)

    ; Те же девять полей, редактируемые — на месте valc/srcc, видны только
    ; когда выбранный слот постоянный (или готовится им стать). yExe и
    ; yFocus — те же y, что и у полей exe/focusHotkey в цикле выше (i=2 и
    ; i=9), чтобы кнопки и подсказка встали в свои строки.
    yExe := 234 + (2 - 1) * 20, yFocus := 234 + (9 - 1) * 20
    ui.eName  := g.Add("Edit", "x158 y234 w220 h22")
    ui.eExe   := g.Add("Edit", "x158 y" yExe " w170 h22")
    ui.eExeBrowse := g.Add("Button", "x334 y" (yExe - 2) " w60 h24", "Обзор…")
    ui.eExeWindow := g.Add("Button", "x398 y" (yExe - 2) " w66 h24", "Окно…")
    ui.eCls   := g.Add("Edit", "x158 y274 w220 h22")
    ui.eMon   := g.Add("DropDownList", "x158 y292 w150", SettingsMonItems())
    ui.eEdge  := g.Add("DropDownList", "x158 y312 w150", SettingsEdgeItems())
    ui.eWidth := g.Add("Edit", "x158 y334 w60 h22 Number Limit3")
    ui.eAct   := g.Add("CheckBox", "x158 y354 w340 h20", "Активировать окно при выезде")
    ui.eBlur  := g.Add("CheckBox", "x158 y374 w340 h20", "Убирать окно, когда фокус ушёл")
    ui.eFocus := g.Add("Edit", "x158 y" yFocus " w220 h22")
    g.SetFont("c808080")
    g.Add("Text", "x384 y" (yFocus + 2) " w146 h18", "после перезапуска")
    g.SetFont("cDefault")

    ui.editCtl := [ui.eName, ui.eExe, ui.eExeBrowse, ui.eExeWindow, ui.eCls,
                   ui.eMon, ui.eEdge, ui.eWidth, ui.eAct, ui.eBlur, ui.eFocus]

    ui.eName.OnEvent("Change",  (*) => SettingsSlotEdited(ui, "name", ui.eName.Value))
    ui.eExe.OnEvent("Change",   (*) => SettingsSlotEdited(ui, "exe", ui.eExe.Value))
    ui.eCls.OnEvent("Change",   (*) => SettingsSlotEdited(ui, "cls", ui.eCls.Value))
    ui.eMon.OnEvent("Change",   (*) => SettingsSlotEdited(ui, "monitor", SettingsMonVal(ui.eMon)))
    ui.eEdge.OnEvent("Change",  (*) => SettingsSlotEdited(ui, "edge", SettingsEdgeVal(ui.eEdge)))
    ui.eWidth.OnEvent("Change", (*) => SettingsSlotEdited(ui, "width", ui.eWidth.Value))
    ui.eAct.OnEvent("Click",    (*) => SettingsSlotEdited(ui, "activateOnShow", ui.eAct.Value))
    ui.eBlur.OnEvent("Click",   (*) => SettingsSlotEdited(ui, "hideOnBlur", ui.eBlur.Value))
    ui.eFocus.OnEvent("Change", (*) => SettingsSlotEdited(ui, "focusHotkey", ui.eFocus.Value))
    ui.eExeBrowse.OnEvent("Click", (*) => SettingsSlotExePick(ui))
    ui.eExeWindow.OnEvent("Click", (*) => SettingsSlotWindowPick(ui))

    lv.OnEvent("ItemSelect",
               (LV, item, sel) => (sel && item) ? SettingsFillRow(ui, item) : "")
    lv.Modify(1, "Select Focus")
    SettingsFillRow(ui, 1)

    tab.UseTab(3)
    g.SetFont("s12 bold")
    g.Add("Text", "x20 y48 w520 h26", "Drawer")
    g.SetFont("s9 norm")
    g.Add("Text", "x20 y80 w520 h20", "версия " VERSION)
    g.Add("Text", "x20 y118 w520 h20", "config.ini")
    g.Add("Edit", "x20 y140 w504 h22 ReadOnly -TabStop", configPath)
    g.SetFont("c606060")
    g.Add("Text", "x20 y180 w504 h226",
          "Программа трогает этот файл только тогда, когда вы нажали "
        . "«Применить» или «ОК», и записывает ровно те строки, которые "
        . "вы изменили. Ни закрытие окна, ни выход из программы ничего "
        . "не сохраняют.`n`n"
        . "github.com/nerzar/Drawer  ·  лицензия MIT`n`n"
        . "Хоткеи слотов заданы номером и не настраиваются:`n"
        . "Ctrl+Alt+1…9  —  выдвинуть или убрать окно слота`n"
        . "Ctrl+Alt+Shift+1…9  —  назначить активное окно слоту`n"
        . "Ctrl+Alt+0  —  очистить динамические слоты`n"
        . "Ctrl+Alt+Shift+0  —  выход, окна возвращаются на места")
    g.SetFont("cDefault")

    tab.UseTab(0)
    ; Строка состояния — единственное место, где окно говорит об ошибке
    ; записи. TrayTip для этого не годится: уведомления пересчитывает
    ; набор quiet, и новые ломают его.
    ui.status := g.Add("Text", "x20 y444 w520 h20", "")
    ui.ok     := g.Add("Button", "x236 y474 w92 h28 Default", "ОК")
    ui.cancel := g.Add("Button", "x338 y474 w92 h28", "Отмена")
    ui.apply  := g.Add("Button", "x440 y474 w92 h28", "Применить")
    ui.ok.OnEvent("Click",     (*) => SettingsSave(true))
    ui.apply.OnEvent("Click",  (*) => SettingsSave(false))
    ui.cancel.OnEvent("Click", (*) => SettingsClose())
    g.OnEvent("Close",  (*) => SettingsClose())
    g.OnEvent("Escape", (*) => SettingsClose())

    ; Окно объявляется своим ДО показа: иначе первый же его кадр успел бы
    ; стать передним планом обычного окна и увести за собой hideOnBlur.
    setUI  := ui
    SettingsRebase()
    setGui := g
    g.Show("w560 h514")
}

; Закрытие само по себе ничего не сохраняет — ни крестиком, ни Escape,
; ни кнопкой «Отмена». Несохранённые правки просто теряются, и об этом
; спрашивают заранее: молча выбросить чужую работу хуже, чем переспросить.
; force — закрытие после удачного сохранения, спрашивать уже не о чем.
SettingsClose(force := false) {
    global setGui, setUI
    if (!force && SettingsIsDirty()) {
        if (MsgBox("Изменения не сохранены. Закрыть и отменить их?",
                   "Ящик", 0x24) != "Yes")
            return true    ; событиям Close и Escape ненулевое значение
    }                      ; означает «окно не закрывать»
    g := setGui
    setGui := 0        ; сначала забыть, потом рушить: IsServiceWindow не
    setUI  := 0        ; должен спрашивать у уже разрушенного окна
    SetTimer(SettingsSlotsTick, 0)   ; иначе таймер живой колонки переживёт закрытие
    try g.Destroy()
}

; ----------------------------- ЗАПИСЬ ------------------------------
; Единственный источник истины — config.ini; пишутся отдельные ключи,
; после записи выполняется обязательная сверка чтением.

; Целое число из поля. Первая же ошибка отменяет весь разбор: записывать
; половину настроек и споткнуться на второй половине нельзя.
SettingsNum(raw, lo, hi, label, &err) {
    if (err != "")
        return 0
    v := Trim(raw)
    if (v = "" || !IsInteger(v)) {
        err := label ": нужно целое число"
        return 0
    }
    v := Integer(v)
    if (v < lo || v > hi) {
        err := label ": допустимо от " lo " до " hi
        return 0
    }
    return v
}

; Пустая строка означает «этот ключ писать не надо»: в списке выбран
; посторонний пункт «в файле: …», то есть значение чужое и менять его
; программа не бралась.
; Принимает сам DropDownList, а не всю ui, — им пользуются и General
; (ui.edge/ui.mon), и панель «Слот» (ui.eEdge/ui.eMon).
SettingsEdgeVal(ddl) {
    keys := SettingsEdgeKeys()
    v := ddl.Value
    return (v >= 1 && v <= keys.Length) ? keys[v] : ""
}
SettingsMonVal(ddl) {
    v := ddl.Value
    if (v = 1)
        return "cursor"
    return (v >= 2 && v <= MonitorGetCount() + 1) ? String(v - 1) : ""
}

; Что сейчас в форме, в том виде, в каком оно ляжет в файл.
SettingsCollect(&err) {
    global setUI
    err := ""
    if !(ui := setUI)
        return 0
    out := []

    w := SettingsNum(ui.width.Value, 5, 100, "Размер окна", &err)
    if (e := SettingsEdgeVal(ui.edge))
        out.Push({ sec: "dynamic", key: "edge", val: e })
    if (m := SettingsMonVal(ui.mon))
        out.Push({ sec: "dynamic", key: "monitor", val: m })
    ; «Без анимации» меняет только число шагов: при нуле шагов
    ; длительность ни на что не влияет, и трогать её незачем.
    ms := (ui.anim.Value = 1) ? 0
        : SettingsNum(ui.animMs.Value, 0, 5000, "Длительность анимации", &err)
    steps := SettingsNum(ui.animSteps.Value, 0, 200, "Шагов анимации", &err)
    b := SettingsNum(ui.blurMs.Value, 10, 60000, "Проверка потери фокуса", &err)
    if (err != "")
        return 0

    out.Push({ sec: "dynamic", key: "width",          val: String(w) })
    out.Push({ sec: "dynamic", key: "activateOnShow", val: ui.act.Value ? "true" : "false" })
    out.Push({ sec: "dynamic", key: "hideOnBlur",     val: ui.blur.Value ? "true" : "false" })
    out.Push({ sec: "general", key: "handles",        val: ui.handles.Value ? "true" : "false" })
    if (ui.anim.Value != 1)
        out.Push({ sec: "general", key: "animMs",     val: String(ms) })
    out.Push({ sec: "general", key: "animSteps",      val: String(steps) })
    out.Push({ sec: "general", key: "blurMs",         val: String(b) })
    return out
}

; Чем программа пользуется прямо сейчас. Сравнивать надо именно с этим,
; а не с содержимым файла: тогда ключ, которого в файле нет и который не
; меняли, остаётся ненаписанным сам собой — умолчания живут в
; LoadConfig, и дублировать их здесь не приходится.
SettingsLive(sec, key) {
    global dynamic, animMs, animSteps, blurMs, handlesOn
    if (sec = "dynamic") {
        v := Opt(dynamic, key, "")
        return (key = "activateOnShow" || key = "hideOnBlur")
             ? (v ? "true" : "false") : String(v)
    }
    switch key {
    case "animMs":    return String(animMs)
    case "animSteps": return String(animSteps)
    case "blurMs":    return String(blurMs)
    case "handles":   return handlesOn ? "true" : "false"
    }
    return ""
}

; -------------------------- ЗАПИСЬ [slotN] -------------------------
; То же правило точечной записи, что и SettingsLive(), — только для
; постоянного слота: если слот сейчас не постоянный или у него нет этого
; поля, сравнивать не с чем, и значение считается новым безусловно.
SettingsLiveSlot(n, key) {
    global permSlots, apps
    if !permSlots.Has(n)
        return ""
    cfg := apps[permSlots[n]]
    if !cfg.HasOwnProp(key)
        return ""
    v := cfg.%key%
    return SettingsIsBool(key) ? (v ? "true" : "false") : String(v)
}

; Постоянному слоту нужен exe — без него нечего искать по процессу.
; Остальные поля свободны, как и у [dynamic].
SettingsSlotValidate(n, e, &err) {
    if (err != "")
        return
    if (Trim(e.exe) = "")
        err := "Слот " n ": exe обязателен для постоянного слота"
}

; Буфер правки слота n в дисковый вид, за вычетом ключей, уже совпадающих
; с текущими значениями, — точечная запись остаётся в силе и для
; [slotN], не только для [dynamic]. Первая же ошибка отменяет весь разбор
; этого слота — записывать половину полей нельзя.
SettingsSlotWrites(n, e, &err) {
    SettingsSlotValidate(n, e, &err)
    if (err != "")
        return []
    w := SettingsNum(String(e.width), 5, 100, "Слот " n ": размер окна", &err)
    if (err != "")
        return []
    name := Trim(e.name) = "" ? "Слот " n : e.name
    cand := [{ key: "name", val: name },
             { key: "exe",  val: Trim(e.exe) },
             { key: "cls",  val: e.cls },
             { key: "monitor", val: String(e.monitor) },
             { key: "edge", val: e.edge },
             { key: "width", val: String(w) },
             { key: "activateOnShow", val: e.activateOnShow ? "true" : "false" },
             { key: "hideOnBlur", val: e.hideOnBlur ? "true" : "false" },
             { key: "focusHotkey", val: e.focusHotkey }]
    out := []
    for c in cand {
        if (SettingsLiveSlot(n, c.key) = c.val)
            continue
        out.Push({ sec: "slot" n, key: c.key, val: c.val })
    }
    return out
}

; Весь буфер setUI.edits в дисковый вид. Та же дисциплина, что у
; SettingsCollect(): первая ошибка отменяет всё, наполовину не пишем.
SettingsSlotsCollect(&err) {
    global setUI
    err := ""
    writes := [], deletes := [], touched := Map()
    if !(ui := setUI) || !ui.edits.Count
        return { writes: writes, deletes: deletes, touched: touched }
    for n, e in ui.edits {
        if (e.kind = "dyn") {
            deletes.Push(n)
            touched[n] := true
            continue
        }
        got := SettingsSlotWrites(n, e, &err)
        if (err != "")
            return { writes: [], deletes: [], touched: Map() }
        for w in got
            writes.Push(w)
        touched[n] := true
    }
    return { writes: writes, deletes: deletes, touched: touched }
}

; Применяет накопленные правки Slots. Порядок жёсткий, как у SettingsSave:
; сначала диск, сверка, и только потом работающая программа. Отдельно —
; то, что не покрывает точечная запись сама по себе:
;
;  - слот, теряющий постоянную привязку или меняющий exe/cls, не должен
;    остаться без хозяина: Release() возвращает окно на исходное место,
;    как при выходе и Ctrl+Alt+0 — и то же самое окно никогда не
;    трогается, если его exe/cls не изменились;
;  - динамическая привязка того же номера отменяется явно: постоянный и
;    динамический не бывают одним слотом одновременно нигде в программе;
;  - [dynamicSlotN], оставшийся от прежней динамической настройки,
;    удаляется при переходе в постоянные — иначе LoadConfig будет
;    показывать про него предупреждение при каждом следующем запуске;
;  - permSlots и managed переиндексируются ПО НОМЕРУ СЛОТА, а не по
;    индексу в apps[]: добавление или удаление [slotN] сдвигает индексы
;    соседних постоянных слотов.
SettingsSlotsApply(plan, &err) {
    global configPath, apps, managed, permSlots, dynSlots, dynamicSlots
    global animMs, animSteps, blurMs, handlesOn, dynamic
    err := ""

    for n in plan.touched {
        if dynSlots.Has(n) {
            Release(dynSlots[n])
            dynSlots.Delete(n)
        }
    }

    delSet := Map()
    for n in plan.deletes
        delSet[n] := true

    for n in plan.deletes {
        try
            IniDelete(configPath, "slot" n)
        catch as e {
            err := "Не удалить [slot" n "]: " e.Message
            return
        }
    }
    for n in plan.touched {
        if !delSet.Has(n)
            try
                IniDelete(configPath, "dynamicSlot" n)
    }

    done := 0
    for w in plan.writes {
        try
            IniWrite(w.val, configPath, w.sec, w.key)
        catch as e {
            err := "Не записалось: [" w.sec "] " w.key " — " e.Message
                 . (done ? ".  До сбоя записано строк: " done : "")
            return
        }
        done++
    }
    for w in plan.writes {
        got := IniRead(configPath, w.sec, w.key, "")
        if (got != w.val) {
            err := "Проверка не прошла: [" w.sec "] " w.key
                 . " — в файле «" got "», ожидалось «" w.val "»"
            return
        }
    }

    oldBySlot := Map(), oldIdent := Map()
    for i, a in apps {
        if managed.Has(i)
            oldBySlot[a.slot] := managed[i]
        oldIdent[a.slot] := { exe: a.exe, cls: a.cls }
    }

    LoadConfig(configPath, &apps, &dynamic, &dynamicSlots,
               &animMs, &animSteps, &blurMs, &handlesOn)

    permSlots.Clear()
    for i, a in apps
        permSlots[a.slot] := i

    managed.Clear()
    for i, a in apps {
        if !oldBySlot.Has(a.slot)
            continue
        ident := oldIdent[a.slot]
        if (ident.exe = a.exe && ident.cls = a.cls)
            managed[i] := oldBySlot[a.slot]
        else
            Release(oldBySlot[a.slot])
        oldBySlot.Delete(a.slot)
    }
    for n, hwnd in oldBySlot     ; слот больше не тот же постоянный — окно домой
        Release(hwnd)

    SetTimer(HandlesSync, -1)
}

; Состояние формы одной строкой — этого хватает, чтобы понять, трогал ли
; её пользователь. Значение из файла может быть невалидным (width=999), и
; полноценный разбор для такого вопроса не годится.
SettingsSnapshot() {
    global setUI
    if !(ui := setUI)
        return ""
    s := ui.width.Value "|" ui.edge.Value "|" ui.mon.Value "|"
       . ui.act.Value "|" ui.blur.Value "|" ui.handles.Value "|"
       . ui.anim.Value "|" ui.animMs.Value "|" ui.animSteps.Value "|"
       . ui.blurMs.Value
    ; Буфер правок Slots — та же строка-снимок, только по номерам
    ; слотов: dirty должен видеть и незаписанную правку постоянного слота.
    for n, e in ui.edits {
        s .= "|s" n ":" e.kind
        if (e.kind = "perm")
            s .= "," e.name "," e.exe "," e.cls "," e.monitor "," e.edge ","
               . e.width "," e.activateOnShow "," e.hideOnBlur "," e.focusHotkey
    }
    return s
}
; Имя поля — snap, а не base: base у любого объекта AHK занято под
; прототип, и присваивание туда строки падает на ObjSetBase. Ровно та же
; ловушка, что с log и exp в тестах.
SettingsRebase() {
    global setUI
    if setUI
        setUI.snap := SettingsSnapshot()
}
SettingsIsDirty() {
    global setUI
    return setUI && setUI.HasOwnProp("snap") && setUI.snap != SettingsSnapshot()
}

SettingsStatus(text, bad := false) {
    global setUI
    if !setUI
        return
    setUI.status.Opt(bad ? "cA00000" : "c006000")
    setUI.status.Text := text
    setUI.status.Redraw()
}

; Применить: диск, сверка, и только потом работающая программа. Порядок
; жёсткий — если запись не удалась, ящик остаётся с прежними настройками,
; а окно с несохранёнными правками, чтобы их можно было повторить.
SettingsSave(closeAfter) {
    global setUI, configPath
    global apps, dynamic, dynamicSlots, animMs, animSteps, blurMs, handlesOn
    if !setUI
        return
    err := ""
    if !(vals := SettingsCollect(&err)) {
        SettingsStatus(err, true)
        return
    }
    ; Slots собираются и проверяются тем же проходом, что и General:
    ; одна ошибка в любой вкладке отменяет запись обеих — наполовину не
    ; сохраняем.
    slotPlan := SettingsSlotsCollect(&err)
    if (err != "") {
        SettingsStatus(err, true)
        return
    }
    hasSlotWork := slotPlan.writes.Length || slotPlan.deletes.Length

    todo := []
    for v in vals {
        if (SettingsLive(v.sec, v.key) = v.val)
            continue
        todo.Push(v)
    }
    if (!todo.Length && !hasSlotWork) {
        SettingsRebase()
        SettingsStatus("Менять нечего: всё уже так")
        if closeAfter
            SettingsClose(true)
        return
    }

    done := 0
    for v in todo {
        try
            IniWrite(v.val, configPath, v.sec, v.key)
        catch as e {
            SettingsStatus("Не записалось: [" v.sec "] " v.key " — " e.Message
                         . (done ? ".  До сбоя записано строк: " done : ""), true)
            return
        }
        done++
    }

    ; Читаем записанное обратно и сравниваем до сообщения об успехе.
    for v in todo {
        got := IniRead(configPath, v.sec, v.key, "")
        if (got != v.val) {
            SettingsStatus("Проверка не прошла: [" v.sec "] " v.key
                         . " — в файле «" got "», ожидалось «" v.val "»", true)
            return
        }
    }

    ; [dynamic]/[general] уже на диске и сверены — то, что ниже, трогает
    ; только [slotN]/[dynamicSlotN] и не может отменить уже совершившийся
    ; факт записи General; LoadConfig в обеих ветках подхватит и его.
    if hasSlotWork {
        slotErr := ""
        SettingsSlotsApply(slotPlan, &slotErr)   ; сама делает LoadConfig и переиндексацию
        if (slotErr != "") {
            SettingsStatus(slotErr, true)
            return
        }
        setUI.edits := Map()
        SettingsSlotsRefreshAll(setUI)
    } else {
        LoadConfig(configPath, &apps, &dynamic, &dynamicSlots,
                   &animMs, &animSteps, &blurMs, &handlesOn)
        SetTimer(HandlesSync, -1)
    }

    SettingsRebase()
    SettingsStatus("Сохранено. Изменённых строк: " (todo.Length + slotPlan.writes.Length)
                 . (slotPlan.deletes.Length ? ", удалено секций: " slotPlan.deletes.Length : ""))
    if closeAfter
        SettingsClose(true)
}
