# =================================================================
# Install-NodeJS.ps1
# 檢查並使用 Winget 安裝最新版的 Node.js LTS (長期支援版)。
# Node.js 安裝後會自動包含 npm。
# =================================================================

# --- 腳本開始 ---
Write-Host "--- Node.js LTS 環境安裝腳本 ---" -ForegroundColor Cyan

# 步驟 1: 檢查是否以系統管理員身分執行
Write-Host "`n1. 正在檢查權限..." -ForegroundColor Yellow
if (-not ([System.Security.Principal.WindowsPrincipal][System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "錯誤：此腳本需要系統管理員權限來安裝軟體。" -ForegroundColor Red
    Write-Host "請使用滑鼠右鍵點擊 PowerShell 圖示，選擇「以系統管理員身分執行」。"
    Read-Host "按 Enter 鍵結束..."
    exit
}
Write-Host "   - 系統管理員權限檢查通過。" -ForegroundColor Green

# 步驟 2: 檢查 Node.js 是否已安裝
Write-Host "`n2. 正在檢查 Node.js 是否已安裝..." -ForegroundColor Yellow
$nodeExists = Get-Command node -ErrorAction SilentlyContinue
if ($nodeExists) {
    $nodeVersion = (node -v).Trim()
    Write-Host "   - 您已安裝 Node.js，版本為 $nodeVersion。" -ForegroundColor Green
    Write-Host "   - 無需重複安裝。"
    Read-Host "按 Enter 鍵結束..."
    exit
}
Write-Host "   - 系統中未找到 Node.js，準備開始安裝。"

# 步驟 3: 檢查 Winget 工具是否存在
Write-Host "`n3. 正在檢查 Winget 套件管理器..." -ForegroundColor Yellow
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "錯誤：找不到 Winget 工具。此腳本需要 Winget。" -ForegroundColor Red
    Write-Host "請確認您的 Windows 11 已更新，或從 Microsoft Store 安裝 'App Installer'。"
    Read-Host "按 Enter 鍵結束..."
    exit
}
Write-Host "   - Winget 檢查通過。" -ForegroundColor Green

# 步驟 4: 執行安裝
Write-Host "`n4. 正在使用 Winget 安裝 Node.js LTS..." -ForegroundColor Yellow
Write-Host "   - 這可能需要幾分鐘時間，請稍候..."

try {
    # -e (--exact) 確保精準匹配, --silent 讓安裝過程無須互動
    winget install --id OpenJS.NodeJS.LTS -e --silent --accept-package-agreements --accept-source-agreements
    
    # 檢查 winget 的執行結果
    if ($LASTEXITCODE -ne 0) {
        throw "Winget 安裝失敗，請檢查網路連線或錯誤訊息。"
    }

    Write-Host "   - Winget 安裝程序已完成。" -ForegroundColor Green
    Write-Host "   - 重要：您需要開啟一個「新的」PowerShell 視窗來讓環境變數生效。" -ForegroundColor Yellow

} catch {
    Write-Host "錯誤：安裝過程中發生問題: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "按 Enter 鍵結束..."
    exit
}

# --- 完成 ---
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Node.js LTS 安裝成功！"
Write-Host "請關閉此視窗，並「重新開啟一個新的 PowerShell 視窗」再繼續後續操作。"
Write-Host "========================================"
Read-Host "按 Enter 鍵結束..."