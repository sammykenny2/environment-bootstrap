<#
.SYNOPSIS
    Setup Python environment and packages

.DESCRIPTION
    Installs Python via pyenv-win and sets up commonly used packages.
    All operations in user directory (no admin required).
    Rejects execution with admin privileges to avoid permission issues.

.PARAMETER PythonVersion
    Python version to install (default: 3.11.0)

.PARAMETER Upgrade
    Upgrade existing packages to latest versions

.PARAMETER Force
    Force reinstall Python and all packages

.EXAMPLE
    .\Setup-PythonPackages.ps1
    Default: Install Python 3.11.0 if missing, install packages

.EXAMPLE
    .\Setup-PythonPackages.ps1 -PythonVersion "3.12.0"
    Install specific Python version

.EXAMPLE
    .\Setup-PythonPackages.ps1 -Upgrade
    Upgrade all packages to latest versions

.EXAMPLE
    .\Setup-PythonPackages.ps1 -Force
    Force reinstall Python and all packages
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$PythonVersion = "3.11.0",

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
    Write-Host "原因：Python packages 應安裝在用戶目錄，避免權限問題" -ForegroundColor Yellow
    Write-Host "母腳本應以一般權限執行，子腳本會在需要時自動提權" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# --- 腳本開始 ---
Write-Host "--- Python Environment Setup ---" -ForegroundColor Cyan

# 處理互斥參數
if ($Force -and $Upgrade) {
    Write-Host "⚠️  警告：不能同時使用 -Force 和 -Upgrade，將使用 -Force" -ForegroundColor Yellow
    $Upgrade = $false
}

# 步驟 1: 檢查 pyenv-win 是否已安裝
Write-Host "`n1. 正在檢查 pyenv-win..." -ForegroundColor Yellow
$pyenvExists = Get-Command pyenv -ErrorAction SilentlyContinue

if (-not $pyenvExists) {
    Write-Host "❌ 錯誤：未找到 pyenv-win" -ForegroundColor Red
    Write-Host "請先執行 Quick-Install.ps1 安裝 pyenv-win" -ForegroundColor Yellow
    exit 1
}

Write-Host "   - pyenv-win 已安裝" -ForegroundColor Green

# 步驟 2: 安裝 Python
Write-Host "`n2. 正在檢查 Python $PythonVersion..." -ForegroundColor Yellow

# 刷新環境變數以確保 pyenv 可用
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

# 檢查是否已安裝指定版本
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

    pyenv install $PythonVersion

    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Python 安裝失敗" -ForegroundColor Red
        exit 1
    }

    Write-Host "   - Python $PythonVersion 安裝完成" -ForegroundColor Green
}

# 步驟 3: 設定 global Python version
Write-Host "`n3. 正在設定 global Python version..." -ForegroundColor Yellow
pyenv global $PythonVersion

if ($LASTEXITCODE -eq 0) {
    $currentVersion = python --version 2>&1
    Write-Host "   - 當前 Python: $currentVersion" -ForegroundColor Green
} else {
    Write-Host "❌ 設定 global version 失敗" -ForegroundColor Red
    exit 1
}

# 步驟 4: 升級 pip
Write-Host "`n4. 正在升級 pip..." -ForegroundColor Yellow
python -m pip install --upgrade pip | Out-Null

if ($LASTEXITCODE -eq 0) {
    $pipVersion = pip --version
    Write-Host "   - $pipVersion" -ForegroundColor Green
} else {
    Write-Host "⚠️  pip 升級失敗，繼續安裝 packages..." -ForegroundColor Yellow
}

# 步驟 5: 安裝 Python packages
Write-Host "`n5. 正在安裝 Python packages..." -ForegroundColor Yellow

# 定義要安裝的 packages
$packages = @(
    "pipenv",
    "poetry",
    "black",
    "pylint",
    "flake8",
    "pytest",
    "pytest-cov",
    "ipython",
    "jupyter",
    "requests",
    "pandas",
    "numpy"
)

Write-Host "   - 將安裝 $($packages.Count) 個 packages" -ForegroundColor Cyan
Write-Host ""

foreach ($package in $packages) {
    Write-Host "   安裝 $package..." -ForegroundColor Gray

    if ($Force) {
        pip install --force-reinstall $package | Out-Null
    } elseif ($Upgrade) {
        pip install --upgrade $package | Out-Null
    } else {
        pip install $package | Out-Null
    }

    if ($LASTEXITCODE -eq 0) {
        Write-Host "      ✓ $package 完成" -ForegroundColor Green
    } else {
        Write-Host "      ✗ $package 失敗" -ForegroundColor Red
        exit 1
    }
}

# --- 完成 ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Python Environment Setup 完成！"
Write-Host "Python Version: $PythonVersion"
Write-Host "========================================"
Write-Host ""
Write-Host "已安裝的 packages：" -ForegroundColor Cyan
pip list
Write-Host ""
exit 0
