<#
.SYNOPSIS
    Install or upgrade Windows Package Manager (winget)

.DESCRIPTION
    Checks and installs winget via App Installer from Microsoft Store.
    Falls back to direct download if Store method fails.
    Supports upgrade and force reinstall modes.
    Self-elevates to Administrator when needed.

.PARAMETER Upgrade
    Upgrade existing installation to latest version

.PARAMETER Force
    Force reinstall even if already installed

.EXAMPLE
    .\Install-Winget.ps1
    Default: Install if missing, skip if already installed

.EXAMPLE
    .\Install-Winget.ps1 -Upgrade
    Upgrade to latest version if installed, install if missing

.EXAMPLE
    .\Install-Winget.ps1 -Force
    Force reinstall winget
#>

param(
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
Write-Host "--- Windows Package Manager (winget) 安裝腳本 ---" -ForegroundColor Cyan

# 處理互斥參數
if ($Force -and $Upgrade) {
    Write-Host "⚠️  警告：不能同時使用 -Force 和 -Upgrade，將使用 -Force" -ForegroundColor Yellow
    $Upgrade = $false
}

# 步驟 2: 檢查 winget 是否已安裝
Write-Host "`n2. 正在檢查 winget 是否已安裝..." -ForegroundColor Yellow
$wingetExists = Get-Command winget -ErrorAction SilentlyContinue
if ($wingetExists) {
    $wingetVersion = (winget --version).Trim()
    Write-Host "   - 您已安裝 winget，版本為 $wingetVersion。" -ForegroundColor Green

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
    Write-Host "   - 系統中未找到 winget，準備開始安裝。"
}

# 步驟 3: 方法 B - 嘗試透過 Microsoft Store 安裝
Write-Host "`n3. 正在嘗試透過 Microsoft Store 安裝..." -ForegroundColor Yellow

try {
    Write-Host "   - 正在打開 Microsoft Store 的 App Installer 頁面..." -ForegroundColor Gray
    Start-Process "ms-windows-store://pdp/?productid=9nblggh4nns1"

    Write-Host ""
    Write-Host "   ╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "   ║  請在打開的 Microsoft Store 視窗中：                  ║" -ForegroundColor Cyan
    Write-Host "   ║  1. 點擊「取得」或「安裝」按鈕                        ║" -ForegroundColor Cyan
    Write-Host "   ║  2. 等待安裝完成                                      ║" -ForegroundColor Cyan
    Write-Host "   ║  3. 返回此視窗繼續                                    ║" -ForegroundColor Cyan
    Write-Host "   ╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    # 等待用戶確認安裝完成
    $response = Read-Host "   安裝完成後請輸入 Y 繼續驗證，或輸入 N 改用自動下載方式 (Y/N)"

    if ($response -eq 'Y' -or $response -eq 'y') {
        Write-Host "`n   - 正在驗證 winget 安裝..." -ForegroundColor Gray

        # 刷新環境變數
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

        # 驗證安裝
        $wingetExists = Get-Command winget -ErrorAction SilentlyContinue
        if ($wingetExists) {
            $wingetVersion = (winget --version).Trim()
            Write-Host "   - winget 安裝成功！版本：$wingetVersion" -ForegroundColor Green
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host "winget 操作完成！"
            Write-Host "請關閉此視窗，並「重新開啟一個新的 PowerShell 視窗」再繼續後續操作。"
            Write-Host "========================================"
            Read-Host "按 Enter 鍵結束..."
            exit 0
        } else {
            Write-Host "   - 未檢測到 winget，將改用自動下載方式..." -ForegroundColor Yellow
        }
    } else {
        Write-Host "`n   - 使用者選擇改用自動下載方式..." -ForegroundColor Yellow
    }
} catch {
    Write-Host "   - 打開 Microsoft Store 失敗：$($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "   - 將改用自動下載方式..." -ForegroundColor Yellow
}

# 步驟 4: 方法 A - Fallback 到 GitHub 直接下載
Write-Host "`n4. 正在從 GitHub 下載 winget..." -ForegroundColor Yellow

try {
    # 取得最新版本資訊
    Write-Host "   - 正在查詢最新版本..." -ForegroundColor Gray
    $apiUrl = "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
    $release = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing
    $version = $release.tag_name
    Write-Host "   - 最新版本：$version" -ForegroundColor Cyan

    # 找到 .msixbundle 下載連結
    $asset = $release.assets | Where-Object { $_.name -like "*.msixbundle" } | Select-Object -First 1
    if (-not $asset) {
        throw "找不到 winget 安裝檔案"
    }

    $downloadUrl = $asset.browser_download_url
    $fileName = $asset.name
    $outputPath = Join-Path $env:TEMP $fileName

    # 下載檔案
    Write-Host "   - 正在下載 $fileName ..." -ForegroundColor Gray
    Write-Host "   - 這可能需要幾分鐘時間，請稍候..." -ForegroundColor Gray
    Invoke-WebRequest -Uri $downloadUrl -OutFile $outputPath -UseBasicParsing

    # 安裝 msixbundle
    Write-Host "   - 正在安裝..." -ForegroundColor Gray
    Add-AppxPackage -Path $outputPath

    # 清理下載檔案
    Remove-Item -Path $outputPath -Force -ErrorAction SilentlyContinue

    # 刷新環境變數
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

    # 驗證安裝
    Write-Host "   - 正在驗證安裝..." -ForegroundColor Gray
    $wingetExists = Get-Command winget -ErrorAction SilentlyContinue
    if ($wingetExists) {
        $wingetVersion = (winget --version).Trim()
        Write-Host "   - winget 安裝成功！版本：$wingetVersion" -ForegroundColor Green
    } else {
        throw "安裝完成但無法找到 winget 命令，請重新開啟 PowerShell 視窗後再試"
    }

} catch {
    Write-Host "錯誤：自動下載安裝失敗：$($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "請手動安裝 winget：" -ForegroundColor Yellow
    Write-Host "1. 開啟 Microsoft Store" -ForegroundColor Yellow
    Write-Host "2. 搜尋「App Installer」" -ForegroundColor Yellow
    Write-Host "3. 點擊安裝" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "或前往：https://github.com/microsoft/winget-cli/releases/latest" -ForegroundColor Yellow
    Write-Host ""
    Read-Host "按 Enter 鍵結束..."
    exit 1
}

# --- 完成 ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "winget 操作完成！"
Write-Host "請關閉此視窗，並「重新開啟一個新的 PowerShell 視窗」再繼續後續操作。"
Write-Host "========================================"
Read-Host "按 Enter 鍵結束..."
exit 0
