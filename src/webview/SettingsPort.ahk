; ====================== DrawerSettingsPort ======================
; Семантический порт между wire-контрактом и рантаймом (см.
; docs/settings-integration-layer.md, «Публичный AHK port»). Это
; единственное место, которое знает оба словаря сразу: снаружи —
; executable/windowClass/widthPercent/blurCheckMs, внутри — exe/cls/
; width/blurMs, слоты, apps и config.ini. Мост словаря рантайма не
; видит, Vue не видит ни INI-секций, ни HWND, ни configPath.
;
; Записи здесь нет ни одной строки: Apply строит тот же вход, что и
; native UI-адаптер, и отдаёт его в SettingsGeneralPlan →
; SettingsApplyPlan. Второй persistence не появляется — это условие
; принятого gate, а не стилистика.
;
; Слайс намеренно узкий. Всё, что за его границей (правка слотов,
; picker, bind/release, watchStatus), отвечает unsupported_action —
; заглушки, притворяющейся успехом, здесь нет.

class DrawerSettingsPort {
    static PROTOCOL_VERSION := 1

    __New() {
        this._disposed := false
    }

    ; ------------------------- действия -------------------------

    GetInitialState(payload) {
        return SettingsBridgeOk(this.StateDto())
    }

    Apply(payload) {
        return this._Save(payload, false)
    }

    Ok(payload) {
        return this._Save(payload, true)
    }

    ; Слайс не сравнивает draft с baseline и не спрашивает подтверждения:
    ; dirty-confirmation остаётся у native Settings, а закрытие без
    ; записи ничего не теряет, кроме несохранённого черновика.
    Cancel(payload) {
        return SettingsBridgeOk(Map("closed", JsonB(true)), true)
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

        edits := JsonGet(draft, "slotEdits", 0)
        if (edits is Array && edits.Length)
            return this.Unsupported("правка слотов")

        err := "", field := ""
        input := this._GeneralInput(JsonGet(draft, "general", 0), &err, &field)
        if (err != "")
            return this._Invalid(err, field)

        ; Тот же plan, что зовёт native SettingsCollect(): валидация,
        ; сравнение с runtime и точечные writes живут там, а не здесь.
        generalWrites := SettingsGeneralPlan(input, &err)
        if !generalWrites
            return this._Invalid(err != "" ? err : "General не разобран", "")

        ; edits = 0 — правок слотов нет, но снимок identity/bindings
        ; реконсиляции нужен всё равно: General-only Save тоже проходит
        ; через неё.
        slotPlan := SettingsSlotsPlan(0, &err)
        if (err != "")
            return SettingsBridgeError("internal_error", err, false)

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
            out.Push("slots." n ".focusHotkey")
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
    ; accent на wire нет: цвет в слайс не входит, и порт подставляет
    ; действующее значение — план сравнит его с runtime и ничего не
    ; напишет. noAnim всегда false: wire несёт длительность всегда,
    ; «без анимации» — способ native не трогать ключ.
    _GeneralInput(g, &err, &field) {
        global HANDLE_BG
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
            accent:         HANDLE_BG
        }
    }

    _Bad(message, path, &err, &field) {
        if (err = "") {
            err := message
            field := path
        }
        return 0
    }

    _Int(m, key, path, &err, &field) {
        if (err != "")
            return 0
        if !(m is Map) || !m.Has(key)
            return this._Bad("Поле не передано: " path, path, &err, &field)
        v := m[key]
        if !IsInteger(v)
            return this._Bad("Поле должно быть целым числом: " path, path, &err, &field)
        return Integer(v)
    }

    _Text(m, key, path, &err, &field) {
        if (err != "")
            return ""
        if !(m is Map) || !m.Has(key)
            return this._Bad("Поле не передано: " path, path, &err, &field)
        v := m[key]
        if (v is Map || v is Array)
            return this._Bad("Поле должно быть строкой: " path, path, &err, &field)
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
            return this._Bad("Поле не передано: " path, path, &err, &field)
        v := m[key]
        if !(v is Integer) || (v != 0 && v != 1)
            return this._Bad("Поле должно быть true или false: " path, path, &err, &field)
        return v ? true : false
    }

    _MonitorIn(m, &err, &field) {
        static path := "general.dynamicDefaults.monitor"
        if (err != "")
            return ""
        if !(m is Map) || !m.Has("kind")
            return this._Bad("Поле не передано: " path, path, &err, &field)
        kind := String(m["kind"])
        if (kind = "cursor")
            return "cursor"
        if (kind != "number")
            return this._Bad("monitor.kind — cursor или number", path ".kind", &err, &field)
        if !m.Has("number") || !IsInteger(m["number"])
            return this._Bad("monitor.number должен быть целым", path ".number", &err, &field)
        return String(Integer(m["number"]))
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
            "slots", slots)
    }

    _GeneralDto(g) {
        return Map(
            "dynamicDefaults", this._BehaviorDto(g.dynamicDefaults),
            "handlesEnabled", JsonB(g.handlesEnabled),
            "animation", Map("durationMs", this._Num(g.animMs, 160),
                             "steps", this._Num(g.animSteps, 14)),
            "blurCheckMs", this._Num(g.blurMs, 250))
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
            "focusHotkey", String(Opt(cfg, "focusHotkey", "")))
    }

    ; windowTitle появляется только там, где окно найдено: в контракте
    ; это два разных варианта SlotStatus, а не одно поле с пустой строкой.
    _StatusDto(st) {
        dto := Map("state", String(st.state))
        if (st.state = "available" || st.state = "parked" || st.state = "shown")
            dto["windowTitle"] := String(st.title)
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
