<#
Прогон стенда Drawer.

    powershell -ExecutionPolicy Bypass -File test\run.ps1
    powershell -ExecutionPolicy Bypass -File test\run.ps1 -Suites all
    powershell -ExecutionPolicy Bypass -File test\run.ps1 -Exe dist\Drawer-v0.1.2\Drawer.exe

ВНИМАНИЕ: тесты двигают настоящие окна, мышь и фокус на том рабочем
столе, где запущены. Работать за машиной во время прогона нельзя —
физическая мышь перебивает MouseMove драйвера, и проверки наведения и
щелчка начинают врать. Для этого стенд и сделан переносимым: копируете
папку проекта в изолированную Windows-VM (два монитора, второй слева) и
запускаете там.

Наборы:
  safe   геометрия, поведение, инвариант, тишина, кромки, стыки —
         работают на синтетических окнах, ничего кроме них не трогают
  apps   настоящие приложения и браузер: нужны установленные VS Code,
         Telegram, Chrome и открытое окно браузера
  all    и то и другое
Отдельный набор: -Only geom,kromka (имена из сводки).

Требуется AutoHotkey v2 (интерпретатор) — путь ищется сам, либо -Ahk.
#>
param(
    [string]$Source  = "",
    [string]$Exe     = "",
    [ValidateSet("safe","apps","all")]
    [string]$Suites  = "safe",
    [string[]]$Only  = @(),
    [string]$Ahk     = "",
    [string]$Work    = "",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$here = $PSScriptRoot
if (-not $Source) { $Source = Join-Path $root "src\drawer.ahk" }
if (-not $Work)   { $Work   = Join-Path $env:TEMP "drawer-test" }

# ---------- интерпретатор ----------
if (-not $Ahk) {
    foreach ($p in @("$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe",
                     "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe",
                     "${env:ProgramFiles(x86)}\AutoHotkey\v2\AutoHotkey64.exe")) {
        if (Test-Path $p) { $Ahk = $p; break }
    }
}
if (-not $Ahk -or -not (Test-Path $Ahk)) {
    Write-Error "Не найден AutoHotkey64.exe (v2). Укажите -Ahk <путь> или поставьте: winget install AutoHotkey.AutoHotkey"
}
Write-Host "AutoHotkey: $Ahk"

if ($Exe) {
    if (-not (Test-Path $Exe)) { Write-Error "Не найден exe: $Exe" }
    $Exe = (Resolve-Path $Exe).Path
    Write-Host "Проверяем собранный exe: $Exe"
} else {
    if (-not (Test-Path $Source)) { Write-Error "Не найден исходник: $Source" }
    $Source = (Resolve-Path $Source).Path
    Write-Host "Проверяем исходник: $Source"
}

function Run-Ahk([string[]]$ahkArgs, [int]$timeoutMs = 60000) {
    $p = Start-Process -FilePath $Ahk -ArgumentList $ahkArgs -PassThru
    if (-not $p.WaitForExit($timeoutMs)) { try { $p.Kill() } catch {}; return 255 }
    return $p.ExitCode
}
function Send-Hotkey([string]$hk) {
    Run-Ahk @("`"$here\sendhk.ahk`"", $hk) 8000 | Out-Null
}
function Stop-Drawer([int]$drawerPid) {
    return Run-Ahk @("`"$here\close-drawer.ahk`"", "$drawerPid") 8000
}
function New-Dir([string]$p) {
    if (Test-Path $p) { Remove-Item $p -Recurse -Force }
    New-Item -ItemType Directory -Path $p -Force | Out-Null
}

# ---------- 1. синтаксис ----------
if (-not $Exe) {
    $v = Start-Process -FilePath $Ahk -ArgumentList @("/validate", $Source) -PassThru -Wait -WindowStyle Hidden
    Write-Host "/validate: $($v.ExitCode)"
    if ($v.ExitCode -ne 0) { Write-Error "Исходник не проходит /validate — тесты запускать бессмысленно." }
}

# ---------- 2. раскладка мониторов ----------
New-Dir $Work
$layoutLog = Join-Path $Work "layout.log"
$lay = Run-Ahk @("`"$here\layout.ahk`"", "`"$layoutLog`"") 20000
Get-Content $layoutLog -Encoding UTF8 | ForEach-Object { Write-Host $_ }
if ($lay -ne 0) {
    if ($Force) { Write-Host "Раскладка не та, но -Force — продолжаем. Названия проверок будут врать." -ForegroundColor Yellow }
    else { Write-Error "Раскладка мониторов не подходит стенду. Нужен второй монитор слева от первого. Обойти: -Force" }
}

# ---------- 3. чужой ящик не должен мешать ----------
# Ctrl+Alt+Shift+0 — полный сброс, а не Exit. Никогда не посылаем его
# неизвестному экземпляру: это удалило бы пользовательский config.ini.
$existingDrawer = @(Get-Process Drawer -ErrorAction SilentlyContinue)
if ($existingDrawer.Count) {
    Write-Error ("Перед тестом закройте запущенный Drawer.exe: PID " + (($existingDrawer | ForEach-Object { $_.Id }) -join ", "))
}

# ---------- 4. наборы ----------
$all = @(
    @{ n="geom";    bench="main";    drv="geom.ahk";    kind="safe"; paint=$true  }
    @{ n="behav";   bench="main";    drv="behav.ahk";   kind="safe"; paint=$true; pid=$true }
    @{ n="invar";   bench="main";    drv="invar.ahk";   kind="safe"; paint=$true  }
    @{ n="quiet";   bench="quiet";   drv="quiet.ahk";   kind="safe"; paint=$true; pid=$true; notify=$true }
    @{ n="kromka";  bench="kromka";  drv="kromka.ahk";  kind="safe"; paint=$true; pid=$true }
    @{ n="extra";   bench="kromka2"; drv="extra.ahk";   kind="safe"; pid=$true }
    @{ n="off";     bench="off";     drv="off.ahk";     kind="safe"; paint=$true; pid=$true }
    @{ n="slots";   bench="nine";    drv="slots.ahk";   kind="safe"; pid=$true }
    @{ n="life";    bench="kromka";  drv="life.ahk";    kind="safe"; paint=$true; pid=$true }
    @{ n="load";    bench="nine";    drv="load.ahk";    kind="safe"; pid=$true }
    @{ n="restart"; bench="kromka";  drv="restart.ahk"; kind="safe"; paint=$true; pid=$true; cmdline=$true }
    @{ n="ghost";   bench="kromka";  drv="ghost.ahk";   kind="safe"; pid=$true }
    @{ n="setstat"; bench="main";    drv="setstat.ahk"; kind="safe"; paint=$true; pid=$true; settingsHk=$true; notify=$true }
    @{ n="apps";    bench="apps";    drv="apps.ahk";    kind="apps"; pid=$true }
    @{ n="browser"; bench="apps";    drv="browser.ahk"; kind="apps"; pid=$true }
)
$want = switch ($Suites) {
    "safe" { $all | Where-Object { $_.kind -eq "safe" } }
    "apps" { $all | Where-Object { $_.kind -eq "apps" } }
    "all"  { $all }
}
if ($Only.Count) {
    # При запуске через -File PowerShell отдаёт "a,b,c" одной строкой и
    # массив сам не разбирает, поэтому разбираем здесь.
    $Only = @($Only | ForEach-Object { $_ -split "," } | Where-Object { $_ })
    $want = $all | Where-Object { $Only -contains $_.n }
    if (-not $want) { Write-Error ("Неизвестные наборы: " + ($Only -join ", ") + ". Есть: " + (($all | ForEach-Object { $_.n }) -join ", ")) }
}

# Тишину меряет отдельная сборка: в Notify дописана строка в файл, потому
# что TrayTip не окно и снаружи его не увидеть. С готовым exe так нельзя.
if ($Exe -and ($want | Where-Object { $_.notify })) {
    Write-Host "Набор quiet требует пересборки Notify — с -Exe пропускаю." -ForegroundColor Yellow
    $want = $want | Where-Object { -not $_.notify }
}

if (($want | Where-Object { $_.paint }) -and -not (Get-Process mspaint -ErrorAction SilentlyContinue)) {
    Write-Host "Запускаю mspaint (постоянный слот стенда)"
    Start-Process mspaint.exe
    Start-Sleep -Seconds 4
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
$results = @()

foreach ($s in $want) {
    Write-Host "`n########## $($s.n) ##########"
    $dir = Join-Path $Work $s.n
    New-Dir $dir
    Copy-Item (Join-Path $here "benches\$($s.bench)\config.ini") (Join-Path $dir "config.ini")

    if ($Exe) {
        Copy-Item $Exe (Join-Path $dir "Drawer.exe")
        $target = Join-Path $dir "Drawer.exe"
        $targetArgs = @()
    } else {
        $txt = [System.IO.File]::ReadAllText($Source)
        if ($s.notify) {
            $pat = '(?m)^(\s*)TrayTip\(text, title, opt\)'
            $ins = '$1FileAppend(title " | " text "`n", A_ScriptDir "\notify.log", "UTF-8")   ; только для теста' + "`n" + '$1TrayTip(text, title, opt)'
            $new = $txt -replace $pat, $ins
            if ($new -eq $txt) { Write-Error "Не нашёл TrayTip(text, title, opt) — сборка для набора quiet не получилась." }
            $txt = $new
        }
        if ($s.settingsHk) {
            # У Settings нет намеренно своего хоткея (Р16) — в бою это пункт
            # трея. Тестовые хоткеи и дамп ListView-ячейки вшиваются только в
            # эту копию исходника, как notify вшивает лог TrayTip для quiet.
            $marker = 'A_TrayMenu.Insert("1&", "Settings", (*) => SettingsWebShow())'
            if ($txt.IndexOf($marker) -lt 0) { Write-Error "Не нашёл пункт трея Settings — сборка для набора setstat не получилась." }
            $ins = @'
Hotkey("$^!+F12", (*) => SettingsShow())        ; только для теста
Hotkey("$^!+F11", (*) => SettingsTestDump())    ; только для теста
SettingsTestDump() {
    global setUI
    out := ""
    if (ui := setUI) {
        for idx, r in ui.slotsRows
            out .= r.n "`t" ui.slotsLv.GetText(idx, 7) "`n"
    }
    FileAppend(out, A_ScriptDir "\status.log", "UTF-8")
}
'@
            $txt = $txt.Replace($marker, $marker + "`n" + $ins)
        }
        [System.IO.File]::WriteAllText((Join-Path $dir "drawer.ahk"), $txt, $utf8)
        $target = $Ahk
        $targetArgs = @("`"$dir\drawer.ahk`"")
    }

    if ($s.cmdline) {
        $line = if ($targetArgs.Count) { "`"$target`" " + ($targetArgs -join " ") }
                else { "`"$target`"" }
        [System.IO.File]::WriteAllText((Join-Path $dir "launch.txt"), $line, $utf8)
    }
    $drawer = Start-Process -FilePath $target -ArgumentList $targetArgs -PassThru
    Start-Sleep -Seconds 2
    if ($drawer.HasExited) {
        Write-Host "ящик не запустился (код $($drawer.ExitCode))" -ForegroundColor Red
        $results += @{ n=$s.n; line="ящик не запустился"; bad=$true }
        continue
    }

    $log = Join-Path $dir "$($s.n).log"
    $drvArgs = @("`"$here\drivers\$($s.drv)`"", "`"$log`"")
    if ($s.pid)    { $drvArgs += "$($drawer.Id)" }
    # Драйверу перезапусков нужно поднимать ящик самому. Команда кладётся
    # файлом рядом со стендом, а драйверу отдаётся только путь к папке:
    # вложенные кавычки в аргументах ломаются слишком легко.
    if ($s.cmdline) { $drvArgs += "`"$dir`"" }
    if ($s.settingsHk) { $drvArgs += "`"$dir\status.log`"" }
    if ($s.notify) { $drvArgs += "`"$dir\notify.log`"" }
    $t = Start-Process -FilePath $Ahk -ArgumentList $drvArgs -PassThru
    if (-not $t.WaitForExit(600000)) {
        Write-Host "ДРАЙВЕР ЗАВИС" -ForegroundColor Red
        try { $t.Kill() } catch {}
    }

    $closeCode = Stop-Drawer $drawer.Id
    Start-Sleep -Milliseconds 500
    if (-not $drawer.HasExited) {
        Write-Host "ящик не закрылся через hidden main window (код $closeCode) — снимаю точный PID $($drawer.Id)" -ForegroundColor Yellow
        try { $drawer.Kill() } catch {}
    }

    if (Test-Path $log) {
        Get-Content $log -Encoding UTF8 | Out-String -Width 220 | Write-Host
        $it = (Select-String -Path $log -Pattern "^ИТОГ" | Select-Object -Last 1).Line
        $err = Select-String -Path $log -Pattern "^ОШИБКА" | Select-Object -Last 1
        $bad = (-not $it) -or ($it -notmatch "провалов 0") -or $err
        $results += @{ n=$s.n; line=$(if ($it) { $it.Trim() } else { "итога нет" }) + $(if ($err) { "  + " + $err.Line } else { "" }); bad=$bad }
    } else {
        $results += @{ n=$s.n; line="лога нет"; bad=$true }
    }
}

# ---------- 5. не осталось ли окон за экранами ----------
Write-Host "`n########## после прогона ##########"
$strandLog = Join-Path $Work "strand.log"
$st = Run-Ahk @("`"$here\strand.ahk`"", "`"$strandLog`"") 30000
Get-Content $strandLog -Encoding UTF8 | ForEach-Object { Write-Host $_ }

Write-Host "`n########## СВОДКА ##########"
$failed = 0
foreach ($r in $results) {
    if ($r.bad) { $failed++ }
    $c = if ($r.bad) { "Red" } else { "Green" }
    Write-Host ("{0,-9} {1}" -f $r.n, $r.line) -ForegroundColor $c
}
if ($st -ne 0) { $failed++; Write-Host "окна остались за пределами экранов — см. выше" -ForegroundColor Red }
Write-Host ("наборов: {0}, с провалами: {1}" -f $results.Count, $failed)
Write-Host "логи и сборки: $Work"
exit $(if ($failed) { 1 } else { 0 })
