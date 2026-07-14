param(
    [string]$NginxHome = "C:\tools\nginx-1.30.3"
)

$ErrorActionPreference = "Stop"
$nginx = Join-Path $NginxHome "nginx.exe"
$config = Join-Path $PSScriptRoot "nginx\windows-local.conf"

if (-not (Test-Path -LiteralPath $nginx)) {
    throw "nginx.exe not found: $nginx"
}

& $nginx -p "$NginxHome\" -c $config -s quit
if ($LASTEXITCODE -ne 0) {
    throw "Nginx stop command failed"
}

Write-Output "Nginx stopped."
