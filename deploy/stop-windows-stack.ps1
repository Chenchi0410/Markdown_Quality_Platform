param(
    [string]$NginxHome = "C:\tools\nginx-1.30.3"
)

$ErrorActionPreference = "Stop"
$runtimeDir = Join-Path $PSScriptRoot ".windows-run"

try {
    & (Join-Path $PSScriptRoot "stop-windows-nginx.ps1") -NginxHome $NginxHome
} catch {
    Write-Warning $_.Exception.Message
}

foreach ($name in @("portal", "syntax-frontend", "syntax-api", "dataset-builder", "evaluation")) {
    $pidFile = Join-Path $runtimeDir "$name.pid"
    if (-not (Test-Path -LiteralPath $pidFile)) {
        continue
    }
    $pidValue = (Get-Content -LiteralPath $pidFile -Raw).Trim()
    $process = if ($pidValue) { Get-Process -Id $pidValue -ErrorAction SilentlyContinue } else { $null }
    if ($process) {
        Stop-Process -Id $process.Id -Force
        Write-Output "$name stopped (PID $pidValue)."
    }
    Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
}
