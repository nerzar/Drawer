; ============ WEBVIEW SETTINGS: ФАЙЛЫ ВРЕМЕНИ ВЫПОЛНЕНИЯ ============
; WebView2 нужны на диске две вещи, которых в самом коде нет:
;
;  1. WebView2Loader.dll. WebView2.ahk зовёт её через
;     DllCall(dllPath "\CreateCoreWebView2EnvironmentWithOptions") —
;     это файл, а не COM-объект, и путь обязан существовать. Внутри
;     установленного WebView2 Runtime этой библиотеки нет (проверено:
;     в Application\<версия> её не лежит) — её поставляет приложение.
;     Поэтому она лежит в вендоре и уезжает в exe.
;  2. index.html фронтенда. Страницу отдаёт виртуальный хост, а он
;     отображает ПАПКУ на диске, не ресурс.
;
; Сам WebView2 Runtime — системный компонент (~150 МБ), его ящик не
; носит: Windows 11 ставит его сама, на Windows 10 он приходит с Edge.
; Отсутствие проверяется отдельно, чтобы вместо кода ошибки DllCall
; человек увидел, что именно поставить.
;
; Собранный exe самодостаточен: оба файла вшиты FileInstall и
; распаковываются во временную папку при первом открытии настроек. До
; этого момента на диск не пишется ничего: обычный запуск ящика
; настройки не открывает.

; Папка названа версией, а не PID: повторные запуски переиспользуют её и
; не копят мусор в %TEMP%, а смена версии приносит свои файлы.
SettingsWebAssetDir() {
    global VERSION
    return A_Temp "\Drawer-WebView-" VERSION
}

SettingsWebLoaderPath() {
    if !A_IsCompiled
        return A_ScriptDir "\webview\vendor\webviewtoo\64bit\WebView2Loader.dll"
    SettingsWebUnpack()
    return SettingsWebAssetDir() "\WebView2Loader.dll"
}

SettingsWebPageDir() {
    if !A_IsCompiled
        return A_ScriptDir "\webview\web"
    SettingsWebUnpack()
    return SettingsWebAssetDir()
}

; Распаковка ассетов из exe. Пути источников — относительно каталога
; ГЛАВНОГО скрипта (src\), а не этого файла: так их разрешает Ahk2Exe, и
; так это проверено репро.
;
; FileInstall стоит отдельной инструкцией внутри try-блока, а не как
; «try FileInstall(...)» одной строкой. Ahk2Exe ищет директиву в начале
; инструкции и с префиксом try её НЕ ВИДИТ: ассет молча не попадает в
; exe, компиляция при этом успешна, и ломается всё только в рантайме —
; распаковкой файла нулевой длины. Проверено репро: та же строка с
; префиксом даёт 0 байт, без префикса — полный размер.
;
; Сам try нужен на случай, когда файл уже занят другим экземпляром ящика:
; содержимое там то же самое. Поэтому проверяется факт распаковки, а не
; отсутствие исключения, и проверяется размером: нулевой файл здесь
; означает именно непопавший ассет.
SettingsWebInstall(dir) {
    try {
        FileInstall("webview\vendor\webviewtoo\64bit\WebView2Loader.dll", dir "\WebView2Loader.dll", 1)
    }
    try {
        FileInstall("webview\web\index.html", dir "\index.html", 1)
    }
}

SettingsWebUnpack() {
    static done := false
    if done
        return
    dir := SettingsWebAssetDir()
    if !DirExist(dir)
        DirCreate(dir)
    SettingsWebInstall(dir)
    for name in ["WebView2Loader.dll", "index.html"] {
        path := dir "\" name
        if (!FileExist(path) || FileGetSize(path) = 0)
            throw Error("не распаковался " name " в " dir)
    }
    done := true
}

; Тот же перебор, которым ищет рантайм сам WebView2.ahk. Дублируется
; сознательно: спросить его заранее нельзя, он ищет уже внутри DllCall.
SettingsWebRuntimeFound() {
    for root in [EnvGet("ProgramFiles(x86)"), A_AppData "\..\Local"] {
        if (root = "")
            continue
        loop files root "\Microsoft\EdgeWebView\Application\*", "D"
            if RegExMatch(A_LoopFilePath, "\\[\d.]+$")
                return true
    }
    return false
}
