# Unpacks the freshly copied test stand into the guest staging directory.
# ASCII-only: this file runs under Windows PowerShell 5.1 in the guest
# (see the warning in run-in-vm.ps1 about BOM-less files and Cyrillic).
param(
    [Parameter(Mandatory)] [string]$StageDir
)
$ErrorActionPreference = "Stop"

$zipPath = Join-Path $StageDir "test.zip"
$testDir = Join-Path $StageDir "test"
if (Test-Path $testDir) { Remove-Item $testDir -Recurse -Force }
Expand-Archive -Path $zipPath -DestinationPath $testDir -Force
