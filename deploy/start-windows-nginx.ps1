param(
    [string]$NginxHome = "C:\tools\nginx-1.30.3"
)

$ErrorActionPreference = "Stop"
$nginx = Join-Path $NginxHome "nginx.exe"
$config = Join-Path $PSScriptRoot "nginx\windows-local.conf"

if (-not (Test-Path -LiteralPath $nginx)) {
    throw "nginx.exe not found: $nginx"
}

if (-not (Test-Path -LiteralPath $config)) {
    throw "Nginx config not found: $config"
}

& $nginx -p "$NginxHome\" -c $config -t
if ($LASTEXITCODE -ne 0) {
    throw "Nginx configuration validation failed"
}

$pidFile = Join-Path $NginxHome "logs\md-platform-nginx.pid"
if (Test-Path -LiteralPath $pidFile) {
    $pidRaw = Get-Content -LiteralPath $pidFile -Raw
    $pidValue = if ($null -eq $pidRaw) { "" } else { ([string]$pidRaw).Trim() }
    if ($pidValue -and (Get-Process -Id $pidValue -ErrorAction SilentlyContinue)) {
        Write-Output "Nginx is already running (PID $pidValue)."
        exit 0
    }
}

Start-Process -FilePath $nginx -ArgumentList "-p", "$NginxHome\", "-c", $config -WindowStyle Hidden
$startedPid = ""
for ($attempt = 0; $attempt -lt 20; $attempt++) {
    if (Test-Path -LiteralPath $pidFile) {
        $pidRaw = Get-Content -LiteralPath $pidFile -Raw
        $startedPid = if ($null -eq $pidRaw) { "" } else { ([string]$pidRaw).Trim() }
        if ($startedPid -and (Get-Process -Id $startedPid -ErrorAction SilentlyContinue)) {
            break
        }
    }
    Start-Sleep -Milliseconds 100
}

if (-not $startedPid -or -not (Get-Process -Id $startedPid -ErrorAction SilentlyContinue)) {
    throw "Nginx did not start. Check $NginxHome\logs\md-platform-error.log"
}

Write-Output "Nginx started (PID $startedPid). Open http://127.0.0.1/"
