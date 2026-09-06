; ============================== СЛОТЫ ==============================
; Slot — центральная runtime-сущность ящика и единственный источник
; истины о том, чем слот является прямо сейчас.
;
; До этого модуля состояние одного слота было размазано по четырём
; параллельным структурам: apps[] (конфигурация постоянных), permSlots
; (номер -> индекс в apps), managed (номер -> захваченное окно) и
; dynSlots (номер -> привязанное окно), плюс dynamicSlots с надстройками.
; Любой ответ на вопрос «что такое слот 3» приходилось собирать из всех
; сразу, и они могли разойтись: индекс в apps сдвигался при появлении
; постоянного слота с меньшим номером, а managed и dynSlots описывали
; один и тот же номер по-разному.
;
; Здесь у слота одна запись и одна идентичность — его НОМЕР. Номер
; переживает перечитывание config.ini, потому что он и есть имя секции
; ([slot3], [dynamicSlot3]) и часть хоткея. Позиции в массивах больше
; нет нигде.
;
; Два lifecycle одного Slot:
;
;   permanent  perm != 0. Конфигурация живёт в config.ini и переживает
;              перезапуск; окно ищется по exe и необязательному cls.
;              window здесь — КЭШ найденного окна: его можно потерять и
;              найти заново, ничего не сломав.
;   dynamic    perm = 0. Конфигурация — общая [dynamic] плюс
;              необязательная надстройка [dynamicSlotN]; window — сама
;              ПРИВЯЗКА, сделанная пользователем в этой сессии и после
;              перезапуска не восстанавливаемая.
;
; Поэтому одно поле window, а не два: слот не бывает обоих родов
; одновременно, и вопрос «какое окно у слота» имеет ровно один ответ.
; Различается не хранение, а разрешение: у постоянного пустой window
; означает «поискать по exe», у динамического — «слот пуст».
;
; Границы модуля:
;
;   вниз  — оконная модель drawer.ahk (state/watched/геометрия): Release,
;           FindWindow, ToggleWindow, FocusWindow, PickActive и предикаты
;           WindowManaged/WindowParked. Слоты знают, КАКОЕ окно
;           принадлежит слоту; что с окном делать — знает оконная модель.
;   вверх — хоткеи, кромки, Settings и WebView-порт зовут функции этого
;           файла и НЕ трогают Slots.byNum. Реестр — не общий словарь.
;
; config.ini остаётся единственным постоянным хранилищем: реестр — это
; проекция файла плюс привязки текущей сессии, а не второе хранилище.
; Лимит 1…9 сохраняется (Slots.COUNT).

; Одна запись реестра. Пустых полей нет: слот существует всегда, даже
; когда он динамический, ничем не занят и в config.ini о нём ни строки.
class Slot {
    n        := 0    ; 1…9 — идентичность слота
    perm     := 0    ; конфигурация [slotN]; 0 — слот динамический
    override := 0    ; надстройка [dynamicSlotN] или 0
    window   := 0    ; окно слота в этой сессии: кэш у постоянного,
                     ; привязка у динамического
    hotkey   := ""   ; show/hide hotkey, принадлежит номеру, а не lifecycle

    __New(n) {
        this.n := n
    }
}

class Slots {
    static COUNT := 9

    ; Номер -> Slot. Записи заводятся по требованию, поэтому реестр
    ; работоспособен и до первого Apply.
    static byNum := Map()

    ; Общие настройки динамических слотов ([dynamic]). Те же умолчания,
    ; что и в LoadConfig: до первого Apply реестр обязан отвечать
    ; осмысленно, а не пустым объектом.
    static defaults := { name: "Слот", monitor: "cursor", edge: "right",
                         width: 60, activateOnShow: true, hideOnBlur: true }

    ; Слот по номеру. Номер вне 1…9 — не слот: такому вызову
    ; возвращается одноразовая пустая запись, и запись в неё никуда не
    ; попадает. Раньше эту роль играло молчаливое permSlots.Has(n) =
    ; false, из-за которого слот 42 выглядел «динамическим».
    static Get(n) {
        if !IsInteger(n)
            return Slot(0)
        n := Integer(n)
        if (n < 1 || n > Slots.COUNT)
            return Slot(0)
        if !Slots.byNum.Has(n)
            Slots.byNum[n] := Slot(n)
        return Slots.byNum[n]
    }

    ; Снимок постоянных привязок: номер -> окно и номер -> identity
    ; (exe/cls), по которой это окно было захвачено. Settings берёт его
    ; ДО любой дисковой операции и отдаёт обратно в Apply: только так
    ; видно, у какого слота identity изменилась, а у какого нет.
    ;
    ; Окно ищем через SlotWindow(), а не берём голый s.window: у слота,
    ; который ни разу не показывали и не подхватывал SlotsSeedManaged()
    ; (приложение запущено уже ПОСЛЕ старта Drawer и хоткей ещё не
    ; нажимали), кэш пуст, хотя статус в списке честно показывает
    ; "available" — окно есть, просто ящик его ещё не держал. Конверсия
    ; в динамический слот из такого состояния раньше теряла окно: снимок
    ; его попросту не видел, и Apply() было нечего восстанавливать.
    static PermSnapshot() {
        bySlot := Map(), ident := Map()
        Loop Slots.COUNT {
            s := Slots.Get(A_Index)
            if !s.perm
                continue
            if (hwnd := SlotWindow(A_Index))
                bySlot[A_Index] := hwnd
            ident[A_Index] := { exe: s.perm.exe, cls: s.perm.cls }
        }
        return { bySlot: bySlot, ident: ident }
    }

    ; Спроецировать прочитанный config.ini на реестр. Единственное место,
    ; где меняются род слота и его конфигурация, и единственное, кроме
    ; SlotRelease/SlotClearDynamic, где окно возвращается домой.
    ;
    ; prevPerm — снимок постоянных привязок из плана Settings (см.
    ; PermSnapshot). При старте его нет: привязывать ещё нечего.
    ;
    ; Порядок стадий важен и проверяется test/narrow/settings-seam.ahk:
    ;
    ;  1. запоминаем ДИНАМИЧЕСКИЕ привязки этой сессии — только они
    ;     переживают перечитывание файла. Кэш постоянного слота
    ;     пересобирается из снимка целиком, потому что окно, захваченное
    ;     уже после снимка, плану неизвестно;
    ;  2. род и конфигурация каждого слота берутся из файла;
    ;  3. слот, который ПЕРЕЧИТАННЫЙ файл сделал постоянным, отпускает
    ;     свою динамическую привязку: постоянный и динамический не бывают
    ;     одним слотом одновременно. Решает файл, а не намерение правки:
    ;     если запись не долетела до диска, слот остался динамическим, и
    ;     отпускать живую привязку было бы неверно;
    ;  4. постоянные привязки восстанавливаются из снимка. Неизменные
    ;     exe/cls — слот остаётся постоянным с тем же окном. Слот явно
    ;     обращён в динамический (секции [slotN] в перечитанном файле нет)
    ;     — окно остаётся тем же, но уже динамической привязкой: живое
    ;     окно не должно пропадать из-за смены рода. Изменилась identity,
    ;     а слот остался постоянным, — окно возвращается на исходное место:
    ;     это уже не то приложение, которое слот ищет.
    static Apply(cfg, prevPerm := 0) {
        DebugLog("[SLOTS] Slots.Apply starting (" (prevPerm ? "reconcile" : "boot") ")")
        old := prevPerm ? prevPerm : { bySlot: Map(), ident: Map() }

        dynBind := Map()
        Loop Slots.COUNT {
            s := Slots.Get(A_Index)
            dynBind[A_Index] := s.perm ? 0 : s.window
        }

        Slots.defaults := cfg.dynamic
        Loop Slots.COUNT {
            n := A_Index, s := Slots.Get(n)
            s.perm     := cfg.perm.Has(n)      ? cfg.perm[n]      : 0
            s.override := cfg.overrides.Has(n) ? cfg.overrides[n] : 0
            s.hotkey   := cfg.hotkeys.Has(n) ? cfg.hotkeys[n] : "^!" n
            s.window   := 0
        }

        Loop Slots.COUNT {
            n := A_Index
            if (dynBind[n] && Slots.Get(n).perm) {
                DebugLog("[CONVERSION] Slot " n " converted from dynamic to permanent (released dyn hwnd=" dynBind[n] ")")
                Release(dynBind[n])
                dynBind[n] := 0
            }
        }
        Loop Slots.COUNT {
            n := A_Index
            if dynBind[n]
                Slots.Get(n).window := dynBind[n]
        }

        for n, hwnd in old.bySlot {
            s := Slots.Get(n)
            ident := old.ident.Has(n) ? old.ident[n] : 0
            if (s.perm && ident && ident.exe = s.perm.exe && ident.cls = s.perm.cls)
                s.window := hwnd
            ; Слот стал динамическим (явной конверсией через Settings или
            ; удалением [slotN]) — окно не выгоняем домой, а передаём его
            ; той же самой привязкой дальше: пользователь не терял окно,
            ; он поменял только то, как слот его ищет.
            else if !s.perm {
                DebugLog("[CONVERSION] Slot " n " converted from permanent to dynamic (kept hwnd=" hwnd ")")
                s.window := hwnd
            }
            else {
                DebugLog("[CONVERSION] Slot " n " permanent identity changed -> released hwnd=" hwnd)
                Release(hwnd)
            }
        }

        Loop Slots.COUNT {
            n := A_Index, s := Slots.Get(n)
            if s.perm
                DebugLog("[SLOTS] Slot " n " [perm]: name='" s.perm.name "' exe='" s.perm.exe "' cls='" s.perm.cls "' showHideHotkey='" s.hotkey "'")
            else
                DebugLog("[SLOTS] Slot " n " [dyn]: showHideHotkey='" s.hotkey "' override=" (s.override ? "yes" : "no") (s.window ? (" window=" s.window) : ""))
        }
        DebugLog("[SLOTS] Slots.Apply completed")
    }
}

; ---------------------------- ЗАПРОСЫ ----------------------------

; Род слота. Единственный признак: есть ли у слота секция [slotN].
SlotIsPermanent(n) {
    return Slots.Get(n).perm ? true : false
}

; Конфигурация постоянного слота — 0, если слот не постоянный.
; Раньше это был PermApp(n): разрешение номера в позицию массива apps.
; Позиции больше нет, разрешать нечего.
SlotPerm(n) {
    return Slots.Get(n).perm
}

; Надстройка [dynamicSlotN] как она прочитана из файла — 0, если секции
; нет. Отсутствие надстройки и надстройка, повторяющая общие значения, —
; разные вещи: от первого зависит, есть ли что удалять с диска.
SlotOverride(n) {
    return Slots.Get(n).override
}

; Общие настройки динамических слотов ([dynamic]).
SlotDefaults() {
    return Slots.defaults
}

; Настройки динамического слота: общие, поверх которых кладутся
; персональные, если для этого номера они заданы.
SlotCfg(n) {
    d := Slots.defaults
    if !(own := Slots.Get(n).override)
        return d
    return { name:           Opt(own, "name",           d.name),
             monitor:        Opt(own, "monitor",        d.monitor),
             edge:           Opt(own, "edge",           d.edge),
             width:          Opt(own, "width",          d.width),
             activateOnShow: Opt(own, "activateOnShow", d.activateOnShow),
             hideOnBlur:     Opt(own, "hideOnBlur",     d.hideOnBlur) }
}

; Настройки, с которыми ящик покажет ЭТОТ слот, каким бы он ни был.
; Один вопрос — один ответ: вызывающему не нужно знать род слота, чтобы
; спросить его ширину и край.
SlotBehavior(n) {
    s := Slots.Get(n)
    return s.perm ? s.perm : SlotCfg(n)
}

; Постоянные слоты по возрастанию номера. Нужен ровно там, где обход
; идёт по приложениям, а не по номерам: регистрация focus-хоткеев при
; старте. Массив временный — идентичностью служит a.slot, не позиция.
SlotPermList() {
    out := []
    Loop Slots.COUNT
        if (a := Slots.Get(A_Index).perm)
            out.Push(a)
    return out
}

SlotHotkey(n) {
    return Slots.Get(n).hotkey
}

; Окно слота прямо сейчас — 0, если его нет. У постоянного слота пустой
; кэш означает «поискать по exe», и результат НИКУДА НЕ ПИШЕТСЯ: беглый
; взгляд на статус не должен подменять выбор, который иначе сделал бы
; FindWindow() в момент реального нажатия. У динамического пустая
; привязка означает «слот пуст», и искать нечего.
SlotWindow(n) {
    s := Slots.Get(n)
    if (s.window && WinExist("ahk_id " s.window))
        return s.window
    return s.perm ? FindWindow(s.perm) : 0
}

; Захватить окно постоянного слота и запомнить его. В отличие от
; SlotWindow() пишет: припаркованное окно поиском по площади можно
; спутать с другим окном того же приложения.
SlotCapture(n) {
    s := Slots.Get(n)
    if !s.perm
        return 0
    hwnd := (s.window && WinExist("ahk_id " s.window)) ? s.window : FindWindow(s.perm)
    if hwnd {
        if (s.window != hwnd)
            DebugLog("[CAPTURE] Slot " n " [perm] captured hwnd=" hwnd)
        s.window := hwnd
    }
    return hwnd
}

; Каким слотом управляется это окно и с какими настройками.
; Постоянная привязка старше динамической: одно и то же окно можно
; захватить постоянным слотом и, отдельно, привязать к динамическому —
; показывать его тогда нужно так, как велит постоянный слот.
SlotOf(hwnd) {
    if !hwnd
        return 0
    dyn := 0
    Loop Slots.COUNT {
        s := Slots.Get(A_Index)
        if (s.window != hwnd)
            continue
        if s.perm
            return s.perm
        if !dyn
            dyn := A_Index
    }
    return dyn ? SlotCfg(dyn) : 0
}

; Слоты с живым привязанным окном, по возрастанию номера: номер, окно и
; его настройки. Порядок задаёт и порядок кромок в стопке, поэтому
; массив, а не Map. Постоянный слот сюда попадает только захваченным —
; поиска по exe здесь нет: кромка есть у окна, которое ящик уже держит.
SlotBound() {
    out := []
    Loop Slots.COUNT {
        n := A_Index, s := Slots.Get(n)
        if (!s.window || !WinExist("ahk_id " s.window))
            continue
        out.Push({ n: n, hwnd: s.window, cfg: SlotBehavior(n) })
    }
    return out
}

; Состояние слота структурой, а не строкой: { state, title, app, icon }.
; Пять состояний — те же, что в integration-контракте
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
; Признаки те же, на которых стоит остальная программа (WindowManaged /
; WindowParked) — второго источника истины не заводится. Вход — номер
; слота, а не строка списка Settings: этим же API пользуется WebView-порт,
; которому ни строк, ни секций config.ini не показывают. Русские подписи
; живут отдельно, в SettingsStatusText(): разбирать статус обратно из
; локализованного текста не должен никто.
SlotStatus(n) {
    if !(hwnd := SlotWindow(n))
        return { state: SlotIsPermanent(n) ? "applicationNotRunning" : "empty",
                 title: "", app: "", icon: "" }
    title := ""
    try title := WinGetTitle("ahk_id " hwnd)
    app := WindowAppName(hwnd)
    icon := SlotIconUri(hwnd)
    if !WindowManaged(hwnd)
        return { state: "available", title: title, app: app, icon: icon }
    return { state: WindowParked(hwnd) ? "parked" : "shown",
             title: title, app: app, icon: icon }
}

; ---------------------------- ОПЕРАЦИИ ----------------------------
; Общие действия над слотом. Хоткеи, кромка, Settings и WebView-порт
; ходят сюда, а не в оконную модель напрямую: второй реализации
; «показать слот» или «отпустить слот» в программе нет.

; Слот: постоянный ищет своё приложение по процессу, динамический
; управляет запомненным окном. Приложение не запущено или слот пуст —
; показывать нечего, молчим.
ToggleSlot(n) {
    DebugLog("[TOGGLE] ToggleSlot(" n ")")
    s := Slots.Get(n)
    if s.perm {
        if (hwnd := SlotCapture(n))
            ToggleWindow(hwnd, s.perm)
        else
            DebugLog("[TOGGLE] Slot " n " [perm] capture failed (no window)")
        return
    }
    if !s.window {
        DebugLog("[TOGGLE] Slot " n " [dyn] is empty")
        return
    }
    if !WinExist("ahk_id " s.window) {
        hwnd := s.window
        s.window := 0            ; окно закрыли — слот просто освобождается
        DebugLog("[TOGGLE] Slot " n " [dyn] window hwnd=" hwnd " closed -> released")
        Release(hwnd)
        return
    }
    ToggleWindow(s.window, SlotCfg(n))
}

; Вернуть фокус постоянному слоту, показав его при необходимости.
; Хоткей фокуса есть только у постоянного слота: слот, переставший быть
; постоянным, теперь просто ничего не делает.
SlotFocus(n) {
    DebugLog("[FOCUS] SlotFocus(" n ")")
    s := Slots.Get(n)
    if !s.perm {
        DebugLog("[FOCUS] Slot " n " is not permanent")
        return
    }
    if (hwnd := SlotCapture(n))
        FocusWindow(hwnd, s.perm)
    else
        DebugLog("[FOCUS] Slot " n " [perm] capture failed (no window)")
}

; Связать активное подходящее окно с динамическим слотом.
; Возвращает structured result: { ok, code, message, hwnd, title }.
; Единая точка связывания для хоткея и WebView-порта.
SlotBind(n) {
    if (!IsInteger(n) || n < 1 || n > Slots.COUNT) {
        DebugLog("[BIND] Slot " n " rejected: validation_error")
        return { ok: false, code: "validation_error", message: "Номер слота должен быть 1…9", hwnd: 0, title: "" }
    }
    if SettingsPickerState().active {
        DebugLog("[BIND] Slot " n " rejected: busy (picker active)")
        return { ok: false, code: "busy", message: "Открыт picker", hwnd: 0, title: "" }
    }
    s := Slots.Get(n)
    if s.perm {
        DebugLog("[BIND] Slot " n " rejected: slot is permanent (" s.perm.name ")")
        return { ok: false, code: "slot_is_permanent",
                 message: "Слот " n " занят постоянной привязкой: " s.perm.name, hwnd: 0, title: "" }
    }
    if !(hwnd := PickActive()) {
        DebugLog("[BIND] Slot " n " rejected: no eligible active window")
        return { ok: false, code: "no_eligible_active_window",
                 message: "Активное окно не годится для ящика", hwnd: 0, title: "" }
    }
    if (s.window && s.window != hwnd) {
        DebugLog("[BIND] Slot " n " releasing previous window hwnd=" s.window)
        Release(s.window)             ; прежнее окно возвращаем на место
    }
    s.window := hwnd
    ; Dynamic сразу получает ту же оконную геометрию и кромку, что permanent.
    if !WindowManaged(hwnd) {
        st := StateOf(hwnd)
        mi := ResolveMonitorForExisting(SlotCfg(n), hwnd)
        if !st.orig
            st.orig := CaptureOrigin(hwnd, mi)
        st.geom := ComputeGeom(SlotCfg(n), mi)
    }
    SetTimer(HandlesSync, -1)
    title := WinGetTitle("ahk_id " hwnd)
    DebugLog("[BIND] Slot " n " bound to hwnd=" hwnd " ('" title "')")
    return { ok: true, code: "", message: "Слот " n " → " title, hwnd: hwnd, title: title }
}

; Освободить динамический слот: вернуть окно на исходное место, забыть о
; привязке и обновить кромки.
; Единая точка освобождения для хоткея и WebView-порта.
SlotRelease(n) {
    if (!IsInteger(n) || n < 1 || n > Slots.COUNT) {
        DebugLog("[RELEASE] Slot " n " rejected: validation_error")
        return { ok: false, code: "validation_error", message: "Номер слота должен быть 1…9", hwnd: 0 }
    }
    if SettingsPickerState().active {
        DebugLog("[RELEASE] Slot " n " rejected: busy (picker active)")
        return { ok: false, code: "busy", message: "Открыт picker", hwnd: 0 }
    }
    s := Slots.Get(n)
    if s.perm {
        DebugLog("[RELEASE] Slot " n " rejected: slot is permanent")
        return { ok: false, code: "slot_is_permanent",
                 message: "Слот " n " — постоянный, его нельзя освободить", hwnd: 0 }
    }
    if !s.window {
        DebugLog("[RELEASE] Slot " n " rejected: not bound")
        return { ok: false, code: "not_bound",
                 message: "Слот " n " не привязан к окну", hwnd: 0 }
    }
    hwnd := s.window
    s.window := 0
    Release(hwnd)
    SetTimer(HandlesSync, -1)
    DebugLog("[RELEASE] Slot " n " released hwnd=" hwnd)
    return { ok: true, code: "", message: "Слот " n " освобождён", hwnd: hwnd }
}

; Очистка динамических слотов. Постоянные не трогаем — их window это
; кэш захвата, а не пользовательская привязка, — и программа продолжает
; работать: это не выход.
SlotClearDynamic() {
    DebugLog("[RELEASE] SlotClearDynamic: clearing all dynamic slots")
    Loop Slots.COUNT {
        s := Slots.Get(A_Index)
        if (s.perm || !s.window)
            continue
        DebugLog("[RELEASE] Slot " A_Index " cleared hwnd=" s.window)
        Release(s.window)
        s.window := 0
    }
    SetTimer(HandlesSync, -1)
}
