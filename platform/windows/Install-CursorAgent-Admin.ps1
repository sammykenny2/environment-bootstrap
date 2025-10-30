<#
.SYNOPSIS
    Install Cursor Agent CLI in WSL2 environment

.DESCRIPTION
    Installs Cursor Agent CLI, an agentic command-line tool for AI-powered development.
    Cursor Agent CLI is independent from Cursor IDE and designed for headless/CLI-only usage.

    Requirements:
    - WSL2 with Ubuntu or compatible distribution
    - Cursor subscription (for authentication)

    Self-elevates to Administrator when needed.

.PARAMETER Upgrade
    Upgrade existing installation to latest version

.PARAMETER Force
    Force reinstall even if already installed

.PARAMETER Distro
    WSL distribution to install in (default: Ubuntu)

.EXAMPLE
    .\Install-CursorAgent-Admin.ps1
    Default: Install if missing, skip if already installed

.EXAMPLE
    .\Install-CursorAgent-Admin.ps1 -Upgrade
    Upgrade to latest version if installed, install if missing

.EXAMPLE
    .\Install-CursorAgent-Admin.ps1 -Force
    Force reinstall Cursor Agent CLI

.EXAMPLE
    .\Install-CursorAgent-Admin.ps1 -Distro "Ubuntu-22.04"
    Install in specific WSL distribution

.NOTES
    - Cursor Agent CLI requires a Cursor subscription
    - Authentication via browser login or API key (CURSOR_API_KEY)
    - Run cursor-agent in WSL terminal after installation
#>

param(
    [Parameter(Mandatory=$false)]
    [switch]$Upgrade,

    [Parameter(Mandatory=$false)]
    [switch]$Force,

    [Parameter(Mandatory=$false)]
    [switch]$NonInteractive,

    [Parameter(Mandatory=$false)]
    [string]$Distro = "Ubuntu"
)

# === Self-Elevation Logic ===
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "🔒 需要管理員權限，正在提權..." -ForegroundColor Cyan

    # Rebuild parameter list
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($Upgrade) { $arguments += " -Upgrade" }
    if ($Force) { $arguments += " -Force" }
    if ($NonInteractive) { $arguments += " -NonInteractive" }
    if ($Distro -ne "Ubuntu") { $arguments += " -Distro `"$Distro`"" }

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
Write-Host "--- Cursor Agent CLI 安裝腳本 ---" -ForegroundColor Cyan

# 處理互斥參數
if ($Force -and $Upgrade) {
    Write-Host "⚠️  警告：不能同時使用 -Force 和 -Upgrade，將使用 -Force" -ForegroundColor Yellow
    $Upgrade = $false
}

# 步驟 1: 檢查 WSL2 依賴
Write-Host "`n1. 正在檢查 WSL2 依賴..." -ForegroundColor Yellow

$wslCommand = Get-Command wsl -ErrorAction SilentlyContinue
if (-not $wslCommand) {
    Write-Host "❌ 未找到 WSL2" -ForegroundColor Red
    Write-Host "   - Cursor Agent CLI 需要在 WSL2 中運行" -ForegroundColor Yellow
    Write-Host "   - 請先執行：.\Install-WSL2-Admin.ps1" -ForegroundColor Cyan
    if (-not $NonInteractive) {
        Read-Host "按 Enter 鍵結束..."
    }
    exit 1
}

try {
    $null = wsl --status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ WSL2 未正確安裝或配置" -ForegroundColor Red
        Write-Host "   - 請先執行：.\Install-WSL2-Admin.ps1" -ForegroundColor Cyan
        if (-not $NonInteractive) {
            Read-Host "按 Enter 鍵結束..."
        }
        exit 1
    }
    Write-Host "   - WSL2 檢查通過 ✓" -ForegroundColor Green
} catch {
    Write-Host "⚠️  WSL2 狀態檢查失敗，但將繼續安裝" -ForegroundColor Yellow
}

# 步驟 2: 檢查指定的發行版是否存在
Write-Host "`n2. 正在檢查 WSL 發行版..." -ForegroundColor Yellow

$wslList = wsl --list --quiet 2>$null
$distroExists = $false

if ($wslList) {
    $trimmedList = $wslList | ForEach-Object { $_.Trim() }
    $distroExists = $trimmedList -contains $Distro
}

if (-not $distroExists) {
    Write-Host "❌ 未找到 WSL 發行版：$Distro" -ForegroundColor Red
    Write-Host "`n可用的發行版：" -ForegroundColor Cyan
    $wslList | Where-Object { $_ } | ForEach-Object {
        Write-Host "   - $_" -ForegroundColor Gray
    }
    Write-Host "`n請使用 -Distro 參數指定正確的發行版，或先安裝 Ubuntu：" -ForegroundColor Yellow
    Write-Host "   wsl --install -d Ubuntu" -ForegroundColor White
    if (-not $NonInteractive) {
        Read-Host "按 Enter 鍵結束..."
    }
    exit 1
}

Write-Host "   - 發行版檢查通過：$Distro ✓" -ForegroundColor Green

# 步驟 3: 檢查 Cursor Agent CLI 是否已安裝
Write-Host "`n3. 正在檢查 Cursor Agent CLI 是否已安裝..." -ForegroundColor Yellow

$checkCommand = "command -v cursor-agent >/dev/null 2>&1 && echo 'installed' || echo 'not-installed'"
$checkResult = wsl -d $Distro bash -c $checkCommand 2>$null

if ($checkResult -match "installed") {
    # 獲取版本信息
    $versionCommand = "cursor-agent --version 2>&1 || echo 'unknown'"
    $versionInfo = wsl -d $Distro bash -c $versionCommand 2>$null

    if ($versionInfo -and $versionInfo -ne "unknown") {
        Write-Host "   - 您已在 $Distro 中安裝 Cursor Agent CLI" -ForegroundColor Green
        Write-Host "   - 版本：$versionInfo" -ForegroundColor Gray
    } else {
        Write-Host "   - 您已在 $Distro 中安裝 Cursor Agent CLI" -ForegroundColor Green
    }

    # 根據參數決定行為
    if ($Force) {
        Write-Host "   - 使用 -Force 參數，將強制重新安裝。" -ForegroundColor Yellow
    } elseif ($Upgrade) {
        Write-Host "   - 使用 -Upgrade 參數，將升級到最新版本。" -ForegroundColor Yellow
    } else {
        Write-Host "   - 無需重複安裝。如需升級請使用 -Upgrade 參數。" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "📝 使用方式：" -ForegroundColor Cyan
        Write-Host "   1. 進入 WSL：wsl -d $Distro" -ForegroundColor White
        Write-Host "   2. 運行 Agent：cursor-agent" -ForegroundColor White
        Write-Host "   3. 或直接運行：cursor-agent chat `"your prompt here`"" -ForegroundColor White
        Write-Host ""
        Write-Host "🔐 認證方式：" -ForegroundColor Cyan
        Write-Host "   - 瀏覽器登錄（推薦）：首次運行時會自動提示" -ForegroundColor White
        Write-Host "   - API Key：export CURSOR_API_KEY=your_api_key" -ForegroundColor White
        Write-Host "   - API Key 獲取：https://cursor.com → Integrations → User API Keys" -ForegroundColor Gray
        if (-not $NonInteractive) {
            Read-Host "按 Enter 鍵結束..."
        }
        exit 0
    }
} else {
    Write-Host "   - 系統中未找到 Cursor Agent CLI，準備開始安裝。" -ForegroundColor Gray
}

# 步驟 4: 檢查 WSL 中是否有 curl
Write-Host "`n4. 正在檢查 WSL 中的 curl..." -ForegroundColor Yellow

$curlCheckCommand = "command -v curl >/dev/null 2>&1 && echo 'installed' || echo 'not-installed'"
$curlCheck = wsl -d $Distro bash -c $curlCheckCommand 2>$null

if ($curlCheck -notmatch "installed") {
    Write-Host "   - 未找到 curl，正在安裝..." -ForegroundColor Yellow

    # 嘗試安裝 curl（支援不同的包管理器）
    $installCurlCommand = @"
if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -qq && sudo apt-get install -y curl
elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y curl
elif command -v apk >/dev/null 2>&1; then
    sudo apk add curl
else
    echo 'error: no package manager found'
    exit 1
fi
"@

    try {
        $curlInstallOutput = wsl -d $Distro bash -c $installCurlCommand 2>&1

        if ($curlInstallOutput -match "error: no package manager found") {
            Write-Host "❌ 無法安裝 curl：未找到支援的包管理器" -ForegroundColor Red
            Write-Host "   - 請手動在 WSL 中安裝 curl" -ForegroundColor Yellow
            if (-not $NonInteractive) {
                Read-Host "按 Enter 鍵結束..."
            }
            exit 1
        }

        # 驗證 curl 是否安裝成功
        $curlVerify = wsl -d $Distro bash -c $curlCheckCommand 2>$null
        if ($curlVerify -match "installed") {
            Write-Host "   - curl 安裝成功 ✓" -ForegroundColor Green
        } else {
            Write-Host "❌ curl 安裝失敗" -ForegroundColor Red
            Write-Host "   - 請手動在 WSL 中執行：sudo apt-get install curl" -ForegroundColor Yellow
            if (-not $NonInteractive) {
                Read-Host "按 Enter 鍵結束..."
            }
            exit 1
        }
    } catch {
        Write-Host "❌ curl 安裝過程發生錯誤：$($_.Exception.Message)" -ForegroundColor Red
        if (-not $NonInteractive) {
            Read-Host "按 Enter 鍵結束..."
        }
        exit 1
    }
} else {
    Write-Host "   - curl 檢查通過 ✓" -ForegroundColor Green
}

# 步驟 5: 安裝/升級 Cursor Agent CLI
Write-Host "`n5. 正在安裝 Cursor Agent CLI..." -ForegroundColor Yellow
Write-Host "   - 這可能需要幾分鐘時間，請稍候..." -ForegroundColor Gray

$installSuccess = $false

# 方法 A: 標準安裝（使用 HTTPS）
$installCommand = "curl https://cursor.com/install -fsSL | bash"

Write-Host "`n執行安裝腳本..." -ForegroundColor Cyan
Write-Host "Command: $installCommand" -ForegroundColor DarkGray

try {
    # 在 WSL 中執行安裝
    $installOutput = wsl -d $Distro bash -c $installCommand 2>&1

    # 顯示安裝輸出
    if ($installOutput) {
        Write-Host ""
        Write-Host "安裝輸出：" -ForegroundColor Gray
        $installOutput | ForEach-Object {
            Write-Host "   $_" -ForegroundColor DarkGray
        }
    }

    # 等待安裝完成後檢查
    Start-Sleep -Seconds 2

    # 驗證安裝
    $verifyCommand = "command -v cursor-agent >/dev/null 2>&1 && echo 'success' || echo 'failed'"
    $verifyResult = wsl -d $Distro bash -c $verifyCommand 2>$null

    if ($verifyResult -match "success") {
        $installSuccess = $true
        Write-Host ""
        Write-Host "✅ Cursor Agent CLI 安裝成功！" -ForegroundColor Green

        # 獲取版本信息
        $versionCommand = "cursor-agent --version 2>&1 || echo 'unknown'"
        $newVersion = wsl -d $Distro bash -c $versionCommand 2>$null
        if ($newVersion -and $newVersion -ne "unknown") {
            Write-Host "   - 版本：$newVersion" -ForegroundColor Gray
        }
    } else {
        Write-Host ""
        Write-Host "⚠️  標準安裝方法未成功" -ForegroundColor Yellow
        Write-Host "   - 可能是網路連線或 SSL 憑證問題" -ForegroundColor Gray
        $installSuccess = $false
    }

} catch {
    Write-Host ""
    Write-Host "⚠️  標準安裝發生錯誤：$($_.Exception.Message)" -ForegroundColor Yellow
    $installSuccess = $false
}

# 方法 B: Fallback - 使用 --ssl-no-revoke（適用於防火牆環境）
if (-not $installSuccess) {
    Write-Host ""
    Write-Host "嘗試 Fallback 方法（繞過 SSL 憑證驗證）..." -ForegroundColor Yellow
    Write-Host "   - 適用於企業防火牆環境" -ForegroundColor Gray

    $fallbackCommand = "curl --ssl-no-revoke -fsSL https://cursor.com/install | bash"
    Write-Host "   Command: $fallbackCommand" -ForegroundColor DarkGray

    try {
        # 在 WSL 中執行 fallback 安裝
        $fallbackOutput = wsl -d $Distro bash -c $fallbackCommand 2>&1

        # 顯示安裝輸出
        if ($fallbackOutput) {
            Write-Host ""
            Write-Host "安裝輸出：" -ForegroundColor Gray
            $fallbackOutput | ForEach-Object {
                Write-Host "   $_" -ForegroundColor DarkGray
            }
        }

        # 等待安裝完成後檢查
        Start-Sleep -Seconds 2

        # 驗證安裝
        $verifyCommand = "command -v cursor-agent >/dev/null 2>&1 && echo 'success' || echo 'failed'"
        $verifyResult = wsl -d $Distro bash -c $verifyCommand 2>$null

        if ($verifyResult -match "success") {
            $installSuccess = $true
            Write-Host ""
            Write-Host "✅ Cursor Agent CLI 安裝成功（使用 Fallback 方法）！" -ForegroundColor Green

            # 獲取版本信息
            $versionCommand = "cursor-agent --version 2>&1 || echo 'unknown'"
            $newVersion = wsl -d $Distro bash -c $versionCommand 2>$null
            if ($newVersion -and $newVersion -ne "unknown") {
                Write-Host "   - 版本：$newVersion" -ForegroundColor Gray
            }
        } else {
            Write-Host ""
            Write-Host "❌ Fallback 方法也無法完成安裝" -ForegroundColor Red
            $installSuccess = $false
        }

    } catch {
        Write-Host ""
        Write-Host "❌ Fallback 安裝發生錯誤：$($_.Exception.Message)" -ForegroundColor Red
        $installSuccess = $false
    }
}

# 步驟 6: 顯示結果和使用說明
Write-Host ""
if ($installSuccess) {
    Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║         Cursor Agent CLI 安裝成功！                     ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 後續步驟：" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1️⃣  進入 WSL 環境：" -ForegroundColor Yellow
    Write-Host "   wsl -d $Distro" -ForegroundColor White
    Write-Host ""
    Write-Host "2️⃣  啟動 Cursor Agent：" -ForegroundColor Yellow
    Write-Host "   cursor-agent" -ForegroundColor White
    Write-Host ""
    Write-Host "3️⃣  或直接運行帶提示：" -ForegroundColor Yellow
    Write-Host "   cursor-agent chat `"find one bug and fix it`"" -ForegroundColor White
    Write-Host ""
    Write-Host "🔐 認證設定：" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   方式 1 - 瀏覽器登錄（推薦）：" -ForegroundColor Yellow
    Write-Host "   首次運行 cursor-agent 時會自動提示瀏覽器登錄" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   方式 2 - API Key（無桌面環境）：" -ForegroundColor Yellow
    Write-Host "   export CURSOR_API_KEY=your_api_key_here" -ForegroundColor White
    Write-Host "   cursor-agent chat `"your prompt`"" -ForegroundColor White
    Write-Host ""
    Write-Host "   獲取 API Key：" -ForegroundColor Gray
    Write-Host "   https://cursor.com → Settings → Integrations → User API Keys" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "⚠️  重要提醒：" -ForegroundColor Yellow
    Write-Host "   - Cursor Agent CLI 需要 Cursor 訂閱才能使用" -ForegroundColor Gray
    Write-Host "   - 目前仍在 Beta 階段" -ForegroundColor Gray
    Write-Host "   - 可讀取、修改、刪除檔案並執行命令，請在可信環境中使用" -ForegroundColor Gray
    Write-Host ""

    if (-not $NonInteractive) {
        Read-Host "按 Enter 鍵結束..."
    }
    exit 0
} else {
    Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║         Cursor Agent CLI 安裝失敗                       ║" -ForegroundColor Red
    Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    Write-Host "💡 故障排除：" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. 確認 WSL2 正常運作：" -ForegroundColor Cyan
    Write-Host "   wsl -d $Distro uname -a" -ForegroundColor White
    Write-Host ""
    Write-Host "2. 確認 curl 已安裝：" -ForegroundColor Cyan
    Write-Host "   wsl -d $Distro curl --version" -ForegroundColor White
    Write-Host "   如未安裝：wsl -d $Distro sudo apt-get install curl" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. 確認網路連線正常：" -ForegroundColor Cyan
    Write-Host "   wsl -d $Distro curl -I https://cursor.com" -ForegroundColor White
    Write-Host ""
    Write-Host "4. 手動在 WSL 中安裝（標準方法）：" -ForegroundColor Cyan
    Write-Host "   wsl -d $Distro" -ForegroundColor White
    Write-Host "   curl https://cursor.com/install -fsSL | bash" -ForegroundColor White
    Write-Host ""
    Write-Host "5. 手動在 WSL 中安裝（防火牆環境）：" -ForegroundColor Cyan
    Write-Host "   wsl -d $Distro" -ForegroundColor White
    Write-Host "   curl --ssl-no-revoke -fsSL https://cursor.com/install | bash" -ForegroundColor White
    Write-Host ""
    Write-Host "6. 查看安裝日誌：" -ForegroundColor Cyan
    Write-Host "   檢查上方的安裝輸出以獲取錯誤信息" -ForegroundColor Gray
    Write-Host ""

    if (-not $NonInteractive) {
        Read-Host "按 Enter 鍵結束..."
    }
    exit 1
}
