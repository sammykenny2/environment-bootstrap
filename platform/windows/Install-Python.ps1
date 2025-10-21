<#
.SYNOPSIS
    Setup Python core environment with pyenv-win

.DESCRIPTION
    Installs pyenv-win, Python, and essential build tools (pip, setuptools, wheel).
    All operations in user directory (no admin required).
    Rejects execution with admin privileges to avoid permission issues.

.PARAMETER PythonVersion
    Python version to install (e.g., "3.11.0").
    If not specified, automatically detects and installs latest stable version.

.PARAMETER Upgrade
    Upgrade existing installation to latest version

.PARAMETER Force
    Force reinstall pyenv-win and Python

.PARAMETER AllowAdmin
    Allow execution with admin privileges (for Administrator accounts only)

.EXAMPLE
    .\Install-Python.ps1
    Default: Install pyenv-win and latest stable Python

.EXAMPLE
    .\Install-Python.ps1 -PythonVersion "3.12.0"
    Install specific Python version

.EXAMPLE
    .\Install-Python.ps1 -Upgrade
    Upgrade to latest stable Python version

.EXAMPLE
    .\Install-Python.ps1 -AllowAdmin
    For Administrator accounts: allow execution with admin privileges
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$PythonVersion = "",  # Empty = auto-detect latest stable

    [Parameter(Mandatory=$false)]
    [switch]$Upgrade,

    [Parameter(Mandatory=$false)]
    [switch]$Force,

    [Parameter(Mandatory=$false)]
    [switch]$AllowAdmin
)

# === Reject Admin Execution (unless explicitly allowed) ===
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isAdmin -and -not $AllowAdmin) {
    Write-Host "❌ 錯誤：檢測到以管理員權限執行" -ForegroundColor Red
    Write-Host ""
    Write-Host "原因：" -ForegroundColor Yellow
    Write-Host "  - 以 admin 執行會導致 user 權限的腳本失敗" -ForegroundColor Yellow
    Write-Host "  - pip packages 會安裝到系統目錄（權限問題）" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "如果您是 Administrator 帳戶且確定要繼續，請使用：" -ForegroundColor Cyan
    Write-Host "  .\Install-Python.ps1 -AllowAdmin" -ForegroundColor White
    Write-Host ""
    Read-Host "按 Enter 鍵結束..."
    exit 1
}

if ($AllowAdmin -and $isAdmin) {
    Write-Host "⚠️  警告：以 Admin 權限執行（已使用 -AllowAdmin 參數）" -ForegroundColor Yellow
    Write-Host ""
}

# --- 腳本開始 ---
Write-Host "--- Python 核心環境安裝腳本 ---" -ForegroundColor Cyan

# 處理互斥參數
if ($Force -and $Upgrade) {
    Write-Host "⚠️  警告：不能同時使用 -Force 和 -Upgrade，將使用 -Force" -ForegroundColor Yellow
    $Upgrade = $false
}

# ========== 第一部分：安裝/升級 pyenv-win ==========

# 步驟 1: 檢查 pyenv-win 是否已安裝
Write-Host "`n1. 正在檢查 pyenv-win 是否已安裝..." -ForegroundColor Yellow
$pyenvExists = Test-Path "$env:USERPROFILE\.pyenv\pyenv-win\bin\pyenv.bat"

if ($pyenvExists) {
    Write-Host "   - 您已安裝 pyenv-win。" -ForegroundColor Green

    # 根據參數決定行為
    if ($Force) {
        Write-Host "   - 使用 -Force 參數，將強制重新安裝 pyenv-win。" -ForegroundColor Yellow
    } elseif ($Upgrade) {
        Write-Host "   - 使用 -Upgrade 參數，將升級 pyenv-win 到最新版本。" -ForegroundColor Yellow
    } else {
        Write-Host "   - pyenv-win 已安裝，跳過。" -ForegroundColor Cyan
    }
} else {
    Write-Host "   - 系統中未找到 pyenv-win，準備開始安裝。"
}

# 步驟 2: 安裝/升級 pyenv-win (如果需要)
if (-not $pyenvExists -or $Force -or $Upgrade) {
    Write-Host "`n2. 正在安裝/升級 pyenv-win..." -ForegroundColor Yellow

    # 清理舊版本
    Write-Host "   - 正在清理舊版本..." -ForegroundColor Gray
    Remove-Item -Path "$env:USERPROFILE\.pyenv" -Recurse -Force -ErrorAction SilentlyContinue
    [System.Environment]::SetEnvironmentVariable('PYENV', $null, 'User')
    [System.Environment]::SetEnvironmentVariable('PYENV_HOME', $null, 'User')
    [System.Environment]::SetEnvironmentVariable('PYENV_ROOT', $null, 'User')

    $UserPath = [System.Environment]::GetEnvironmentVariable('Path', 'User')
    if ($UserPath) {
        $NewPath = ($UserPath -split ';' | Where-Object { $_ -notlike "*pyenv*" }) -join ';'
        [System.Environment]::SetEnvironmentVariable('Path', $NewPath, 'User')
    }

    $installSuccess = $false

    # 方法 A: 使用官方安裝腳本 (Primary)
    try {
        Write-Host "   - 正在使用官方安裝腳本..." -ForegroundColor Gray

        $installerPath = "$env:TEMP\install-pyenv-win.ps1"

        # 下載官方安裝腳本
        Invoke-WebRequest -UseBasicParsing `
            -Uri "https://raw.githubusercontent.com/pyenv-win/pyenv-win/master/pyenv-win/install-pyenv-win.ps1" `
            -OutFile $installerPath

        # 執行安裝腳本
        & $installerPath

        # 刪除安裝腳本
        Remove-Item -Path $installerPath -Force -ErrorAction SilentlyContinue

        # 刷新環境變數確認安裝
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "User") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "Machine")

        $pyenvCheck = Get-Command pyenv -ErrorAction SilentlyContinue
        if ($pyenvCheck) {
            Write-Host "   - pyenv-win 安裝成功！" -ForegroundColor Green
            $installSuccess = $true
        } else {
            throw "官方安裝腳本執行後未找到 pyenv 命令"
        }

    } catch {
        Write-Host "⚠️  官方安裝腳本失敗：$($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "   - 將嘗試 fallback 方法" -ForegroundColor Yellow
        $installSuccess = $false
    }

    # 方法 B: 手動安裝 (Fallback)
    if (-not $installSuccess) {
        Write-Host "   - 正在使用手動安裝方法..." -ForegroundColor Gray

        $PyEnvDir = "$env:USERPROFILE\.pyenv"
        $ZipFile = "$env:TEMP\pyenv-win.zip"

        try {
            Write-Host "   - 正在下載 pyenv-win..." -ForegroundColor Gray
            Invoke-WebRequest -UseBasicParsing `
                -Uri "https://github.com/pyenv-win/pyenv-win/archive/master.zip" `
                -OutFile $ZipFile

            Write-Host "   - 正在解壓縮..." -ForegroundColor Gray
            New-Item -Path $PyEnvDir -ItemType Directory -Force | Out-Null
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipFile, $PyEnvDir)

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

            # 刷新當前 session 的環境變數
            $env:Path = "$PyEnvBin;$PyEnvShims;" + [System.Environment]::GetEnvironmentVariable("Path", "Machine")

            Write-Host "   - pyenv-win 安裝成功！" -ForegroundColor Green

        } catch {
            Write-Host "❌ pyenv-win 安裝失敗：$($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    }
}

# 刷新環境變數確保 pyenv 可用
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "User") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "Machine")

# ========== 第二部分：安裝/升級 Python ==========

# 步驟 3: 確定要安裝的 Python 版本
Write-Host "`n3. 正在確定 Python 版本..." -ForegroundColor Yellow

if ($PythonVersion -eq "") {
    # 自動檢測最新穩定版
    Write-Host "   - 未指定版本，正在檢測最新穩定版..." -ForegroundColor Gray

    try {
        $availableVersions = pyenv install --list 2>&1 | Select-String "^\s*3\.\d+\.\d+$" | ForEach-Object { $_.Line.Trim() }
        if ($availableVersions) {
            # 取最後一個（最新）
            $PythonVersion = $availableVersions | Select-Object -Last 1
            Write-Host "   - 檢測到最新穩定版：$PythonVersion" -ForegroundColor Cyan
        } else {
            Write-Host "⚠️  無法檢測最新版本，使用默認版本 3.11.0" -ForegroundColor Yellow
            $PythonVersion = "3.11.0"
        }
    } catch {
        Write-Host "⚠️  版本檢測失敗，使用默認版本 3.11.0" -ForegroundColor Yellow
        $PythonVersion = "3.11.0"
    }
} else {
    Write-Host "   - 指定版本：$PythonVersion" -ForegroundColor Cyan
}

# 步驟 4: 安裝 Python
Write-Host "`n4. 正在檢查 Python $PythonVersion..." -ForegroundColor Yellow

$installedVersions = pyenv versions 2>$null
$pythonInstalled = $installedVersions -match $PythonVersion

if ($pythonInstalled -and -not $Force) {
    Write-Host "   - Python $PythonVersion 已安裝" -ForegroundColor Green
} else {
    if ($Force) {
        Write-Host "   - 使用 -Force 參數，重新安裝 Python $PythonVersion" -ForegroundColor Yellow
    } else {
        Write-Host "   - Python $PythonVersion 未安裝，開始安裝..." -ForegroundColor Yellow
    }

    Write-Host "   - 這可能需要幾分鐘時間，請稍候..." -ForegroundColor Gray
    pyenv install $PythonVersion

    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Python 安裝失敗" -ForegroundColor Red
        exit 1
    }

    Write-Host "   - Python $PythonVersion 安裝完成" -ForegroundColor Green
}

# 步驟 5: 設定 global Python version
Write-Host "`n5. 正在設定 global Python version..." -ForegroundColor Yellow
pyenv global $PythonVersion

if ($LASTEXITCODE -eq 0) {
    # 刷新 PATH 確保 python 可用
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "User") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "Machine")

    $currentVersion = python --version 2>&1
    Write-Host "   - 當前 Python: $currentVersion" -ForegroundColor Green
} else {
    Write-Host "❌ 設定 global version 失敗" -ForegroundColor Red
    exit 1
}

# 步驟 6: 升級核心工具 (pip, setuptools, wheel)
Write-Host "`n6. 正在升級核心工具..." -ForegroundColor Yellow

try {
    Write-Host "   - 正在升級 pip..." -ForegroundColor Gray
    python -m pip install --upgrade pip 2>&1 | Out-Null

    if ($LASTEXITCODE -eq 0) {
        $pipVersion = pip --version
        Write-Host "   - ✓ $pipVersion" -ForegroundColor Green
    } else {
        Write-Host "   - ⚠️ pip 升級失敗" -ForegroundColor Yellow
    }

    Write-Host "   - 正在升級 setuptools 和 wheel..." -ForegroundColor Gray
    pip install --upgrade setuptools wheel 2>&1 | Out-Null

    if ($LASTEXITCODE -eq 0) {
        Write-Host "   - ✓ setuptools 和 wheel 升級成功" -ForegroundColor Green
    } else {
        Write-Host "   - ⚠️ setuptools/wheel 升級失敗，但不影響基本使用" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️  核心工具升級時發生錯誤，但不影響 Python 使用" -ForegroundColor Yellow
}

# --- 完成 ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Python 核心環境安裝完成！"
Write-Host "Python Version: $PythonVersion"
Write-Host "========================================"
Write-Host ""
Write-Host "已安裝：" -ForegroundColor Cyan
Write-Host "  - pyenv-win (Python 版本管理)"
Write-Host "  - Python $PythonVersion"
Write-Host "  - pip, setuptools, wheel"
Write-Host ""
exit 0
