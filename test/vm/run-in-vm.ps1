<#
Прогоняет стенд Drawer внутри VM (VMware Workstation) и приносит логи
обратно. Рабочий стол хоста при этом не трогается: гость запускается
nogui, мышь и окна двигаются только внутри него.

    powershell -ExecutionPolicy Bypass -File test\vm\run-in-vm.ps1
    powershell -ExecutionPolicy Bypass -File test\vm\run-in-vm.ps1 -Suites all
    powershell -ExecutionPolicy Bypass -File test\vm\run-in-vm.ps1 -Snapshot base-ahk-v2

ВНИМАНИЕ: запускать через pwsh (PowerShell 7), не через powershell.exe
(Windows PowerShell 5.1) — 5.1 читает этот файл без BOM как ANSI и
ломает кириллицу в комментариях/строках.

VM и стенд в госте настраиваются один раз вручную (два монитора через
Full Screen + Cycle Multiple Monitors, AutoHotkey v2) — см. память
проекта drawer-vm-vmware. Это состояние держит снимок base-ahk-v2:
проверено, что и раскладка мониторов, и наличие AHK переживают откат
и старт в nogui без открытого окна. Здесь VM только запускается,
получает свежий исходник и отдаёт логи.

Заменяет старую VBoxManage-версию этого скрипта (стенд теперь на
VMware — у VirtualBox оказался неисправимый баг рендера второго
монитора). Старая версия ни разу не была прогнана до конца и была
рассинхронизирована с реальной VM (не то имя, не тот пользователь) —
эта видимость истории не нужна, правки внесены напрямую.

vmrun-ловушки, из-за которых этот скрипт не тривиален (см. память
drawer-vm-vmware):
- runProgramInGuest БЕЗ -interactive выполняется в фоновой сессии, не
  видит рабочий стол — всегда добавлять -interactive.
- cmd.exe через -interactive стабильно отдаёт код 1 независимо от
  команды (необъяснено, просто избегать) — все пробники на powershell.
- runScriptInGuest создаёт временный файл без расширения ("vixScript0")
  и пытается открыть его через ассоциацию приложений — Windows не
  знает чем, и виснет на диалоге "Выберите приложение". НЕ
  ИСПОЛЬЗОВАТЬ runScriptInGuest вообще. Только runProgramInGuest с
  настоящими .ps1-файлами (-File), скопированными заранее.
- vmrun не умеет ни рекурсивное копирование папок, ни таймаут на
  гостевую команду, ни стриминг stdout — всё это сделано руками ниже.
#>
param(
    [string]$Vmx        = "D:\VMware\win\Windows 11 x64.vmx",
    [string]$VmUser     = "TEST",
    [string]$VmPassword = "1211",
    [string]$Source     = "",
    [ValidateSet("safe","apps","all")]
    [string]$Suites     = "safe",
    [string[]]$Only     = @(),
    [string]$Snapshot   = "",
    [string]$OutDir     = "",
    [switch]$Gui,
    [switch]$KeepRunning,
    [int]$BootWaitMin   = 10,
    [int]$RunTimeoutMin = 60
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$here = $PSScriptRoot

# ---------- vmrun ----------
$vmrun = $null
foreach ($p in @(
    "$env:ProgramFiles\VMware\VMware Workstation\vmrun.exe",
    "${env:ProgramFiles(x86)}\VMware\VMware Workstation\vmrun.exe"
)) { if (Test-Path $p) { $vmrun = $p; break } }
if (-not $vmrun) {
    # Нестандартная установка (например на другом диске) — не попадает
    # ни в Program Files, ни в InstallLocation из реестра; найдена
    # через путь службы, которую регистрирует сам инсталлятор.
    $svc = Get-CimInstance Win32_Service -Filter "Name='VMAuthdService'" -ErrorAction SilentlyContinue
    if ($svc -and $svc.PathName -match '^"?(.+)\\vmware-authd\.exe"?$') {
        $cand = Join-Path $Matches[1] "vmrun.exe"
        if (Test-Path $cand) { $vmrun = $cand }
    }
}
if (-not $vmrun) { Write-Error "Не найден vmrun.exe. Укажите путь вручную в начале скрипта." }
Write-Host "vmrun: $vmrun"

if (-not (Test-Path $Vmx)) { Write-Error "Не найден .vmx: $Vmx" }
if (-not $Source) { $Source = Join-Path $root "src\drawer.ahk" }
if (-not (Test-Path $Source)) { Write-Error "Не найден исходник: $Source" }
if (-not $OutDir) { $OutDir = Join-Path $env:TEMP "drawer-vm-logs" }

$psExeGuest = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
$stageDir   = "C:\drawer-test"

function VmHost([string[]]$a) {
    & $vmrun -T ws @a
    if ($LASTEXITCODE -ne 0) { Write-Error "vmrun $($a -join ' ') -> код $LASTEXITCODE" }
}
function VmGuest([string[]]$a) {
    & $vmrun -T ws -gu $VmUser -gp $VmPassword @a
    if ($LASTEXITCODE -ne 0) { Write-Error "vmrun (гость) $($a -join ' ') -> код $LASTEXITCODE" }
}
# Не бросает — для проверок готовности и лучше-удаления-чем-упасть.
function TryVmGuest([string[]]$a) {
    & $vmrun -T ws -gu $VmUser -gp $VmPassword @a 2>&1 | Out-Null
    return $LASTEXITCODE
}
function IsRunning {
    $out = & $vmrun -T ws list
    return ($out -join "`n") -match [regex]::Escape($Vmx)
}
# vmrun не умеет таймаут на длинные гостевые команды сам — оборачиваем
# через Start-Process, как run.ps1 делает для AHK-процессов.
# ВАЖНО: -ArgumentList массивом НЕ квотирует элементы с пробелами (путь
# к .vmx выше — "...\Windows 11 x64.vmx" — рвётся ровно на этом
# пробеле, vmrun получает битый путь и падает с "unknown file suffix").
# Собираем одну pre-quoted строку и отдаём её как единственный элемент.
function Invoke-VmrunTimeout([string[]]$vmrunArgs, [int]$timeoutMs) {
    $argLine = ($vmrunArgs | ForEach-Object {
        if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ }
    }) -join ' '
    $p = Start-Process -FilePath $vmrun -ArgumentList $argLine -PassThru -NoNewWindow
    if (-not $p.WaitForExit($timeoutMs)) {
        Write-Host "КОМАНДА ЗАВИСЛА, снимаю" -ForegroundColor Red
        try { $p.Kill() } catch {}
        return -1
    }
    return $p.ExitCode
}

# ---------- запуск ----------
if ($Snapshot) {
    if (IsRunning) {
        # Не бросаем: revertToSnapshot ниже отрабатывает и на живой VM
        # (сбрасывает текущее состояние на снимок), так что неудачный
        # stop тут не повод останавливать весь скрипт.
        try { VmHost @("stop", $Vmx, "soft") } catch { Write-Host "мягкий stop перед откатом не удался: $_" -ForegroundColor Yellow }
        Start-Sleep -Seconds 5
    }
    Write-Host "откатываю на снимок `"$Snapshot`""
    VmHost @("revertToSnapshot", $Vmx, $Snapshot)
}
if (-not (IsRunning)) {
    Write-Host "запускаю VM ($(if ($Gui) { 'с окном' } else { 'nogui' }))"
    VmHost @("start", $Vmx, $(if ($Gui) { "gui" } else { "nogui" }))
}

Write-Host "жду готовности гостя (до $BootWaitMin мин)" -NoNewline
$deadline = (Get-Date).AddMinutes($BootWaitMin)
$ready = $false
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 10
    $code = TryVmGuest @("runProgramInGuest", $Vmx, "-interactive", $psExeGuest, "-NoProfile", "-Command", "exit")
    if ($code -eq 0) { $ready = $true; break }
    Write-Host "." -NoNewline
}
Write-Host ""
if (-not $ready) { Write-Error "Гость не отозвался. Посмотреть: & `"$vmrun`" -T ws captureScreen `"$Vmx`" guest.png" }

# ---------- заливаем свежий стенд ----------
# У vmrun нет рекурсивного копирования папок — упаковываем в zip,
# распаковываем уже внутри гостя настоящим .ps1-файлом (не
# runScriptInGuest — см. предупреждение в начале файла).
Write-Host "собираю стенд в архив"
$zipLocal = Join-Path $env:TEMP "drawer-test-$([guid]::NewGuid()).zip"
Compress-Archive -Path (Join-Path $root "test\*") -DestinationPath $zipLocal -Force

Write-Host "копирую стенд, исходник и вспомогательные скрипты в гостя"
TryVmGuest @("deleteDirectoryInGuest", $Vmx, $stageDir) | Out-Null
VmGuest @("createDirectoryInGuest", $Vmx, $stageDir)
VmGuest @("CopyFileFromHostToGuest", $Vmx, $zipLocal, "$stageDir\test.zip")
VmGuest @("CopyFileFromHostToGuest", $Vmx, $Source, "$stageDir\drawer.ahk")
VmGuest @("CopyFileFromHostToGuest", $Vmx, (Join-Path $here "helpers\unzip-stage.ps1"), "$stageDir\unzip-stage.ps1")
VmGuest @("CopyFileFromHostToGuest", $Vmx, (Join-Path $here "helpers\run-suite.ps1"),   "$stageDir\run-suite.ps1")
VmGuest @("CopyFileFromHostToGuest", $Vmx, (Join-Path $here "helpers\zip-results.ps1"), "$stageDir\zip-results.ps1")
Remove-Item $zipLocal -Force

VmGuest @("runProgramInGuest", $Vmx, "-interactive", $psExeGuest,
          "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "$stageDir\unzip-stage.ps1",
          "-StageDir", $stageDir)

# ---------- прогон ----------
Write-Host "`n########## прогон внутри VM ##########"
$vrArgs = @("-T","ws","-gu",$VmUser,"-gp",$VmPassword,
            "runProgramInGuest",$Vmx,"-interactive",$psExeGuest,
            "-NoProfile","-ExecutionPolicy","Bypass","-File","$stageDir\run-suite.ps1",
            "-StageDir",$stageDir,"-Suites",$Suites)
if ($Only.Count) { $vrArgs += @("-Only", ($Only -join ",")) }
$code = Invoke-VmrunTimeout $vrArgs ($RunTimeoutMin * 60000)
Write-Host "########## гостевой процесс завершился с кодом: $code ##########`n"

# ---------- забираем логи ----------
if (Test-Path $OutDir) { Remove-Item $OutDir -Recurse -Force }
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

TryVmGuest @("runProgramInGuest", $Vmx, "-interactive", $psExeGuest,
             "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "$stageDir\zip-results.ps1",
             "-StageDir", $stageDir, "-VmUser", $VmUser) | Out-Null
$zipBackLocal = Join-Path $OutDir "results.zip"
if ((TryVmGuest @("CopyFileFromGuestToHost", $Vmx, "$stageDir\results.zip", $zipBackLocal)) -eq 0) {
    Expand-Archive -Path $zipBackLocal -DestinationPath $OutDir -Force
    Remove-Item $zipBackLocal -Force
}
TryVmGuest @("CopyFileFromGuestToHost", $Vmx, "$stageDir\console.log", (Join-Path $OutDir "console.log")) | Out-Null
& $vmrun -T ws captureScreen $Vmx (Join-Path $OutDir "guest-screen.png") 2>&1 | Out-Null
Write-Host "логи: $OutDir"

# ---------- сводка из console.log ----------
$consoleLocal = Join-Path $OutDir "console.log"
$failed = $true
if (Test-Path $consoleLocal) {
    Get-Content $consoleLocal -Encoding UTF8 | ForEach-Object { Write-Host $_ }
    $summary = Select-String -Path $consoleLocal -Pattern "с провалами: (\d+)" | Select-Object -Last 1
    if ($summary) { $failed = [int]$summary.Matches[0].Groups[1].Value -ne 0 }
} else {
    Write-Host "console.log не вернулся — считаю прогон проваленным" -ForegroundColor Red
}

# ---------- выключение ----------
if (-not $KeepRunning) {
    Write-Host "выключаю VM"
    # Мягкий stop иногда отдаёт код ошибки (например если гость ещё
    # занят предыдущей guestcontrol-сессией) — это не повод обрывать
    # скрипт до резервного hard stop ниже, поэтому не бросаем.
    try { VmHost @("stop", $Vmx, "soft") } catch { Write-Host "мягкий stop не удался: $_" -ForegroundColor Yellow }
    $offDeadline = (Get-Date).AddMinutes(3)
    while ((Get-Date) -lt $offDeadline -and (IsRunning)) { Start-Sleep -Seconds 5 }
    if (IsRunning) { VmHost @("stop", $Vmx, "hard") }
}
exit $(if ($failed) { 1 } else { 0 })
