<#
.SYNOPSIS
    Install or upgrade Ngrok using Windows Package Manager (winget)

.DESCRIPTION
    Checks and installs Ngrok. Supports upgrade and force reinstall modes.
    Self-elevates to Administrator when needed.
    Fallback to direct download if winget fails.

.PARAMETER Upgrade
    Upgrade existing installation to latest version

.PARAMETER Force
    Force reinstall even if already installed

.EXAMPLE
    .\Install-Ngrok-Admin.ps1
    Default: Install if missing, skip if already installed

.EXAMPLE
    .\Install-Ngrok-Admin.ps1 -Upgrade
    Upgrade to latest version if installed, install if missing

.EXAMPLE
    .\Install-Ngrok-Admin.ps1 -Force
    Force reinstall Ngrok
#>

param(
    [Parameter(Mandatory=$false)]
    [switch]$Upgrade,

    [Parameter(Mandatory=$false)]
    [switch]$Force,

    [Parameter(Mandatory=$false)]
    [switch]$NonInteractive
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
Write-Host "--- Ngrok 安裝腳本 ---" -ForegroundColor Cyan

# 處理互斥參數
if ($Force -and $Upgrade) {
    Write-Host "⚠️  警告：不能同時使用 -Force 和 -Upgrade，將使用 -Force" -ForegroundColor Yellow
    $Upgrade = $false
}

# 步驟 1: 檢查 winget 是否可用
Write-Host "`n1. 正在檢查 winget 套件管理器..." -ForegroundColor Yellow
$wingetExists = Get-Command winget -ErrorAction SilentlyContinue

if (-not $wingetExists) {
    Write-Host "⚠️  未找到 winget，將使用 fallback 方法" -ForegroundColor Yellow
    $useWinget = $false
} else {
    Write-Host "   - winget 檢查通過" -ForegroundColor Green
    $useWinget = $true
}

# 步驟 2: 檢查 Ngrok 是否已安裝
Write-Host "`n2. 正在檢查 Ngrok 是否已安裝..." -ForegroundColor Yellow

# 刷新環境變數
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

$ngrokExists = Get-Command ngrok -ErrorAction SilentlyContinue
if ($ngrokExists) {
    $ngrokVersion = (ngrok version 2>&1 | Select-String "version" | Select-Object -First 1).ToString().Trim()
    Write-Host "   - 您已安裝 Ngrok: $ngrokVersion" -ForegroundColor Green

    # 根據參數決定行為
    if ($Force) {
        Write-Host "   - 使用 -Force 參數，將強制重新安裝。" -ForegroundColor Yellow
    } elseif ($Upgrade) {
        Write-Host "   ⚠️  注意：Ngrok 沒有公開版本 API，無法自動檢測是否為最新版本" -ForegroundColor Yellow
        Write-Host "   - 您目前的版本：$ngrokVersion" -ForegroundColor Cyan
        Write-Host "   - 如需升級，請前往 https://ngrok.com/download 檢查最新版本" -ForegroundColor Cyan
        Write-Host "   - 如確定需要升級，請使用 -Force 參數強制重新安裝" -ForegroundColor Cyan
        Write-Host "   - ✓ 已安裝，跳過" -ForegroundColor Green
        if (-not $NonInteractive) {
        Read-Host "按 Enter 鍵結束..."
        }
        exit 0
    } else {
        Write-Host "   - 無需重複安裝。如需升級請使用 -Upgrade 參數。" -ForegroundColor Cyan
        if (-not $NonInteractive) {
        Read-Host "按 Enter 鍵結束..."
        }
        exit 0
    }
} else {
    Write-Host "   - 系統中未找到 Ngrok，準備開始安裝。"
}

# 步驟 3: 安裝/升級 Ngrok
$installSuccess = $false

if ($useWinget) {
    # 方法 A: 使用 winget 安裝
    Write-Host "`n3. 正在使用 winget 安裝 Ngrok..." -ForegroundColor Yellow
    Write-Host "   - 這可能需要幾分鐘時間，請稍候..."

    try {
        if ($Upgrade -and $ngrokExists) {
            $command = "winget upgrade --id Ngrok.Ngrok -e --silent --accept-package-agreements --accept-source-agreements"
            Write-Host "   - 正在升級 Ngrok..." -ForegroundColor Gray
        } else {
            $command = "winget install --id Ngrok.Ngrok -e --silent --accept-package-agreements --accept-source-agreements"
            if ($Force) {
                $command += " --force"
            }
            Write-Host "   - 正在安裝 Ngrok..." -ForegroundColor Gray
        }

        Invoke-Expression $command 2>&1 | Out-Null
        $exitCode = $LASTEXITCODE

        # Winget exit codes:
        # 0 = Success
        # -1978335189 (0x8A15002B) = No applicable update found (already latest)

        if ($exitCode -eq 0) {
            Write-Host "   - Ngrok 安裝成功！" -ForegroundColor Green
            $installSuccess = $true
        } elseif (($Upgrade -and $ngrokExists) -and ($exitCode -eq -1978335189)) {
            Write-Host "   - Ngrok 已是最新版本！" -ForegroundColor Green
            $installSuccess = $true
        } else {
            Write-Host "⚠️  winget 安裝失敗 (exit code: $exitCode)" -ForegroundColor Yellow
            Write-Host "   - 將嘗試 fallback 方法" -ForegroundColor Yellow
            $installSuccess = $false
        }
    } catch {
        Write-Host "⚠️  winget 安裝發生錯誤：$($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "   - 將嘗試 fallback 方法" -ForegroundColor Yellow
        $installSuccess = $false
    }
}

# 方法 B: Fallback - 從官網下載 zip
if (-not $installSuccess) {
    Write-Host "`n3. 正在從官網下載 Ngrok..." -ForegroundColor Yellow

    try {
        # Ngrok Windows 64-bit 下載連結
        $downloadUrl = "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-windows-amd64.zip"
        $zipFile = "$env:TEMP\ngrok.zip"
        $installDir = "$env:ProgramFiles\ngrok"

        Write-Host "   - 正在下載 Ngrok..." -ForegroundColor Gray
        $ProgressPreference = 'Continue'  # Show download progress
        try {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $zipFile -UseBasicParsing
            Write-Host "   - 下載完成！" -ForegroundColor Green
        } finally {
            $ProgressPreference = 'SilentlyContinue'  # Restore default
        }

        Write-Host "   - 正在解壓縮..." -ForegroundColor Gray

        # 建立安裝目錄
        if (Test-Path $installDir) {
            Remove-Item -Path $installDir -Recurse -Force
        }
        New-Item -Path $installDir -ItemType Directory -Force | Out-Null

        # 解壓縮
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipFile, $installDir)

        # 清理 zip 檔案
        Remove-Item -Path $zipFile -Force

        # 加入 PATH
        Write-Host "   - 正在更新 PATH 環境變數..." -ForegroundColor Gray
        $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")

        if ($machinePath -notlike "*$installDir*") {
            [System.Environment]::SetEnvironmentVariable("Path", "$installDir;$machinePath", "Machine")
        }

        # 刷新當前 session PATH（完整讀取 Machine + User）
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

        # 驗證安裝
        $ngrokCheck = Get-Command ngrok -ErrorAction SilentlyContinue
        if ($ngrokCheck) {
            Write-Host "   - Ngrok 安裝成功！" -ForegroundColor Green
            $installSuccess = $true
        } else {
            throw "Ngrok 安裝後未找到 ngrok 命令"
        }

    } catch {
        Write-Host "❌ Ngrok 安裝失敗：$($_.Exception.Message)" -ForegroundColor Red
        Write-Host "   - 請手動從 https://ngrok.com/download 下載安裝" -ForegroundColor Yellow
        if (-not $NonInteractive) {
        Read-Host "按 Enter 鍵結束..."
        }
        exit 1
    }
}

# --- 完成 ---
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Ngrok 安裝完成！"
Write-Host "請關閉此視窗，並「重新開啟一個新的 PowerShell 視窗」再繼續後續操作。"
Write-Host "========================================" -ForegroundColor Cyan

# 顯示版本資訊
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
$ngrokCheck = Get-Command ngrok -ErrorAction SilentlyContinue
if ($ngrokCheck) {
    $ngrokVersion = ngrok version 2>&1 | Select-String "version" | Select-Object -First 1
    Write-Host "`n已安裝版本：$ngrokVersion" -ForegroundColor Green
    Write-Host ""
    Write-Host "提示：首次使用需要設定 authtoken" -ForegroundColor Cyan
    Write-Host "      ngrok config add-authtoken <your_token>" -ForegroundColor White
}

Write-Host ""
if (-not $NonInteractive) {
Read-Host "按 Enter 鍵結束..."
}
exit 0
