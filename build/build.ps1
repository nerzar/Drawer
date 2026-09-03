<#
Собирает тестовый релиз Drawer: компилирует src\drawer.ahk в один exe
(Ahk2Exe, без консоли, со своей иконкой) и складывает готовую папку
Drawer-<version> рядом с config.ini, README.md и LICENSE.

Использование:
    powershell -ExecutionPolicy Bypass -File build\build.ps1
    powershell -ExecutionPolicy Bypass -File build\build.ps1 -Version v0.2

Ahk2Exe нужен один раз: скачать релиз с
https://github.com/AutoHotkey/Ahk2Exe/releases и распаковать
Ahk2Exe.exe в .tools\Ahk2Exe\ (эта папка — вне git, .gitignore).
#>
param(
    [string]$Version = ""
)

$ErrorActionPreference = "Stop"
$root      = Split-Path -Parent $PSScriptRoot

# Версия хранится в одном месте — в самом src\drawer.ahk, её же показывает
# уведомление при запуске. Читаем оттуда, чтобы имя папки и архива не
# разъехалось с тем, что видит тестер.
if (-not $Version) {
    $src = Get-Content (Join-Path $root "src\drawer.ahk") -Raw -Encoding UTF8
    if ($src -notmatch '(?m)^VERSION\s*:=\s*"([^"]+)"') {
        Write-Error "В src\drawer.ahk не найдена строка VERSION := ""...""}"
    }
    $Version = "v" + $Matches[1]
}
$ahk2exe   = Join-Path $root ".tools\Ahk2Exe\Ahk2Exe.exe"
$base      = "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe"
$outDir    = Join-Path $root "dist\Drawer-$Version"
$exeOut    = Join-Path $outDir "Drawer.exe"

if (!(Test-Path $ahk2exe)) {
    Write-Error "Не найден компилятор: $ahk2exe`nСкачайте релиз с https://github.com/AutoHotkey/Ahk2Exe/releases и распакуйте Ahk2Exe.exe в .tools\Ahk2Exe\"
}
if (!(Test-Path $base)) {
    Write-Error "Не найден интерпретатор AutoHotkey v2: $base`nНужен для сборки как база компиляции (сам exe после сборки AutoHotkey не требует)."
}

New-Item -ItemType Directory -Force -Path $outDir | Out-Null

Write-Host "Компиляция $exeOut ..."
$p = Start-Process -FilePath $ahk2exe -PassThru -Wait -NoNewWindow -ArgumentList @(
    '/in',   (Join-Path $root "src\drawer.ahk"),
    '/out',  $exeOut,
    '/icon', (Join-Path $root "assets\icon.ico"),
    '/base', $base
)
if ($p.ExitCode -ne 0) {
    Write-Error "Ahk2Exe завершился с кодом $($p.ExitCode)"
}

Copy-Item (Join-Path $root "src\config.ini") $outDir -Force
Copy-Item (Join-Path $root "LICENSE")        $outDir -Force
# В архиве два описания: короткое github\README.md — то же, что на
# странице проекта, и подробная инструкция из корня репозитория. Без
# второго тестер, распаковав архив, получает только совет «скачайте из
# Releases» — то есть отсылку к тому, что уже скачано.
# Имя SETUP.md, а не «Инструкция.md»: Compress-Archive записывает имена
# файлов без флага UTF-8, и кириллица в архиве превращается в мусор.
Copy-Item (Join-Path $root "github\README.md") (Join-Path $outDir "README.md") -Force
Copy-Item (Join-Path $root "README.md")        (Join-Path $outDir "SETUP.md")  -Force

$zip = Join-Path $root "dist\Drawer-$Version.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $outDir "*") -DestinationPath $zip

Write-Host "`nГотово: $outDir"
Get-ChildItem $outDir | Format-Table Name, Length
Write-Host "Архив: $zip  ($([math]::Round((Get-Item $zip).Length/1KB)) КБ)"
