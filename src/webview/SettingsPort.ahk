; ====================== DrawerSettingsPort ======================
; Семантический порт между wire-контрактом и рантаймом (см.
; docs/settings-integration-layer.md, «Публичный AHK port»). Это
; единственное место, которое знает оба словаря сразу: снаружи —
; executable/windowClass/widthPercent/blurCheckMs, внутри — exe/cls/
; width/blurMs, слоты, apps и config.ini. Мост словаря рантайма не
; видит, Vue не видит ни INI-секций, ни HWND. Абсолютный путь к config.ini
; Vue получает только через GetConfigPath/CopyConfigPath — вычислять его
; во frontend нельзя.
;
; Записи здесь нет ни одной строки: Apply строит тот же вход, что и
; native UI-адаптер, и отдаёт его в SettingsGeneralPlan →
; SettingsApplyPlan. Второй persistence не появляется — это условие
; принятого gate, а не стилистика.
;
; Через порт проходит вся вкладка General: те же десять ключей, что
; правит native ([dynamic] width/edge/monitor/activateOnShow/hideOnBlur и
; [general] handles/animMs/animSteps/blurMs/accent), а также существующие
; permanent Slots через SettingsSlotsPlan и общий native picker.
; Bind/release подключаются через SlotBind/SlotRelease к рантайму; conversion отклоняется в slotEdits.

class DrawerSettingsPort {
    static PROTOCOL_VERSION := 1

    __New(owner := 0) {
        this._disposed := false
        this._owner := owner
        this._ownerHwnd := owner ? owner.Hwnd : 0
    }

    PickerBusy() {
        return SettingsPickerState().active
    }

    CancelPicker() {
        if this._ownerHwnd
            SettingsCancelPicker(this._ownerHwnd)
    }

    Pick(kind) {
        if (this._disposed || !this._owner || !WinExist("ahk_id " this._ownerHwnd))
            return SettingsBridgeError("internal_error", "Settings уже закрыт", false)
        result := SettingsRunPicker(kind, this._owner)
        if !result
            return SettingsBridgeOk(Map("selected", JsonB(false)))
        if (kind = "exe")
            return SettingsBridgeOk(Map("selected", JsonB(true), "executable", result))
        return SettingsBridgeOk(Map("selected", JsonB(true), "window",
            Map("title", result.title, "executable", result.exe, "windowClass", result.cls)))
    }

    ; ------------------------- действия -------------------------

    GetInitialState(payload) {
        return SettingsBridgeOk(this.StateDto())
    }

    ; Фактический путь к используемому config.ini. Vue его не вычисляет:
    ; файл выбирает AHK (рядом со скриптом/exe), путь уходит только отсюда.
    GetConfigPath(payload) {
        global configPath
        return SettingsBridgeOk(Map("path", configPath))
    }

    ; Копирование делает host (A_Clipboard), а не browser clipboard:
    ; в WebView2 на него нельзя полагаться. Копируется тот же configPath,
    ; что отдаёт GetConfigPath.
    CopyConfigPath(payload) {
        global configPath
        try
            A_Clipboard := configPath
        catch as e
            return SettingsBridgeError("internal_error", "Не удалось скопировать путь: " e.Message, false)
        return SettingsBridgeOk(Map("path", configPath))
    }

    GetSlotStatuses() {
        statuses := Map()
        Loop 9
            statuses[A_Index] := this._StatusDto(SlotStatus(A_Index))
        return statuses
    }

    Bind(payload) {
        slot := this._SlotNumberIn(payload)
        if !slot
            return SettingsBridgeError("invalid_request", "Номер слота должен быть 1…9", false)
        return this.BindActive(slot)
    }

    Release(payload) {
        slot := this._SlotNumberIn(payload)
        if !slot
            return SettingsBridgeError("invalid_request", "Номер слота должен быть 1…9", false)
        return this.ReleaseDynamic(slot)
    }

    BindActive(slotNumber) {
        res := SlotBind(slotNumber)
        if !res.ok
            return SettingsBridgeError(res.code, res.message, false)
        return SettingsBridgeOk(Map(
            "slot", slotNumber,
            "status", this._StatusDto(SlotStatus(slotNumber)),
            "state", this.StateDto()
        ))
    }

    ReleaseDynamic(slotNumber) {
        res := SlotRelease(slotNumber)
        if !res.ok
            return SettingsBridgeError(res.code, res.message, false)
        return SettingsBridgeOk(Map(
            "slot", slotNumber,
            "status", this._StatusDto(SlotStatus(slotNumber)),
            "state", this.StateDto()
        ))
    }

    _SlotNumberIn(payload) {
        if !(payload is Map)
            return 0
        slot := JsonGet(payload, "slot", 0)
        if !(slot is Integer) || slot < 1 || slot > 9
            return 0
        return Integer(slot)
    }

    Apply(payload) {
        return this._Save(payload, false)
    }

    Ok(payload) {
        return this._Save(payload, true)
    }

    ; Закрытие без записи. Правило то же, что у native SettingsClose():
    ; несохранённый черновик молча не выбрасывается. Разделение труда —
    ; из ADR: сравнивает draft с baseline порт (он один знает, что
    ; применено), спрашивает человека WebView.
    ;
    ; closed:false — «пока не закрываю»: мост возвращается в open, окно
    ; остаётся. Фронтенд после такого ответа показывает подтверждение и
    ; при согласии присылает cancel ещё раз с discardChanges.
    ;
    ; Ответ уходит сразу, поэтому 5-секундный timeout закрытия в мосте
    ; не успевает выстрелить, пока человек думает: вопрос задаётся уже
    ; в состоянии open. MsgBox отсюда сделал бы ровно обратное —
    ; заблокировал бы очередь сообщений WebView на время раздумий.
    Cancel(payload) {
        draft := JsonGet(payload, "draft", 0)
        discard := JsonGet(payload, "discardChanges", false)
        if (discard = true || !this._DraftDirty(draft))
            return SettingsBridgeOk(Map("closed", JsonB(true)), true)
        return SettingsBridgeOk(Map("closed", JsonB(false)), false)
    }

    ; Есть ли в черновике хоть что-то, чего нет в применённом состоянии.
    ; Считает это тот же SettingsGeneralPlan, который делает Save: его
    ; список writes и есть перечень отличий от runtime. Второе сравнение
    ; полей разошлось бы с первым — ровно так и появляются окна, которые
    ; спрашивают про несохранённое, когда сохранять нечего.
    ;
    ; Неразобранный черновик считается изменённым: форму правили, раз в
    ; ней лежит то, чего DTO не принимает, и терять это молча нельзя.
    _DraftDirty(draft) {
        if !(draft is Map)
            return false
        err := "", field := ""
        edits := this._SlotsInput(JsonGet(draft, "slotEdits", []), &err, &field)
        if (err != "")
            return true
        input := this._GeneralInput(JsonGet(draft, "general", 0), &err, &field)
        if (err != "")
            return true
        writes := SettingsGeneralPlan(input, &err)
        if !writes
            return true
        slotPlan := SettingsSlotsPlan(edits, &err, SettingsDynamicFinal(writes))
        return err != "" || writes.Length || slotPlan.writes.Length || slotPlan.deletes.Length
            || slotPlan.dynDeletes.Length || slotPlan.keyDeletes.Length
    }

    Unsupported(action) {
        return SettingsBridgeError("unsupported_action",
            "Действие ещё не подключено к WebView: " action, false)
    }

    Dispose() {
        if this._disposed
            return false
        this._disposed := true
        return true
    }

    ; --------------------------- Save ---------------------------

    _Save(payload, closeAfter) {
        draft := JsonGet(payload, "draft", 0)
        if !(draft is Map)
            return SettingsBridgeError("invalid_request", "В запросе нет draft", false)

        err := "", field := ""
        edits := this._SlotsInput(JsonGet(draft, "slotEdits", []), &err, &field)
        if (err != "")
            return this._Invalid(err, field)
        input := this._GeneralInput(JsonGet(draft, "general", 0), &err, &field)
        if (err != "")
            return this._Invalid(err, field)

        ; Тот же plan, что зовёт native SettingsCollect(): валидация,
        ; сравнение с runtime и точечные writes живут там, а не здесь.
        generalWrites := SettingsGeneralPlan(input, &err)
        if !generalWrites
            return this._Invalid(err != "" ? err : "General не разобран", "")

        ; Единственный план Slots, общий с native, включая no-op и dirty.
        ; Границы значений проверяет он, и адрес поля называет тоже он:
        ; разбирать русский текст ответа, чтобы понять, к какому слоту
        ; вести человека, — ровно то, от чего уводил C3.
        slotPlan := SettingsSlotsPlan(edits, &err, SettingsDynamicFinal(generalWrites))
        if (err != "")
            return this._Invalid(err, slotPlan.field)

        outcome := ""
        SettingsApplyPlan(generalWrites, slotPlan, &outcome)
        return this._SaveOutcome(outcome, closeAfter)
    }

    ; Outcome C4 -> wire. Правила те же, что у native: код пуст только
    ; при успехе, partial отдаётся при тронутом диске, state — только
    ; когда рантайм действительно перечитан.
    _SaveOutcome(outcome, closeAfter) {
        if (outcome.code != "") {
            extra := Map()
            if outcome.mayHavePersisted
                extra["partial"] := Map("mayHavePersisted", JsonB(true),
                                        "runtimeReloaded", JsonB(outcome.runtimeReloaded))
            if outcome.runtimeReloaded
                extra["state"] := this.StateDto(outcome.state)
            if (outcome.HasOwnProp("diagnostics") && outcome.diagnostics.Length)
                extra["diagnostics"] := outcome.diagnostics
            return SettingsBridgeError(outcome.code, outcome.err, outcome.retryable, extra)
        }

        result := Map(
            "saved", JsonB(outcome.saved),
            "changedFields", outcome.changedWrites,
            "changedSlots", outcome.changedSlots,
            "restartRequiredFields", this._RestartFields(outcome.restartRequired),
            ; Замечания к перечитанному config.ini. У native их показывает
            ; ConfigDiagShow; из моста MsgBox заблокировал бы очередь
            ; сообщений WebView, поэтому они едут ответом (C5).
            "diagnostics", outcome.diagnostics,
            ; Канонический state после записи. При no-op реконсиляции не
            ; было, и снимок берётся здесь: рантайм и так канонический.
            "state", this.StateDto(outcome.state))
        if closeAfter
            result["closing"] := JsonB(true)
        return SettingsBridgeOk(result, closeAfter)
    }

    _RestartFields(nums) {
        out := []
        for n in nums
            out.Push("slots." n ".hotkey")
        return out
    }

    _Invalid(message, field) {
        extra := Map()
        if (field != "")
            extra["field"] := field
        return SettingsBridgeError("validation_error", message, true, extra)
    }

    ; ------------------ wire General -> вход плана ------------------
    ; Проверяется только форма: есть ли поле и того ли оно рода. Границы
    ; (5…100, 10…60000, enum края) остаются в backend — дублировать их
    ; здесь значило бы завести вторую валидацию, расходящуюся с первой.
    ; Поэтому field заполняется у ошибок формы, а сообщения о границах
    ; приходят от плана без field: разбирать русский текст, чтобы
    ; вычислить путь поля, — ровно то, от чего уводил C3.
    ;
    ; noAnim всегда false: wire несёт длительность всегда, а «без
    ; анимации» — это ноль шагов. У native это отдельный пункт списка
    ; только затем, чтобы не переписывать animMs; разницы в поведении
    ; между «0 шагов» и «без анимации» нет (см. Slide: animSteps < 1).
    _GeneralInput(g, &err, &field) {
        if !(g is Map)
            return this._Bad("В draft нет general", "general", &err, &field)
        dd := JsonGet(g, "dynamicDefaults", 0)
        if !(dd is Map)
            return this._Bad("В general нет dynamicDefaults",
                             "general.dynamicDefaults", &err, &field)
        anim := JsonGet(g, "animation", 0)
        if !(anim is Map)
            return this._Bad("В general нет animation",
                             "general.animation", &err, &field)

        return {
            width:          this._Int(dd, "widthPercent", "general.dynamicDefaults.widthPercent", &err, &field),
            edge:           this._Text(dd, "edge", "general.dynamicDefaults.edge", &err, &field),
            monitor:        this._MonitorIn(JsonGet(dd, "monitor", 0), &err, &field),
            activateOnShow: this._Bool(dd, "activateOnShow", "general.dynamicDefaults.activateOnShow", &err, &field),
            hideOnBlur:     this._Bool(dd, "hideOnBlur", "general.dynamicDefaults.hideOnBlur", &err, &field),
            handlesEnabled: this._Bool(g, "handlesEnabled", "general.handlesEnabled", &err, &field),
            noAnim:         false,
            animMs:         this._Int(anim, "durationMs", "general.animation.durationMs", &err, &field),
            animSteps:      this._Int(anim, "steps", "general.animation.steps", &err, &field),
            blurMs:         this._Int(g, "blurCheckMs", "general.blurCheckMs", &err, &field),
            accent:         this._Text(g, "accent", "general.accent", &err, &field),
            handleWidth:    this._Int(JsonGet(g, "handle", 0), "width", "general.handle.width", &err, &field),
            handleHeight:   this._Int(JsonGet(g, "handle", 0), "height", "general.handle.height", &err, &field),
            handleGap:      this._Int(JsonGet(g, "handle", 0), "gap", "general.handle.gap", &err, &field)
        }
    }

    _Bad(message, path, &err, &field) {
        if (err = "") {
            err := message
            field := path
        }
        return 0
    }

    ; Как поле называется у человека. Путь — адрес для формы: по нему
    ; она подсвечивает контрол. В сообщении должно стоять название,
    ; иначе внизу окна написано «slots.3.widthPercent», а на экране
    ; то же самое подписано «Ширина (%)».
    _FieldLabel(path) {
        static names := Map(
            "general.dynamicDefaults.widthPercent",   "размер окна",
            "general.dynamicDefaults.edge",           "сторона выезда",
            "general.dynamicDefaults.monitor",        "монитор",
            "general.dynamicDefaults.monitor.number", "номер монитора",
            "general.dynamicDefaults.activateOnShow", "активация при открытии",
            "general.dynamicDefaults.hideOnBlur",     "автоскрытие",
            "general.handlesEnabled",                 "кромки у края экрана",
            "general.animation.durationMs",           "длительность анимации",
            "general.animation.steps",                "шаги анимации",
            "general.blurCheckMs",                    "проверка потери фокуса",
            "general.accent",                         "цвет акцента",
            "general.handle.width",                   "размер кромки",
            "general.handle.height",                  "высота кромки",
            "general.handle.gap",                     "отступ между кромками")
        if names.Has(path)
            return names[path]
        ; Имена полей слота знает backend: он же ставит их в свои
        ; сообщения о границах значений, и расходиться им нельзя.
        if RegExMatch(path, "^slots\.(\d)(?:\.(.+))?$", &m)
            return SettingsSlotFieldLabel(m[1], m[2])
        return path
    }

    _Int(m, key, path, &err, &field) {
        if (err != "")
            return 0
        if !(m is Map) || !m.Has(key)
            return this._Bad("Поле не передано: " this._FieldLabel(path), path, &err, &field)
        v := m[key]
        if !IsInteger(v)
            return this._Bad("Поле должно быть целым числом: " this._FieldLabel(path), path, &err, &field)
        return Integer(v)
    }

    _Text(m, key, path, &err, &field) {
        if (err != "")
            return ""
        if !(m is Map) || !m.Has(key)
            return this._Bad("Поле не передано: " this._FieldLabel(path), path, &err, &field)
        v := m[key]
        if (v is Map || v is Array)
            return this._Bad("Поле должно быть строкой: " this._FieldLabel(path), path, &err, &field)
        return String(v)
    }

    ; Булево на wire обязано быть настоящим true/false. Строка "false"
    ; истинна в AHK, и без этой проверки она доехала бы до backend, где
    ; SettingsBoolIn (C5) её всё равно отвергнет — но уже без указания
    ; поля, а значит менее внятно для формы.
    _Bool(m, key, path, &err, &field) {
        if (err != "")
            return false
        if !(m is Map) || !m.Has(key)
            return this._Bad("Поле не передано: " this._FieldLabel(path), path, &err, &field)
        v := m[key]
        if !(v is Integer) || (v != 0 && v != 1)
            return this._Bad("Поле должно быть true или false: " this._FieldLabel(path), path, &err, &field)
        return v ? true : false
    }

    _MonitorIn(m, &err, &field, path := "general.dynamicDefaults.monitor") {
        if (err != "")
            return ""
        if !(m is Map) || !m.Has("kind")
            return this._Bad("Поле не передано: " this._FieldLabel(path), path, &err, &field)
        kind := String(m["kind"])
        if (kind = "cursor")
            return "cursor"
        ; Значение приехало из config.ini негодным и вернулось назад
        ; нетронутым. Ответ должен звать выбрать монитор, а не описывать
        ; допустимые kind: человек этого поля не заполнял.
        if (kind = "invalid")
            return this._Bad("Монитор в config.ini задан неверно («"
                             . String(JsonGet(m, "raw", "")) "») — выберите заново",
                             path, &err, &field)
        if (kind != "number")
            return this._Bad("monitor.kind — cursor или number", path, &err, &field)
        if !m.Has("number") || !IsInteger(m["number"])
            return this._Bad("monitor.number должен быть целым", path ".number", &err, &field)
        return String(Integer(m["number"]))
    }

    ; Wire shape only: semantic validation and disk diff stay in SettingsSlotsPlan.
    _SlotsInput(items, &err, &field) {
        edits := Map()
        if !(items is Array)
            return this._Bad("slotEdits должен быть массивом", "slotEdits", &err, &field)
        for item in items {
            if !(item is Map)
                return this._Bad("Правка слота должна быть объектом", "slotEdits", &err, &field)
            n := JsonGet(item, "number", 0)
            if !(n is Integer) || n < 1 || n > 9
                return this._Bad("Номер слота должен быть 1…9", "slotEdits", &err, &field)
            path := "slots." n
            if edits.Has(n)
                return this._Bad("Повторная правка слота " n, path, &err, &field)
            kind := JsonGet(item, "kind", "")
            if (kind != "permanent" && kind != "dynamic")
                return this._Bad("Род слота — permanent или dynamic", path, &err, &field)
            v := JsonGet(item, "value", 0)
            if !(v is Map)
                return this._Bad("Нет конфигурации слота", path, &err, &field)
            ; У динамического слота правится только поведение: имени, exe
            ; и хоткея у него нет, а секция [dynamicSlotN] знает ровно эти
            ; пять ключей. Само превращение постоянного в динамический —
            ; тот же род на wire: план сам увидит, что [slotN] существует.
            if (kind = "dynamic") {
                edits[n] := {
                    kind: "dyn",
                    width: this._Int(v, "widthPercent", path ".widthPercent", &err, &field),
                    edge: this._Text(v, "edge", path ".edge", &err, &field),
                    monitor: this._MonitorIn(JsonGet(v, "monitor", 0), &err, &field, path ".monitor"),
                    activateOnShow: this._Bool(v, "activateOnShow", path ".activateOnShow", &err, &field),
                    hideOnBlur: this._Bool(v, "hideOnBlur", path ".hideOnBlur", &err, &field),
                    hotkey: this._Text(v, "hotkey", path ".hotkey", &err, &field)
                }
                if (err != "")
                    return 0
                continue
            }
            edits[n] := {
                kind: "perm",
                name: this._Text(v, "name", path ".name", &err, &field),
                exe: this._Text(v, "executable", path ".executable", &err, &field),
                cls: this._Text(v, "windowClass", path ".windowClass", &err, &field),
                hotkey: this._Text(v, "hotkey", path ".hotkey", &err, &field),
                width: this._Int(v, "widthPercent", path ".widthPercent", &err, &field),
                edge: this._Text(v, "edge", path ".edge", &err, &field),
                monitor: this._MonitorIn(JsonGet(v, "monitor", 0), &err, &field, path ".monitor"),
                activateOnShow: this._Bool(v, "activateOnShow", path ".activateOnShow", &err, &field),
                hideOnBlur: this._Bool(v, "hideOnBlur", path ".hideOnBlur", &err, &field)
            }
            if (err != "")
                return 0
        }
        return edits
    }

    ; ------------------ рантайм -> wire SettingsState ------------------

    StateDto(snap := 0) {
        if !snap
            snap := SettingsStateSnapshot()
        slots := []
        for s in snap.slots
            slots.Push(this._SlotDto(s))
        return Map(
            "protocolVersion", DrawerSettingsPort.PROTOCOL_VERSION,
            "general", this._GeneralDto(snap.general),
            "slots", slots,
            "monitors", this._MonitorsDto())
    }

    _MonitorsDto() {
        monitors := []
        count := 0
        try count := MonitorGetCount()
        Loop count {
            n := A_Index
            wl := 0, wt := 0, wr := 0, wb := 0
            w := 0, h := 0
            try {
                if MonitorGetWorkArea(n, &wl, &wt, &wr, &wb) {
                    w := wr - wl
                    h := wb - wt
                } else if MonitorGet(n, &wl, &wt, &wr, &wb) {
                    w := wr - wl
                    h := wb - wt
                }
            } catch {
                w := 0, h := 0
            }
            monitors.Push(Map(
                "number", n,
                "width", this._Num(w, 0),
                "height", this._Num(h, 0)))
        }
        return monitors
    }

    ; accent — шесть hex-цифр без «#», ровно как в config.ini и как их
    ; принимает SettingsAccentIn. Решётка нужна только CSS, и добавляет
    ; её форма: на wire формат один.
    _GeneralDto(g) {
        return Map(
            "dynamicDefaults", this._BehaviorDto(g.dynamicDefaults),
            "handlesEnabled", JsonB(g.handlesEnabled),
            "animation", Map("durationMs", this._Num(g.animMs, 160),
                             "steps", this._Num(g.animSteps, 14)),
            "blurCheckMs", this._Num(g.blurMs, 250),
            "accent", String(Opt(g, "accent", "2A2E35")),
            "handle", Map("width", this._Num(Opt(g, "handleWidth", 22), 22),
                           "height", this._Num(Opt(g, "handleHeight", 34), 34),
                           "gap", this._Num(Opt(g, "handleGap", 8), 8)))
    }

    _BehaviorDto(b) {
        return Map(
            "monitor", this._MonitorDto(Opt(b, "monitor", "cursor")),
            "edge", String(Opt(b, "edge", "right")),
            "widthPercent", this._Num(Opt(b, "width", 60), 60),
            "activateOnShow", JsonB(Opt(b, "activateOnShow", true)),
            "hideOnBlur", JsonB(Opt(b, "hideOnBlur", true)))
    }

    _SlotDto(s) {
        dto := Map("number", s.n, "status", this._StatusDto(s.status))
        if (s.kind = "perm") {
            dto["kind"] := "permanent"
            dto["value"] := this._PermValueDto(s.cfg)
            return dto
        }
        dto["kind"] := "dynamic"
        dto["label"] := String(Opt(s.cfg, "name", "Слот " s.n))
        dto["effective"] := this._BehaviorDto(s.cfg)
        dto["hotkey"] := HotkeyAhkToHuman(String(Opt(s.cfg, "hotkey", SlotHotkey(s.n))))
        ; Тот же засев, которым native заполняет панель при «Сделать
        ; постоянным», — форма не должна выдумывать умолчания сама.
        dto["permanentDefaults"] := this._PermValueDto(SettingsEditSeed(s.n))
        return dto
    }

    _PermValueDto(cfg) {
        return Map(
            "name", String(Opt(cfg, "name", "")),
            "executable", String(Opt(cfg, "exe", "")),
            "windowClass", String(Opt(cfg, "cls", "")),
            "monitor", this._MonitorDto(Opt(cfg, "monitor", "cursor")),
            "edge", String(Opt(cfg, "edge", "right")),
            "widthPercent", this._Num(Opt(cfg, "width", 60), 60),
            "activateOnShow", JsonB(Opt(cfg, "activateOnShow", true)),
            "hideOnBlur", JsonB(Opt(cfg, "hideOnBlur", true)),
            ; Человеку — человеческая запись ("Ctrl + Alt + F2"), не
            ; синтаксис AutoHotkey: форма отправит её назад как есть,
            ; SettingsHotkeyIn() на стороне AHK разберёт её обратно в
            ; "^!F2" сама. Второго конвертера на стороне Vue не заводим —
            ; источник истины один, и он уже здесь.
            "hotkey", HotkeyAhkToHuman(String(Opt(cfg, "hotkey", ""))))
    }

    ; windowTitle появляется только там, где окно найдено: в контракте
    ; это два разных варианта SlotStatus, а не одно поле с пустой строкой.
    _StatusDto(st) {
        dto := Map("state", String(st.state))
        if !(st.state = "available" || st.state = "parked" || st.state = "shown")
            return dto
        dto["windowTitle"] := String(st.title)
        ; Имя приложения и его иконка — то, чем строка списка опознаётся
        ; на глаз. Заголовок для этого не годится: у динамического слота
        ; он меняется на каждый документ. Иконка едет data-URI: другого
        ; способа отдать картинку в WebView2 нет.
        dto["application"] := String(Opt(st, "app", ""))
        if (Opt(st, "icon", "") != "")
            dto["icon"] := String(st.icon)
        return dto
    }

    _MonitorDto(v) {
        if (v = "" || v = "cursor")
            return Map("kind", "cursor")
        if IsInteger(v)
            return Map("kind", "number", "number", Integer(v))
        ; Значение правил руками, и оно негодное. Врать про cursor нельзя:
        ; ResolveMonitor на нём бросит. Отдаём как есть отдельным видом —
        ; форма покажет, что там лежит, и даст выбрать заново.
        return Map("kind", "invalid", "raw", String(v))
    }

    ; config.ini читается как текст, поэтому число может приехать
    ; строкой или мусором. Integer() на мусоре бросает, а падать при
    ; сборке снимка нельзя — снимок нужен именно тогда, когда что-то не
    ; так.
    _Num(v, def) {
        return IsInteger(v) ? Integer(v) : (IsNumber(v) ? Number(v) : def)
    }
}
