<#
.SYNOPSIS
    Install Node.js global packages

.DESCRIPTION
    Installs Node.js global packages in user directory.
    Requires Setup-NodeJS.ps1 to be run first.
    Rejects execution with admin privileges to avoid permission issues.

.PARAMETER Upgrade
    Upgrade existing packages to latest versions

.PARAMETER Force
    Force reinstall all packages

.EXAMPLE
    .\Setup-NodePackages.ps1
    Default: Install if missing, skip if already installed

.EXAMPLE
    .\Setup-NodePackages.ps1 -Upgrade
    Upgrade all packages to latest versions

.EXAMPLE
    .\Setup-NodePackages.ps1 -Force
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
    Write-Host "原因：npm global packages 應安裝在用戶目錄，避免權限問題" -ForegroundColor Yellow
    Write-Host "母腳本應以一般權限執行，子腳本會在需要時自動提權" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# --- 腳本開始 ---
Write-Host "--- Node.js Global Packages 安裝腳本 ---" -ForegroundColor Cyan

# 處理互斥參數
if ($Force -and $Upgrade) {
    Write-Host "⚠️  警告：不能同時使用 -Force 和 -Upgrade，將使用 -Force" -ForegroundColor Yellow
    $Upgrade = $false
}

# 步驟 1: 檢查 Node.js 和 npm 環境
Write-Host "`n1. 正在檢查 Node.js 和 npm 環境..." -ForegroundColor Yellow

# 刷新環境變數以確保 node/npm 可用
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "User") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "Machine")

$nodeExists = Get-Command node -ErrorAction SilentlyContinue
$npmExists = Get-Command npm -ErrorAction SilentlyContinue

if (-not $nodeExists) {
    Write-Host "❌ 錯誤：未找到 Node.js" -ForegroundColor Red
    Write-Host "請先執行 Install-NodeJS.ps1 安裝 Node.js" -ForegroundColor Yellow
    exit 1
}

if (-not $npmExists) {
    Write-Host "❌ 錯誤：未找到 npm" -ForegroundColor Red
    Write-Host "請先執行 Setup-NodeJS.ps1 配置 npm 環境" -ForegroundColor Yellow
    exit 1
}

$nodeVersion = (node -v).Trim()
$npmVersion = (npm -v).Trim()
Write-Host "   - Node.js: $nodeVersion" -ForegroundColor Green
Write-Host "   - npm: $npmVersion" -ForegroundColor Green

# 步驟 2: 安裝 global packages
Write-Host "`n2. 正在安裝 global packages..." -ForegroundColor Yellow

# 定義要安裝的 packages
$packages = @(
    # AI CLI Tools
    "@anthropic-ai/claude-code",
    "@google/gemini-cli",
    "@openai/codex",
    "@github/copilot"
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
            npm install -g $package --force | Out-Null
        } elseif ($Upgrade) {
            npm install -g $package@latest | Out-Null
        } else {
            # 檢查是否已安裝
            $installed = npm list -g $package --depth=0 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "      ✓ 已安裝，跳過" -ForegroundColor DarkGray
                continue
            }
            npm install -g $package | Out-Null
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
Write-Host "Node.js Global Packages 安裝完成！"
Write-Host "========================================"
Write-Host ""

if ($packages.Count -gt 0) {
    Write-Host "已安裝的 global packages：" -ForegroundColor Cyan
    npm list -g --depth=0
    Write-Host ""
} else {
    Write-Host "提示：目前沒有安裝任何 global packages" -ForegroundColor Cyan
    Write-Host "如需安裝，請編輯此腳本的 `$packages 數組" -ForegroundColor Cyan
    Write-Host ""
}

exit 0
