<#
.SYNOPSIS
    Install or upgrade WSL2 (Windows Subsystem for Linux 2)

.DESCRIPTION
    Checks and installs WSL2 with specified Linux distribution.
    Supports upgrade and force reinstall modes.
    Self-elevates to Administrator when needed.
    Fallback to manual feature enable if wsl --install fails.

.PARAMETER Distro
    Linux distribution to install. Default: Ubuntu
    Options: Ubuntu, Debian, kali-linux, openSUSE-Leap-15.5

.PARAMETER Upgrade
    Upgrade WSL kernel and distribution to latest version

.PARAMETER Force
    Force reinstall even if already installed

.PARAMETER NonInteractive
    No user prompts (for automation)

.EXAMPLE
    .\Install-WSL2-Admin.ps1
    Default: Install WSL2 with Ubuntu if missing

.EXAMPLE
    .\Install-WSL2-Admin.ps1 -Distro "Debian"
    Install WSL2 with Debian distribution

.EXAMPLE
    .\Install-WSL2-Admin.ps1 -Upgrade
    Upgrade WSL kernel and distributions to latest version

.EXAMPLE
    .\Install-WSL2-Admin.ps1 -Force
    Force reinstall WSL2
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$Distro = "Ubuntu",

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
    if ($Distro -ne "Ubuntu") { $arguments += " -Distro `"$Distro`"" }
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
Write-Host "--- WSL2 安裝腳本 ---" -ForegroundColor Cyan

# 處理互斥參數
if ($Force -and $Upgrade) {
    Write-Host "⚠️  警告：不能同時使用 -Force 和 -Upgrade，將使用 -Force" -ForegroundColor Yellow
    $Upgrade = $false
}

# 步驟 1: 檢查 Windows 版本
Write-Host "`n1. 正在檢查 Windows 版本..." -ForegroundColor Yellow
$windowsBuild = [System.Environment]::OSVersion.Version.Build

if ($windowsBuild -lt 19041) {
    Write-Host "❌ WSL2 需要 Windows 10 版本 19041 (2004) 或更高版本" -ForegroundColor Red
    Write-Host "   - 您的版本：Build $windowsBuild" -ForegroundColor Yellow
    Write-Host "   - 請先更新 Windows" -ForegroundColor Yellow
    if (-not $NonInteractive) {
        Read-Host "按 Enter 鍵結束..."
    }
    exit 1
}
Write-Host "   - Windows Build: $windowsBuild ✓" -ForegroundColor Green

# 步驟 2: 檢查 WSL 是否已安裝
Write-Host "`n2. 正在檢查 WSL 是否已安裝..." -ForegroundColor Yellow

$wslCommand = Get-Command wsl -ErrorAction SilentlyContinue
$wslInstalled = $false

if ($wslCommand) {
    try {
        $null = wsl --status 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   - WSL 已安裝" -ForegroundColor Green
            $wslInstalled = $true

            # 顯示當前版本
            $wslVersion = wsl --version 2>$null
            if ($wslVersion) {
                Write-Host "   - WSL 版本資訊：" -ForegroundColor Cyan
                $wslVersion | ForEach-Object { Write-Host "     $_" -ForegroundColor Gray }
            }
        }
    } catch {
        $wslInstalled = $false
    }
}

if (-not $wslInstalled) {
    Write-Host "   - 系統中未找到 WSL，準備開始安裝。" -ForegroundColor Gray
}

# 根據參數決定行為
if ($wslInstalled -and -not $Force -and -not $Upgrade) {
    Write-Host "   - 無需重複安裝。如需升級請使用 -Upgrade 參數。" -ForegroundColor Cyan
    if (-not $NonInteractive) {
        Read-Host "按 Enter 鍵結束..."
    }
    exit 0
}

if ($Force) {
    Write-Host "   - 使用 -Force 參數，將強制重新安裝。" -ForegroundColor Yellow
} elseif ($Upgrade) {
    Write-Host "   - 使用 -Upgrade 參數，將升級到最新版本。" -ForegroundColor Yellow
}

# 步驟 3: 執行安裝/升級
$installSuccess = $false

if ($windowsBuild -ge 19041) {
    # 方法 A: 使用 wsl --install (Windows 10 build 19041+)
    Write-Host "`n3. 正在使用 wsl --install 安裝..." -ForegroundColor Yellow

    try {
        if ($Upgrade -and $wslInstalled) {
            # 升級模式
            Write-Host "   - 正在升級 WSL..." -ForegroundColor Gray
            wsl --update 2>&1 | Out-Null

            if ($LASTEXITCODE -eq 0) {
                Write-Host "   - WSL 核心已更新！" -ForegroundColor Green
                $installSuccess = $true
            } else {
                Write-Host "⚠️  WSL 更新失敗" -ForegroundColor Yellow
                Write-Host "   - 將嘗試 fallback 方法" -ForegroundColor Yellow
                $installSuccess = $false
            }
        } else {
            # 安裝模式
            Write-Host "   - 正在安裝 WSL2 和 $Distro..." -ForegroundColor Gray
            Write-Host "   - 這可能需要幾分鐘時間，請稍候..." -ForegroundColor Gray

            if ($Force -or -not $wslInstalled) {
                wsl --install -d $Distro --no-launch 2>&1 | Out-Null

                if ($LASTEXITCODE -eq 0) {
                    Write-Host "   - WSL2 和 $Distro 安裝成功！" -ForegroundColor Green
                    $installSuccess = $true
                } else {
                    Write-Host "⚠️  wsl --install 失敗" -ForegroundColor Yellow
                    Write-Host "   - 將嘗試 fallback 方法" -ForegroundColor Yellow
                    $installSuccess = $false
                }
            }
        }
    } catch {
        Write-Host "⚠️  wsl --install 發生錯誤：$($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "   - 將嘗試 fallback 方法" -ForegroundColor Yellow
        $installSuccess = $false
    }
}

# 方法 B: Fallback - 手動啟用 Windows 功能
if (-not $installSuccess) {
    Write-Host "`n3. 正在使用手動方法安裝 WSL2..." -ForegroundColor Yellow

    try {
        # 檢查功能是否已啟用
        Write-Host "   - 正在檢查 Windows 功能..." -ForegroundColor Gray

        $vmpFeature = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -ErrorAction SilentlyContinue
        $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -ErrorAction SilentlyContinue

        $needRestart = $false

        # 啟用 Virtual Machine Platform
        if ($vmpFeature.State -ne "Enabled") {
            Write-Host "   - 正在啟用 Virtual Machine Platform..." -ForegroundColor Gray
            Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart | Out-Null
            $needRestart = $true
        } else {
            Write-Host "   - Virtual Machine Platform 已啟用" -ForegroundColor Green
        }

        # 啟用 Windows Subsystem for Linux
        if ($wslFeature.State -ne "Enabled") {
            Write-Host "   - 正在啟用 Windows Subsystem for Linux..." -ForegroundColor Gray
            Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart | Out-Null
            $needRestart = $true
        } else {
            Write-Host "   - Windows Subsystem for Linux 已啟用" -ForegroundColor Green
        }

        if ($needRestart) {
            Write-Host ""
            Write-Host "⚠️  重要：已啟用 Windows 功能，需要重新啟動電腦" -ForegroundColor Yellow
            Write-Host ""

            if (-not $NonInteractive) {
                $reboot = Read-Host "是否現在重新啟動？(Y/N)"
                if ($reboot -eq 'Y' -or $reboot -eq 'y') {
                    Write-Host "正在重新啟動..." -ForegroundColor Yellow
                    Restart-Computer -Force
                    exit 0
                } else {
                    Write-Host ""
                    Write-Host "請手動重新啟動電腦後，執行以下步驟：" -ForegroundColor Yellow
                    Write-Host "1. 下載 WSL2 核心更新：https://aka.ms/wsl2kernel" -ForegroundColor White
                    Write-Host "2. 執行：wsl --set-default-version 2" -ForegroundColor White
                    Write-Host "3. 從 Microsoft Store 安裝 $Distro" -ForegroundColor White
                    exit 0
                }
            } else {
                Write-Host "NonInteractive 模式：需要手動重啟並完成安裝" -ForegroundColor Yellow
                exit 0
            }
        }

        # 下載並安裝 WSL2 Linux 核心更新包
        Write-Host "   - 正在下載 WSL2 Linux 核心更新包..." -ForegroundColor Gray
        $kernelUrl = "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi"
        $kernelPath = "$env:TEMP\wsl_update_x64.msi"

        $ProgressPreference = 'Continue'
        try {
            Invoke-WebRequest -Uri $kernelUrl -OutFile $kernelPath -UseBasicParsing
            Write-Host "   - 下載完成！" -ForegroundColor Green
        } finally {
            $ProgressPreference = 'SilentlyContinue'
        }

        Write-Host "   - 正在安裝 WSL2 核心..." -ForegroundColor Gray
        Start-Process msiexec.exe -ArgumentList "/i", $kernelPath, "/qn", "/norestart" -Wait

        # 清理
        Remove-Item -Path $kernelPath -Force -ErrorAction SilentlyContinue

        # 設定 WSL2 為預設版本
        Write-Host "   - 正在設定 WSL2 為預設版本..." -ForegroundColor Gray
        wsl --set-default-version 2 2>&1 | Out-Null

        Write-Host "   - WSL2 核心安裝完成！" -ForegroundColor Green
        Write-Host ""
        Write-Host "請從 Microsoft Store 安裝您選擇的 Linux 發行版：" -ForegroundColor Yellow
        Write-Host "  https://aka.ms/wslstore" -ForegroundColor Cyan
        Write-Host "  推薦：$Distro" -ForegroundColor White

        $installSuccess = $true

    } catch {
        Write-Host "❌ WSL2 安裝失敗：$($_.Exception.Message)" -ForegroundColor Red
        Write-Host "   - 請參考官方文檔：https://docs.microsoft.com/windows/wsl/install" -ForegroundColor Yellow
        if (-not $NonInteractive) {
            Read-Host "按 Enter 鍵結束..."
        }
        exit 1
    }
}

# 驗證安裝成功
if (-not $installSuccess) {
    Write-Host "❌ WSL2 安裝/升級失敗" -ForegroundColor Red
    if (-not $NonInteractive) {
        Read-Host "按 Enter 鍵結束..."
    }
    exit 1
}

# --- 完成 ---
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "WSL2 安裝完成！"
Write-Host "========================================" -ForegroundColor Cyan

# 顯示已安裝的發行版
Write-Host ""
Write-Host "已安裝的 Linux 發行版：" -ForegroundColor Cyan
wsl --list --verbose 2>$null | ForEach-Object {
    if ($_ -and $_ -notmatch "^Windows") {
        Write-Host "  $_" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "後續步驟：" -ForegroundColor Yellow
Write-Host "1. 啟動 WSL：wsl" -ForegroundColor White
Write-Host "2. 設定 Linux 用戶名和密碼（首次啟動時）" -ForegroundColor White
Write-Host "3. 更新套件：sudo apt update && sudo apt upgrade" -ForegroundColor White

Write-Host ""
if (-not $NonInteractive) {
    Read-Host "按 Enter 鍵結束..."
}
exit 0
