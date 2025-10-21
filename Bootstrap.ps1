<#
.SYNOPSIS
    Bootstrap script - Download and execute full environment setup

.DESCRIPTION
    Single-file distribution script that:
    1. Downloads the complete environment-bootstrap repository
    2. Extracts to temp directory
    3. Executes Quick-Install.ps1
    4. Cleans up temporary files

    This script requires NO external dependencies - only built-in PowerShell features.

.PARAMETER AllowAdmin
    Allow execution with admin privileges (for Administrator accounts only)

.EXAMPLE
    .\Bootstrap.ps1
    Downloads and installs complete development environment

.EXAMPLE
    .\Bootstrap.ps1 -AllowAdmin
    For Administrator accounts: allow execution with admin privileges

.NOTES
    - Must run with NORMAL user permissions (NOT admin)
    - Child scripts will self-elevate when needed (UAC prompts)
    - Temporary files are automatically cleaned up after installation
#>

param(
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
    Write-Host "  - npm/pip packages 會安裝到系統目錄（權限問題）" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "如果您是 Administrator 帳戶且確定要繼續，請使用：" -ForegroundColor Cyan
    Write-Host "  .\Bootstrap.ps1 -AllowAdmin" -ForegroundColor White
    Write-Host ""
    Read-Host "按 Enter 鍵結束..."
    exit 1
}

if ($AllowAdmin -and $isAdmin) {
    Write-Host "⚠️  警告：以 Admin 權限執行（已使用 -AllowAdmin 參數）" -ForegroundColor Yellow
    Write-Host ""
}

# --- 腳本開始 ---
Clear-Host
Write-Host @"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║        Environment Bootstrap - Installer                 ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Host ""
Write-Host "此腳本將：" -ForegroundColor Cyan
Write-Host "  1. 下載完整的環境安裝工具" -ForegroundColor Gray
Write-Host "  2. 自動安裝開發環境（Node.js, Python, Git, etc.）" -ForegroundColor Gray
Write-Host "  3. 子腳本需要時會自動彈出 UAC 提權視窗" -ForegroundColor Gray
Write-Host ""
$confirm = Read-Host "按 Enter 繼續，或按 Ctrl+C 取消"

# 步驟 1: 下載 repository
Write-Host "`n[1/4] 正在下載環境安裝工具..." -ForegroundColor Yellow

$repoUrl = "https://github.com/sammykenny2/environment-bootstrap/archive/refs/heads/main.zip"
$zipFile = "$env:TEMP\env-bootstrap-$(Get-Date -Format 'yyyyMMdd-HHmmss').zip"
$extractPath = "$env:TEMP\env-bootstrap-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$repoDir = "$extractPath\environment-bootstrap-main"

try {
    Invoke-WebRequest -Uri $repoUrl -OutFile $zipFile -UseBasicParsing
    Write-Host "   - 下載完成" -ForegroundColor Green
} catch {
    Write-Host "❌ 下載失敗：$($_.Exception.Message)" -ForegroundColor Red
    Write-Host "請檢查網路連線或稍後再試" -ForegroundColor Yellow
    Read-Host "按 Enter 鍵結束..."
    exit 1
}

# 步驟 2: 解壓縮
Write-Host "`n[2/4] 正在解壓縮..." -ForegroundColor Yellow

try {
    Expand-Archive -Path $zipFile -DestinationPath $extractPath -Force
    Write-Host "   - 解壓縮完成" -ForegroundColor Green
} catch {
    Write-Host "❌ 解壓縮失敗：$($_.Exception.Message)" -ForegroundColor Red
    Read-Host "按 Enter 鍵結束..."
    exit 1
}

# 步驟 3: 執行 Quick-Install.ps1
Write-Host "`n[3/4] 正在執行完整安裝程序..." -ForegroundColor Yellow
Write-Host "   - 執行位置：$repoDir" -ForegroundColor Gray
Write-Host "   - 子腳本需要時會彈出 UAC 視窗，請允許提權" -ForegroundColor Cyan
Write-Host ""

Push-Location $repoDir

try {
    if ($AllowAdmin) {
        & "$repoDir\Quick-Install.ps1" -AllowAdmin
    } else {
        & "$repoDir\Quick-Install.ps1"
    }
    $installExitCode = $LASTEXITCODE
} catch {
    Write-Host "❌ 安裝過程發生錯誤：$($_.Exception.Message)" -ForegroundColor Red
    $installExitCode = 1
} finally {
    Pop-Location
}

# 步驟 4: 清理臨時檔案
Write-Host "`n[4/4] 正在清理臨時檔案..." -ForegroundColor Yellow

try {
    Remove-Item -Path $zipFile -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "   - 清理完成" -ForegroundColor Green
} catch {
    Write-Host "⚠️  清理臨時檔案時發生錯誤（可忽略）" -ForegroundColor Yellow
}

# 完成
Write-Host ""
if ($installExitCode -eq 0) {
    Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                                                           ║" -ForegroundColor Green
    Write-Host "║               Bootstrap Complete! 🎉                      ║" -ForegroundColor Green
    Write-Host "║                                                           ║" -ForegroundColor Green
    Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Green
} else {
    Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║                                                           ║" -ForegroundColor Red
    Write-Host "║            Installation Failed                            ║" -ForegroundColor Red
    Write-Host "║                                                           ║" -ForegroundColor Red
    Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    Write-Host "請檢查上方的錯誤訊息" -ForegroundColor Yellow
}

Write-Host ""
exit $installExitCode
