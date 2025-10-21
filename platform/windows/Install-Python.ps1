# =================================================================
# Install-Python.ps1
# 安裝 pyenv-win 環境管理工具，用於管理多個 Python 版本。
# =================================================================

# --- 腳本開始 ---
Write-Host "--- PyEnv-Win 環境安裝腳本 ---" -ForegroundColor Cyan

# 步驟 1: 清理舊版本
Write-Host "`n1. 正在清理舊版本..." -ForegroundColor Yellow

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

# 步驟 2: 載入 Archive 模塊
Write-Host "`n2. 正在載入 Archive 模塊..." -ForegroundColor Yellow

try {
    Import-Module Microsoft.PowerShell.Archive -Force -ErrorAction Stop
    Write-Host "   - Archive 模塊已載入。" -ForegroundColor Green
} catch {
    Write-Host "   - Archive 模塊載入失敗，將使用手動解壓縮。" -ForegroundColor Yellow
}

# 步驟 3: 安裝 pyenv-win
Write-Host "`n3. 正在安裝 pyenv-win..." -ForegroundColor Yellow

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
