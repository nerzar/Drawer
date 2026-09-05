<#
Собирает тестовый релиз Drawer: собирает фронтенд Settings, компилирует
src\drawer.ahk в один exe (Ahk2Exe, без консоли, со своей иконкой) и
складывает готовую папку Drawer-<version> рядом с config.ini, README.md
и LICENSE.

Ассеты WebView Settings — index.html фронтенда и WebView2Loader.dll —
вшиваются в exe через FileInstall (см. src\SettingsWebAssets.ahk) и
распаковываются во временную папку при первом открытии настроек. В папке
релиза их нет и быть не должно: на машине пользователя ни node, ни
npm run build не нужны.

Использование:
    powershell -ExecutionPolicy Bypass -File build\build.ps1
    powershell -ExecutionPolicy Bypass -File build\build.ps1 -Version v0.2
    powershell -ExecutionPolicy Bypass -File build\build.ps1 -SkipFrontend

Ahk2Exe нужен один раз: скачать релиз с
https://github.com/AutoHotkey/Ahk2Exe/releases и распаковать
Ahk2Exe.exe в .tools\Ahk2Exe\ (эта папка — вне git, .gitignore).
Для сборки фронтенда нужен Node.js; -SkipFrontend берёт уже собранный
src\webview\web\index.html как есть.
#>
param(
    [string]$Version = "",
    [switch]$SkipFrontend
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

# --- ассеты WebView Settings ------------------------------------------
$webDir = Join-Path $root "src\webview\web"
$loader = Join-Path $root "src\webview\vendor\webviewtoo\64bit\WebView2Loader.dll"

if (-not $SkipFrontend) {
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Error "Не найден npm. Установите Node.js или соберите фронтенд заранее и запустите с -SkipFrontend."
    }
    Write-Host "Сборка фронтенда Settings ..."
    Push-Location (Join-Path $root "settings-ui")
    try {
        if (-not (Test-Path "node_modules")) {
            & npm ci --no-audit --no-fund
            if ($LASTEXITCODE -ne 0) { Write-Error "npm ci завершился с кодом $LASTEXITCODE" }
        }
        & npm run build
        if ($LASTEXITCODE -ne 0) { Write-Error "npm run build завершился с кодом $LASTEXITCODE" }
    } finally { Pop-Location }
}

# Однофайловость — условие упаковки, а не стиль: FileInstall принимает
# только литеральное имя, а обычная сборка Vite даёт assets/*-<hash>.js,
# где хеш меняется каждый раз. Проверяем инвариант здесь, чтобы поломка
# конфигурации Vite не уехала в релиз молча недостающим ассетом.
$webFiles = @(Get-ChildItem $webDir -Recurse -File -ErrorAction SilentlyContinue)
if ($webFiles.Count -ne 1 -or $webFiles[0].Name -ne "index.html") {
    $found = ($webFiles | ForEach-Object { $_.Name }) -join ", "
    Write-Error "Ожидался ровно один файл $webDir\index.html, найдено ($($webFiles.Count)): $found`nПроверьте viteSingleFile в settings-ui\vite.config.js."
}
if (-not (Test-Path $loader)) {
    Write-Error "Не найден $loader — без него WebView2 не поднимется: WebView2.ahk зовёт эту библиотеку через DllCall."
}
$payload = $webFiles[0].Length + (Get-Item $loader).Length
Write-Host ("Ассеты WebView: index.html {0} КБ + WebView2Loader.dll {1} КБ" -f `
    [math]::Round($webFiles[0].Length/1KB), [math]::Round((Get-Item $loader).Length/1KB))

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

# Ahk2Exe находит FileInstall только в главном скрипте и молча пропускает
# директиву, до которой не добрался: компиляция считается успешной, а exe
# уезжает без ассетов, и ломается это лишь в рантайме. По размеру такое не
# ловится — текст исходников сам по себе больше нагрузки. Поэтому ищем в
# exe кусок каждого ассета байт в байт.
function Test-Embedded {
    param([string]$ExePath, [string]$AssetPath)
    # Latin1 сохраняет байты один в один, поэтому поиск идёт обычным
    # IndexOf по строке, а не поэлементным циклом по массиву.
    $l1 = [Text.Encoding]::Latin1
    $bytes = [IO.File]::ReadAllBytes($AssetPath)
    # Кусок из середины: начало DLL — PE-заголовок, он есть и у самого
    # exe, и совпадение по нему ничего не доказывало бы.
    $off = [int]($bytes.Length / 2)
    $needle = $l1.GetString($bytes[$off..($off + 255)])
    return $l1.GetString([IO.File]::ReadAllBytes($ExePath)).IndexOf($needle) -ge 0
}

foreach ($asset in @($webFiles[0].FullName, $loader)) {
    if (-not (Test-Embedded -ExePath $exeOut -AssetPath $asset)) {
        Write-Error "Ассет не попал в exe: $asset`nAhk2Exe видит FileInstall только как начало инструкции: 'try FileInstall(...)' одной строкой он пропускает молча. Проверьте src\webview\SettingsWebAssets.ahk."
    }
}
Write-Host "Ассеты найдены внутри exe: index.html, WebView2Loader.dll"

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
