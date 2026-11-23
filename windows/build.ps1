$ErrorActionPreference = "Stop"

$WinDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $WinDir
$BuildDir = Join-Path $RootDir "build"
$TestExe = Join-Path $BuildDir "FileLinkParserTests.exe"
$OutExe = Join-Path $BuildDir "AntigravityFileOpener.exe"

New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null

function Find-Csc {
    $candidates = @(
        "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe",
        "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\csc.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }
    $cmd = Get-Command csc.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw "未找到 Windows 内置 C# 编译器 (csc.exe)，请确认 .NET Framework 4.x 可用。"
}

$Csc = Find-Csc
Write-Host "==> 使用编译器: $Csc"

Write-Host "==> [1/2] 编译并运行 Windows 单元测试..."
& $Csc /nologo /optimize+ /utf8output /codepage:65001 /target:exe `
    "/out:$TestExe" `
    (Join-Path $WinDir "FileLinkParser.cs") `
    (Join-Path $WinDir "LocalActionServer.cs") `
    (Join-Path $WinDir "FileLinkParserTests.cs")
if ($LASTEXITCODE -ne 0) { throw "单元测试编译失败" }

& $TestExe
if ($LASTEXITCODE -ne 0) { throw "单元测试运行失败" }

Write-Host "==> [2/2] 编译 AntigravityFileOpener.exe (静默无黑框 WinExe)..."
& $Csc /nologo /optimize+ /utf8output /codepage:65001 /target:winexe `
    /r:System.dll /r:System.Core.dll /r:System.Drawing.dll /r:System.Windows.Forms.dll `
    "/out:$OutExe" `
    (Join-Path $WinDir "FileLinkParser.cs") `
    (Join-Path $WinDir "LocalActionServer.cs") `
    (Join-Path $WinDir "ContextMenuPresenter.cs") `
    (Join-Path $WinDir "Program.cs")
if ($LASTEXITCODE -ne 0) { throw "AntigravityFileOpener.exe 编译失败" }

Write-Host "✅ Windows 构建完成: $OutExe"
