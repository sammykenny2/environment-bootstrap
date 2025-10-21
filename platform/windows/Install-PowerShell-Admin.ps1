<#
.SYNOPSIS
    Install or upgrade PowerShell 7

.DESCRIPTION
    Checks and installs PowerShell 7 (Core/Cross-platform version).
    Primary method: Install via winget
    Fallback method: Download MSI from GitHub releases
    Supports upgrade and force reinstall modes.
    Self-elevates to Administrator when needed.

.PARAMETER Upgrade
    Upgrade existing installation to latest version

.PARAMETER Force
    Force reinstall even if already installed

.EXAMPLE
    .\Install-PowerShell.ps1
    Default: Install if missing, skip if already installed

.EXAMPLE
    .\Install-PowerShell.ps1 -Upgrade
    Upgrade to latest version if installed, install if missing

.EXAMPLE
    .\Install-PowerShell.ps1 -Force
    Force reinstall PowerShell 7
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
Write-Host "--- PowerShell 7 安裝腳本 ---" -ForegroundColor Cyan

# 處理互斥參數
if ($Force -and $Upgrade) {
    Write-Host "⚠️  警告：不能同時使用 -Force 和 -Upgrade，將使用 -Force" -ForegroundColor Yellow
    $Upgrade = $false
}

# 步驟 1: 檢查 PowerShell 7 是否已安裝
Write-Host "`n1. 正在檢查 PowerShell 7 是否已安裝..." -ForegroundColor Yellow
$pwshExists = Get-Command pwsh -ErrorAction SilentlyContinue

if ($pwshExists) {
    $pwshVersion = (pwsh -v).Trim()
    Write-Host "   - 您已安裝 PowerShell 7，版本為 $pwshVersion。" -ForegroundColor Green

    # 根據參數決定行為
    if ($Force) {
        Write-Host "   - 使用 -Force 參數，將強制重新安裝。" -ForegroundColor Yellow
    } elseif ($Upgrade) {
        Write-Host "   - 使用 -Upgrade 參數，將升級到最新版本。" -ForegroundColor Yellow
    } else {
        Write-Host "   - 無需重複安裝。如需升級請使用 -Upgrade 參數。" -ForegroundColor Cyan
        exit 0
    }
} else {
    Write-Host "   - 系統中未找到 PowerShell 7，準備開始安裝。"
}

# 步驟 2: 方法 A - 嘗試使用 winget 安裝
Write-Host "`n2. 正在嘗試透過 winget 安裝..." -ForegroundColor Yellow

$wingetExists = Get-Command winget -ErrorAction SilentlyContinue
$wingetSuccess = $false

if ($wingetExists) {
    Write-Host "   - winget 可用，使用 winget 安裝..." -ForegroundColor Gray

    try {
        if ($Upgrade -and $pwshExists) {
            # 升級模式
            Write-Host "   - 正在升級 PowerShell 7..." -ForegroundColor Gray
            $output = winget upgrade --id Microsoft.PowerShell -e --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
            $exitCode = $LASTEXITCODE

            # Winget exit codes:
            # 0 = Success
            # -1978335189 (0x8A15002B) = No applicable update found (already latest)

            if ($exitCode -eq 0) {
                Write-Host "   - PowerShell 7 升級成功！" -ForegroundColor Green
                $wingetSuccess = $true
            } elseif ($exitCode -eq -1978335189) {
                Write-Host "   - PowerShell 7 已是最新版本！" -ForegroundColor Green
                $wingetSuccess = $true
            } else {
                throw "Winget 升級失敗 (exit code: $exitCode)"
            }
        } else {
            # 安裝或強制重裝模式
            $command = "winget install --id Microsoft.PowerShell -e --silent --accept-package-agreements --accept-source-agreements"
            if ($Force) {
                $command += " --force"
            }

            Write-Host "   - 正在安裝 PowerShell 7..." -ForegroundColor Gray
            Invoke-Expression $command

            if ($LASTEXITCODE -eq 0) {
                Write-Host "   - PowerShell 7 安裝成功！" -ForegroundColor Green
                $wingetSuccess = $true
            } else {
                throw "Winget 安裝失敗"
            }
        }
    } catch {
        Write-Host "   - winget 安裝失敗：$($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "   - 將改用 MSI 下載方式..." -ForegroundColor Yellow
    }
} else {
    Write-Host "   - winget 不可用，將改用 MSI 下載方式..." -ForegroundColor Yellow
}

# 步驟 3: 方法 B - Fallback 到 GitHub 下載 MSI
if (-not $wingetSuccess) {
    Write-Host "`n3. 正在從 GitHub 下載 PowerShell 7 MSI..." -ForegroundColor Yellow

    try {
        # 取得最新版本資訊
        Write-Host "   - 正在查詢最新版本..." -ForegroundColor Gray
        $apiUrl = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
        $release = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing
        $version = $release.tag_name -replace '^v', ''
        Write-Host "   - 最新版本：$version" -ForegroundColor Cyan

        # 找到 x64 MSI 下載連結
        $asset = $release.assets | Where-Object { $_.name -like "*win-x64.msi" } | Select-Object -First 1
        if (-not $asset) {
            throw "找不到 PowerShell 7 MSI 安裝檔案"
        }

        $downloadUrl = $asset.browser_download_url
        $fileName = $asset.name
        $outputPath = Join-Path $env:TEMP $fileName

        # 下載檔案 (with progress)
        Write-Host "   - 正在下載 $fileName ..." -ForegroundColor Gray
        $ProgressPreference = 'Continue'  # Show download progress
        try {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $outputPath -UseBasicParsing
            Write-Host "   - 下載完成！" -ForegroundColor Green
        } finally {
            $ProgressPreference = 'SilentlyContinue'  # Restore default
        }

        # 安裝 MSI
        Write-Host "   - 正在安裝..." -ForegroundColor Gray
        $msiArgs = @(
            "/i", $outputPath,
            "/qn",  # Quiet mode, no user interaction
            "/norestart"
        )

        if ($Force) {
            $msiArgs += "REINSTALLMODE=vamus"
            $msiArgs += "REINSTALL=ALL"
        }

        $installProcess = Start-Process msiexec.exe -ArgumentList $msiArgs -Wait -PassThru

        # 清理下載檔案
        Remove-Item -Path $outputPath -Force -ErrorAction SilentlyContinue

        if ($installProcess.ExitCode -eq 0) {
            Write-Host "   - PowerShell 7 安裝成功！" -ForegroundColor Green
        } else {
            throw "MSI 安裝失敗，退出碼：$($installProcess.ExitCode)"
        }

    } catch {
        Write-Host "錯誤：MSI 下載安裝失敗：$($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        Write-Host "請手動安裝 PowerShell 7：" -ForegroundColor Yellow
        Write-Host "前往：https://github.com/PowerShell/PowerShell/releases/latest" -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }
}

# 刷新環境變數
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

# 驗證安裝
Write-Host "`n正在驗證安裝..." -ForegroundColor Yellow
$pwshExists = Get-Command pwsh -ErrorAction SilentlyContinue
if ($pwshExists) {
    $pwshVersion = (pwsh -v).Trim()
    Write-Host "   - PowerShell 7 驗證成功！版本：$pwshVersion" -ForegroundColor Green
} else {
    Write-Host "⚠️  安裝完成但無法找到 pwsh 命令" -ForegroundColor Yellow
    Write-Host "請重新開啟 PowerShell 視窗後再試" -ForegroundColor Yellow
}

# --- 完成 ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PowerShell 7 操作完成！"
Write-Host "請關閉此視窗，並「重新開啟一個新的 PowerShell 視窗」再繼續後續操作。"
Write-Host "========================================"
exit 0
