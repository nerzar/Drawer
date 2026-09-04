# Runs test\run.ps1 inside the guest and writes everything it prints to
# console.log next to the stage dir. vmrun has no way to stream guest
# stdout back to the host, so this file is the only path results take.
# ASCII-only: this file runs under Windows PowerShell 5.1 in the guest
# (see the warning in run-in-vm.ps1 about BOM-less files and Cyrillic).
param(
    [Parameter(Mandatory)] [string]$StageDir,
    [ValidateSet("safe","apps","all")]
    [string]$Suites = "safe",
    [string[]]$Only  = @()
)

$logPath    = Join-Path $StageDir "console.log"
$scriptPath = Join-Path $StageDir "test\run.ps1"
$sourcePath = Join-Path $StageDir "drawer.ahk"
$utf8       = New-Object System.Text.UTF8Encoding($false)

# A plain array splat (@array) binds positionally and ignores the
# "-Name" look of its own elements - it does NOT do named binding.
# Only a hashtable splat does; that is what @callArgs needs to be.
$callArgs = @{ Source = $sourcePath; Suites = $Suites }
if ($Only.Count) { $callArgs.Only = ($Only -join ",") }

try {
    # *>&1 folds the Information stream in too - run.ps1 writes its
    # output with Write-Host, which *>&1 is the documented way to catch.
    $text = & $scriptPath @callArgs *>&1 | Out-String -Width 500
    $code = $LASTEXITCODE
} catch {
    $text = $_ | Out-String
    $code = 1
}
[System.IO.File]::WriteAllText($logPath, $text, $utf8)
exit $code
