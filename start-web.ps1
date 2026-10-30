# 一鍵啟動 Web UI：後端 (FastAPI :8000) + 前端 (Next.js :3000)，就緒後開瀏覽器。
# 用法：雙擊 start-web.bat，或在 PowerShell 執行 .\start-web.ps1
# 停止：關閉 "Backend" / "Frontend" 兩個視窗即可。

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$Web = Join-Path $Root 'web'

# 安裝 uv / Node 後舊視窗的 PATH 可能未更新，先重新讀取
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
            [Environment]::GetEnvironmentVariable('Path', 'User')
# conda 等外部 venv 會讓 uv 發出警告，子程序不需要
Remove-Item Env:VIRTUAL_ENV -ErrorAction SilentlyContinue

function Test-Port([int]$Port) {
    $client = New-Object System.Net.Sockets.TcpClient
    try { $client.Connect('127.0.0.1', $Port); return $true }
    catch { return $false }
    finally { $client.Dispose() }
}

function Wait-Url([string]$Url, [int]$TimeoutSec) {
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        try {
            Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5 | Out-Null
            return $true
        } catch { Start-Sleep -Seconds 1 }
    }
    return $false
}

foreach ($cmd in 'uv', 'node') {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Host "找不到 $cmd，請先安裝（見 web/README.md）。" -ForegroundColor Red
        Read-Host 'Press Enter to exit'
        exit 1
    }
}
if (-not (Test-Path (Join-Path $Root '.env'))) {
    Write-Host '警告：找不到 .env，觀察池與 AI 功能將無法使用。' -ForegroundColor Yellow
}

# 後端
if (Test-Port 8000) {
    Write-Host 'Backend already running on :8000, skipping.' -ForegroundColor DarkGray
} else {
    Write-Host 'Starting backend...' -ForegroundColor Cyan
    $backendCmd = @"
`$Host.UI.RawUI.WindowTitle = 'Backend (FastAPI :8000)'
uv sync
uv run uvicorn api.main:app --reload --reload-include='*.py' --port 8000
"@
    Start-Process powershell -WorkingDirectory $Root `
        -ArgumentList '-NoExit', '-ExecutionPolicy', 'Bypass', '-Command', $backendCmd
}

# 前端（npm.cmd 避開 npm.ps1 的執行原則限制）
if (Test-Port 3000) {
    Write-Host 'Frontend already running on :3000, skipping.' -ForegroundColor DarkGray
} else {
    Write-Host 'Starting frontend...' -ForegroundColor Cyan
    $install = if (Test-Path (Join-Path $Web 'node_modules')) { '' } else { 'npm.cmd install' }
    $frontendCmd = @"
`$Host.UI.RawUI.WindowTitle = 'Frontend (Next.js :3000)'
$install
npm.cmd run dev
"@
    Start-Process powershell -WorkingDirectory $Web `
        -ArgumentList '-NoExit', '-ExecutionPolicy', 'Bypass', '-Command', $frontendCmd
}

# 首次 uv sync / npm install 可能較久
Write-Host 'Waiting for backend...' -NoNewline
if (Wait-Url 'http://localhost:8000/api/health' 300) { Write-Host ' ready' -ForegroundColor Green }
else { Write-Host ' timed out, check the Backend window' -ForegroundColor Red }

Write-Host 'Waiting for frontend...' -NoNewline
if (Wait-Url 'http://localhost:3000' 300) { Write-Host ' ready' -ForegroundColor Green }
else { Write-Host ' timed out, check the Frontend window' -ForegroundColor Red }

Start-Process 'http://localhost:3000'
Write-Host 'Opened http://localhost:3000. Close the Backend / Frontend windows to stop.'
Start-Sleep -Seconds 3
