<#
Прогоняет стенд внутри виртуальной машины и приносит логи обратно.
Рабочий стол хоста при этом не трогается вообще: гость работает
headless, мышь и окна двигаются внутри него.

    powershell -ExecutionPolicy Bypass -File test\vm\run-in-vm.ps1
    powershell -ExecutionPolicy Bypass -File test\vm\run-in-vm.ps1 -Suites all
    powershell -ExecutionPolicy Bypass -File test\vm\run-in-vm.ps1 -Snapshot чисто

ВМ создаётся скриптом new-vm.ps1. Здесь она только запускается,
получает свежий исходник и отдаёт логи.
#>
param(
    [string]$Name     = "drawer-test",
    [string]$User     = "tester",
    [string]$Password = "tester",
    [string]$Source   = "",
    [ValidateSet("safe","apps","all")]
    [string]$Suites   = "safe",
    [string[]]$Only   = @(),
    [string]$Snapshot = "",
    [string]$OutDir   = "",
    [switch]$Gui,
    [switch]$KeepRunning,
    [int]$BootWaitMin = 10,
    [int]$RunTimeoutMin = 60
)

$ErrorActionPreference = "Stop"
$vb   = "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not (Test-Path $vb)) { Write-Error "Не найден VBoxManage: $vb" }
if (-not $Source) { $Source = Join-Path $root "src\drawer.ahk" }
if (-not (Test-Path $Source)) { Write-Error "Не найден исходник: $Source" }
if (-not $OutDir) { $OutDir = Join-Path $env:TEMP "drawer-vm-logs" }

$G = @("guestcontrol", $Name, "--username", $User, "--password", $Password)
function Vb { & $vb @args; if ($LASTEXITCODE -ne 0) { Write-Error "VBoxManage $($args -join ' ') -> код $LASTEXITCODE" } }
function VmState { ((& $vb showvminfo $Name --machinereadable | Select-String '^VMState=').Line -replace '^VMState="(.*)"$', '$1') }

# ---------- запуск ----------
if ($Snapshot) {
    if ((VmState) -ne "poweroff") { Vb controlvm $Name poweroff; Start-Sleep -Seconds 5 }
    Write-Host "откатываю на снимок `"$Snapshot`""
    Vb snapshot $Name restore $Snapshot
}
if ((VmState) -ne "running") {
    Write-Host "запускаю ВМ ($(if ($Gui) { 'с окном' } else { 'headless' }))"
    Vb startvm $Name --type $(if ($Gui) { "gui" } else { "headless" })
}

Write-Host "жду готовности гостя (до $BootWaitMin мин)" -NoNewline
$deadline = (Get-Date).AddMinutes($BootWaitMin)
$ready = $false
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 10
    & $vb @G run --timeout 20000 --wait-stdout --exe "C:\Windows\System32\cmd.exe" -- cmd.exe /c echo ready 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { $ready = $true; break }
    Write-Host "." -NoNewline
}
Write-Host ""
if (-not $ready) { Write-Error "Гость не отозвался. Посмотреть: VBoxManage controlvm `"$Name`" screenshotpng guest.png" }

# Экраны выставляем каждый раз: после отката снимка раскладка могла
# вернуться к той, что была на момент снимка.
& $vb controlvm $Name setscreenlayout 0 primary 0 0 1920 1080 32 2>&1 | Out-Null
Start-Sleep -Seconds 2
& $vb controlvm $Name setscreenlayout 1 on -1920 0 1920 1080 32 2>&1 | Out-Null
Start-Sleep -Seconds 3

# ---------- заливаем свежий стенд ----------
Write-Host "копирую стенд и исходник в гостя"
& $vb @G rmdir --recursive "C:\drawer-test\test" 2>&1 | Out-Null
& $vb @G rmdir --recursive "C:\drawer-test\src"  2>&1 | Out-Null
Vb @G mkdir --parents "C:\drawer-test\src"
Vb @G copyto --recursive --target-directory "C:\drawer-test" (Join-Path $root "test")
Vb @G copyto --target-directory "C:\drawer-test\src" $Source

# ---------- прогон ----------
# $args -- это автоматическая переменная PowerShell, своей её делать нельзя.
$psArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass",
            "-File", "C:\drawer-test\test\run.ps1",
            "-Ahk", "C:\drawer-test\ahk\AutoHotkey64.exe",
            "-Suites", $Suites)
if ($Only.Count) { $psArgs += @("-Only", ($Only -join ",")) }
Write-Host "`n########## прогон внутри ВМ ##########"
& $vb @G run --timeout ($RunTimeoutMin * 60000) --wait-stdout --wait-stderr `
    --exe "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -- powershell.exe @psArgs
$code = $LASTEXITCODE
Write-Host "########## код возврата: $code ##########`n"

# ---------- забираем логи и снимок экрана ----------
if (Test-Path $OutDir) { Remove-Item $OutDir -Recurse -Force }
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
& $vb @G copyfrom --recursive --target-directory $OutDir "C:\Users\$User\AppData\Local\Temp\drawer-test" 2>&1 | Out-Null
& $vb controlvm $Name screenshotpng (Join-Path $OutDir "guest-screen0.png") 0 2>&1 | Out-Null
& $vb controlvm $Name screenshotpng (Join-Path $OutDir "guest-screen1.png") 1 2>&1 | Out-Null
Write-Host "логи и снимки экранов: $OutDir"

if (-not $KeepRunning) {
    Write-Host "выключаю ВМ"
    & $vb controlvm $Name acpipowerbutton 2>&1 | Out-Null
    $off = (Get-Date).AddMinutes(3)
    while ((Get-Date) -lt $off -and (VmState) -eq "running") { Start-Sleep -Seconds 5 }
    if ((VmState) -eq "running") { & $vb controlvm $Name poweroff 2>&1 | Out-Null }
}
exit $code
