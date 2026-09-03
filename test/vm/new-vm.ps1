<#
Создаёт виртуальную машину для стенда: два экрана 1920x1080, второй
слева от первого, автоустановка Windows с ISO, Guest Additions, копия
AutoHotkey внутрь. После этого VM готова к test\vm\run-in-vm.ps1.

    powershell -ExecutionPolicy Bypass -File test\vm\new-vm.ps1 -Iso D:\iso\win11.iso

ISO нужен свой: Windows 11 Enterprise (оценочная, 90 дней) с
microsoft.com/evalcenter — там форма регистрации, скачивать надо руками.

Установка идёт 20-40 минут без вопросов. Скрипт ждёт, пока в госте
заработает управление, и только тогда возвращает управление.

Всё, что здесь есть, проверено по VBoxManage --help версии 7.2, но
целиком прогон возможен только с ISO на руках — до первого запуска это
непроверенный код.
#>
param(
    [Parameter(Mandatory=$true)][string]$Iso,
    [string]$Name       = "drawer-test",
    [int]$Ram           = 4096,
    [int]$Cpus          = 4,
    [int]$DiskMb        = 65536,
    [string]$User       = "tester",
    [string]$Password   = "tester",
    [int]$ImageIndex    = 1,
    [string]$Locale     = "ru_RU",
    [string]$Country    = "RU",
    [switch]$Gui,
    [int]$InstallWaitMin = 60
)

$ErrorActionPreference = "Stop"
$vb = "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe"
if (-not (Test-Path $vb)) { Write-Error "Не найден VBoxManage: $vb" }
if (-not (Test-Path $Iso)) { Write-Error "Не найден ISO: $Iso" }
$Iso = (Resolve-Path $Iso).Path

function Vb { & $vb @args; if ($LASTEXITCODE -ne 0) { Write-Error "VBoxManage $($args -join ' ') -> код $LASTEXITCODE" } }

if ((& $vb list vms) -match "^`"$([regex]::Escape($Name))`"") {
    Write-Error "ВМ `"$Name`" уже есть. Удалить: VBoxManage unregistervm `"$Name`" --delete"
}

Write-Host "1/6  создаю ВМ"
Vb createvm --name $Name --platform-architecture x86 --ostype Windows11_64 --register

# Два экрана 1920x1080 требуют около 16 МБ видеопамяти; 128 — с запасом.
# Windows 11 не ставится без EFI и TPM 2.0, поэтому они не опциональны.
Write-Host "2/6  настраиваю железо"
Vb modifyvm $Name --memory $Ram --cpus $Cpus --vram 128 `
    --monitor-count 2 --graphicscontroller vboxsvga `
    --firmware efi --tpm-type 2.0 `
    --nic1 nat --audio-driver none `
    --clipboard-mode bidirectional --drag-and-drop disabled
Vb modifynvram $Name enrollmssignatures
Vb modifynvram $Name secureboot --enable

Write-Host "3/6  диск и контроллер"
$vmDir = Split-Path -Parent ((& $vb showvminfo $Name --machinereadable | Select-String '^CfgFile=').Line -replace '^CfgFile="(.*)"$', '$1')
$vdi = Join-Path $vmDir "$Name.vdi"
Vb createmedium disk --filename $vdi --size $DiskMb --format VDI
Vb storagectl $Name --name SATA --add sata --controller IntelAhci --portcount 2 --bootable on
Vb storageattach $Name --storagectl SATA --port 0 --device 0 --type hdd --medium $vdi
Vb storageattach $Name --storagectl SATA --port 1 --device 0 --type dvddrive --medium emptydrive

Write-Host "4/6  автоустановка Windows (20-40 минут, вопросов не будет)"
Vb unattended install $Name --iso $Iso `
    --user $User --user-password $Password --full-user-name $User `
    --install-additions --locale $Locale --country $Country `
    --image-index $ImageIndex `
    --start-vm $(if ($Gui) { "gui" } else { "headless" })

Write-Host "5/6  жду, пока в госте заработает управление (до $InstallWaitMin мин)"
$deadline = (Get-Date).AddMinutes($InstallWaitMin)
$ready = $false
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 20
    & $vb guestcontrol $Name run --username $User --password $Password `
        --timeout 20000 --wait-stdout --exe "C:\Windows\System32\cmd.exe" `
        -- cmd.exe /c echo ready 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { $ready = $true; break }
    Write-Host "." -NoNewline
}
Write-Host ""
if (-not $ready) { Write-Error "Гость так и не отозвался. Посмотрите на него: VBoxManage startvm `"$Name`" --type gui" }

Write-Host "6/6  раскладываю экраны и кладу AutoHotkey в гостя"
# Второй экран слева от первого — от этого зависит, какие края
# внутренние, и половина проверок инварианта именно это и меряет.
Vb controlvm $Name setscreenlayout 0 primary 0 0 1920 1080 32
Start-Sleep -Seconds 2
Vb controlvm $Name setscreenlayout 1 on -1920 0 1920 1080 32
Start-Sleep -Seconds 3

$ahkHost = @("$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe",
             "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe") |
           Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $ahkHost) { Write-Error "На хосте не найден AutoHotkey64.exe — скопировать в гостя нечего." }
Vb guestcontrol $Name mkdir --username $User --password $Password --parents "C:\drawer-test\ahk"
Vb guestcontrol $Name copyto --username $User --password $Password `
    --target-directory "C:\drawer-test\ahk" $ahkHost

Write-Host @"

Готово. Дальше:

  1. Проверьте раскладку экранов в госте — она должна быть
     "монитор 2 слева от монитора 1". Если setscreenlayout не подействовал,
     зайдите в гостя (VBoxManage startvm "$Name" --type gui) и перетащите
     второй экран влево в параметрах дисплея. Стенд сам откажется
     работать на неправильной раскладке, молча неверных результатов не будет.

  2. Снимок чистого состояния, чтобы каждый прогон начинался с него:
     VBoxManage snapshot "$Name" take чисто --pause
     VBoxManage controlvm "$Name" resume

  3. Прогон:
     powershell -ExecutionPolicy Bypass -File test\vm\run-in-vm.ps1
"@
