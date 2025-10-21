<#
.SYNOPSIS
    Setup Node.js global packages in user directory

.DESCRIPTION
    Configures npm to install global packages in user directory (no admin required).
    Installs commonly used development packages.
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
Write-Host "--- Node.js Global Packages 配置 ---" -ForegroundColor Cyan

# 處理互斥參數
if ($Force -and $Upgrade) {
    Write-Host "⚠️  警告：不能同時使用 -Force 和 -Upgrade，將使用 -Force" -ForegroundColor Yellow
    $Upgrade = $false
}

# 步驟 1: 檢查 Node.js 是否已安裝
Write-Host "`n1. 正在檢查 Node.js..." -ForegroundColor Yellow
$nodeExists = Get-Command node -ErrorAction SilentlyContinue

if (-not $nodeExists) {
    Write-Host "❌ 錯誤：未找到 Node.js" -ForegroundColor Red
    Write-Host "請先執行 Quick-Install.ps1 安裝 Node.js" -ForegroundColor Yellow
    exit 1
}

$nodeVersion = (node -v).Trim()
$npmVersion = (npm -v).Trim()
Write-Host "   - Node.js: $nodeVersion" -ForegroundColor Green
Write-Host "   - npm: $npmVersion" -ForegroundColor Green

# 步驟 2: 配置 npm global prefix
Write-Host "`n2. 正在配置 npm global 目錄..." -ForegroundColor Yellow

$npmGlobalPath = "$env:USERPROFILE\.npm-global"

# 建立目錄
if (-not (Test-Path $npmGlobalPath)) {
    New-Item -Path $npmGlobalPath -ItemType Directory -Force | Out-Null
    Write-Host "   - 建立目錄：$npmGlobalPath" -ForegroundColor Gray
}

# 設定 npm prefix
npm config set prefix $npmGlobalPath
Write-Host "   - npm prefix 設定為：$npmGlobalPath" -ForegroundColor Green

# 步驟 3: 加入 PATH
Write-Host "`n3. 正在更新 PATH 環境變數..." -ForegroundColor Yellow

$userPath = [System.Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike "*$npmGlobalPath*") {
    [System.Environment]::SetEnvironmentVariable('Path', "$npmGlobalPath;$userPath", 'User')
    $env:Path = "$npmGlobalPath;$env:Path"
    Write-Host "   - 已加入 PATH：$npmGlobalPath" -ForegroundColor Green
} else {
    Write-Host "   - PATH 已包含 npm global 目錄" -ForegroundColor Cyan
}

# 步驟 4: 安裝 global packages
Write-Host "`n4. 正在安裝 global packages..." -ForegroundColor Yellow

# 定義要安裝的 packages
$packages = @(
    "typescript",
    "ts-node",
    "eslint",
    "prettier",
    "nodemon",
    "pm2",
    "@nestjs/cli",
    "create-react-app",
    "create-next-app"
)

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

# --- 完成 ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Node.js Global Packages 配置完成！"
Write-Host "安裝目錄：$npmGlobalPath"
Write-Host "========================================"
Write-Host ""
Write-Host "已安裝的 global packages：" -ForegroundColor Cyan
npm list -g --depth=0
Write-Host ""
exit 0
