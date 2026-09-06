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

; ==================== SettingsDwmTheme ====================
; Приведение системного Windows titlebar к визуальному стилю Drawer
; через DwmSetWindowAttribute (без создания custom window chrome).
; Нативные кнопки сворачивания/закрытия, системный drag, resize,
; snap layouts и accessibility остаются штатными средствами ОС.
; Если атрибуты не поддерживаются (Windows 10 или старые сборки),
; они молча игнорируются и остаётся системный fallback.
ApplyDwmTitlebarTheme(hwnd) {
    if !hwnd
        return
    ; DWMWA_USE_IMMERSIVE_DARK_MODE: 20 (Win11 / Win10 20H1+), 19 (Win10 1809)
    hr := -1
    try hr := DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "Int", 20, "Int*", 1, "Int", 4, "Int")
    if (hr != 0) {
        try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "Int", 19, "Int*", 1, "Int", 4, "Int")
    }

    ; DWMWA_CAPTION_COLOR (35): #17181C (COLORREF 0x001C1817, matching --bg-app)
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "Int", 35, "UInt*", 0x001C1817, "Int", 4)

    ; DWMWA_TEXT_COLOR (36): #EDEDEF (COLORREF 0x00EFEDED, matching --text)
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "Int", 36, "UInt*", 0x00EFEDED, "Int", 4)

    ; DWMWA_BORDER_COLOR (34): #2A2E35 (COLORREF 0x00352E2A, matching Drawer accent/border)
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "Int", 34, "UInt*", 0x00352E2A, "Int", 4)
}

class SettingsWebViewAdapter {
    ; WebDir и LoaderPath приходят снаружи готовыми: где лежат файлы —
    ; вопрос упаковки (SettingsWebAssets.ahk), а не транспорта. В
    ; несобранном виде это дерево репозитория, в собранном — распакованная
    ; временная папка, и адаптеру эта разница не видна.
    __New(Title, WebDir, LoaderPath, DataDir, OnJson, OnCloseRequested, OnDestroyed) {
        this._closed := false
        this._onJson := OnJson
        this._onCloseRequested := OnCloseRequested
        this._onDestroyed := OnDestroyed

        ; 1060x700 — размер, при котором вкладка Slots показывает
        ; утверждённый макет целиком: список из девяти слотов без
        ; прокрутки и поля правой колонки в их проектных ширинах. В
        ; окне поуже страница ужимает поля сама (+Resize), но проектных
        ; ширин уже не держит.
        settings := { DllPath: LoaderPath,
                      DataDir: DataDir,
                      DefaultWidth: 1060,
                      DefaultHeight: 700 }
        this.Window := WebViewGui("+Resize", Title, , settings)
        ApplyDwmTitlebarTheme(this.Window.Hwnd)
        this._messageHandler := ObjBindMethod(this, "_HandleWebMessage")
        this._messageToken := this.Window.WebMessageReceived(this._messageHandler)
        this._newWindowHandler := ObjBindMethod(this, "_HandleNewWindow")
        this._newWindowToken := this.Window.NewWindowRequested(this._newWindowHandler)
        this._closeHandler := ObjBindMethod(this, "_HandleNativeClose")
        this.Window.OnEvent("Close", this._closeHandler)
        this.Window.Control.BrowseFolder(WebDir)
        this.Window.Navigate("index.html")
    }

    Show(Options := "w1060 h700 Center") {
        ApplyDwmTitlebarTheme(this.Window.Hwnd)
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

    _HandleNewWindow(Sender, Args) {
        Args.Handled := 1
        try Run(Args.Uri)
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
        try control.wv.remove_NewWindowRequested(this._newWindowToken)
        try control.wvc.Close()
        try WebViewCtrl.ActiveHwnds.Delete(control.Hwnd)
        try window.Destroy()
        this.Window := 0
        this._onDestroyed.Call(this, Reason)
        return true
    }
}
