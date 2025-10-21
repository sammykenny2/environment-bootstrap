<#
.SYNOPSIS
    Install or upgrade Node.js LTS using Windows Package Manager (winget)

.DESCRIPTION
    Checks and installs Node.js LTS. Includes npm automatically.
    Supports upgrade and force reinstall modes.
    Self-elevates to Administrator when needed.

.PARAMETER Version
    Version to install. Options: LTS (default), Latest, or specific version (e.g., "20.10.0")

.PARAMETER Upgrade
    Upgrade existing installation to latest version

.PARAMETER Force
    Force reinstall even if already installed

.EXAMPLE
    .\Install-NodeJS.ps1
    Default: Install if missing, skip if already installed

.EXAMPLE
    .\Install-NodeJS.ps1 -Upgrade
    Upgrade to latest LTS if installed, install if missing

.EXAMPLE
    .\Install-NodeJS.ps1 -Force
    Force reinstall Node.js LTS

.EXAMPLE
    .\Install-NodeJS.ps1 -Version "18.19.0"
    Install specific version
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$Version = "LTS",

    [Parameter(Mandatory=$false)]
    [switch]$Upgrade,

    [Parameter(Mandatory=$false)]
    [switch]$Force
)

# === Self-Elevation Logic ===
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "🔒 需要管理員權限，正在提權..." -ForegroundColor Cyan

    # Rebuild parameter list
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($Version -ne "LTS") { $arguments += " -Version `"$Version`"" }
    if ($Upgrade) { $arguments += " -Upgrade" }
    if ($Force) { $arguments += " -Force" }

    # Elevate and execute
    try {
        $process = Start-Process powershell.exe -ArgumentList $arguments -Verb RunAs -Wait -PassThru
        exit $process.ExitCode
    } catch {
        Write-Host "❌ UAC 取消或提權失敗" -ForegroundColor Red
        exit 1
    }
}

# === Already have Admin, continue with actual work ===
Write-Host "--- Node.js LTS 環境安裝腳本 ---" -ForegroundColor Cyan

# 處理互斥參數
if ($Force -and $Upgrade) {
    Write-Host "⚠️  警告：不能同時使用 -Force 和 -Upgrade，將使用 -Force" -ForegroundColor Yellow
    $Upgrade = $false
}

# 步驟 2: 檢查 Node.js 是否已安裝
Write-Host "`n2. 正在檢查 Node.js 是否已安裝..." -ForegroundColor Yellow
$nodeExists = Get-Command node -ErrorAction SilentlyContinue
if ($nodeExists) {
    $nodeVersion = (node -v).Trim()
    Write-Host "   - 您已安裝 Node.js，版本為 $nodeVersion。" -ForegroundColor Green

    # 根據參數決定行為
    if ($Force) {
        Write-Host "   - 使用 -Force 參數，將強制重新安裝。" -ForegroundColor Yellow
    } elseif ($Upgrade) {
        Write-Host "   - 使用 -Upgrade 參數，將升級到最新版本。" -ForegroundColor Yellow
    } else {
        Write-Host "   - 無需重複安裝。如需升級請使用 -Upgrade 參數。" -ForegroundColor Cyan
        Read-Host "按 Enter 鍵結束..."
        exit 0
    }
} else {
    Write-Host "   - 系統中未找到 Node.js，準備開始安裝。"
}

# 步驟 3: 檢查 Winget 工具是否存在
Write-Host "`n3. 正在檢查 Winget 套件管理器..." -ForegroundColor Yellow
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "錯誤：找不到 Winget 工具。此腳本需要 Winget。" -ForegroundColor Red
    Write-Host "請確認您的 Windows 11 已更新，或從 Microsoft Store 安裝 'App Installer'。"
    Read-Host "按 Enter 鍵結束..."
    exit 1
}
Write-Host "   - Winget 檢查通過。" -ForegroundColor Green

# 步驟 4: 準備安裝參數
Write-Host "`n4. 準備安裝參數..." -ForegroundColor Yellow

# 根據 Version 參數決定 package ID
switch ($Version) {
    "LTS" {
        $packageId = "OpenJS.NodeJS.LTS"
        $versionArg = ""
        Write-Host "   - 目標版本：最新 LTS 版本" -ForegroundColor Cyan
    }
    "Latest" {
        $packageId = "OpenJS.NodeJS"
        $versionArg = ""
        Write-Host "   - 目標版本：最新穩定版本（非 LTS）" -ForegroundColor Cyan
    }
    default {
        $packageId = "OpenJS.NodeJS"
        $versionArg = "--version $Version"
        Write-Host "   - 目標版本：$Version" -ForegroundColor Cyan
    }
}

# 步驟 5: 執行安裝/升級
if ($Upgrade -and $nodeExists) {
    Write-Host "`n5. 正在升級 Node.js..." -ForegroundColor Yellow
    Write-Host "   - 這可能需要幾分鐘時間，請稍候..."

    try {
        $command = "winget upgrade --id $packageId -e --silent --accept-package-agreements --accept-source-agreements"
        if ($versionArg) {
            $command += " $versionArg"
        }

        Invoke-Expression $command

        if ($LASTEXITCODE -ne 0) {
            throw "Winget 升級失敗，請檢查網路連線或錯誤訊息。"
        }

        Write-Host "   - Node.js 升級成功！" -ForegroundColor Green
        Write-Host "   - 重要：您需要開啟一個「新的」PowerShell 視窗來讓環境變數生效。" -ForegroundColor Yellow
    } catch {
        Write-Host "錯誤：升級過程中發生問題: $($_.Exception.Message)" -ForegroundColor Red
        Read-Host "按 Enter 鍵結束..."
        exit 1
    }
} else {
    # 安裝或強制重裝
    if ($Force) {
        Write-Host "`n5. 正在強制重新安裝 Node.js..." -ForegroundColor Yellow
    } else {
        Write-Host "`n5. 正在安裝 Node.js..." -ForegroundColor Yellow
    }
    Write-Host "   - 這可能需要幾分鐘時間，請稍候..."

    try {
        $command = "winget install --id $packageId -e --silent --accept-package-agreements --accept-source-agreements"
        if ($versionArg) {
            $command += " $versionArg"
        }
        if ($Force) {
            $command += " --force"
        }

        Invoke-Expression $command

        if ($LASTEXITCODE -ne 0) {
            throw "Winget 安裝失敗，請檢查網路連線或錯誤訊息。"
        }

        Write-Host "   - Node.js 安裝成功！" -ForegroundColor Green
        Write-Host "   - 重要：您需要開啟一個「新的」PowerShell 視窗來讓環境變數生效。" -ForegroundColor Yellow
    } catch {
        Write-Host "錯誤：安裝過程中發生問題: $($_.Exception.Message)" -ForegroundColor Red
        Read-Host "按 Enter 鍵結束..."
        exit 1
    }
}

# 步驟 6: 升級 npm 到最新版本
Write-Host "`n6. 正在升級 npm..." -ForegroundColor Yellow

# 刷新環境變數以確保 npm 可用
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

# 檢查 npm 是否可用
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
            Write-Host "⚠️  npm 升級失敗，但不影響 Node.js 使用" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "⚠️  npm 升級時發生錯誤：$($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "   - 但不影響 Node.js 使用" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️  無法找到 npm，可能需要重新開啟 PowerShell 視窗" -ForegroundColor Yellow
}

# --- 完成 ---
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Node.js 操作完成！"
Write-Host "請關閉此視窗，並「重新開啟一個新的 PowerShell 視窗」再繼續後續操作。"
Write-Host "========================================"
Read-Host "按 Enter 鍵結束..."
exit 0
