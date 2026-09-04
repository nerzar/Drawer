# Bundles run.ps1's per-suite work dir into results.zip so the host can
# pull everything back in one file.
# ASCII-only: this file runs under Windows PowerShell 5.1 in the guest
# (see the warning in run-in-vm.ps1 about BOM-less files and Cyrillic).
param(
    [Parameter(Mandatory)] [string]$StageDir,
    [Parameter(Mandatory)] [string]$VmUser
)
$ErrorActionPreference = "Stop"

$work    = "C:\Users\$VmUser\AppData\Local\Temp\drawer-test"
$zipPath = Join-Path $StageDir "results.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

if (Test-Path $work) {
    Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zipPath -Force
}
