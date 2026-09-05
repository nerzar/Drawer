# Узкий end-to-end smoke первого WebView-слайса:
#   getInitialState -> General.blurCheckMs -> правка -> Apply ->
#   SettingsApplyPlan -> канонический state обратно во Vue.
#
# Окнами, мышью и фокусом не управляет, поэтому VM не нужна — но окно
# WebView2 на несколько секунд появляется на экране, это неизбежно: слайс
# и есть окно.
#
# Работает на КОПИИ src/ во временной папке: A_ScriptDir там свой, значит
# Apply пишет во временный config.ini, а не в рабочий. Инструментация
# вшивается в копию, как это делает test/run.ps1 для набора setstat.
#
# Запуск:  pwsh -File test\narrow\webview-slice.ps1

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
    Copy-Item (Join-Path $repo "src\config.ini") (Join-Path $dir "config.ini")
    Copy-Item (Join-Path $repo "src\webview") (Join-Path $dir "webview") -Recurse
    Copy-Item (Join-Path $PSScriptRoot "webview-slice.js") (Join-Path $dir "webview-slice.js")

    $marker = 'A_TrayMenu.Insert("2&", "Settings (WebView2)", (*) => SettingsWebShow())'
    $src = [IO.File]::ReadAllText((Join-Path $repo "src\drawer.ahk"))
    if ($src.IndexOf($marker) -lt 0) { throw "Не нашёл пункт трея WebView2 — копия для smoke не собрана" }

    $inject = @'

; ---- инструментация узкого smoke (только в этой копии исходника) ----
smokeJs := FileRead(A_ScriptDir "\webview-slice.js", "UTF-8")
smokeTries := 0
smokeWaited := 0
SetTimer(SmokeOpen, -800)
SetTimer(SmokeDrive, 700)
SetTimer(SmokeWatch, 500)

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

SmokeWatch() {
    global webTrace, smokeWaited
    smokeWaited += 500
    log := ""
    try log := FileRead(webTrace, "UTF-8")
    if (smokeWaited > 60000)
        SettingsWebTrace("request smoke.failed:watchdog")
    else if !InStr(log, "smoke.done")
        return
    SetTimer(SmokeDrive, 0)
    SetTimer(SmokeWatch, 0)
    ExitApp(0)
}
'@
    [IO.File]::WriteAllText((Join-Path $dir "drawer.ahk"), $src.Replace($marker, $marker + "`r`n" + $inject), $utf8)

    $cfg = Join-Path $dir "config.ini"
    $before = [IO.File]::ReadAllText($cfg, [Text.Encoding]::Unicode)
    Check "0a: во временном config.ini blurMs=250 до запуска" ($before -match '(?m)^blurMs=250\s*$')

    # --- прогон ------------------------------------------------------
    $p = Start-Process -FilePath $ahk -ArgumentList @("`"$dir\drawer.ahk`"") -PassThru
    if (-not $p.WaitForExit(90000)) {
        try { $p.Kill() } catch {}
        Check "0b: приложение завершилось само" $false
    } else {
        Check "0b: приложение завершилось само" $true
    }

    $logPath = Join-Path $dir "bridge.log"
    $log = if (Test-Path $logPath) { [IO.File]::ReadAllText($logPath, [Text.Encoding]::UTF8) } else { "" }

    # --- транскрипт моста -------------------------------------------
    Check "1a: мост принял settings.getInitialState" ($log -match 'request settings\.getInitialState')
    Check "1b: и ответил успехом" ($log -match 'response settings\.getInitialState ok=true')
    Check "1c: форма показала значение из config.ini (250)" ($log -match 'request smoke\.loaded-250')

    Check "2a: Apply с blurCheckMs=5 дошёл до backend" ($log -match 'request settings\.apply')
    Check "2b: и вернулся structured validation_error" ($log -match 'response settings\.apply ok=false code=validation_error')
    Check "2c: Vue показала текст ошибки backend, canonical не сдвинулся" ($log -match 'request smoke\.rejected-5')

    Check "3a: Apply с blurCheckMs=300 вернулся успехом" ($log -match 'response settings\.apply ok=true')
    Check "3b: канонический state вернулся во Vue и заменил baseline" ($log -match 'request smoke\.saved-300')
    Check "3c: драйвер не сообщил ни одного провала" (-not ($log -match 'smoke\.failed'))

    Check "4a: окно WebView уничтожено на выходе" ($log -match 'webview-destroyed')

    # --- сам файл ----------------------------------------------------
    $after = [IO.File]::ReadAllText($cfg, [Text.Encoding]::Unicode)
    Check "5a: в config.ini записалось blurMs=300" ($after -match '(?m)^blurMs=300\s*$')
    Check "5b: файл остался UTF-16 LE с комментариями пользователя" ($after -match 'Ящик' -and $after -match 'Настройки читаются заново')
    Check "5c: соседние ключи не переписаны" ($after -match '(?m)^animMs=160\s*$' -and $after -match '(?m)^animSteps=14\s*$')
    Check "5d: секция [dynamic] цела" ($after -match '(?m)^width=70\s*$' -and $after -match '(?m)^edge=right\s*$')

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
