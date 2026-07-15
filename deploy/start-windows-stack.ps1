param(
    [string]$EvaluationRoot = "C:\Users\sangzs1\doc-eval",
    [string]$DatasetBuilderRoot = "C:\Users\sangzs1\Construct_dataset_webserver",
    [string]$SyntaxRoot = "C:\Users\sangzs1\Grammar_Check_Webserver",
    [string]$PortalRoot = "C:\Users\sangzs1\Markdown_Quality_Platform",
    [string]$NginxHome = "C:\tools\nginx-1.30.3"
)

$ErrorActionPreference = "Stop"
$runtimeDir = Join-Path $PSScriptRoot ".windows-run"
New-Item -ItemType Directory -Path $runtimeDir -Force | Out-Null

function Start-ManagedProcess {
    param(
        [string]$Name,
        [string]$FilePath,
        [string[]]$Arguments,
        [string]$WorkingDirectory
    )

    if (-not (Test-Path -LiteralPath $FilePath)) {
        throw "$Name executable not found: $FilePath"
    }

    $pidFile = Join-Path $runtimeDir "$Name.pid"
    if (Test-Path -LiteralPath $pidFile) {
        $existingPid = (Get-Content -LiteralPath $pidFile -Raw).Trim()
        if ($existingPid -and (Get-Process -Id $existingPid -ErrorAction SilentlyContinue)) {
            Write-Output "$Name is already running (PID $existingPid)."
            return
        }
    }

    $stdout = Join-Path $runtimeDir "$Name.out.log"
    $stderr = Join-Path $runtimeDir "$Name.err.log"
    $startParameters = @{
        FilePath = $FilePath
        ArgumentList = $Arguments
        WorkingDirectory = $WorkingDirectory
        RedirectStandardOutput = $stdout
        RedirectStandardError = $stderr
        WindowStyle = "Hidden"
        PassThru = $true
    }
    $process = Start-Process @startParameters
    Set-Content -LiteralPath $pidFile -Value $process.Id -Encoding ascii
    Write-Output "$Name started (PID $($process.Id))."
}

function Wait-Endpoint {
    param([string]$Name, [string]$Url)

    for ($attempt = 0; $attempt -lt 150; $attempt++) {
        $status = & curl.exe -s -o NUL -w "%{http_code}" $Url
        if ($status -match "^(200|204|307|308)$") {
            Write-Output "$Name is ready ($status)."
            return
        }
        Start-Sleep -Milliseconds 200
    }
    throw "$Name did not become ready. Check $runtimeDir"
}

Start-ManagedProcess -Name "evaluation" -FilePath (Join-Path $EvaluationRoot ".venv\Scripts\python.exe") -Arguments @("-m", "uvicorn", "server.app:app", "--reload", "--host", "127.0.0.1", "--port", "8000") -WorkingDirectory $EvaluationRoot

Start-ManagedProcess -Name "dataset-builder" -FilePath (Join-Path $DatasetBuilderRoot ".venv\Scripts\python.exe") -Arguments @("-m", "uvicorn", "app.main:app", "--host", "127.0.0.1", "--port", "8001") -WorkingDirectory $DatasetBuilderRoot

Start-ManagedProcess -Name "syntax-api" -FilePath (Get-Command node.exe).Source -Arguments @("node_modules/tsx/dist/cli.mjs", "src/server.ts") -WorkingDirectory (Join-Path $SyntaxRoot "backend")

Start-ManagedProcess -Name "syntax-frontend" -FilePath (Get-Command node.exe).Source -Arguments @("node_modules/vite/bin/vite.js", "--host", "127.0.0.1", "--port", "5173") -WorkingDirectory (Join-Path $SyntaxRoot "frontend")

Start-ManagedProcess -Name "portal" -FilePath (Get-Command node.exe).Source -Arguments @("node_modules/vite/bin/vite.js", "--host", "127.0.0.1", "--port", "5174") -WorkingDirectory $PortalRoot

Wait-Endpoint -Name "conversion evaluation" -Url "http://127.0.0.1:8000/evaluation/"
Wait-Endpoint -Name "dataset builder" -Url "http://127.0.0.1:8001/api/dataset-builder/health"
Wait-Endpoint -Name "syntax API" -Url "http://127.0.0.1:3000/api/syntax/health"
Wait-Endpoint -Name "syntax frontend" -Url "http://127.0.0.1:5173/syntax-check/"
Wait-Endpoint -Name "portal" -Url "http://127.0.0.1:5174/"

& (Join-Path $PSScriptRoot "start-windows-nginx.ps1") -NginxHome $NginxHome
Wait-Endpoint -Name "unified portal" -Url "http://127.0.0.1/"

Write-Output "All services are ready: http://127.0.0.1/"
