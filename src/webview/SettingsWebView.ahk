#Include vendor\webviewtoo\WebViewToo.ahk

; ==================== SettingsWebViewAdapter ====================
; Транспорт: окно WebView2, приём JSON от страницы и отправка JSON
; обратно. Ни протокола, ни настроек не знает — его меняют, когда
; меняется способ доставки, а не когда меняется контракт.
;
; Страница отдаётся не через file://: модульные скрипты Vite оттуда
; браузер блокирует как cross-origin. Папка сборки отображается на
; виртуальный хост, и страница живёт на обычном https-origin, где
; работают и модули, и относительные пути.
;
; Системный крестик не уничтожает controller: обработчик Close
; возвращает true (отменяет закрытие) и сообщает мосту. Уничтожить
; WebView вправе только Destroy(), после того как решение о закрытии
; принято, — иначе несохранённый черновик исчезал бы молча.

class SettingsWebViewAdapter {
    __New(Title, WebDir, DataDir, OnJson, OnCloseRequested, OnDestroyed) {
        this._closed := false
        this._onJson := OnJson
        this._onCloseRequested := OnCloseRequested
        this._onDestroyed := OnDestroyed

        loaderPath := A_ScriptDir "\webview\vendor\webviewtoo\64bit\WebView2Loader.dll"
        if A_IsCompiled {
            WebViewCtrl.CreateFileFromResource("64bit\WebView2Loader.dll", WebViewCtrl.TempDir)
            loaderPath := WebViewCtrl.TempDir "\64bit\WebView2Loader.dll"
        }

        settings := { DllPath: loaderPath,
                      DataDir: DataDir,
                      DefaultWidth: 980,
                      DefaultHeight: 620 }
        this.Window := WebViewGui("+Resize", Title, , settings)
        this._messageHandler := ObjBindMethod(this, "_HandleWebMessage")
        this._messageToken := this.Window.WebMessageReceived(this._messageHandler)
        this._closeHandler := ObjBindMethod(this, "_HandleNativeClose")
        this.Window.OnEvent("Close", this._closeHandler)
        this.Window.Control.BrowseFolder(WebDir)
        this.Window.Navigate("index.html")
    }

    Show(Options := "w980 h620 Center") {
        this.Window.Show(Options)
    }

    SendJson(Json) {
        if !this._closed
            this.Window.PostWebMessageAsJson(Json)
    }

    ExecuteScript(JavaScript) {
        if !this._closed
            return this.Window.ExecuteScriptAsync(JavaScript)
    }

    Hwnd => this._closed ? 0 : this.Window.Hwnd

    _HandleWebMessage(Sender, Args) {
        this._onJson.Call(this, Args.WebMessageAsJson)
    }

    _HandleNativeClose(*) {
        if !this._closed
            this._onCloseRequested.Call(this)
        return true          ; отменить системное закрытие
    }

    Destroy(Reason := "host", *) {
        if this._closed
            return false
        this._closed := true

        window := this.Window
        control := window.Control
        try control.wv.remove_WebMessageReceived(this._messageToken)
        try control.wvc.Close()
        try WebViewCtrl.ActiveHwnds.Delete(control.Hwnd)
        try window.Destroy()
        this.Window := 0
        this._onDestroyed.Call(this, Reason)
        return true
    }
}
