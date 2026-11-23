$ErrorActionPreference = "Stop"

$WinDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $WinDir
$InstallDir = Join-Path $env:LOCALAPPDATA "AntigravityFileOpener"
$InstallExe = Join-Path $InstallDir "AntigravityFileOpener.exe"
$RunKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"

$NodeCmd = Get-Command node -ErrorAction SilentlyContinue
if (-not $NodeCmd) {
    throw "未找到 Node.js，请先安装 Node.js 后重试。"
}

Write-Host "==> [1/5] 停止旧后台进程..."
Get-Process -Name "AntigravityFileOpener" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 300

Write-Host "==> [2/5] 运行测试并编译 Windows 原生服务..."
& (Join-Path $WinDir "build.ps1")

Write-Host "==> [3/5] 安装到 $InstallDir 并配置开机静默自启..."
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Copy-Item -Force (Join-Path $RootDir "build\AntigravityFileOpener.exe") $InstallExe
Set-ItemProperty -Path $RunKey -Name "AntigravityFileOpener" -Value "`"$InstallExe`" --silent"

Write-Host "==> [4/5] 启动后台原生服务..."
Start-Process -FilePath $InstallExe -ArgumentList "--silent" -WindowStyle Hidden

$healthy = $false
for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Milliseconds 250
    try {
        $resp = Invoke-RestMethod -Uri "http://127.0.0.1:59321/health" -TimeoutSec 1
        if ($resp.ok -eq $true) {
            $healthy = $true
            break
        }
    } catch {}
}

if (-not $healthy) {
    throw "后台服务未能响应 http://127.0.0.1:59321/health，请查看 $env:TEMP\antigravity-file-opener.log"
}

Write-Host "==> [5/5] 同步前端交互模块到 theme-patch/user/custom.js..."
& $NodeCmd.Source (Join-Path $RootDir "sync-custom-js.mjs") install
if ($LASTEXITCODE -ne 0) { throw "前端同步失败" }

Write-Host "✅ Windows 安装并启动完成！(http://127.0.0.1:59321/health 正常)"
