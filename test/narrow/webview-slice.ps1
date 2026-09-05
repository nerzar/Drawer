# Узкий end-to-end smoke вкладки General через WebView:
#   getInitialState -> правка полей -> Apply -> SettingsApplyPlan ->
#   канонический state обратно во Vue -> Отмена с dirty-подтверждением.
#
# Окнами, мышью и фокусом не управляет, поэтому VM не нужна — но окно
# WebView2 на несколько секунд появляется на экране, это неизбежно:
# проверяется само окно.
#
# Работает на КОПИИ src/ во временной папке: A_ScriptDir там свой, значит
# Apply пишет во временный config.ini, а не в рабочий. Инструментация
# вшивается в копию, как это делает test/run.ps1 для набора setstat.
#
#   -Compiled  собрать копию тем же Ahk2Exe, что и релиз, и прогнать
#              полученный exe в папке БЕЗ webview\: ни фронтенда, ни
#              вендора, ни DLL рядом. Это и есть проверка упаковки —
#              всё, что нужно, обязано приехать внутри exe.
#
# Запуск:  pwsh -File test\narrow\webview-slice.ps1
#          pwsh -File test\narrow\webview-slice.ps1 -Compiled

param([switch]$Compiled)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$utf8 = New-Object System.Text.UTF8Encoding($false)

$ahk = "C:\Users\nerza\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe"
if (-not (Test-Path $ahk)) { $ahk = "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe" }
if (-not (Test-Path $ahk)) { throw "Не найден AutoHotkey64.exe" }

$web = Join-Path $repo "src\webview\web\index.html"
if (-not (Test-Path $web)) {
    throw "Фронтенд не собран: нет $web. Сначала: cd settings-ui; npm run build"
}

$results = @()
function Check([string]$name, [bool]$ok) {
    $script:results += [pscustomobject]@{ Name = $name; Ok = $ok }
}

# --- временная копия приложения -------------------------------------
$dir = Join-Path ([IO.Path]::GetTempPath()) ("drawer-webview-slice-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Path $dir | Out-Null
try {
    # Копируется всё дерево src\ целиком, а не перечисленные файлы:
    # drawer.ahk включает соседние модули (SettingsWebAssets.ahk,
    # webview\*), и список пришлось бы править при каждом новом файле —
    # причём молча, потому что копия просто не загрузилась бы.
    Copy-Item (Join-Path $repo "src\*") $dir -Recurse
    Copy-Item (Join-Path $PSScriptRoot "webview-slice.js") (Join-Path $dir "webview-slice.js")

    $marker = 'A_TrayMenu.Insert("2&", "Settings (WebView2)", (*) => SettingsWebShow())'
    $src = [IO.File]::ReadAllText((Join-Path $repo "src\drawer.ahk"))
    if ($src.IndexOf($marker) -lt 0) { throw "Не нашёл пункт трея WebView2 — копия для smoke не собрана" }

    $inject = @'

; ---- инструментация узкого smoke (только в этой копии исходника) ----
smokeJs := FileRead(A_ScriptDir "\webview-slice.js", "UTF-8")
smokeTries := 0
smokeWaited := 0
smokeNativeDone := false
SetTimer(SmokeOpen, -800)
SetTimer(SmokeDrive, 700)
SetTimer(SmokeWatch, 500)
SetTimer(SmokeNativeClose, 400)

; webTrace задаётся здесь, а не рядом с вставкой: вставка стоит выше
; #Include webview\SettingsWebHost.ahk, и его собственное
; global webTrace := "" затёрло бы путь. Таймер срабатывает после того,
; как весь auto-execute уже отработал.
SmokeOpen() {
    global webTrace
    webTrace := A_ScriptDir "\bridge.log"
    SettingsWebShow()
}

; Скрипт вшивается повторно, пока страница не подхватит его: до конца
; навигации ExecuteScript уходит в about:blank. Сам драйвер защищён
; флагом window.__drawerSmoke, поэтому лишние впрыски безвредны.
SmokeDrive() {
    global webAdapter, smokeJs, smokeTries
    if !IsObject(webAdapter)
        return
    if (++smokeTries > 60) {
        SettingsWebTrace("request smoke.failed:inject-timeout")
        SetTimer(SmokeDrive, 0)
        return
    }
    try webAdapter.ExecuteScript(smokeJs)
}

; Системный крестик драйвер нажать не может: он живёт внутри страницы.
; Зовём тот же путь, которым его зовёт адаптер, — так проверяется, что
; грязный черновик переживает закрытие ОКНОМ, а не только кнопкой, и что
; пятисекундный timeout решения не срабатывает, пока человек думает.
SmokeNativeClose() {
    global webBridge, webTrace, smokeNativeDone
    log := ""
    try log := FileRead(webTrace, "UTF-8")
    if (smokeNativeDone || !InStr(log, "smoke.dirty-guarded") || !IsObject(webBridge))
        return
    smokeNativeDone := true
    SetTimer(SmokeNativeClose, 0)
    webBridge.NativeCloseRequested()
}

; Ждём не только конца сценария, но и уничтожения окна: последний шаг —
; закрытие по «Отмене» из формы, и выйти раньше значило бы проверить
; закрытие выходом ящика, а не тем, что проверяется.
SmokeWatch() {
    global webTrace, smokeWaited
    smokeWaited += 500
    log := ""
    try log := FileRead(webTrace, "UTF-8")
    if (smokeWaited > 60000)
        SettingsWebTrace("request smoke.failed:watchdog")
    else if !(InStr(log, "smoke.done") && InStr(log, "webview-destroyed"))
        return
    SetTimer(SmokeDrive, 0)
    SetTimer(SmokeWatch, 0)
    ExitApp(0)
}
'@
    [IO.File]::WriteAllText((Join-Path $dir "drawer.ahk"), $src.Replace($marker, $marker + "`r`n" + $inject), $utf8)

    # --- при -Compiled: собрать exe и увести его в чистую папку ------
    $runDir = $dir
    if ($Compiled) {
        $ahk2exe = Join-Path $repo ".tools\Ahk2Exe\Ahk2Exe.exe"
        if (-not (Test-Path $ahk2exe)) {
            throw "Не найден $ahk2exe. Скачайте релиз Ahk2Exe и распакуйте в .tools\Ahk2Exe\"
        }
        $runDir = Join-Path $dir "release"
        New-Item -ItemType Directory -Path $runDir | Out-Null
        $exe = Join-Path $runDir "Drawer.exe"
        $c = Start-Process -FilePath $ahk2exe -PassThru -Wait -NoNewWindow -ArgumentList @(
            '/in', (Join-Path $dir "drawer.ahk"),
            '/out', $exe,
            '/icon', (Join-Path $repo "assets\icon.ico"),
            '/base', $ahk
        )
        Check "0c: Ahk2Exe собрал exe" (($c.ExitCode -eq 0) -and (Test-Path $exe))
        if (-not (Test-Path $exe)) { throw "Ahk2Exe не собрал $exe (код $($c.ExitCode))" }

        # Рядом с exe не остаётся ничего от дерева исходников: ни
        # webview\web, ни вендора с WebView2Loader.dll.
        Move-Item (Join-Path $dir "config.ini") $runDir
        Move-Item (Join-Path $dir "webview-slice.js") $runDir
        Check "0d: рядом с exe нет ни фронтенда, ни вендора" `
            (-not (Test-Path (Join-Path $runDir "webview")))
    }

    $cfg = Join-Path $runDir "config.ini"
    $before = [IO.File]::ReadAllText($cfg, [Text.Encoding]::Unicode)
    Check "0a: во временном config.ini blurMs=250 до запуска" ($before -match '(?m)^blurMs=250\s*$')

    # --- прогон ------------------------------------------------------
    $target = if ($Compiled) { Join-Path $runDir "Drawer.exe" } else { $ahk }
    $targetArgs = if ($Compiled) { @() } else { @("`"$dir\drawer.ahk`"") }
    $p = Start-Process -FilePath $target -ArgumentList $targetArgs -PassThru
    if (-not $p.WaitForExit(90000)) {
        try { $p.Kill() } catch {}
        Check "0b: приложение завершилось само" $false
    } else {
        Check "0b: приложение завершилось само" $true
    }

    $logPath = Join-Path $runDir "bridge.log"
    $log = if (Test-Path $logPath) { [IO.File]::ReadAllText($logPath, [Text.Encoding]::UTF8) } else { "" }

    # --- транскрипт моста -------------------------------------------
    Check "1a: мост принял settings.getInitialState" ($log -match 'request settings\.getInitialState')
    Check "1b: и ответил успехом" ($log -match 'response settings\.getInitialState ok=true')
    Check "1c: форма заполнена из config.ini целиком, а не умолчаниями" ($log -match 'request smoke\.loaded-full')

    Check "2a: Apply дошёл до backend" ($log -match 'request settings\.apply')
    Check "2b: пустое поле вернулось structured validation_error" ($log -match 'response settings\.apply ok=false code=validation_error')
    Check "2c: форма подсветила поле по имени из ответа" ($log -match 'request smoke\.field-error')
    Check "2d: границу значения проверил backend, текст доехал в форму" ($log -match 'request smoke\.range-error')

    Check "3a: Apply четырёх полей разом вернулся успехом" ($log -match 'response settings\.apply ok=true')
    Check "3b: канонический state вернулся во Vue и заменил baseline" ($log -match 'request smoke\.saved')
    Check "3c: драйвер не сообщил ни одного провала" (-not ($log -match 'smoke\.failed'))

    Check "4a: Отмена с грязным черновиком спросила, а не закрыла" ($log -match 'request smoke\.dirty-guarded')
    Check "4b: системный крестик спросил тем же путём" `
        (($log -match 'native-close-requested') -and ($log -match 'request smoke\.native-guarded'))
    Check "4c: отказ вернул мост в open, окно осталось" `
        (($log -match 'close-denied') -and -not ($log -match 'native-close-timeout'))
    Check "4d: Отмена без изменений закрыла окно сама" ($log -match 'settings-closed reason=cancel origin=frontend')
    Check "4e: окно WebView уничтожено" ($log -match 'webview-destroyed')

    if ($Compiled) {
        # Ассеты приехали внутрь exe и распаковались во временную папку
        # версии — именно оттуда их взял виртуальный хост и DllCall.
        $ver = ([IO.File]::ReadAllText((Join-Path $repo "src\drawer.ahk")) `
                | Select-String -Pattern '(?m)^VERSION\s*:=\s*"([^"]+)"').Matches[0].Groups[1].Value
        $unpack = Join-Path ([IO.Path]::GetTempPath()) "Drawer-WebView-$ver"
        # Только на существование проверять нельзя: Ahk2Exe, не увидев
        # FileInstall, оставляет ассет за бортом, и распаковка создаёт
        # файл нулевой длины — существующий и бесполезный.
        foreach ($a in @(
            @{ n = "6a"; file = "index.html";         src = "src\webview\web\index.html" },
            @{ n = "6b"; file = "WebView2Loader.dll"; src = "src\webview\vendor\webviewtoo\64bit\WebView2Loader.dll" }
        )) {
            $dst = Join-Path $unpack $a.file
            $want = (Get-Item (Join-Path $repo $a.src)).Length
            $got = if (Test-Path $dst) { (Get-Item $dst).Length } else { -1 }
            Check "$($a.n): $($a.file) распакован из exe байт в байт ($got из $want)" ($got -eq $want)
        }
    }

    # --- сам файл ----------------------------------------------------
    $after = [IO.File]::ReadAllText($cfg, [Text.Encoding]::Unicode)
    Check "5a: в [general] записались blurMs, handles и пресет анимации" `
        (($after -match '(?m)^blurMs=300\s*$') -and ($after -match '(?m)^handles=false\s*$') `
         -and ($after -match '(?m)^animMs=100\s*$') -and ($after -match '(?m)^animSteps=10\s*$'))
    Check "5b: accent появился ключом, которого в файле не было" ($after -match '(?m)^accent=332A35\s*$')
    Check "5c: в [dynamic] записался width=80, соседние ключи целы" `
        (($after -match '(?m)^width=80\s*$') -and ($after -match '(?m)^edge=right\s*$') `
         -and ($after -match '(?m)^monitor=cursor\s*$') -and ($after -match '(?m)^hideOnBlur=true\s*$'))
    Check "5d: файл остался UTF-16 LE с комментариями пользователя" ($after -match 'Ящик' -and $after -match 'Настройки читаются заново')

    $mode = if ($Compiled) { "собранный exe" } else { "исходник" }
    "режим: $mode"
    $ok = $true
    foreach ($r in $results) {
        $ok = $ok -and $r.Ok
        "{0} {1}" -f $(if ($r.Ok) { "OK  " } else { "FAIL" }), $r.Name
    }
    ""
    if ($ok) { "ВСЕ ПРОВЕРКИ ПРОШЛИ ($($results.Count))" } else { "ЕСТЬ ПРОВАЛЫ"; "--- bridge.log ---"; $log }
    exit $(if ($ok) { 0 } else { 1 })
}
finally {
    if ($env:DRAWER_SMOKE_KEEP -ne "1") {
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    } else {
        "temp: $dir"
    }
}
