<#
.SYNOPSIS
    Setup Node.js environment in user directory

.DESCRIPTION
    Configures npm to install global packages in user directory (no admin required).
    Upgrades npm to latest version.
    Rejects execution with admin privileges to avoid permission issues.

.PARAMETER Upgrade
    Upgrade npm to latest version

.PARAMETER Force
    Force reinstall npm

.EXAMPLE
    .\Setup-NodeJS.ps1
    Default: Configure npm global directory and upgrade npm

.EXAMPLE
    .\Setup-NodeJS.ps1 -Upgrade
    Upgrade npm to latest version

.EXAMPLE
    .\Setup-NodeJS.ps1 -Force
    Force reinstall npm
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
    Write-Host "原因：npm 應配置在用戶目錄，避免權限問題" -ForegroundColor Yellow
    Write-Host "母腳本應以一般權限執行，子腳本會在需要時自動提權" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# --- 腳本開始 ---
Write-Host "--- Node.js 環境配置 ---" -ForegroundColor Cyan

# 處理互斥參數
if ($Force -and $Upgrade) {
    Write-Host "⚠️  警告：不能同時使用 -Force 和 -Upgrade，將使用 -Force" -ForegroundColor Yellow
    $Upgrade = $false
}

# 步驟 1: 檢查 Node.js 是否已安裝
Write-Host "`n1. 正在檢查 Node.js..." -ForegroundColor Yellow

# 刷新環境變數以確保 node/npm 可用
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "User") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "Machine")

$nodeExists = Get-Command node -ErrorAction SilentlyContinue

if (-not $nodeExists) {
    Write-Host "❌ 錯誤：未找到 Node.js" -ForegroundColor Red
    Write-Host "請先執行 Install-NodeJS.ps1 安裝 Node.js" -ForegroundColor Yellow
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

# 步驟 4: 升級 npm
Write-Host "`n4. 正在升級 npm..." -ForegroundColor Yellow

# 刷新環境變數
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "User") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "Machine")

$npmExists = Get-Command npm -ErrorAction SilentlyContinue
if ($npmExists) {
    $currentNpmVersion = (npm -v).Trim()
    Write-Host "   - 當前 npm 版本：$currentNpmVersion" -ForegroundColor Cyan

    try {
        Write-Host "   - 正在升級 npm 到最新版本..." -ForegroundColor Gray
        npm install -g npm@latest 2>&1 | Out-Null

        if ($LASTEXITCODE -eq 0) {
            $newNpmVersion = (npm -v).Trim()
            Write-Host "   - npm 升級成功！新版本：$newNpmVersion" -ForegroundColor Green
        } else {
            Write-Host "⚠️  npm 升級失敗" -ForegroundColor Yellow
            exit 1
        }
    } catch {
        Write-Host "❌ npm 升級時發生錯誤：$($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "❌ 無法找到 npm" -ForegroundColor Red
    exit 1
}

# --- 完成 ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Node.js 環境配置完成！"
Write-Host "npm global 目錄：$npmGlobalPath"
Write-Host "npm 版本：$(npm -v)"
Write-Host "========================================"
Write-Host ""
exit 0
