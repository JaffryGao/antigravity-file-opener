$ErrorActionPreference = "Stop"

$WinDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $WinDir
$InstallDir = Join-Path $env:LOCALAPPDATA "AntigravityFileOpener"
$TokenDir = Join-Path (Join-Path $env:USERPROFILE ".config") "antigravity-file-opener"
$RunKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"

Get-Process -Name "AntigravityFileOpener" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 250

Remove-ItemProperty -Path $RunKey -Name "AntigravityFileOpener" -ErrorAction SilentlyContinue
if (Test-Path $InstallDir) { Remove-Item -Recurse -Force $InstallDir }
if (Test-Path $TokenDir) { Remove-Item -Recurse -Force $TokenDir }

$NodeCmd = Get-Command node -ErrorAction SilentlyContinue
if ($NodeCmd) {
    & $NodeCmd.Source (Join-Path $RootDir "sync-custom-js.mjs") uninstall
}

Write-Host "✅ 已彻底卸载 AntigravityFileOpener (Windows) 后台服务、自启项、配置与前端模块。"
