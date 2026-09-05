; ====================== SettingsJsonBridge ======================
; Протокольный слой: разбирает конверт, диспетчеризует action в порт и
; отправляет ответ обратно. Про config.ini, слоты и HWND не знает ничего
; — это разделение из ADR (мост ↔ порт), и оно же позволяет проверять
; протокол без WebView.
;
; На wire ровно три типа: request (Vue → AHK, с уникальным id),
; response (AHK → Vue, повторяет id и action) и event (без id). Ответ
; связан с запросом только через id, поэтому запрос без id не получает
; ответа вовсе: отправить его некуда.
;
; Picker runs outside WebMessageReceived with an operation gate.
; Accepted close waits for the modal stack to unwind before disposal.

class SettingsJsonBridge {
    __New(Adapter, Port, CloseTimeoutMs := 5000, Trace := 0) {
        this._adapter := Adapter
        this._port := Port
        this._closeTimeoutMs := CloseTimeoutMs
        this._traceCallback := Trace
        this._closeState := "open"          ; open | awaitingDecision | closing | closed
        this._closeOrigin := ""
        this._closedEventSent := false
        this._disposed := false
        this._closeTimeoutHandler := ObjBindMethod(this, "_CloseTimedOut")
        this._destroyHandler := ObjBindMethod(this, "_DestroyNow")
        this._statusHandler := ObjBindMethod(this, "_PollStatus")
        this._watching := false
        this._statuses := Map()
        this._picker := false
        this._pendingClose := 0
    }

    HandleJson(Json) {
        try {
            msg := JsonParse(Json)
            if !(msg is Map)
                throw Error("сообщение не объект")
            request := { type:    String(JsonGet(msg, "type")),
                         id:      String(JsonGet(msg, "id")),
                         action:  String(JsonGet(msg, "action")),
                         payload: JsonGet(msg, "payload", Map()) }
            if (request.type != "request" || request.id = "" || request.action = "")
                throw Error("конверт не request")
        } catch as e {
            ; Ответить нечем: без id клиент не сопоставит ответ ни с чем.
            this._Trace("invalid-request " e.Message)
            return
        }
        this.HandleRequest(request)
    }

    ; Отдельно от HandleJson, чтобы диспетчер и lifecycle можно было
    ; проверять без WebView и без codec.
    HandleRequest(Request) {
        if (this._closeState = "closing" || this._closeState = "closed")
            return

        action := Request.action
        this._Trace("request " action " id=" Request.id)
        if (this._picker || this._port.PickerBusy()) {
            switch action {
            case "settings.apply", "settings.ok", "picker.exe", "picker.window", "slot.bind", "slot.release", "slot.watchStatus":
                this._SendError(Request, "busy", "Открыт picker", true)
                return
            }
        }
        if (this._closeState = "awaitingDecision"
            && action != "settings.cancel" && action != "settings.ok"
            && action != "settings.getInitialState") {
            this._SendError(Request, "busy", "Ожидается решение о закрытии Settings", true)
            return
        }

        try {
            switch action {
            case "settings.getInitialState":
                outcome := this._port.GetInitialState(Request.payload)
            case "settings.apply":
                outcome := this._port.Apply(Request.payload)
            case "settings.ok":
                outcome := this._port.Ok(Request.payload)
            case "settings.cancel":
                outcome := this._port.Cancel(Request.payload)
            case "slot.watchStatus":
                outcome := this._WatchStatus(Request.payload)
            case "picker.exe", "picker.window":
                this._picker := true
                ; Leave WebMessageReceived before entering a native modal loop.
                SetTimer(ObjBindMethod(this, "_RunPicker", Request), -1)
                return
            case "slot.bind":
                outcome := this._port.Bind(Request.payload)
            case "slot.release":
                outcome := this._port.Release(Request.payload)
            default:
                this._SendError(Request, "unsupported_action", "Неизвестное действие: " action, false)
                return
            }
        } catch as e {
            ; Мост живёт в колбэке WebView: вылет отсюда убил бы канал,
            ; а не запрос. Наружу уходит internal_error с текстом.
            this._SendError(Request, "internal_error", e.Message, false)
            if (action = "settings.cancel" || action = "settings.ok")
                this._ResumeAfterDeniedClose()
            return
        }

        this._Reply(Request, outcome)

        if (outcome.Ok && action = "slot.watchStatus" && this._watching)
            this._PollStatus()

        if !outcome.Ok {
            if (action = "settings.cancel" || action = "settings.ok")
                this._ResumeAfterDeniedClose()
            return
        }
        if (action = "settings.cancel" || action = "settings.ok") {
            if outcome.Close
                this._CommitClose(action = "settings.ok" ? "ok" : "cancel",
                                  this._DecisionOrigin(), false)
            else
                this._ResumeAfterDeniedClose()
        }
    }

    ; Системный крестик не рушит WebView сам: адаптер отменяет закрытие и
    ; спрашивает Vue. Иначе несохранённый черновик исчезал бы молча.
    NativeCloseRequested(*) {
        if (this._closeState != "open") {
            this._Trace("native-close-ignored state=" this._closeState)
            return
        }
        this._closeState := "awaitingDecision"
        this._closeOrigin := "nativeWindow"
        this._Trace("native-close-requested")
        this._SendEvent("settings.closeRequested", Map("reason", "window"))
        SetTimer(this._closeTimeoutHandler, -this._closeTimeoutMs)
    }

    Shutdown(Reason := "drawerExit") {
        if (this._closeState = "closed")
            return
        this._CommitClose(Reason, "host", true, true)
    }

    TransportDestroyed(*) {
        this._closeState := "closed"
        this.Dispose()
    }

    Dispose() {
        if this._picker {
            this._port.CancelPicker()
            return false
        }
        if this._disposed
            return false
        this._disposed := true
        this._watching := false
        SetTimer(this._statusHandler, 0)
        this._statuses.Clear()
        this._Trace("slot-watch disposed")
        SetTimer(this._closeTimeoutHandler, 0)
        SetTimer(this._destroyHandler, 0)
        try this._port.Dispose()
        this._Trace("bridge-disposed")
        return true
    }

    ; ------------------------- отправка -------------------------

    _RunPicker(request) {
        this._Trace("picker-enter")
        try {
            if (this._closeState != "open") {
                if (this._closeState = "awaitingDecision")
                    this._Reply(request, SettingsBridgeOk(Map("selected", JsonB(false))))
                return
            }
            outcome := this._port.Pick(request.action = "picker.exe" ? "exe" : "window")
            if (this._closeState = "open")
                this._Reply(request, outcome)
            else if (this._closeState = "awaitingDecision")
                this._Reply(request, SettingsBridgeOk(Map("selected", JsonB(false))))
        } catch as e {
            if (this._closeState = "open")
                this._SendError(request, "internal_error", e.Message, false)
            else if (this._closeState = "awaitingDecision")
                this._Reply(request, SettingsBridgeOk(Map("selected", JsonB(false))))
        } finally {
            this._picker := false
            this._Trace("picker-exit")
            if this._pendingClose {
                pending := this._pendingClose
                this._pendingClose := 0
                this._FinishClose(pending.reason, pending.origin, pending.forced, pending.sync)
            } else if (this._closeState = "closed")
                this.Dispose()
        }
    }

    _WatchStatus(payload) {
        enabled := JsonGet(payload, "enabled", "")
        if !(enabled is Integer) || (enabled != 0 && enabled != 1)
            return SettingsBridgeError("invalid_request", "enabled должен быть true или false", false)
        this._watching := enabled
        this._statuses.Clear()
        SetTimer(this._statusHandler, enabled ? 400 : 0)
        this._Trace("slot-watch enabled=" enabled)
        return SettingsBridgeOk(Map("enabled", JsonB(enabled)))
    }

    _PollStatus() {
        if (!this._watching || this._disposed)
            return
        try {
            for n, status in this._port.GetSlotStatuses() {
                signature := JsonDump(status)
                if (!this._statuses.Has(n) || !(this._statuses[n] == signature)) {
                    this._statuses[n] := signature
                    this._SendEvent("slot.statusChanged", Map("slot", n, "status", status))
                }
            }
        } catch as e {
            this._Trace("slot-watch-error " e.Message)
        }
    }

    _Reply(Request, Outcome) {
        if !Outcome.Ok {
            this._Trace("response " Request.action " ok=false code=" Outcome.Code)
            this._SendError(Request, Outcome.Code, Outcome.Message,
                            Outcome.Retryable, Outcome.Extra)
            return
        }
        this._Trace("response " Request.action " ok=true")
        this._Send(Map("type", "response",
                       "id", Request.id,
                       "action", Request.action,
                       "ok", JsonB(true),
                       "result", Outcome.Result))
    }

    _SendError(Request, Code, Message, Retryable, Extra := 0) {
        error := Map("code", Code, "message", Message,
                     "retryable", JsonB(Retryable))
        if (Extra is Map) {
            for k, v in Extra
                error[k] := v
        }
        this._Send(Map("type", "response",
                       "id", Request.id,
                       "action", Request.action,
                       "ok", JsonB(false),
                       "error", error))
    }

    _SendEvent(Name, Data) {
        this._Send(Map("type", "event", "event", Name, "data", Data))
    }

    _Send(Message) {
        this._adapter.SendJson(JsonDump(Message))
    }

    ; ------------------------- lifecycle -------------------------

    _ResumeAfterDeniedClose() {
        if (this._closeState != "awaitingDecision")
            return
        SetTimer(this._closeTimeoutHandler, 0)
        this._closeState := "open"
        this._closeOrigin := ""
        this._Trace("close-denied")
    }

    _DecisionOrigin() {
        return this._closeOrigin = "nativeWindow" ? "nativeWindow" : "frontend"
    }

    _CommitClose(Reason, Origin, Forced, DestroySynchronously := false) {
        if (this._closeState = "closing" || this._closeState = "closed")
            return
        this._closeState := "closing"
        SetTimer(this._closeTimeoutHandler, 0)
        SetTimer(this._destroyHandler, 0)
        if this._picker {
            this._pendingClose := { reason: Reason, origin: Origin, forced: Forced, sync: DestroySynchronously }
            this._Trace("picker-close-deferred")
            this._port.CancelPicker()
            return
        }
        this._FinishClose(Reason, Origin, Forced, DestroySynchronously)
    }

    _FinishClose(Reason, Origin, Forced, DestroySynchronously) {
        this.Dispose()
        this._SendClosed(Reason, Origin, Forced)
        if DestroySynchronously
            this._DestroyNow(Reason)
        else
            ; Response и event должны успеть уйти до уничтожения WebView.
            SetTimer(this._destroyHandler, -1)
    }

    _SendClosed(Reason, Origin, Forced) {
        if this._closedEventSent
            return
        this._closedEventSent := true
        this._SendEvent("settings.closed", Map("reason", Reason, "origin", Origin,
                                               "forced", JsonB(Forced)))
        this._Trace("settings-closed reason=" Reason " origin=" Origin)
    }

    _CloseTimedOut() {
        if (this._closeState != "awaitingDecision")
            return
        this._Trace("native-close-timeout")
        this._CommitClose("nativeCloseTimeout", "nativeWindow", true)
    }

    _DestroyNow(Reason := "") {
        if (this._closeState != "closing")
            return
        this._closeState := "closed"
        this._adapter.Destroy(Reason != "" ? Reason : "settingsClosed")
    }

    _Trace(Message) {
        if this._traceCallback
            this._traceCallback.Call(Message)
    }
}

; Результат действия порта. Result и Extra — Map: сериализует их мост
; одним JsonDump, поэтому порт не собирает JSON руками и не может
; выпустить на wire несбалансированную строку.
SettingsBridgeOk(Result := 0, Close := false) {
    return { Ok: true, Result: Result is Map ? Result : Map(), Close: Close }
}

SettingsBridgeError(Code, Message, Retryable := false, Extra := 0) {
    return { Ok: false, Code: Code, Message: Message,
             Retryable: Retryable, Extra: Extra, Close: false }
}
