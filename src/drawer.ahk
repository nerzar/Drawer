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
HANDLE_BG    := "2A2E35"
LoadConfig(configPath, &apps, &dynamic, &dynamicSlots, &animMs, &animSteps, &blurMs, &handlesOn, &HANDLE_BG)
; =================================================================

; Читает config.ini в структуры программы. Числовые и строковые поля
; (monitor, edge, width, animMs…) идут в приложение как есть — их
; проверяют ResolveMonitor/ComputeGeom при показе. Отдельно проверяются
; только activateOnShow/hideOnBlur: непустая строка "false" в AHK
; истинна, поэтому её нужно явно разобрать, а не просто передать дальше.
LoadConfig(path, &apps, &dynamic, &dynamicSlots, &animMs, &animSteps, &blurMs, &handlesOn, &handleBg) {
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
    ; Цвет кромки — тоже настройка теперь; умолчание то же значение, что
    ; раньше было зашито константой, так что старый config.ini без этого
    ; ключа ведёт себя точно как прежде. Формат проверяется так же
    ; придирчиво, как true/false у IniBool — иначе правка руками с опечаткой
    ; уронит HandleLighten() ниже прямо при старте.
    handleBg := IniRead(path, "general", "accent", "2A2E35")
    if !RegExMatch(handleBg, "^[0-9A-Fa-f]{6}$") {
        MsgBox("config.ini: [general] accent=" handleBg " — ожидается 6 hex-цифр (RRGGBB), взято 2A2E35", "Ящик")
        handleBg := "2A2E35"
    }

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

managed   := Map()   ; номер слота -> захваченный hwnd
state     := Map()   ; hwnd -> { orig, geom }
watched   := Map()   ; выдвинутые окна с hideOnBlur: hwnd -> настройки
permSlots := Map()   ; номер слота -> индекс в apps (живёт до LoadConfig)
dynSlots  := Map()   ; номер слота -> hwnd
notified  := Map()   ; текст уведомления -> true, пока оно ещё актуально
handles   := Map()   ; номер слота -> кромка припаркованного окна
handleMode := 0      ; режим опроса кромок: 0 нет, 1 редкий, 2 частый
handleSync := 0      ; тактов до следующей полной пересборки кромок
setGui    := 0       ; окно настроек, пока оно открыто
setUI     := 0       ; его контролы и значения, с которыми окно открылось
serviceWindows := Map()   ; hwnd своего окна -> true, пока оно живо
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
for a in apps {
    if (Opt(a, "focusHotkey", "") = "")
        continue
    try {
        Hotkey(Hooked(a.focusHotkey), OnFocusHotkey.Bind(a.slot))
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
; спокойный тёмный цвет, чуть светлее под курсором. Сам HANDLE_BG уже
; загружен из config.ini выше (LoadConfig, ключ [general] accent, см.
; Settings — там же живёт выбор цвета). HANDLE_BG_HOT в файле отдельно
; не хранится — это HANDLE_BG, пересвеченный HandleLighten() заново
; после каждого LoadConfig (см. её вызовы в SettingsReconcileRuntime и
; SettingsSave).
; try — HandleLighten не должен уронить каждый обычный запуск программы
; из-за собственной арифметики; при сбое запасной оттенок — тот, что был
; зашит константой раньше.
try
    HANDLE_BG_HOT := HandleLighten(HANDLE_BG, 0.10)
catch
    HANDLE_BG_HOT := "3A414D"
HANDLE_FG     := "D6DAE2"

; Пересвеченная копия hex-цвета (без "#") в сторону белого на долю pct
; (0..1) на канал — единственный способ получить HANDLE_BG_HOT (и
; безопасный для текста оттенок акцента в Settings) для ПРОИЗВОЛЬНОГО
; выбранного цвета, а не только для того одного значения, что раньше
; было зашито константой.
HandleLighten(hex, pct) {
    r := Integer("0x" SubStr(hex, 1, 2))
    g := Integer("0x" SubStr(hex, 3, 2))
    b := Integer("0x" SubStr(hex, 5, 2))
    r := Round(r + (255 - r) * pct)
    g := Round(g + (255 - g) * pct)
    b := Round(b + (255 - b) * pct)
    return Format("{:02X}{:02X}{:02X}", r, g, b)
}
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

; ========================= СЛУЖЕБНЫЕ ОКНА =========================
; Часть окон ящик открывает сам: настройки, диалог выбора окна, позже —
; host WebView2. Для остального кода это не окна пользователя: в слот их
; привязать нельзя, фокус вместо припаркованного окна им не отдают, и
; переход в них не считается потерей фокуса (Р18).
;
; Кромкам такая отметка не нужна: у них пустой заголовок и ToolWindow,
; и отборы ящика отсеивают их сами. Окно настроек — обычное окно с
; заголовком и фокусом, иначе им нельзя пользоваться, поэтому исключение
; приходится назвать явно.
;
; Это именно реестр, а не пара известных переменных. Ядру нечего знать
; о том, как называется окно настроек и сколько у него диалогов: кто
; окно открыл, тот его и объявляет — ServiceWindowAdd() перед показом,
; ServiceWindowDrop() перед разрушением. Поэтому следующее своё окно
; (WebView2 host) включается в те же пять отборов одной строкой
; регистрации, а не правкой каждого из них.

ServiceWindowAdd(hwnd) {
    global serviceWindows
    if hwnd
        serviceWindows[hwnd] := true
}

ServiceWindowDrop(hwnd) {
    global serviceWindows
    if serviceWindows.Has(hwnd)
        serviceWindows.Delete(hwnd)
}

; Своё ли это окно. Запись об умершем окне снимается прямо здесь:
; Windows переиспользует hwnd, и забытая запись однажды назвала бы
; служебным чужое окно пользователя — молчаливый отказ, который потом
; не воспроизвести.
IsServiceWindow(hwnd) {
    global serviceWindows
    if !hwnd
        return false
    if serviceWindows.Has(hwnd) {
        if WinExist("ahk_id " hwnd)
            return true
        serviceWindows.Delete(hwnd)
    }
    ; Пока ящик не открыл ничего своего, диалоги ему не принадлежат —
    ; это условие было и раньше, в виде «нет окна настроек, значит нет».
    if !serviceWindows.Count
        return false
    ; Собственный диалог: вопрос про несохранённые правки, MsgBox из
    ; LoadConfig и подобное. Для ящика это продолжение того же служебного
    ; окна — пока висит вопрос, пользователь никуда не уходил, и
    ; выдвинутый слот уезжать не должен. Без этого WatchBlur, который
    ; тикает и во время MsgBox, видит обычное окно переднего плана и
    ; убирает слот. Свой диалог отличается от чужого процессом.
    try
        return WinGetClass("ahk_id " hwnd) = "#32770"
            && WinGetPID("ahk_id " hwnd) = DllCall("GetCurrentProcessId", "UInt")
    return false
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
    global managed, permSlots, dynSlots
    for n in permSlots {
        if (managed.Has(n) && managed[n] = hwnd)
            return PermApp(n)
    }
    for n, h in dynSlots {
        if (h = hwnd)
            return SlotCfg(n)
    }
    return 0
}

; Колбэк держит НОМЕР слота, а не индекс в apps. apps пересобирается
; при каждом LoadConfig в порядке номеров, поэтому появление постоянного
; слота с меньшим номером сдвигает индексы всех следующих за ним — а
; хоткей регистрируется один раз при старте и продолжал бы звать прежнее
; число, попадая в чужой слот или в несуществующий индекс. Номер слота
; такого сдвига не знает, а permSlots спрашивается в момент нажатия:
; слот, переставший быть постоянным, теперь просто ничего не делает.
;
; Сама клавиша остаётся той, что была назначена при старте:
; перерегистрации нет, и правка focusHotkey по-прежнему вступает в силу
; после перезапуска — ровно так, как подписано в форме настроек.
OnFocusHotkey(n, *) {
    try
        FocusApp(n)
    catch as e
        Notify("Сбой: " e.Message, "Ящик", 3)
}

; Слот: постоянный ищет своё приложение по процессу, динамический
; управляет запомненным окном.
ToggleSlot(n) {
    global permSlots, dynSlots
    if permSlots.Has(n) {
        ToggleApp(n)
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
    global permSlots, dynSlots
    if permSlots.Has(n) {
        Notify("Слот " n " занят постоянной привязкой: " PermApp(n).name, "Ящик", 2)
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

; Настройки постоянного слота по его номеру — 0, если слот не постоянный.
; Единственное место, где индекс в apps ещё используется, и используется
; он тут же, без сохранения: индекс действителен только до следующего
; LoadConfig, потому что apps пересобирается в порядке номеров. Всё, что
; живёт дольше одного вызова — managed, колбэки хоткеев, снимки в плане
; Settings, — обязано помнить номер слота.
PermApp(n) {
    global apps, permSlots
    return permSlots.Has(n) ? apps[permSlots[n]] : 0
}

; Окно слота прямо сейчас — 0, если его нет. Постоянный слот ищется тем
; же поиском, что и для хоткея, но результат НИКУДА НЕ ПИШЕТСЯ: managed
; здесь только читается. Иначе беглый взгляд на статус подменял бы выбор,
; который иначе сделал бы FindWindow() в момент реального нажатия.
; Динамический слот берётся из dynSlots как есть.
SlotWindow(n) {
    global managed, permSlots, dynSlots
    if permSlots.Has(n) {
        if (managed.Has(n) && WinExist("ahk_id " managed[n]))
            return managed[n]
        return FindWindow(PermApp(n))
    }
    return (dynSlots.Has(n) && WinExist("ahk_id " dynSlots[n])) ? dynSlots[n] : 0
}

; Состояние слота структурой, а не строкой: { state, title }. Пять
; состояний — те же, что в integration-контракте
; (docs/settings-integration-layer.md):
;
;   empty                  динамический слот без окна
;   applicationNotRunning  постоянный слот, приложение не запущено
;   available              окно есть, но ящик его ещё не показывал
;   parked                 окно за пределами всех мониторов
;   shown                  окно на экране
;
; title заполнен только там, где окно действительно есть.
;
; Признаки те же, на которых стоит остальная программа (HandleManaged /
; HandleParked) — второго источника истины не заводится. Вход — номер
; слота, а не строка списка Settings: этим же API пользуется WebView-порт,
; которому ни строк, ни секций config.ini не показывают. Русские подписи
; живут отдельно, в SettingsStatusText(): разбирать статус обратно из
; локализованного текста не должен никто.
SlotStatus(n) {
    global permSlots
    if !(hwnd := SlotWindow(n))
        return { state: permSlots.Has(n) ? "applicationNotRunning" : "empty",
                 title: "" }
    title := ""
    try title := WinGetTitle("ahk_id " hwnd)
    if !HandleManaged(hwnd)
        return { state: "available", title: title }
    return { state: HandleParked(hwnd) ? "parked" : "shown", title: title }
}

; Постоянный слот: окно ищется по настройкам приложения. Приложение не
; запущено — показывать нечего, молчим: это то же самое, что нажать на
; пустой слот.
ToggleApp(n) {
    if !(a := PermApp(n))
        return
    if !(hwnd := AppWindow(n, a))
        return
    ToggleWindow(hwnd, a)
}

FocusApp(n) {
    if !(a := PermApp(n))
        return
    if !(hwnd := AppWindow(n, a))
        return
    FocusWindow(hwnd, a)
}

; Захваченное окно помним: припаркованное окно поиском по площади
; можно спутать с другим окном того же приложения. Ключ — номер слота:
; он переживает перечитывание конфига, а индекс в apps — нет.
AppWindow(n, a) {
    global managed
    hwnd := (managed.Has(n) && WinExist("ahk_id " managed[n])) ? managed[n] : FindWindow(a)
    if hwnd
        managed[n] := hwnd
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
    global managed, permSlots, dynSlots
    out := []
    Loop 9 {
        n := A_Index
        if permSlots.Has(n) {
            if !(managed.Has(n) && WinExist("ahk_id " managed[n]))
                continue
            out.Push({ n: n, hwnd: managed[n], cfg: PermApp(n) })
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

; HandleFace красит hd.gui.BackColor только на переходе наведения
; (on != hd.hot) — уже стоящая на месте кромка в покое этот код не
; проходит и не заметит новый HANDLE_BG сама. Вызывается сразу после
; Settings-Apply, который поменял акцент, чтобы настройка не выглядела
; неприменённой, пока никто не тронул мышью ни одну кромку.
HandleRepaintAll() {
    global handles, HANDLE_BG, HANDLE_BG_HOT
    for n, hd in handles {
        try {
            hd.gui.BackColor := hd.hot ? HANDLE_BG_HOT : HANDLE_BG
            DllCall("InvalidateRect", "Ptr", hd.gui.Hwnd, "Ptr", 0, "Int", 1)
        }
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
; Связь с остальным ящиком — одна: свои окна объявляются служебными
; через ServiceWindowAdd()/ServiceWindowDrop(). Сам отбор живёт в ядре
; (IsServiceWindow) и о настройках ничего не знает; пользуются им
; PickActive, TrackedFore, FocusCandidate, StillFocused и FindWindow.

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

SettingsFieldLabel(key) {
    static labels := Map(
        "name", "Имя",
        "exe", "Файл (exe)",
        "cls", "Класс окна",
        "monitor", "Монитор",
        "edge", "Край",
        "width", "Ширина (%)",
        "activateOnShow", "Активация",
        "hideOnBlur", "Автоскрытие",
        "focusHotkey", "Хоткей")
    return labels[key]
}

; Поля панели «только чтение» (динамический слот) — короче редактируемой:
; ни класса окна, ни «Автоскрытие» смысла показывать нет, раз их всё равно
; нельзя тронуть, не сделав слот постоянным.
SettingsReadOnlyFields() {
    return ["name", "exe", "monitor", "edge", "width",
            "activateOnShow", "focusHotkey"]
}

; Человеческое значение поля для панели «только чтение» — то же самое,
; что редактируемые контролы (DropDownList) и так показывают текстом;
; без этого монитор/край читались бы как сырой config-код.
SettingsDisplayVal(cfg, key, n) {
    if (key = "monitor") {
        v := cfg.HasOwnProp("monitor") ? cfg.monitor : ""
        return (v = "" || v = "cursor") ? "Следовать за курсором" : "Монитор " v
    }
    if (key = "edge") {
        static edges := Map("right", "Справа", "left", "Слева", "top", "Сверху", "bottom", "Снизу")
        v := cfg.HasOwnProp("edge") ? cfg.edge : ""
        return edges.Has(v) ? edges[v] : SettingsVal(cfg, key)
    }
    if (key = "exe" && !cfg.HasOwnProp("exe"))
        return "(пусто)"
    if (key = "focusHotkey" && !cfg.HasOwnProp("focusHotkey"))
        return "Ctrl + Alt + " n
    return SettingsVal(cfg, key)
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
    return (IniRead(configPath, s, key, "") = want) ? "из [" s "]" : "из [" s "] ≠ файл"
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

; Строки списка: девять номеров слотов. Общие настройки динамических
; слотов (бывшая строка 0/"[dynamic]") сюда больше не входят — это не
; слот, а конфигурация, и её место на вкладке General. cfg — тот самый
; объект, который ящик спросит при нажатии хоткея, поэтому показанное и
; работающее разойтись не могут.
SettingsRows() {
    global permSlots, dynamicSlots
    rows := []
    Loop 9 {
        n := A_Index
        if permSlots.Has(n) {
            rows.Push({ n: n, kind: "perm", cfg: PermApp(n),
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
    return (r.kind = "perm") ? "Постоянный" : "Динамический"
}

; Цвет индикатора статуса в строке списка: заметно тем же языком, что и
; сама программа отличает «выдвинут» от «припаркован» — не выдумывает
; новую трёхцветную модель поверх SlotStatus(). Ветвится по enum, а не
; по подписи: подпись переводима, состояние — нет.
SettingsStatusColor(state) {
    if (state = "empty")
        return "3A3D44"
    if (state = "applicationNotRunning")
        return "5A5D64"
    return "5FB37C"
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
; запереть, поэтому пока диалог открыт, он объявлен служебным окном
; (ServiceWindowAdd) — иначе Ctrl+Alt+Shift+N мог бы привязать сам
; диалог вместо того окна, которое пользователь пришёл выбирать.
SettingsPickWindow() {
    global setGui
    cands := SettingsWindowCandidates()
    result := { picked: 0 }

    g := Gui("+Owner" setGui.Hwnd " -MinimizeBox", "Ящик — выбор окна")
    g.BackColor := "17181C"
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", g.Hwnd, "Int", 20, "Int*", 1, "Int", 4)
    g.SetFont("s9 cEDEDEF", "Segoe UI")
    g.Add("Text", "x12 y10 w460 h20 cEDEDEF",
          cands.Length ? "Окно, которое сейчас открыто:" : "Подходящих окон не найдено.")
    lv := SettingsDarkListView(g.Add("ListView", "x12 y32 w460 h280 -Multi +Report Background1E2025", ["Заголовок", "Процесс"]))
    for c in cands
        lv.Add("", c.title, c.exe)
    lv.ModifyCol(1, 320), lv.ModifyCol(2, 130)
    if cands.Length
        lv.Modify(1, "Select Focus")

    ok     := SettingsDark(g.Add("Button", "+0x8000 x300 y320 w82 h28 Default", "Выбрать"))
    cancel := SettingsDark(g.Add("Button", "+0x8000 x392 y320 w80 h28", "Отмена"))
    ok.Enabled := cands.Length > 0

    finish(use) {
        if use {
            row := lv.GetNext(0)
            if (row && row <= cands.Length)
                result.picked := cands[row]
        }
        ServiceWindowDrop(g.Hwnd)   ; сначала забыть, потом рушить
        g.Destroy()
    }
    ok.OnEvent("Click", (*) => finish(true))
    cancel.OnEvent("Click", (*) => finish(false))
    lv.OnEvent("DoubleClick", (*) => finish(true))
    g.OnEvent("Close", (*) => finish(false))
    g.OnEvent("Escape", (*) => finish(false))

    ; hwnd запоминается отдельно: если диалог снесут вместе с окном
    ; настроек, finish() не выполнится, а g.Hwnd у разрушенного Gui уже
    ; не спросить — а снять регистрацию всё равно надо, иначе номер
    ; hwnd, переиспользованный Windows, останется помечен служебным.
    pickHwnd := g.Hwnd
    ServiceWindowAdd(pickHwnd)
    g.Show("w484 h360")
    WinWaitClose("ahk_id " pickHwnd)
    ServiceWindowDrop(pickHwnd)
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

; Единственное место, где состояние слота превращается в текст. Сам
; статус приходит из SlotStatus() уже разобранным, поэтому обратного
; разбора русской строки нигде нет — ни здесь, ни в индикаторе, ни у
; будущего WebView-порта. Подписи прежние дословно: на них стоят
; проверки набора setstat.
SettingsStatusText(st) {
    switch st.state {
    case "empty":                 return "пусто"
    case "applicationNotRunning": return "приложение не запущено"
    case "available":             return "окно: " st.title
    case "parked":                return "припаркован"
    case "shown":                 return "выдвинут"
    }
    return ""
}

; Путь к exe для иконки строки списка — только когда у слота есть
; настоящее живое окно прямо сейчас: exe в config.ini хранится голым
; именем файла (SettingsPickExe), без пути, а достать иконку можно
; только по полному пути. Окно спрашивается тем же SlotWindow(), что и
; статус, — вторым источником истины не заводится.
SettingsSlotIconPath(n) {
    if !(hwnd := SlotWindow(n))
        return ""
    try
        return WinGetProcessPath("ahk_id " hwnd)
    return ""
}

; ----------------------------- ПРАВКИ ------------------------------
; Буфер несохранённых правок вкладки Slots — setUI.edits, Map номер слота
; -> { kind: "perm", ...девять полей... } либо { kind: "dyn" } (слот
; готовится лишиться [slotN]). Ничего из этого не пишется в файл до
; «Применить»/«ОК» — тот же принцип, что уже держит форму General.
;
; Состояние эта правка не трогает: SlotStatus() спрашивает
; permSlots/dynSlots/managed напрямую и получает только номер слота, а не
; буфер, — колонка «Состояние» показывает, что происходит на самом деле,
; а не то, что вот-вот будет записано.

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
    global permSlots
    if permSlots.Has(n) {
        a := PermApp(n)
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

; Буфер правки вернулся к тому же, с чего начался SettingsEditSeed(n), —
; сравниваются все девять полей панели «Слот».
SettingsSlotUnchanged(e, n) {
    seed := SettingsEditSeed(n)
    for key in SettingsFields()
        if (e.%key% != seed.%key%)
            return false
    return true
}

; Обработчик правки одного поля панели «Слот». populating гасит вызов,
; пока панель сама заполняет контролы при переключении строки списка —
; иначе один клик по строке выглядел бы как правка всех девяти полей.
; Если после правки буфер снова совпал с исходным SettingsEditSeed(n) —
; запись убирается: иначе SettingsSnapshot() продолжала бы видеть слот
; тронутым только из-за самого факта наличия записи в ui.edits, и
; SettingsIsDirty()/пометка «не сохранено» врали бы после ручного отката.
SettingsSlotEdited(ui, key, val) {
    if ui.populating
        return
    n := ui.editingSlot
    if !n
        return
    if !ui.edits.Has(n)
        ui.edits[n] := SettingsEditSeed(n)
    ui.edits[n].%key% := val
    if SettingsSlotUnchanged(ui.edits[n], n)
        ui.edits.Delete(n)
}

; Пересчитать статус (точку и текст) во всех строках списка. Ошибка на
; одной строке пропускает только её и не трогает таймер.
SettingsSlotsTick() {
    global setUI
    if !(ui := setUI)
        return
    Loop 9
        try
            SettingsSlotRowPaint(ui, A_Index)
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
; Иконка-подсказка вместо всегда видимой строки с именем ключа: рядом со
; свежим скриншотом стало видно, что «width»/«edge»/«monitor» голым
; текстом под полем читаются как обрывок отладочного вывода, а не как
; техническая подсказка. Тот же приём, что уже применён к cls в Slots —
; по клику всплывает ToolTip, обычно поле этим никто не пользуется.
SettingsHint(g, x, y, section, key) {
    global configPath
    txt := "Ключ config.ini: " key
         . (IniHas(configPath, section, key) ? "" : "  (не задан — используется значение по умолчанию)")
    g.SetFont("s8 c9A9CA3")
    ctl := g.Add("Text", "x" x " y" y " w14 h16 Center", "ⓘ")
    g.SetFont("s9 cEDEDEF")
    ctl.OnEvent("Click", (*) => (ToolTip(txt), SetTimer(() => ToolTip(), -3000)))
    return ctl
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

; Панель под списком: поля динамического слота (только чтение) и
; источник каждого. Постоянные слоты сюда не попадают — для них
; SettingsFillRow показывает редактируемую панель (SettingsFillEditable).
SettingsFill(box, valc, srcc, r) {
    ; Короткий заголовок — «Слот N», без раздела/состояния: полный текст
    ; вида «Слот N — постоянный, [slotN]» на узкой панели наезжал на
    ; кнопку «Сделать динамическим…» рядом. Тип слота и так виден по
    ; плашке в списке слева и по подписи самой кнопки.
    box.Text := "Слот " r.n
    for i, key in SettingsReadOnlyFields() {
        valc[i].Text := SettingsDisplayVal(r.cfg, key, r.n)
        srcc[i].Text := r.cfg.HasOwnProp(key)
                      ? SettingsSrc(r.sections, key, r.cfg.%key%,
                                    SettingsIsBool(key))
                      : (key = "focusHotkey" ? "по номеру" : "по умолчанию")
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
    ui.box.Text := "Слот " ef.n . (ef.HasOwnProp("pending") ? "  ·  не сохранено" : "")
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
    ui.freeNote.Visible := !editable

    if editable
        SettingsFillEditable(ui, ef)
    else
        SettingsFill(ui.box, ui.valc, ui.srcc, r)

    if editable
        ; DropDownList после Visible=false→true (и после программного
        ; .Choose() внутри SettingsFillEditable) иногда не перерисовывает
        ; сама ни стрелку, ни текст выбранного пункта — переприменить тему
        ; и перерисовать нужно ПОСЛЕ того, как значения уже расставлены,
        ; иначе invalidate освежит контрол ещё со старым текстом.
        for c in ui.editCtl
            SettingsInvalidate(SettingsDark(c))

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
    idx := ui.selectedSlot
    if !idx
        return
    r := ui.slotsRows[idx]
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
    SettingsSlotRowPaint(ui, idx)
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

; Иконка приложения поверх номера-аватара — только когда путь реально
; поменялся: SettingsSlotsTick() перерисовывает все девять строк каждые
; 400мс, а LoadPicture — файловый вызов, тратить его на одно и то же
; каждый тик незачем. Хендл — ресурс GDI, свой на каждую строку;
; предыдущий явно закрывается перед тем, как завести новый, и в
; SettingsClose() — раз окно всё равно закрывается, а не только строка.
SettingsSlotRowIcon(row, n) {
    path := SettingsSlotIconPath(n)
    if (path = row.iconPath)
        return
    if row.iconHwnd {
        try DllCall("DestroyIcon", "Ptr", row.iconHwnd)
        row.iconHwnd := 0
    }
    row.iconPath := path
    if (path != "") {
        try {
            hicon := LoadPicture(path, "Icon1 w20 h20", &imgType)
            if (hicon && imgType = 1) {
                row.iconHwnd := hicon
                row.icon.Value := "HICON:" hicon
            }
        }
    }
    row.icon.Visible := (row.iconHwnd != 0)
    row.avatar.Visible := (row.iconHwnd = 0)
}

; Перерисовать одну строку своего списка слотов (аватар/имя/статус/
; плашка) по эффективному состоянию (с учётом буфера правок) и текущему
; акценту. Замена родных колонок ListView — Край/Монитор/Ширина сюда не
; входят, они и так на виду в панели «Слот» справа, как только строку
; выбрали.
SettingsSlotRowPaint(ui, idx) {
    row := ui.slotRow[idx]
    r   := ui.slotsRows[idx]
    ef  := SettingsEffective(ui, r)
    perm := (ef.kind = "perm")

    row.avatar.Text := String(idx)
    row.avatar.Opt(perm ? "Background333640 c" HandleLighten(ui.accentVal, 0.6)
                         : "Background1E2025 c6C6E76")
    SettingsInvalidate(row.avatar)
    SettingsSlotRowIcon(row, r.n)
    row.name.Text := SettingsVal(ef.cfg, "name")

    st := SlotStatus(r.n)
    row.meta.Text := SettingsStatusText(st)
    row.dot.Opt("Background" SettingsStatusColor(st.state))
    SettingsInvalidate(row.dot)

    row.pill.Text := SettingsKind(ef)
    if perm
        row.pill.Opt("Background" HandleLighten(ui.accentVal, 0.12) . " c" HandleLighten(ui.accentVal, 0.6))
    else
        row.pill.Opt("Background2B2D33 c9A9CA3")
    SettingsInvalidate(row.pill)
}

; После сохранения список мог не совпасть с диском построчно сразу в
; нескольких местах (типы и поля нескольких слотов) — перечитывается
; целиком, как при открытии окна, а не точечными правками по одной строке.
SettingsSlotsRefreshAll(ui) {
    ui.slotsRows := SettingsRows()
    Loop 9
        SettingsSlotRowPaint(ui, A_Index)
    if ui.selectedSlot
        SettingsFillRow(ui, ui.selectedSlot)
}

; Тёмная тема системного контрола — недокументированный, но широко
; используемый приём (SetWindowTheme + DarkMode_Explorer). Ошибка молча
; проглатывается: без поддержки контрол просто останется светлым,
; программа не падает и не сообщает об этом пользователю (это не сбой).
SettingsDark(ctrl) {
    try DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
    return ctrl
}

; Смена Background у уже показанного контрола через .Opt() Windows не
; всегда перерисовывает сама — тот же случай, что уже решён для окон-
; кромок в HandleRepaintAll(). Нужна там, где перекраска контрола не
; идёт рядом со сменой Visible (та и так вызывает полную перерисовку).
SettingsInvalidate(ctrl) {
    try DllCall("InvalidateRect", "Ptr", ctrl.Hwnd, "Ptr", 0, "Int", 1)
    return ctrl
}

; RRGGBB -> COLORREF (0x00BBGGRR), которого ждут GDI-вызовы ниже.
SettingsBGR(hex) {
    r := Integer("0x" SubStr(hex, 1, 2))
    g := Integer("0x" SubStr(hex, 3, 2))
    b := Integer("0x" SubStr(hex, 5, 2))
    return (b << 16) | (g << 8) | r
}

; Закрытый DropDownList SetWindowTheme("DarkMode_Explorer") красит, а
; вот сам выпадающий список — отдельное системное окно (листбокс) со
; своим цветом, тему не наследует и остаётся белым с синим текстом.
; WM_CTLCOLORLISTBOX — обычный (не own-draw) способ его перекрасить:
; Windows перед отрисовкой спрашивает родителя, каким HBRUSH/цветом
; текста красить, и это тот вопрос. Один раз на процесс — Drawer больше
; нигде листбоксов/комбобоксов не показывает, ловить чужие незачем.
SettingsDdlColors(wParam, lParam, msg, hwnd) {
    static brush := 0
    if !brush
        brush := DllCall("gdi32\CreateSolidBrush", "UInt", SettingsBGR("252A31"), "Ptr")
    DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", SettingsBGR("EDEDEF"))
    DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", SettingsBGR("252A31"))
    return brush
}

; Тёмный ListView — тому самому диалогу выбора окна (SettingsPickWindow),
; единственному настоящему ListView, что остался в программе. Одной
; SetWindowTheme мало: строки и фон под ней всё равно рисуются системным
; белым, пока явно не задать LVM_SETBKCOLOR/…TEXTBKCOLOR/…TEXTCOLOR.
SettingsDarkListView(lv) {
    SettingsDark(lv)
    try DllCall("uxtheme\SetWindowTheme", "Ptr", lv.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
    SendMessage(0x1001, 0, SettingsBGR("1E2025"), lv)   ; LVM_SETBKCOLOR
    SendMessage(0x1026, 0, SettingsBGR("1E2025"), lv)   ; LVM_SETTEXTBKCOLOR
    SendMessage(0x1024, 0, SettingsBGR("EDEDEF"), lv)   ; LVM_SETTEXTCOLOR
    return lv
}

; Обвязка для контролов Settings: тёмная тема (SettingsDark) плюс, если
; передан список, — запись в него. panel — один из трёх списков в
; ui.panels: вместе с остальными контролами того же списка он целиком
; прячется/показывается в SettingsNavClick при переключении раздела.
SettingsMk(panel, ctrl) {
    SettingsDark(ctrl)
    if panel
        panel.Push(ctrl)
    return ctrl
}

; Плоская «карточка» вместо системного GroupBox. На тёмном фоне рамка
; обычного GroupBox остаётся бледной, системной — получается «окно
; мастера», а не плитка из мокапа. Вместо неё — залитый прямоугольник
; своего оттенка (--bg-card) и обычный жирный текст-заголовок поверх;
; скруглений всё равно нет ни там, ни там — предел нативного Gui.
; Возвращает контрол заголовка: у панели «Слот» в него потом
; переписывается динамический текст (SettingsFill/SettingsFillEditable).
SettingsCard(g, panel, x, y, w, h, title) {
    bg := SettingsMk(panel, g.Add("Text", "x" x " y" y " w" w " h" h " Background1E2025 Border", ""))
    SettingsRound(bg, w, h, 10)
    g.SetFont("s10 bold cEDEDEF")
    titleCtl := SettingsMk(panel, g.Add("Text", "x" (x + 18) " y" (y + 16) " w" (w - 36) " h20", title))
    g.SetFont("s9 norm cEDEDEF")
    return titleCtl
}

; Скруглённый контрол через SetWindowRgn — не own-draw: сам контрол
; рисуется как обычно, регион только обрезает его до эллипса/скруглённого
; прямоугольника, а из-под срезанных углов проступает фон окна. radius=0
; — полный эллипс (кружок/капсула для мелких контролов), иначе —
; скруглённый прямоугольник с этим радиусом угла. +1 к w/h компенсирует
; то, что CreateRoundRectRgn чертит прямоугольник на пиксель уже, чем
; заказано, — иначе скруглённая карточка на пиксель не дотягивалась бы
; до собственного заявленного размера.
SettingsRound(ctrl, w, h, radius := 0) {
    try {
        rgn := radius
             ? DllCall("CreateRoundRectRgn", "Int", 0, "Int", 0, "Int", w + 1, "Int", h + 1, "Int", radius, "Int", radius, "Ptr")
             : DllCall("CreateEllipticRgn", "Int", 0, "Int", 0, "Int", w, "Int", h, "Ptr")
        DllCall("SetWindowRgn", "Ptr", ctrl.Hwnd, "Ptr", rgn, "Int", true)
    }
    return ctrl
}

; Пояснение про класс окна по клику рядом с полем cls. Само поле
; (ui.eCls) остаётся настоящим и по-прежнему редактируется руками — это
; только подсказка, вынесенная во всплывающее окно вместо отдельной
; вечно занятой строки формы.
SettingsClsInfo(*) {
    ToolTip("Класс окна (ahk_class). Уточняет, какое именно окно ловить,`n"
          . "если под этим exe их несколько. Обычно заполняется сам`n"
          . "кнопкой «Окно…» — руками трогать нужно редко, но можно.")
    SetTimer(() => ToolTip(), -4000)
}

; Левый навигатор заменяет верхний Tab3: показывает один из трёх
; ui.panels, красит активный пункт акцентом, остальные — нейтрально, и
; держит таймер живой колонки Slots точно так же, как раньше держало
; событие Tab3 "Change", — тикает, только пока виден раздел Slots.
; После показа Slots панель «Слот» перезаполняется явно: сама она может
; быть скрыта целиком предыдущим переключением раздела, а какие из её
; полей показывать — только для чтения или редактируемые — решает
; SettingsFillRow() по текущему выбору в списке, не эта функция.
SettingsNavClick(ui, idx, *) {
    for panel in ui.panels
        for c in panel
            c.Visible := false
    for c in ui.panels[idx]
        c.Visible := true
    ui.activeNav := idx
    SettingsNavRepaint(ui)
    if (idx = 2)
        SettingsFillRow(ui, ui.selectedSlot ? ui.selectedSlot : 1)
    SettingsSlotsTimer(idx = 2 ? 2 : 0)
}

SettingsNavRepaint(ui) {
    for n in ui.nav {
        active := (n.idx = ui.activeNav)
        opt := (active ? ("Background" HandleLighten(ui.accentVal, 0.12)) : "Background1B1C21")
             . " c" (active ? HandleLighten(ui.accentVal, 0.5) : "9A9CA3")
        n.ctl.Opt(opt)
        n.icon.Opt(opt)
        SettingsInvalidate(n.ctl)
        SettingsInvalidate(n.icon)
    }
}

; Клик по образцу или свой HEX — оба ведут сюда. Отмечает галочкой
; образец, который совпал с текущим значением, и красит мини-превью
; плитки кромки тем же цветом, каким кромка будет закрашена на самом
; деле — HandleCreate/HandleApply берут его из того же HANDLE_BG.
SettingsAccentPick(ui, hex, *) {
    ui.accentVal := hex
    for s in ui.swatchCtl
        s.ctl.Text := (s.hex = hex) ? "✓" : ""
    ui.accentPreview.Opt("Background" hex)
    SettingsInvalidate(ui.accentPreview)
    if (ui.accentHex.Value != hex)
        ui.accentHex.Value := hex
    SettingsRepaintAccent(ui)
}
; Свой HEX подтверждается по мере ввода, а не по потере фокуса: так
; превью и галочки образцов обновляются сразу. Неполный/неверный ввод
; просто пока не принимается — ui.accentVal и так всегда валиден.
SettingsAccentHexEdited(ui) {
    hex := StrUpper(Trim(ui.accentHex.Value))
    if RegExMatch(hex, "^[0-9A-F]{6}$")
        SettingsAccentPick(ui, hex)
}

; Акцент красит не только образцы и мини-превью кромки: активный пункт
; навигации, плашки «Постоянный» и подсветку выбранной строки в списке
; слотов, и плашку-подсказку под динамическим слотом. Тот же приём, что
; HandleRepaintAll() уже делает для настоящих окон-кромок, только для
; контролов этого окна.
SettingsRepaintAccent(ui) {
    SettingsNavRepaint(ui)
    Loop 9
        SettingsSlotRowPaint(ui, A_Index)
    SettingsSlotRowHighlight(ui)
    ui.freeNote.Opt("Background" HandleLighten(ui.accentVal, 0.12) . " c" HandleLighten(ui.accentVal, 0.55))
    SettingsInvalidate(ui.freeNote)
}

; Подсветка выбранной строки списка слотов акцентом — своя, вместо
; системного (синего) выделения ListView.
SettingsSlotRowHighlight(ui) {
    for idx, row in ui.slotRow {
        row.bg.Opt("Background" (idx = ui.selectedSlot ? HandleLighten(ui.accentVal, 0.12) : "1E2025"))
        SettingsInvalidate(row.bg)
    }
}

; Клик по строке своего списка слотов — обновляет подсветку и панель
; «Слот» справа. Общий обработчик для всех контролов строки (фон,
; аватар, имя, статус, плашка): в каждой строке их несколько, и клик по
; любому должен выбирать строку целиком.
SettingsSlotRowSelect(ui, idx, *) {
    ui.selectedSlot := idx
    SettingsSlotRowHighlight(ui)
    SettingsFillRow(ui, idx)
}

SettingsOpen() {
    global setGui, setUI, VERSION, configPath
    global animMs, animSteps, blurMs, handlesOn, dynamic, HANDLE_BG

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
        ; Окно исчезло мимо SettingsClose. Регистрацию снимаем явно:
        ; полагаться на то, что мёртвую запись однажды подчистит
        ; IsServiceWindow, нельзя — hwnd могли уже переиспользовать.
        try ServiceWindowDrop(setGui.Hwnd)
        setGui := 0
    }

    static ddlColorsHooked := false
    if !ddlColorsHooked {
        OnMessage(0x0134, SettingsDdlColors)   ; WM_CTLCOLORLISTBOX — один раз на процесс
        ddlColorsHooked := true
    }

    ; Тёмная тема — насколько это в принципе достижимо у обычного Win32
    ; Gui без owner-draw: тёмный фон, светлый текст, тёмная системная
    ; тема у ListView/кнопок/полей и тёмный заголовок окна через DWM.
    ; Скруглений, теней и градиентов из мокапа тут не будет — это уже
    ; предел того, что даёт нативный контрол без переписывания окна на
    ; WebView2.
    g := Gui("-MaximizeBox", "Drawer — Settings")
    g.BackColor := "17181C"
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", g.Hwnd, "Int", 20, "Int*", 1, "Int", 4)
    g.SetFont("s9 cEDEDEF", "Segoe UI")

    ui := {}
    panelGeneral := [], panelSlots := [], panelAbout := []
    contentX := 244
    pad := 18

    ; ---- левый навигатор: General / Slots / About вместо Tab3 ----
    g.Add("Text", "x0 y0 w208 h720 Background1B1C21", "")
    g.SetFont("c9A9CA3")
    navDefs := [["General", 1, "⚙"], ["Slots", 2, "⊞"], ["About", 3, "ⓘ"]]
    ui.nav := []
    for d in navDefs {
        y := 20 + (A_Index - 1) * 40
        g.SetFont("s11 c9A9CA3")
        icon := g.Add("Text", "x16 y" y " w22 h30 Background1B1C21 Center", d[3])
        g.SetFont("s9 c9A9CA3")
        t := g.Add("Text", "x38 y" y " w154 h30 Background1B1C21", "  " d[1])
        icon.OnEvent("Click", SettingsNavClick.Bind(ui, d[2]))
        t.OnEvent("Click", SettingsNavClick.Bind(ui, d[2]))
        ui.nav.Push({ ctl: t, icon: icon, idx: d[2] })
    }
    g.SetFont("cEDEDEF")

    ; ==================== General ====================
    g.SetFont("s13 bold")
    panelGeneral.Push(g.Add("Text", "x" contentX " y16 w780 h24", "Общие настройки"))
    g.SetFont("s9 norm c9A9CA3")
    panelGeneral.Push(g.Add("Text", "x" contentX " y42 w780 h18",
        "Поведение, внешний вид и умолчания для динамических слотов."))
    g.SetFont("cEDEDEF")

    cardW := 382, cardH := 264, gapX := 16, gapY := 16
    c1x := contentX,              c1y := 72
    c2x := contentX + cardW+gapX, c2y := 72
    c3x := contentX,              c3y := 72 + cardH + gapY
    c4x := contentX + cardW+gapX, c4y := 72 + cardH + gapY

    ; -- Поведение по умолчанию: [dynamic] --
    ; Заголовок и подсказка говорят ровно то, что происходит в файле:
    ; постоянные слоты сюда не заглядывают, у них свои значения в
    ; [slotN], и менять их отсюда нельзя. Иначе первая же правка выглядит
    ; как «настройка не работает».
    SettingsCard(g, panelGeneral, c1x, c1y, cardW, cardH, "Поведение по умолчанию")

    rowY := c1y + 56
    panelGeneral.Push(g.Add("Text", "x" (c1x + pad) " y" rowY " w120 h20", "Размер окна"))
    ui.width := SettingsMk(panelGeneral, g.Add("Edit", "-E0x200 Background252A31 x" (c1x + 150) " y" (rowY - 3) " w50 h28 Number Limit3",
                      String(Opt(dynamic, "width", 60))))
    panelGeneral.Push(g.Add("Text", "x" (c1x + 206) " y" rowY " w80 h20", "% экрана"))
    panelGeneral.Push(SettingsHint(g, c1x + 292, rowY + 4, "dynamic", "width"))

    rowY += 34
    panelGeneral.Push(g.Add("Text", "x" (c1x + pad) " y" rowY " w120 h20", "Сторона выезда"))
    ui.edge := SettingsMk(panelGeneral, g.Add("DropDownList", "-E0x200 x" (c1x + 150) " y" (rowY - 3) " w150 h28", SettingsEdgeItems()))
    SettingsEdgePick(ui.edge, Opt(dynamic, "edge", "right"))
    panelGeneral.Push(SettingsHint(g, c1x + 306, rowY + 4, "dynamic", "edge"))

    rowY += 34
    panelGeneral.Push(g.Add("Text", "x" (c1x + pad) " y" rowY " w120 h20", "Монитор"))
    ui.mon := SettingsMk(panelGeneral, g.Add("DropDownList", "-E0x200 x" (c1x + 150) " y" (rowY - 3) " w150 h28", SettingsMonItems()))
    SettingsMonPick(ui.mon, Opt(dynamic, "monitor", "cursor"))
    panelGeneral.Push(SettingsHint(g, c1x + 306, rowY + 4, "dynamic", "monitor"))

    rowY += 38
    ui.act := SettingsMk(panelGeneral, g.Add("CheckBox", "x" (c1x + pad) " y" rowY " w" (cardW - 2 * pad) " h20", "Активировать окно при открытии"))
    ui.act.Value := Opt(dynamic, "activateOnShow", true) ? 1 : 0

    rowY += 24
    ui.blur := SettingsMk(panelGeneral, g.Add("CheckBox", "x" (c1x + pad) " y" rowY " w" (cardW - 2 * pad) " h20", "Убирать окно, когда фокус ушёл в другое"))
    ui.blur.Value := Opt(dynamic, "hideOnBlur", true) ? 1 : 0

    ; -- Внешний вид: [general] handles + [general] accent --
    SettingsCard(g, panelGeneral, c2x, c2y, cardW, cardH, "Внешний вид")
    ui.handles := SettingsMk(panelGeneral, g.Add("CheckBox", "x" (c2x + pad) " y" (c2y + 40) " w300 h20", "Кромки у края экрана"))
    ui.handles.Value := handlesOn ? 1 : 0
    panelGeneral.Push(SettingsHint(g, c2x + 324, c2y + 43, "general", "handles"))

    panelGeneral.Push(g.Add("Text", "x" (c2x + pad) " y" (c2y + 78) " w" (cardW - 2 * pad) " h1 Background2A2C33", ""))
    panelGeneral.Push(g.Add("Text", "x" (c2x + pad) " y" (c2y + 92) " w150 h20", "Цвет акцента"))

    palette := ["2A2E35", "332A35", "2A352E", "2A3335", "332F2A", "2E2E2E"]
    ui.accentVal := HANDLE_BG
    ui.swatchCtl := []
    swY := c2y + 116
    sx := c2x + pad
    for hex in palette {
        sw := SettingsMk(panelGeneral, g.Add("Text", "x" sx " y" swY " w27 h27 Background" hex " Center",
                         (hex = HANDLE_BG) ? "✓" : ""))
        SettingsRound(sw, 27, 27)
        sw.OnEvent("Click", SettingsAccentPick.Bind(ui, hex))
        ui.swatchCtl.Push({ ctl: sw, hex: hex })
        sx += 33
    }
    g.SetFont("c9A9CA3")
    panelGeneral.Push(g.Add("Text", "x" (c2x + pad) " y" (swY + 41) " w40 h20", "HEX:"))
    g.SetFont("cEDEDEF")
    ui.accentHex := SettingsMk(panelGeneral, g.Add("Edit", "-E0x200 Background252A31 x" (c2x + pad + 42) " y" (swY + 39) " w70 h26", HANDLE_BG))
    ui.accentHex.OnEvent("Change", (*) => SettingsAccentHexEdited(ui))

    previewW := 88, previewH := 108
    previewX := c2x + cardW - pad - previewW
    previewBox := SettingsMk(panelGeneral,
        g.Add("Text", "x" previewX " y" swY " w" previewW " h" previewH " BackgroundDEE0E4", ""))
    SettingsRound(previewBox, previewW, previewH, 10)
    handleW := 20, handleH := 34
    handleX := previewX + previewW - handleW
    handleY := swY + (previewH - handleH) // 2
    ui.accentPreview := SettingsMk(panelGeneral,
        g.Add("Text", "x" handleX " y" handleY " w" handleW " h" handleH " Background" HANDLE_BG, ""))
    g.SetFont("s10 bold cD6DAE2")
    panelGeneral.Push(g.Add("Text", "x" handleX " y" (handleY + 9) " w" handleW " h16 Center BackgroundTrans", "›"))
    g.SetFont("s9 norm cEDEDEF")

    ; -- Анимация: два ключа, но выбирается одним списком --
    SettingsCard(g, panelGeneral, c3x, c3y, cardW, cardH, "Анимация")
    rowY := c3y + 56
    panelGeneral.Push(g.Add("Text", "x" (c3x + pad) " y" rowY " w150 h20", "Плавность"))
    ui.anim := SettingsMk(panelGeneral, g.Add("DropDownList", "-E0x200 x" (c3x + 182) " y" (rowY - 3) " w184 h28", SettingsAnimItems()))

    rowY += 34
    panelGeneral.Push(g.Add("Text", "x" (c3x + pad) " y" rowY " w150 h20", "Длительность (мс)"))
    ui.animMs := SettingsMk(panelGeneral, g.Add("Edit", "-E0x200 Background252A31 x" (c3x + 182) " y" (rowY - 3) " w56 h28 Number Limit4", String(animMs)))

    rowY += 34
    panelGeneral.Push(g.Add("Text", "x" (c3x + pad) " y" rowY " w150 h20", "Шагов"))
    ui.animSteps := SettingsMk(panelGeneral, g.Add("Edit", "-E0x200 Background252A31 x" (c3x + 182) " y" (rowY - 3) " w56 h28 Number Limit3", String(animSteps)))

    SettingsAnimPick(ui, animMs, animSteps)
    ui.anim.OnEvent("Change", (*) => SettingsAnimToggle())

    ; -- Дополнительно: blurMs --
    SettingsCard(g, panelGeneral, c4x, c4y, cardW, cardH, "Дополнительно")
    rowY := c4y + 56
    panelGeneral.Push(g.Add("Text", "x" (c4x + pad) " y" rowY " w190 h20", "Проверка потери фокуса (мс)"))
    ui.blurMs := SettingsMk(panelGeneral, g.Add("Edit", "-E0x200 Background252A31 x" (c4x + 212) " y" (rowY - 3) " w56 h28 Number Limit5", String(blurMs)))
    g.SetFont("c9A9CA3")
    panelGeneral.Push(g.Add("Text", "x" (c4x + pad) " y" (rowY + 38) " w" (cardW - 2 * pad) " h48",
        "Интервал опроса, используется только для скрытия окна, когда фокус ушёл (hideOnBlur)."))
    g.SetFont("cEDEDEF")

    ; ==================== Slots ====================
    g.SetFont("s13 bold")
    panelSlots.Push(g.Add("Text", "x" contentX " y16 w780 h24", "Слоты Drawer"))
    g.SetFont("s9 norm c9A9CA3")
    panelSlots.Push(g.Add("Text", "x" contentX " y42 w780 h18", "Настройте слоты для приложений и горячие клавиши."))
    g.SetFont("cEDEDEF")

    listX := contentX, listY := 72, listW := 358, listH := 536
    detailX := listX + listW + 18, detailY := 72, detailW := 404, detailH := 536

    ; Список — свой, не системный ListView: белый native-контрол на тёмном
    ; окне не спрятать ни SetWindowTheme, ни LVM_SETBKCOLOR целиком —
    ; системные полосы прокрутки и выделение остаются светлыми/синими.
    ; Девять фиксированных строк (их ровно девять всегда, SettingsRows()
    ; это гарантирует) проще и надёжнее нарисовать самим — тем же приёмом,
    ; что уже держит карточки и левый навигатор: залитые Text-контролы,
    ; свои клики, подсветка выбранной строки своим акцентом.
    listBg := g.Add("Text", "x" listX " y" listY " w" listW " h" listH " Background1E2025", "")
    panelSlots.Push(listBg)
    SettingsRound(listBg, listW, listH, 10)

    rowH := 44
    ui.slotRow := []
    Loop 9 {
        n := A_Index
        rowY := listY + (n - 1) * rowH

        bg := SettingsMk(panelSlots, g.Add("Text", "x" (listX + 1) " y" rowY " w" (listW - 2) " h" rowH " Background1E2025", ""))

        avatar := SettingsMk(panelSlots, g.Add("Text", "x" (listX + 13) " y" (rowY + 8) " w28 h28 Background333640 Center", String(n)))
        SettingsRound(avatar, 28, 28, 10)
        ; Поверх номера — картинка иконки, когда её удаётся достать
        ; (SettingsSlotRowPaint); номер под ней остаётся видимым запасным
        ; вариантом для слотов без запущенного/привязанного окна.
        icon := SettingsMk(panelSlots, g.Add("Picture", "x" (listX + 17) " y" (rowY + 12) " w20 h20 Hidden", ""))

        nameX := listX + 13 + 28 + 11
        pillW := 84
        pillX := listX + listW - 13 - pillW
        name := SettingsMk(panelSlots, g.Add("Text", "x" nameX " y" (rowY + 7) " w" (pillX - nameX - 8) " h16", ""))

        dot := SettingsMk(panelSlots, g.Add("Text", "x" nameX " y" (rowY + 27) " w6 h6 Background5FB37C", ""))

        g.SetFont("s8 c9A9CA3")
        meta := SettingsMk(panelSlots, g.Add("Text", "x" (nameX + 11) " y" (rowY + 24) " w" (listX + listW - 13 - nameX - 11) " h16", ""))
        g.SetFont("s9 cEDEDEF")

        g.SetFont("s8 bold")
        pill := SettingsMk(panelSlots, g.Add("Text", "x" pillX " y" (rowY + 8) " w" pillW " h16 Center", ""))
        SettingsRound(pill, pillW, 16, 8)
        g.SetFont("s9 norm cEDEDEF")

        if (n < 9)
            SettingsMk(panelSlots, g.Add("Text", "x" (listX + 13) " y" (rowY + rowH - 1) " w" (listW - 26) " h1 Background2A2C33", ""))

        ui.slotRow.Push({ bg: bg, avatar: avatar, icon: icon, iconPath: "", iconHwnd: 0,
                          name: name, dot: dot, meta: meta, pill: pill })
        for c in [bg, avatar, icon, name, dot, meta, pill]
            c.OnEvent("Click", SettingsSlotRowSelect.Bind(ui, n))
    }
    ui.slotsRows := SettingsRows()
    ui.edits := Map(), ui.populating := false, ui.editingSlot := 0, ui.selectedSlot := 0

    box := SettingsCard(g, panelSlots, detailX, detailY, detailW, detailH, "Слот")
    box.Move(, , detailW - 190 - 14 - pad - 10)   ; не залезать под кнопку справа
    ui.convert := SettingsMk(panelSlots,
        g.Add("Button", "+0x8000 x" (detailX + detailW - 190 - 14) " y" (detailY + 8) " w190 h26", "Сделать постоянным…"))
    ui.convert.OnEvent("Click", (*) => SettingsConvertClick(ui))
    panelSlots.Push(g.Add("Text", "x" (detailX + pad) " y" (detailY + 38) " w" (detailW - 2 * pad) " h1 Background2A2C33", ""))

    fx := detailX + pad, fLabelW := 130, fValX := fx + fLabelW + 8

    ; Подписи редактируемой сетки (постоянный слот) — те же девять строк,
    ; что и у ui.eName/eExe/…/eFocus ниже; показываются только вместе с
    ; ними (уходят в ui.editCtl), иначе на местах убранных из read-only
    ; class/hideOnBlur подписи висели бы без контрола рядом.
    editLabels := []
    for i, key in SettingsFields() {
        y := detailY + 44 + (i - 1) * 30
        editLabels.Push(SettingsMk(panelSlots, g.Add("Text", "x" fx " y" y " w" fLabelW " h18", SettingsFieldLabel(key))))
    }

    ; Панель «только чтение» (динамический слот) — короче редактируемой
    ; (см. SettingsReadOnlyFields) и со своими подписями/значениями
    ; (SettingsDisplayVal/SettingsSrc), а не сырыми config-значениями.
    roLabels := [], valc := [], srcc := []
    for i, key in SettingsReadOnlyFields() {
        y := detailY + 44 + (i - 1) * 30
        roLabels.Push(SettingsMk(panelSlots, g.Add("Text", "x" fx " y" y " w" fLabelW " h18", SettingsFieldLabel(key))))
        valc.Push(SettingsMk(panelSlots, g.Add("Text", "x" fValX " y" y " w100 h18", "")))
        g.SetFont("c9A9CA3")
        srcc.Push(SettingsMk(panelSlots, g.Add("Text", "x" (fValX + 108) " y" y " w118 h18", "")))
        g.SetFont("cEDEDEF")
    }
    ui.box := box, ui.valc := valc, ui.srcc := srcc
    ui.roCtl := []
    for c in roLabels
        ui.roCtl.Push(c)
    for c in valc
        ui.roCtl.Push(c)
    for c in srcc
        ui.roCtl.Push(c)

    ; Плашка под динамическим слотом: поясняет, что он свободен и живёт
    ; общими настройками General, а не выдумывает новую настройку —
    ; ровно то же самое давно показывает панель «Слот», просто раньше без
    ; единого места, куда за этими настройками пойти.
    freeNoteY := detailY + 44 + SettingsReadOnlyFields().Length * 30 + 22
    ui.freeNote := SettingsMk(panelSlots, g.Add("Text", "x" fx " y" freeNoteY " w" (detailW - 2 * pad) " h64",
          "Слот свободен и использует общие настройки динамических слотов "
        . "(вкладка General). Сделайте его постоянным, чтобы задать своё "
        . "приложение и хоткей."))
    SettingsRound(ui.freeNote, detailW - 2 * pad, 64, 10)

    ; Те же девять полей, редактируемые — поверх valc/srcc, видны только
    ; когда выбранный слот постоянный (или готовится им стать). yExe,
    ; yCls и yFocus — те же y, что и у полей exe/cls/focusHotkey в цикле
    ; выше (i=2,3,9), чтобы кнопки и пояснение встали в свои строки.
    yExe := detailY + 44 + (2 - 1) * 30
    yCls := detailY + 44 + (3 - 1) * 30
    yFocus := detailY + 44 + (9 - 1) * 30
    ui.eName  := SettingsMk(panelSlots, g.Add("Edit", "-E0x200 Background252A31 x" fValX " y" (detailY + 44) " w210 h26"))
    ui.eExe   := SettingsMk(panelSlots, g.Add("Edit", "-E0x200 Background252A31 x" fValX " y" yExe " w110 h26"))
    ui.eExeBrowse := SettingsMk(panelSlots, g.Add("Button", "+0x8000 x" (fValX + 116) " y" (yExe - 1) " w52 h26", "Обзор…"))
    ui.eExeWindow := SettingsMk(panelSlots, g.Add("Button", "+0x8000 x" (fValX + 172) " y" (yExe - 1) " w52 h26", "Окно…"))
    ui.eCls   := SettingsMk(panelSlots, g.Add("Edit", "-E0x200 Background252A31 x" fValX " y" yCls " w110 h26"))
    clsInfo := SettingsMk(panelSlots,
        g.Add("Text", "x" (fValX + 116) " y" (yCls + 3) " w20 h20 Background2B2D33 Center", "ⓘ"))
    SettingsRound(clsInfo, 20, 20)
    clsInfo.OnEvent("Click", SettingsClsInfo)
    ui.eMon   := SettingsMk(panelSlots, g.Add("DropDownList", "-E0x200 x" fValX " y" (detailY + 44 + 3 * 30) " w180 h26", SettingsMonItems()))
    ui.eEdge  := SettingsMk(panelSlots, g.Add("DropDownList", "-E0x200 x" fValX " y" (detailY + 44 + 4 * 30) " w180 h26", SettingsEdgeItems()))
    ui.eWidth := SettingsMk(panelSlots, g.Add("Edit", "-E0x200 Background252A31 x" fValX " y" (detailY + 44 + 5 * 30) " w60 h26 Number Limit3"))
    ui.eAct   := SettingsMk(panelSlots, g.Add("CheckBox", "x" fValX " y" (detailY + 44 + 6 * 30 + 3) " w226 h20", "Активировать окно при выезде"))
    ui.eBlur  := SettingsMk(panelSlots, g.Add("CheckBox", "x" fValX " y" (detailY + 44 + 7 * 30 + 3) " w226 h20", "Убирать окно, когда фокус ушёл"))
    ui.eFocus := SettingsMk(panelSlots, g.Add("Edit", "-E0x200 Background252A31 x" fValX " y" yFocus " w160 h26"))
    g.SetFont("s8 c9A9CA3")
    focusCaption := SettingsMk(panelSlots, g.Add("Text", "x" fValX " y" (yFocus + 27) " w160 h16", "после перезапуска"))
    g.SetFont("s9 cEDEDEF")

    ui.editCtl := [ui.eName, ui.eExe, ui.eExeBrowse, ui.eExeWindow, ui.eCls, clsInfo,
                   ui.eMon, ui.eEdge, ui.eWidth, ui.eAct, ui.eBlur, ui.eFocus, focusCaption, editLabels*]

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

    Loop 9
        SettingsSlotRowPaint(ui, A_Index)
    SettingsSlotRowSelect(ui, 1)

    ; ==================== About ====================
    g.SetFont("s16 bold")
    panelAbout.Push(g.Add("Text", "x" contentX " y72 w300 h30", "Drawer"))
    g.SetFont("s9 norm c9A9CA3")
    panelAbout.Push(g.Add("Text", "x" (contentX + 90) " y80 w200 h20", "версия " VERSION))
    g.SetFont("cEDEDEF")

    panelAbout.Push(g.Add("Text", "x" contentX " y122 w780 h20", "config.ini"))
    ; ReadOnly-поле Win32 красит белым независимо от SetWindowTheme — в
    ; отличие от обычных Edit выше, тут фон приходится задавать явно.
    panelAbout.Push(SettingsMk(0, g.Add("Edit", "-E0x200 x" contentX " y144 w780 h26 ReadOnly -TabStop Background1E2025", configPath)))

    g.SetFont("c9A9CA3")
    panelAbout.Push(g.Add("Text", "x" contentX " y186 w780 h60",
          "Программа трогает этот файл только тогда, когда вы нажали "
        . "«Применить» или «ОК», и записывает ровно те строки, которые "
        . "вы изменили. Ни закрытие окна, ни выход из программы ничего "
        . "не сохраняют."))
    g.SetFont("cEDEDEF")
    panelAbout.Push(g.Add("Text", "x" contentX " y254 w780 h20", "github.com/nerzar/Drawer  ·  лицензия MIT"))

    g.SetFont("s9 bold")
    panelAbout.Push(g.Add("Text", "x" contentX " y292 w300 h20", "Горячие клавиши"))
    g.SetFont("s9 norm")
    hk := [["Ctrl+Alt+1…9", "Выдвинуть / убрать окно слота"],
           ["Ctrl+Alt+Shift+1…9", "Назначить активное окно слоту"],
           ["Ctrl+Alt+0", "Очистить динамические слоты"],
           ["Ctrl+Alt+Shift+0", "Выход, окна возвращаются на места"]]
    for row in hk {
        y := 320 + (A_Index - 1) * 26
        panelAbout.Push(g.Add("Text", "x" contentX " y" y " w220 h20", row[1]))
        g.SetFont("c9A9CA3")
        panelAbout.Push(g.Add("Text", "x" (contentX + 226) " y" y " w400 h20", row[2]))
        g.SetFont("cEDEDEF")
    }

    ; ==================== подвал: всегда виден ====================
    ; Строка состояния — единственное место, где окно говорит об ошибке
    ; записи. TrayTip для этого не годится: уведомления пересчитывает
    ; набор quiet, и новые ломают его.
    footerY := 624
    ui.status := SettingsMk(0, g.Add("Text", "x" contentX " y" footerY " w460 h20", ""))
    btnY := footerY + 30
    ui.cancel := SettingsMk(0, g.Add("Button", "+0x8000 x748 y" btnY " w92 h32", "Отмена"))
    ui.apply  := SettingsMk(0, g.Add("Button", "+0x8000 x846 y" btnY " w92 h32", "Применить"))
    ui.ok     := SettingsMk(0, g.Add("Button", "+0x8000 x944 y" btnY " w92 h32 Default", "ОК"))
    ui.ok.OnEvent("Click",     (*) => SettingsSave(true))
    ui.apply.OnEvent("Click",  (*) => SettingsSave(false))
    ui.cancel.OnEvent("Click", (*) => SettingsClose())
    g.OnEvent("Close",  (*) => SettingsClose())
    g.OnEvent("Escape", (*) => SettingsClose())

    ui.panels := [panelGeneral, panelSlots, panelAbout]
    SettingsNavClick(ui, 1)

    ; Окно объявляется своим ДО показа: иначе первый же его кадр успел бы
    ; стать передним планом обычного окна и увести за собой hideOnBlur.
    setUI  := ui
    SettingsRebase()
    setGui := g
    ServiceWindowAdd(g.Hwnd)
    g.Show("w1060 h720")
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
    ui := setUI
    setGui := 0        ; сначала забыть, потом рушить: IsServiceWindow не
    setUI  := 0        ; должен спрашивать у уже разрушенного окна
    if g
        ServiceWindowDrop(g.Hwnd)
    SetTimer(SettingsSlotsTick, 0)   ; иначе таймер живой колонки переживёт закрытие
    if ui {
        for row in ui.slotRow
            if row.iconHwnd
                try DllCall("DestroyIcon", "Ptr", row.iconHwnd)
    }
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

; validate/plan для General: семантический вход (не GUI controls, не setUI),
; сравнение с текущим runtime и точечная запись — тот же семантический DTO,
; которым позже сможет пользоваться WebView-порт (см.
; spikes/webview2-settings/docs/settings-integration-layer.md,
; DrawerSettingsPort.Save). Без side effects: ни IniWrite, ни LoadConfig.
SettingsGeneralPlan(input, &err) {
    err := ""
    w := SettingsNum(input.width, 5, 100, "Размер окна", &err)
    ; «Без анимации» меняет только число шагов: при нуле шагов
    ; длительность ни на что не влияет, и трогать её незачем.
    ms := input.noAnim ? 0
        : SettingsNum(input.animMs, 0, 5000, "Длительность анимации", &err)
    steps := SettingsNum(input.animSteps, 0, 200, "Шагов анимации", &err)
    b := SettingsNum(input.blurMs, 10, 60000, "Проверка потери фокуса", &err)
    if (err != "")
        return 0

    cand := []
    if (input.edge != "")
        cand.Push({ sec: "dynamic", key: "edge", val: input.edge })
    if (input.monitor != "")
        cand.Push({ sec: "dynamic", key: "monitor", val: input.monitor })
    cand.Push({ sec: "dynamic", key: "width",          val: String(w) })
    cand.Push({ sec: "dynamic", key: "activateOnShow", val: input.activateOnShow ? "true" : "false" })
    cand.Push({ sec: "dynamic", key: "hideOnBlur",     val: input.hideOnBlur ? "true" : "false" })
    cand.Push({ sec: "general", key: "handles",        val: input.handlesEnabled ? "true" : "false" })
    if !input.noAnim
        cand.Push({ sec: "general", key: "animMs",     val: String(ms) })
    cand.Push({ sec: "general", key: "animSteps",      val: String(steps) })
    cand.Push({ sec: "general", key: "blurMs",         val: String(b) })
    cand.Push({ sec: "general", key: "accent",         val: input.accent })

    out := []
    for c in cand {
        if (SettingsLive(c.sec, c.key) = c.val)
            continue
        out.Push(c)
    }
    return out
}

; UI-adapter: только читает setUI и переводит DropDownList в смысловые
; значения. Валидацию и сравнение с runtime делает SettingsGeneralPlan —
; backend-seam controls/GUI не видит.
SettingsCollect(&err) {
    global setUI
    err := ""
    if !(ui := setUI)
        return 0
    input := {
        width: ui.width.Value,
        edge: SettingsEdgeVal(ui.edge),
        monitor: SettingsMonVal(ui.mon),
        activateOnShow: ui.act.Value,
        hideOnBlur: ui.blur.Value,
        handlesEnabled: ui.handles.Value,
        noAnim: (ui.anim.Value = 1),
        animMs: ui.animMs.Value,
        animSteps: ui.animSteps.Value,
        blurMs: ui.blurMs.Value,
        accent: ui.accentVal
    }
    return SettingsGeneralPlan(input, &err)
}

; Чем программа пользуется прямо сейчас. Сравнивать надо именно с этим,
; а не с содержимым файла: тогда ключ, которого в файле нет и который не
; меняли, остаётся ненаписанным сам собой — умолчания живут в
; LoadConfig, и дублировать их здесь не приходится.
SettingsLive(sec, key) {
    global dynamic, animMs, animSteps, blurMs, handlesOn, HANDLE_BG
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
    case "accent":    return HANDLE_BG
    }
    return ""
}

; -------------------------- ЗАПИСЬ [slotN] -------------------------
; То же правило точечной записи, что и SettingsLive(), — только для
; постоянного слота: если слот сейчас не постоянный или у него нет этого
; поля, сравнивать не с чем, и значение считается новым безусловно.
SettingsLiveSlot(n, key) {
    global permSlots
    if !permSlots.Has(n)
        return ""
    cfg := PermApp(n)
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

; validate/plan для Slots: тот же семантический вход/выход, каким сможет
; пользоваться WebView-порт (slotEdits DTO) — Map номер слота -> правка,
; без обращения к setUI. Внутри переиспользует существующие
; SettingsSlotValidate/SettingsSlotWrites. Та же дисциплина, что у
; SettingsGeneralPlan(): первая ошибка отменяет весь план, наполовину не
; пишем. Плюс read-only снимок текущих identity/bindings — он нужен
; SettingsReconcileRuntime() уже ПОСЛЕ диска, а не для записи здесь.
SettingsSlotsPlan(edits, &err) {
    global apps, managed
    err := ""
    writes := [], deletes := [], touched := Map()
    if edits {
        for n, e in edits {
            if (e.kind = "dyn") {
                deletes.Push(n)
                touched[n] := true
                continue
            }
            got := SettingsSlotWrites(n, e, &err)
            if (err != "")
                return { writes: [], deletes: [], touched: Map(), oldBySlot: Map(), oldIdent: Map() }
            for w in got
                writes.Push(w)
            touched[n] := true
        }
    }
    ; Снимок берём независимо от того, есть ли правки слотов вообще:
    ; General-only Save тоже проходит через reconciliation (ниже), и без
    ; этого снимка она обнулила бы managed вместо того, чтобы оставить
    ; его как есть.
    oldBySlot := Map(), oldIdent := Map()
    for a in apps {
        if managed.Has(a.slot)
            oldBySlot[a.slot] := managed[a.slot]
        oldIdent[a.slot] := { exe: a.exe, cls: a.cls }
    }
    return { writes: writes, deletes: deletes, touched: touched,
             oldBySlot: oldBySlot, oldIdent: oldIdent }
}

; UI-adapter: тонкая обёртка над буфером setUI.edits.
SettingsSlotsCollect(&err) {
    global setUI
    err := ""
    return SettingsSlotsPlan(setUI ? setUI.edits : 0, &err)
}

; -------- ОБЩИЙ SEAM: persistence+verify -> runtime reconciliation --------
; Три стадии из ADR (settings-integration-layer.md): validate/plan уже
; сделаны выше (SettingsGeneralPlan/SettingsSlotsPlan) и не имеют side
; effects; дальше — только диск (эта функция) и, отдельно, только runtime
; (следующая). Ни эта функция, ни её вызывающая сторона не знают про
; GUI-controls: вход — уже готовые списки {sec,key,val} и slotPlan.

; Секция удалена, если повторное чтение подтверждает её отсутствие.
; IniDelete(Filename, Section) без Key стирает секцию целиком; IniRead с
; Default вместо Key возвращает список оставшихся ключей или сам Default,
; если секции нет, — без исключения в обоих случаях. Специально НЕ читаем
; через голое "throws if absent" (IniRead(path, sec) без Default): тогда
; любое исключение при чтении — хоть блокировка файла, хоть чужая ошибка —
; неотличимо от «секции нет» и ложно засчиталось бы как подтверждённое
; удаление. Здесь же исключение при самом чтении означает «не смогли
; сверить», а не «удалено», и намеренно возвращает false — сверка не
; прошла, а не наоборот.
SettingsVerifyDeleted(path, sec) {
    try
        return IniRead(path, sec, , "") = ""
    catch
        return false
}

; Провал persistence одной записью: код контракта плюс человеческий
; текст. По коду ветвится клиент (write_failed / verify_failed из
; docs/settings-integration-layer.md), текст native показывает в
; статус-строке. Раньше был только текст, и отличить «не записалось» от
; «записалось не то» можно было лишь разбором русской фразы.
SettingsPersistFail(&outcome, code, msg) {
    outcome.ok := false
    outcome.code := code
    outcome.err := msg
}

; Сверка одного записанного ключа. Чтение при сверке тоже может не
; удаться — файл занят другим процессом, — и это «не смогли сверить», а
; не «в файле пусто»: без отдельной ветки такой сбой попадал бы в текст
; как «в файле «»» и выглядел бы расхождением значений. Наружу в обоих
; случаях verify_failed: записанному нельзя верить, пока не прочитано.
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

; Только диск: пишет, удаляет и сверяет General и Slots одним проходом.
; Не вызывает Release()/LoadConfig() ни при успехе, ни при ошибке — про
; runtime знает только SettingsReconcileRuntime(), и только после того,
; как эта функция полностью отработала (успешно или нет).
;
; mayHavePersisted означает ровно одно: хотя бы одна дисковая операция
; ЗАВЕРШИЛАСЬ. Бросившая исключение IniWrite/IniDelete файл не меняет,
; поэтому флаг в catch не поднимается — иначе первый же неудавшийся
; write запускал бы реконсиляцию неизменённого файла и объявлял рантайм
; перечитанным там, где его вообще не трогали.
SettingsPersistVerified(generalWrites, slotPlan, &outcome) {
    global configPath
    outcome := { ok: true, code: "", err: "", mayHavePersisted: false }

    gDone := 0
    for v in generalWrites {
        try
            IniWrite(v.val, configPath, v.sec, v.key)
        catch as e {
            SettingsPersistFail(&outcome, "write_failed",
                "Не записалось: [" v.sec "] " v.key " — " e.Message
              . (gDone ? ".  До сбоя записано строк: " gDone : ""))
            return
        }
        gDone++
        outcome.mayHavePersisted := true
    }
    for v in generalWrites {
        detail := ""
        if !SettingsVerifyValue(configPath, v.sec, v.key, v.val, &detail) {
            SettingsPersistFail(&outcome, "verify_failed",
                "Проверка не прошла: [" v.sec "] " v.key detail)
            return
        }
    }

    delSet := Map()
    for n in slotPlan.deletes
        delSet[n] := true

    for n in slotPlan.deletes {
        try
            IniDelete(configPath, "slot" n)
        catch as e {
            SettingsPersistFail(&outcome, "write_failed",
                "Не удалить [slot" n "]: " e.Message)
            return
        }
        outcome.mayHavePersisted := true
    }
    for n in slotPlan.deletes {
        if !SettingsVerifyDeleted(configPath, "slot" n) {
            SettingsPersistFail(&outcome, "verify_failed",
                "Проверка не прошла: [slot" n "] не удалился")
            return
        }
    }
    ; Секция [dynamicSlotN] у слота, ставшего постоянным, ни на что не
    ; влияет, но LoadConfig сообщает о ней при каждом старте. Раньше её
    ; удаление шло голым try и молча глотало отказ — единственная
    ; дисковая операция Save без сверки. Сначала читаем: если секции нет,
    ; файл не трогаем вовсе, иначе IniDelete по заведомо отсутствующей
    ; секции поднимал бы mayHavePersisted на каждом Save со слотами.
    for n in slotPlan.touched {
        if delSet.Has(n)
            continue
        if SettingsVerifyDeleted(configPath, "dynamicSlot" n)
            continue
        try
            IniDelete(configPath, "dynamicSlot" n)
        catch as e {
            SettingsPersistFail(&outcome, "write_failed",
                "Не удалить [dynamicSlot" n "]: " e.Message)
            return
        }
        outcome.mayHavePersisted := true
        if !SettingsVerifyDeleted(configPath, "dynamicSlot" n) {
            SettingsPersistFail(&outcome, "verify_failed",
                "Проверка не прошла: [dynamicSlot" n "] не удалился")
            return
        }
    }

    sDone := 0
    for w in slotPlan.writes {
        try
            IniWrite(w.val, configPath, w.sec, w.key)
        catch as e {
            SettingsPersistFail(&outcome, "write_failed",
                "Не записалось: [" w.sec "] " w.key " — " e.Message
              . (sDone ? ".  До сбоя записано строк: " sDone : ""))
            return
        }
        sDone++
        outcome.mayHavePersisted := true
    }
    for w in slotPlan.writes {
        detail := ""
        if !SettingsVerifyValue(configPath, w.sec, w.key, w.val, &detail) {
            SettingsPersistFail(&outcome, "verify_failed",
                "Проверка не прошла: [" w.sec "] " w.key detail)
            return
        }
    }
}

; Только runtime, только после SettingsPersistVerified — при полном
; успехе и при partial failure одинаково (best-effort отражение того, что
; фактически осталось в config.ini). Release() живёт только здесь:
;
;  - слот, теряющий постоянную привязку или меняющий exe/cls, не должен
;    остаться без хозяина: Release() возвращает окно на исходное место,
;    как при выходе и Ctrl+Alt+0 — и то же самое окно никогда не
;    трогается, если его exe/cls не изменились;
;  - динамическая привязка номера, который правил пользователь, снимается
;    явно: постоянный и динамический не бывают одним слотом одновременно;
;  - managed ключуется НОМЕРОМ СЛОТА, а не индексом в apps[]: добавление
;    или удаление [slotN] сдвигает индексы соседних постоянных слотов, а
;    номер слота такого сдвига не знает. permSlots пересобирается здесь же
;    и дальше LoadConfig не живёт;
;  - snapshot oldBySlot/oldIdent берётся из slotPlan, то есть сделан ДО
;    любой дисковой операции — а не после, как было бы багом;
;  - dynSlots для тронутых номеров освобождается только если ФАКТИЧЕСКИ
;    перезагруженный config.ini подтверждает переход в постоянные
;    (permSlots.Has(n) уже после LoadConfig), а не по одному намерению
;    правки: если запись слота n не долетела до диска (partial failure),
;    слот n остаётся динамическим и на диске, и в рантайме — отпускать
;    в этом случае активную привязку было бы неверно.
SettingsReconcileRuntime(slotPlan) {
    global configPath, apps, managed, permSlots, dynSlots, dynamicSlots
    global animMs, animSteps, blurMs, handlesOn, dynamic, HANDLE_BG, HANDLE_BG_HOT

    LoadConfig(configPath, &apps, &dynamic, &dynamicSlots,
               &animMs, &animSteps, &blurMs, &handlesOn, &HANDLE_BG)
    try
        HANDLE_BG_HOT := HandleLighten(HANDLE_BG, 0.10)
    catch
        HANDLE_BG_HOT := "3A414D"
    HandleRepaintAll()

    permSlots.Clear()
    for i, a in apps
        permSlots[a.slot] := i

    for n in slotPlan.touched {
        if (dynSlots.Has(n) && permSlots.Has(n)) {
            Release(dynSlots[n])
            dynSlots.Delete(n)
        }
    }

    managed.Clear()
    oldBySlot := slotPlan.oldBySlot
    for a in apps {
        if !oldBySlot.Has(a.slot)
            continue
        ident := slotPlan.oldIdent[a.slot]
        if (ident.exe = a.exe && ident.cls = a.cls)
            managed[a.slot] := oldBySlot[a.slot]
        else
            Release(oldBySlot[a.slot])
        oldBySlot.Delete(a.slot)
    }
    for n, hwnd in oldBySlot     ; слот больше не тот же постоянный — окно домой
        Release(hwnd)

    SetTimer(HandlesSync, -1)
}

; Копия поведения слота одним объектом. Снимок обязан пережить
; следующий LoadConfig: dynamic и dynamicSlots заменяются целиком, а
; SlotCfg() для слота без собственной секции возвращает сам объект
; dynamic — отдать его наружу значило бы отдать ссылку на живой глобал.
SettingsBehaviorCopy(cfg) {
    return { name:           Opt(cfg, "name", ""),
             monitor:        Opt(cfg, "monitor", ""),
             edge:           Opt(cfg, "edge", ""),
             width:          Opt(cfg, "width", ""),
             activateOnShow: Opt(cfg, "activateOnShow", true),
             hideOnBlur:     Opt(cfg, "hideOnBlur", true) }
}

; Канонический снимок ПРИМЕНЁННОГО состояния: то, чем программа
; пользуется прямо сейчас, а не то, что набрано в форме. Отвечает на
; единственный вопрос клиента после частичной записи — «что в итоге
; действует», — и потому включает живой статус слота (C3), а не только
; конфиг. Имена полей внутренние (exe/cls/width, monitor строкой):
; перевод в имена wire (executable/windowClass/widthPercent, MonitorRef)
; — работа порта, здесь ей не место.
SettingsStateSnapshot() {
    global dynamic, animMs, animSteps, blurMs, handlesOn, HANDLE_BG
    slots := []
    Loop 9 {
        n := A_Index
        if (a := PermApp(n))
            slots.Push({ n: n, kind: "perm", status: SlotStatus(n),
                         cfg: { name: a.name, exe: a.exe, cls: a.cls,
                                monitor: a.monitor, edge: a.edge,
                                width: a.width,
                                activateOnShow: a.activateOnShow,
                                hideOnBlur: a.hideOnBlur,
                                focusHotkey: Opt(a, "focusHotkey", "") } })
        else
            slots.Push({ n: n, kind: "dyn", status: SlotStatus(n),
                         cfg: SettingsBehaviorCopy(SlotCfg(n)) })
    }
    return { general: { dynamicDefaults: SettingsBehaviorCopy(dynamic),
                        handlesEnabled: handlesOn, animMs: animMs,
                        animSteps: animSteps, blurMs: blurMs,
                        accent: HANDLE_BG },
             slots: slots }
}

; Номера слотов, которых Save действительно коснулся: и переписанные
; [slotN], и удалённые. changedWrites считает поля, этот список — слоты;
; в контракте это changedSlots. Порядок возрастающий и без повторов:
; у одного слота обычно несколько изменённых ключей.
SettingsChangedSlots(slotPlan) {
    seen := Map()
    for w in slotPlan.writes
        seen[Integer(SubStr(w.sec, 5))] := true
    for n in slotPlan.deletes
        seen[n] := true
    out := []
    Loop 9
        if seen.Has(A_Index)
            out.Push(A_Index)
    return out
}

; Слоты, у которых изменился focusHotkey. Хоткеи регистрируются один раз
; при старте (см. цикл по apps в начале файла), и Save их не
; переставляет — это принятое поведение C1, а не недоделка. Контракт
; называет этот список restartRequiredFields; текст native статус-строки
; C4 не меняет, поле нужно клиенту порта.
SettingsRestartRequired(slotPlan) {
    out := []
    for w in slotPlan.writes
        if (w.key = "focusHotkey")
            out.Push(Integer(SubStr(w.sec, 5)))
    return out
}

; Строгая последовательность validate/plan (уже выполнен вызывающей
; стороной) -> persistence+verify -> runtime reconciliation. Единственная
; точка, которая решает, нужна ли реконсиляция: она нужна, если диск хоть
; немного тронут, — успешно или нет. Native Settings — первый клиент;
; DrawerSettingsPort (WebView) станет вторым клиентом этой же функции, не
; получая при этом ни setUI, ни HWND, ни INI-секции напрямую.
;
; Outcome — полный контракт Save, а не «сохранилось/не сохранилось»:
;
;  - code пуст ровно тогда, когда ошибки нет; saved отличает успех от
;    no-op. Клиент ветвится по code, человек читает err;
;  - mayHavePersisted говорит, что файл уже изменён и rollback не
;    обещан; runtimeReloaded — что рантайм после этого перечитан;
;  - state отдаётся ТОЛЬКО при runtimeReloaded: иначе про применённое
;    состояние ничего не известно и снимок был бы выдумкой;
;  - retryable запрещён только там, где диск тронут, а перечитать его не
;    вышло. Если диска не касались вовсе, рантайм остался каноническим,
;    и повтор безопасен независимо от кода ошибки.
;
; Исключения наружу не выходят: единственный вызывающий — GUI-колбэк
; Apply/OK, и вылет из него уронил бы не Save, а всё окно настроек.
SettingsApplyPlan(generalWrites, slotPlan, &outcome) {
    hasSlotWork := slotPlan.writes.Length || slotPlan.deletes.Length
    outcome := { saved: false, code: "", err: "", retryable: false,
                 changedWrites: 0, changedDeletes: 0,
                 changedSlots: [], restartRequired: [],
                 mayHavePersisted: false, runtimeReloaded: false, state: 0 }
    if (!generalWrites.Length && !hasSlotWork)
        return

    persist := "", reloadErr := ""
    try
        SettingsPersistVerified(generalWrites, slotPlan, &persist)
    catch as e
        ; Ошибки диска persistence ловит сама; сюда попадает только
        ; неожиданное. Худшее предположение — файл тронут: реконсиляция
        ; ниже прочитает, что там на самом деле.
        persist := { ok: false, code: "internal_error", mayHavePersisted: true,
                     err: "Сбой записи настроек: " e.Message }
    outcome.mayHavePersisted := persist.mayHavePersisted

    if persist.mayHavePersisted {
        try {
            SettingsReconcileRuntime(slotPlan)
            outcome.runtimeReloaded := true
        } catch as e
            reloadErr := e.Message
    }
    if outcome.runtimeReloaded
        outcome.state := SettingsStateSnapshot()

    if !persist.ok {
        outcome.code := persist.code
        outcome.err := persist.err
        outcome.retryable := !outcome.mayHavePersisted || outcome.runtimeReloaded
        return
    }
    if (reloadErr != "") {
        ; Диск записан и сверен, но перечитать не удалось. Успехом это
        ; называть нельзя: про рантайм больше ничего не известно, а
        ; повтор Save пошёл бы поверх состояния, которого никто не видел.
        outcome.code := "internal_error"
        outcome.err := "Настройки записаны, но перечитать конфиг не удалось: " reloadErr
        return
    }
    outcome.saved := true
    outcome.changedWrites := generalWrites.Length + slotPlan.writes.Length
    outcome.changedDeletes := slotPlan.deletes.Length
    outcome.changedSlots := SettingsChangedSlots(slotPlan)
    outcome.restartRequired := SettingsRestartRequired(slotPlan)
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
       . ui.blurMs.Value "|" ui.accentVal
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

; Применить: собрать план (validate/plan), отдать его общему seam
; (persistence+verify -> runtime reconciliation) и обновить только native
; UI по результату. Сам порядок стадий и Release() внутри — забота
; SettingsApplyPlan()/SettingsReconcileRuntime(), не этой функции.
SettingsSave(closeAfter) {
    global setUI
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

    outcome := ""
    SettingsApplyPlan(vals, slotPlan, &outcome)

    ; Провал — это непустой code, а не непустой текст: текст остаётся
    ; человеческим сообщением и в статус-строке, и на wire.
    if (outcome.code != "") {
        SettingsStatus(outcome.err, true)
        return
    }
    if !outcome.saved {
        SettingsRebase()
        SettingsStatus("Менять нечего: всё уже так")
        if closeAfter
            SettingsClose(true)
        return
    }

    if hasSlotWork {
        setUI.edits := Map()
        SettingsSlotsRefreshAll(setUI)
    }

    SettingsRebase()
    SettingsStatus("Сохранено. Изменённых строк: " outcome.changedWrites
                 . (outcome.changedDeletes ? ", удалено секций: " outcome.changedDeletes : ""))
    if closeAfter
        SettingsClose(true)
}
