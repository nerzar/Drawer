; ==================== WebView Settings: хост ====================
; Склейка транспорта, моста и порта с рантаймом ящика. Единственный файл
; из webview/, который знает про глобалы drawer.ahk, и единственная точка
; входа: пункт трея и завершение работы.
;
; Native Settings остаётся на месте и продолжает работать: WebView —
; второй клиент того же backend, а не замена окну. Пока slice не
; закрывает правку слотов, picker и bind, native — единственный
; полноценный путь.

global webAdapter := 0     ; SettingsWebViewAdapter, пока окно живо
global webBridge  := 0     ; SettingsJsonBridge того же окна
global webHwnd    := 0     ; hwnd окна: после Destroy адаптер его уже не знает
global webTrace   := ""    ; путь файла трассировки моста; пусто — не писать

; Ошибка в настройках не должна ронять ящик — та же защита, что у
; native SettingsShow() и у хоткеев.
SettingsWebShow() {
    try
        SettingsWebOpen()
    catch as e
        Notify("WebView-настройки не открылись: " e.Message, "Ящик", 3)
}

SettingsWebOpen() {
    global webAdapter, webBridge, webHwnd
    if (IsObject(webAdapter) && webHwnd && WinExist("ahk_id " webHwnd)) {
        WinActivate("ahk_id " webHwnd)
        return
    }

    ; Рантайм проверяем до создания окружения: иначе вместо понятного
    ; «поставьте компонент» человек получит код ошибки DllCall.
    if !SettingsWebRuntimeFound()
        throw Error("не установлен Microsoft Edge WebView2 Runtime."
                  . " Скачать: https://go.microsoft.com/fwlink/p/?LinkId=2124703")

    webDir := SettingsWebPageDir()
    loader := SettingsWebLoaderPath()
    if !FileExist(webDir "\index.html")
        throw Error("нет собранного фронтенда: " webDir "\index.html")
    if !FileExist(loader)
        throw Error("нет WebView2Loader.dll: " loader)

    ; Профиль WebView2 — свой на процесс: два экземпляра ящика не должны
    ; драться за одну папку данных браузера.
    dataDir := A_Temp "\Drawer-WebView2-" DllCall("GetCurrentProcessId", "UInt")

    webAdapter := SettingsWebViewAdapter("Ящик — настройки", webDir, loader, dataDir,
        SettingsWebJson, SettingsWebCloseRequested, SettingsWebDestroyed)
    webBridge := SettingsJsonBridge(webAdapter, DrawerSettingsPort(), 5000, SettingsWebTrace)
    webHwnd := webAdapter.Hwnd
    ; Окно ящика, а не пользователя: в слот его привязать нельзя, и
    ; переход в него не считается потерей фокуса (Р18, реестр C2).
    ServiceWindowAdd(webHwnd)
    webAdapter.Show()
}

SettingsWebJson(adapter, json) {
    global webBridge
    if IsObject(webBridge)
        webBridge.HandleJson(json)
}

SettingsWebCloseRequested(adapter) {
    global webBridge
    if IsObject(webBridge)
        webBridge.NativeCloseRequested()
}

SettingsWebDestroyed(adapter, reason) {
    global webAdapter, webBridge, webHwnd
    if IsObject(webBridge)
        webBridge.TransportDestroyed()
    ServiceWindowDrop(webHwnd)
    webHwnd := 0
    webAdapter := 0
    webBridge := 0
    SettingsWebTrace("host webview-destroyed reason=" reason)
}

; Выход ящика уносит окно настроек с собой: WebView2 — отдельный
; процесс, и оставить его без хоста нельзя.
SettingsWebShutdown() {
    global webAdapter, webBridge
    if IsObject(webBridge)
        webBridge.Shutdown("drawerExit")
    else if IsObject(webAdapter)
        webAdapter.Destroy("drawerExit")
}

; Диагностика моста. По умолчанию выключена: путь задаёт тот, кому нужен
; журнал (узкий smoke из test/narrow), а не рабочая сборка.
SettingsWebTrace(message) {
    global webTrace
    if (webTrace != "")
        try FileAppend(FormatTime(, "HH:mm:ss") " " message "`n", webTrace, "UTF-8")
}
