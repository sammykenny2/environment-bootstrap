<#
.SYNOPSIS
    Install Python development packages

.DESCRIPTION
    Installs Python development packages using pip.
    Requires Setup-Python.ps1 to be run first.
    All operations in user directory (no admin required).
    Rejects execution with admin privileges to avoid permission issues.

.PARAMETER Upgrade
    Upgrade existing packages to latest versions

.PARAMETER Force
    Force reinstall all packages

.EXAMPLE
    .\Setup-PythonPackages.ps1
    Default: Install packages if missing

.EXAMPLE
    .\Setup-PythonPackages.ps1 -Upgrade
    Upgrade all packages to latest versions

.EXAMPLE
    .\Setup-PythonPackages.ps1 -Force
    Force reinstall all packages
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
    Write-Host "原因：Python packages 應安裝在用戶目錄，避免權限問題" -ForegroundColor Yellow
    Write-Host "母腳本應以一般權限執行，子腳本會在需要時自動提權" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# --- 腳本開始 ---
Write-Host "--- Python Development Packages 安裝腳本 ---" -ForegroundColor Cyan

# 處理互斥參數
if ($Force -and $Upgrade) {
    Write-Host "⚠️  警告：不能同時使用 -Force 和 -Upgrade，將使用 -Force" -ForegroundColor Yellow
    $Upgrade = $false
}

# 步驟 1: 檢查 Python 是否已安裝
Write-Host "`n1. 正在檢查 Python 環境..." -ForegroundColor Yellow

# 刷新環境變數以確保 python 可用
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "User") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "Machine")

$pythonExists = Get-Command python -ErrorAction SilentlyContinue

if (-not $pythonExists) {
    Write-Host "❌ 錯誤：未找到 Python" -ForegroundColor Red
    Write-Host "請先執行 Setup-Python.ps1 安裝 Python 核心環境" -ForegroundColor Yellow
    exit 1
}

$pythonVersion = python --version 2>&1
$pipVersion = pip --version 2>&1
Write-Host "   - Python: $pythonVersion" -ForegroundColor Green
Write-Host "   - pip: $pipVersion" -ForegroundColor Green

# 步驟 2: 安裝 Python development packages
Write-Host "`n2. 正在安裝 Python development packages..." -ForegroundColor Yellow

# 定義要安裝的 packages (目前為空，用戶可自行添加)
$packages = @(
    # 範例 (已註解)：
    # "pipenv",
    # "poetry",
    # "black",
    # "pylint",
    # "flake8",
    # "pytest",
    # "pytest-cov",
    # "ipython",
    # "jupyter",
    # "requests",
    # "pandas",
    # "numpy"
)

if ($packages.Count -eq 0) {
    Write-Host "   - packages 列表為空，跳過安裝" -ForegroundColor Cyan
    Write-Host "   - 如需安裝 packages，請編輯此腳本的 `$packages 數組" -ForegroundColor Gray
} else {
    Write-Host "   - 將安裝 $($packages.Count) 個 packages" -ForegroundColor Cyan
    Write-Host ""

    foreach ($package in $packages) {
        Write-Host "   安裝 $package..." -ForegroundColor Gray

        if ($Force) {
            pip install --force-reinstall $package 2>&1 | Out-Null
        } elseif ($Upgrade) {
            pip install --upgrade $package 2>&1 | Out-Null
        } else {
            pip install $package 2>&1 | Out-Null
        }

        if ($LASTEXITCODE -eq 0) {
            Write-Host "      ✓ $package 完成" -ForegroundColor Green
        } else {
            Write-Host "      ✗ $package 失敗" -ForegroundColor Red
            exit 1
        }
    }
}

# --- 完成 ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Python Development Packages 安裝完成！"
Write-Host "========================================"
Write-Host ""

if ($packages.Count -gt 0) {
    Write-Host "已安裝的 packages：" -ForegroundColor Cyan
    pip list
    Write-Host ""
} else {
    Write-Host "提示：目前沒有安裝任何 development packages" -ForegroundColor Cyan
    Write-Host "如需安裝，請編輯此腳本的 `$packages 數組" -ForegroundColor Cyan
    Write-Host ""
}

exit 0
