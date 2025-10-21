<#
.SYNOPSIS
    Setup pyenv-win for Python version management

.DESCRIPTION
    Installs pyenv-win to user directory (no admin required).
    Supports upgrade and force reinstall modes.
    Rejects execution with admin privileges to avoid permission issues.

.PARAMETER Upgrade
    Upgrade existing installation to latest version

.PARAMETER Force
    Force reinstall even if already installed

.EXAMPLE
    .\Setup-Python.ps1
    Default: Install if missing, skip if already installed

.EXAMPLE
    .\Setup-Python.ps1 -Upgrade
    Upgrade to latest version

.EXAMPLE
    .\Setup-Python.ps1 -Force
    Force reinstall pyenv-win
#>

param(
    [Parameter(Mandatory=$false)]
    [switch]$Upgrade,

    [Parameter(Mandatory=$false)]
    [switch]$Force
)

# === Reject Admin Privileges ===
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isAdmin) {
    Write-Host "❌ 錯誤：此腳本不應以管理員權限執行" -ForegroundColor Red
    Write-Host ""
    Write-Host "原因：pyenv-win 應安裝在用戶目錄，避免權限問題" -ForegroundColor Yellow
    Write-Host "母腳本應以一般權限執行，子腳本會在需要時自動提權" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# --- 腳本開始 ---
Write-Host "--- PyEnv-Win 環境安裝腳本 ---" -ForegroundColor Cyan

# 處理互斥參數
if ($Force -and $Upgrade) {
    Write-Host "⚠️  警告：不能同時使用 -Force 和 -Upgrade，將使用 -Force" -ForegroundColor Yellow
    $Upgrade = $false
}

# 步驟 1: 檢查 pyenv-win 是否已安裝
Write-Host "`n1. 正在檢查 pyenv-win 是否已安裝..." -ForegroundColor Yellow
$pyenvExists = Test-Path "$env:USERPROFILE\.pyenv\pyenv-win\bin\pyenv.bat"

if ($pyenvExists) {
    Write-Host "   - 您已安裝 pyenv-win。" -ForegroundColor Green

    # 根據參數決定行為
    if ($Force) {
        Write-Host "   - 使用 -Force 參數，將強制重新安裝。" -ForegroundColor Yellow
    } elseif ($Upgrade) {
        Write-Host "   - 使用 -Upgrade 參數，將升級到最新版本。" -ForegroundColor Yellow
    } else {
        Write-Host "   - 無需重複安裝。如需升級請使用 -Upgrade 參數。" -ForegroundColor Cyan
        exit 0
    }
} else {
    Write-Host "   - 系統中未找到 pyenv-win，準備開始安裝。"
}

# 步驟 2: 清理舊版本 (如果是 Force 或 Upgrade)
if ($Force -or $Upgrade -or -not $pyenvExists) {
    Write-Host "`n2. 正在清理舊版本..." -ForegroundColor Yellow

Remove-Item -Path "$env:USERPROFILE\.pyenv" -Recurse -Force -ErrorAction SilentlyContinue
[System.Environment]::SetEnvironmentVariable('PYENV', $null, 'User')
[System.Environment]::SetEnvironmentVariable('PYENV_HOME', $null, 'User')
[System.Environment]::SetEnvironmentVariable('PYENV_ROOT', $null, 'User')

$UserPath = [System.Environment]::GetEnvironmentVariable('Path', 'User')
if ($UserPath) {
    $NewPath = ($UserPath -split ';' | Where-Object { $_ -notlike "*pyenv*" }) -join ';'
    [System.Environment]::SetEnvironmentVariable('Path', $NewPath, 'User')
}

    Write-Host "   - 清理完成。" -ForegroundColor Green
}

# 步驟 3: 載入 Archive 模塊
Write-Host "`n3. 正在載入 Archive 模塊..." -ForegroundColor Yellow

try {
    Import-Module Microsoft.PowerShell.Archive -Force -ErrorAction Stop
    Write-Host "   - Archive 模塊已載入。" -ForegroundColor Green
} catch {
    Write-Host "   - Archive 模塊載入失敗，將使用手動解壓縮。" -ForegroundColor Yellow
}

# 步驟 4: 安裝 pyenv-win
Write-Host "`n4. 正在安裝 pyenv-win..." -ForegroundColor Yellow

$PyEnvDir = "$env:USERPROFILE\.pyenv"
$ZipFile = "$env:TEMP\pyenv-win.zip"

try {
    # 下載壓縮檔
    Write-Host "   - 正在下載..." -ForegroundColor Gray
    Invoke-WebRequest -UseBasicParsing `
        -Uri "https://github.com/pyenv-win/pyenv-win/archive/master.zip" `
        -OutFile $ZipFile

    # 建立目錄
    New-Item -Path $PyEnvDir -ItemType Directory -Force | Out-Null

    # 解壓縮（使用 .NET 作為備援方案）
    Write-Host "   - 正在解壓縮..." -ForegroundColor Gray
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipFile, $PyEnvDir)

    # 整理檔案結構
    Write-Host "   - 正在整理檔案..." -ForegroundColor Gray
    Move-Item -Path "$PyEnvDir\pyenv-win-master\*" -Destination "$PyEnvDir" -Force
    Remove-Item -Path "$PyEnvDir\pyenv-win-master" -Recurse -Force
    Remove-Item -Path $ZipFile -Force

    # 設定環境變數
    Write-Host "   - 正在設定環境變數..." -ForegroundColor Gray
    [System.Environment]::SetEnvironmentVariable('PYENV', "$PyEnvDir\pyenv-win\", 'User')
    [System.Environment]::SetEnvironmentVariable('PYENV_ROOT', "$PyEnvDir\pyenv-win\", 'User')
    [System.Environment]::SetEnvironmentVariable('PYENV_HOME', "$PyEnvDir\pyenv-win\", 'User')

    # 加入 PATH
    $UserPath = [System.Environment]::GetEnvironmentVariable('Path', 'User')
    $PyEnvBin = "$PyEnvDir\pyenv-win\bin"
    $PyEnvShims = "$PyEnvDir\pyenv-win\shims"

    if ($UserPath -notlike "*$PyEnvBin*") {
        [System.Environment]::SetEnvironmentVariable('Path', "$PyEnvBin;$PyEnvShims;$UserPath", 'User')
    }

    Write-Host "   - 安裝成功！" -ForegroundColor Green

} catch {
    Write-Host "   - 安裝失敗：$_" -ForegroundColor Red
    Read-Host "按 Enter 鍵結束..."
    exit 1
}

# --- 完成 ---
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "PyEnv-Win 安裝成功！"
Write-Host "請重新開啟 PowerShell 視窗，然後執行 'pyenv --version' 驗證安裝。"
Write-Host "========================================"
Read-Host "按 Enter 鍵結束..."
