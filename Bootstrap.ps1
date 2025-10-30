<#
.SYNOPSIS
    Bootstrap script - Download and execute full environment setup

.DESCRIPTION
    Single-file distribution script that:
    1. Asks for installation mode (Quick/Full)
    2. Downloads the complete environment-bootstrap repository
    3. Extracts to temp directory
    4. Optionally creates .env configuration
    5. Executes Quick-Install.ps1 or Full-Install.ps1 based on mode
    6. Cleans up temporary files

    This script requires NO external dependencies - only built-in PowerShell features.

.PARAMETER AllowAdmin
    Allow execution with admin privileges (for Administrator accounts only)

.EXAMPLE
    .\Bootstrap.ps1
    Interactive setup with installation mode and configuration

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
Write-Host "歡迎使用 Windows 開發環境自動安裝工具！" -ForegroundColor Cyan
Write-Host ""

# 步驟 0: 選擇安裝模式
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor DarkGray
Write-Host "請選擇安裝模式：" -ForegroundColor Yellow
Write-Host ""
Write-Host "  [1] Quick Mode - 基礎開發工具" -ForegroundColor White
Write-Host "      • Node.js, Python, Git, PowerShell 7" -ForegroundColor Gray
Write-Host "      • 適合一般開發使用" -ForegroundColor Gray
Write-Host ""
Write-Host "  [2] Full Mode - 完整容器化環境" -ForegroundColor White
Write-Host "      • Quick Mode 的所有工具" -ForegroundColor Gray
Write-Host "      • WSL2, Docker Desktop, Ngrok, Cursor Agent CLI" -ForegroundColor Gray
Write-Host "      • 適合需要容器環境的開發" -ForegroundColor Gray
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor DarkGray

$modeChoice = ""
while ($modeChoice -ne "1" -and $modeChoice -ne "2") {
    $modeChoice = Read-Host "`n請選擇 (1 或 2)"
    if ($modeChoice -ne "1" -and $modeChoice -ne "2") {
        Write-Host "❌ 無效選擇，請輸入 1 或 2" -ForegroundColor Red
    }
}

$installMode = if ($modeChoice -eq "1") { "Quick" } else { "Full" }
$installScript = if ($modeChoice -eq "1") { "Quick-Install.ps1" } else { "Full-Install.ps1" }

Write-Host ""
Write-Host "✓ 已選擇：$installMode Mode" -ForegroundColor Green
Write-Host ""

# 步驟 1: 下載 repository
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor DarkGray
Write-Host "[1/5] 正在下載環境安裝工具..." -ForegroundColor Yellow

$repoUrl = "https://github.com/sammykenny2/environment-bootstrap/archive/refs/heads/main.zip"
$zipFile = "$env:TEMP\env-bootstrap-$(Get-Date -Format 'yyyyMMdd-HHmmss').zip"
$extractPath = "$env:TEMP\env-bootstrap-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$repoDir = "$extractPath\environment-bootstrap-main"

try {
    Invoke-WebRequest -Uri $repoUrl -OutFile $zipFile -UseBasicParsing
    Write-Host "   ✓ 下載完成" -ForegroundColor Green
} catch {
    Write-Host "❌ 下載失敗：$($_.Exception.Message)" -ForegroundColor Red
    Write-Host "請檢查網路連線或稍後再試" -ForegroundColor Yellow
    Read-Host "按 Enter 鍵結束..."
    exit 1
}

# 步驟 2: 解壓縮
Write-Host "`n[2/5] 正在解壓縮..." -ForegroundColor Yellow

try {
    Expand-Archive -Path $zipFile -DestinationPath $extractPath -Force
    Write-Host "   ✓ 解壓縮完成" -ForegroundColor Green
} catch {
    Write-Host "❌ 解壓縮失敗：$($_.Exception.Message)" -ForegroundColor Red
    Read-Host "按 Enter 鍵結束..."
    exit 1
}

# 步驟 3: 配置向導
Write-Host "`n[3/5] 配置設定..." -ForegroundColor Yellow

$envFilePath = Join-Path $repoDir ".env"

if (Test-Path $envFilePath) {
    Write-Host "   ✓ 找到現有的 .env 配置文件" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    Write-Host "配置向導" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "部分工具需要個人化配置（例如 Git 使用者資訊）。" -ForegroundColor Gray
    Write-Host "您可以現在設定，或稍後手動編輯 .env 文件。" -ForegroundColor Gray
    Write-Host ""

    $configNow = Read-Host "是否現在進行配置？(Y/n)"

    if ($configNow -eq "" -or $configNow -eq "Y" -or $configNow -eq "y") {
        Write-Host ""
        Write-Host "請提供以下資訊：" -ForegroundColor Cyan
        Write-Host ""

        # Git 配置
        Write-Host "Git 配置 (用於 commit 記錄)：" -ForegroundColor Yellow

        $gitUserName = ""
        while ($gitUserName.Trim() -eq "") {
            $gitUserName = Read-Host "  您的姓名 (例如: John Doe)"
            if ($gitUserName.Trim() -eq "") {
                Write-Host "  ❌ 姓名不能為空，請重新輸入" -ForegroundColor Red
            }
        }

        $gitUserEmail = ""
        while ($gitUserEmail.Trim() -eq "" -or $gitUserEmail -notmatch '@') {
            $gitUserEmail = Read-Host "  您的 Email (例如: john@example.com)"
            if ($gitUserEmail.Trim() -eq "") {
                Write-Host "  ❌ Email 不能為空，請重新輸入" -ForegroundColor Red
            } elseif ($gitUserEmail -notmatch '@') {
                Write-Host "  ❌ Email 格式不正確，請重新輸入" -ForegroundColor Red
            }
        }

        Write-Host "  ✓ Git 配置完成" -ForegroundColor Green

        # Ngrok 配置 (僅 Full 模式)
        $ngrokAuthToken = ""
        if ($installMode -eq "Full") {
            Write-Host ""
            Write-Host "Ngrok 配置 (可選)：" -ForegroundColor Yellow
            Write-Host "  如果您有 Ngrok 帳號，可以設定 authtoken" -ForegroundColor Gray
            Write-Host "  取得 token：https://dashboard.ngrok.com/get-started/your-authtoken" -ForegroundColor Gray
            $ngrokAuthToken = Read-Host "  Ngrok authtoken (留空跳過)"

            if ($ngrokAuthToken.Trim() -ne "") {
                Write-Host "  ✓ Ngrok 配置完成" -ForegroundColor Green
            } else {
                Write-Host "  ⊘ 跳過 Ngrok 配置（稍後可手動設定）" -ForegroundColor Gray
            }
        }

        # 創建 .env 文件
        Write-Host ""
        Write-Host "正在創建 .env 配置文件..." -ForegroundColor Cyan

        $envContent = @"
# Environment Bootstrap Configuration
# This file was auto-generated by Bootstrap.ps1

# ============================================================================
# Git Configuration (Required for Setup-Git.ps1)
# ============================================================================

# Your name for git commits
GIT_USER_NAME=$gitUserName

# Your email for git commits
GIT_USER_EMAIL=$gitUserEmail

# ============================================================================
# Ngrok Configuration (Optional, for Setup-Ngrok.ps1)
# ============================================================================

# Ngrok authentication token (get from https://dashboard.ngrok.com/get-started/your-authtoken)
NGROK_AUTHTOKEN=$ngrokAuthToken

# ============================================================================
# Network Configuration (Optional)
# ============================================================================

# Proxy settings (if behind corporate proxy)
# Uncomment and set if needed
# HTTP_PROXY=http://proxy.example.com:8080
# HTTPS_PROXY=http://proxy.example.com:8080
# NO_PROXY=localhost,127.0.0.1

# ============================================================================
# Notes
# ============================================================================

# - Leave values empty if not needed (empty values will be skipped by scripts)
# - For more configuration options, see individual script documentation
"@

        try {
            Set-Content -Path $envFilePath -Value $envContent -Encoding UTF8
            Write-Host "   ✓ .env 文件創建完成" -ForegroundColor Green
        } catch {
            Write-Host "   ⚠️  無法創建 .env 文件：$($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "   配置將在安裝過程中提示" -ForegroundColor Gray
        }
    } else {
        Write-Host ""
        Write-Host "   ⊘ 跳過配置" -ForegroundColor Gray
        Write-Host "   提示：稍後可以複製 .env.example 為 .env 並手動編輯" -ForegroundColor Cyan
    }
}

# 步驟 4: 執行安裝程序
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor DarkGray
Write-Host "[4/5] 正在執行 $installMode Mode 安裝程序..." -ForegroundColor Yellow
Write-Host "   執行位置：$repoDir" -ForegroundColor Gray
Write-Host "   子腳本需要時會彈出 UAC 視窗，請允許提權" -ForegroundColor Cyan
Write-Host ""

Push-Location $repoDir

try {
    if ($AllowAdmin) {
        & "$repoDir\$installScript" -AllowAdmin
    } else {
        & "$repoDir\$installScript"
    }
    $installExitCode = $LASTEXITCODE
} catch {
    Write-Host "❌ 安裝過程發生錯誤：$($_.Exception.Message)" -ForegroundColor Red
    $installExitCode = 1
} finally {
    Pop-Location
}

# 步驟 5: 清理臨時檔案
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor DarkGray
Write-Host "[5/5] 正在清理臨時檔案..." -ForegroundColor Yellow

try {
    Remove-Item -Path $zipFile -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "   ✓ 清理完成" -ForegroundColor Green
} catch {
    Write-Host "   ⚠️  清理臨時檔案時發生錯誤（可忽略）" -ForegroundColor Yellow
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
