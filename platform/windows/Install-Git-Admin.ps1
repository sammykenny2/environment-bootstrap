<#
.SYNOPSIS
    Install or upgrade Git for Windows using Windows Package Manager (winget)

.DESCRIPTION
    Checks and installs Git for Windows. Supports upgrade and force reinstall modes.
    Self-elevates to Administrator when needed.
    Fallback to direct download if winget fails.

.PARAMETER Upgrade
    Upgrade existing installation to latest version

.PARAMETER Force
    Force reinstall even if already installed

.EXAMPLE
    .\Install-Git.ps1
    Default: Install if missing, skip if already installed

.EXAMPLE
    .\Install-Git.ps1 -Upgrade
    Upgrade to latest version if installed, install if missing

.EXAMPLE
    .\Install-Git.ps1 -Force
    Force reinstall Git
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
Write-Host "--- Git for Windows 安裝腳本 ---" -ForegroundColor Cyan

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

# 步驟 2: 檢查 Git 是否已安裝
Write-Host "`n2. 正在檢查 Git 是否已安裝..." -ForegroundColor Yellow

# 刷新環境變數
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

$gitExists = Get-Command git -ErrorAction SilentlyContinue
if ($gitExists) {
    $gitVersion = (git --version).Trim()
    Write-Host "   - 您已安裝 Git，版本為 $gitVersion。" -ForegroundColor Green

    # 根據參數決定行為
    if ($Force) {
        Write-Host "   - 使用 -Force 參數，將強制重新安裝。" -ForegroundColor Yellow
    } elseif ($Upgrade) {
        Write-Host "   - 使用 -Upgrade 參數，將升級到最新版本。" -ForegroundColor Yellow
    } else {
        Write-Host "   - 無需重複安裝。如需升級請使用 -Upgrade 參數。" -ForegroundColor Cyan
        if (-not $NonInteractive) {
        Read-Host "按 Enter 鍵結束..."
        }
        exit 0
    }
} else {
    Write-Host "   - 系統中未找到 Git，準備開始安裝。"
}

# 步驟 3: 安裝/升級 Git
$installSuccess = $false

if ($useWinget) {
    # 方法 A: 使用 winget 安裝
    Write-Host "`n3. 正在使用 winget 安裝 Git..." -ForegroundColor Yellow
    Write-Host "   - 這可能需要幾分鐘時間，請稍候..."

    try {
        if ($Upgrade -and $gitExists) {
            $command = "winget upgrade --id Git.Git -e --silent --accept-package-agreements --accept-source-agreements"
            Write-Host "   - 正在升級 Git..." -ForegroundColor Gray
        } else {
            $command = "winget install --id Git.Git -e --silent --accept-package-agreements --accept-source-agreements"
            if ($Force) {
                $command += " --force"
            }
            Write-Host "   - 正在安裝 Git..." -ForegroundColor Gray
        }

        Invoke-Expression $command

        if ($LASTEXITCODE -eq 0) {
            Write-Host "   - Git 安裝成功！" -ForegroundColor Green
            $installSuccess = $true
        } else {
            Write-Host "⚠️  winget 安裝失敗，將嘗試 fallback 方法" -ForegroundColor Yellow
            $installSuccess = $false
        }
    } catch {
        Write-Host "⚠️  winget 安裝發生錯誤：$($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "   - 將嘗試 fallback 方法" -ForegroundColor Yellow
        $installSuccess = $false
    }
}

# 方法 B: Fallback - 從官網下載安裝器
if (-not $installSuccess) {
    Write-Host "`n3. 正在從官網下載 Git 安裝器..." -ForegroundColor Yellow

    try {
        # 抓取最新版本的下載連結
        Write-Host "   - 正在檢測最新版本..." -ForegroundColor Gray

        # Git for Windows 官方下載頁面
        $downloadUrl = "https://github.com/git-for-windows/git/releases/latest/download/Git-2.43.0-64-bit.exe"

        # 嘗試從 GitHub API 取得最新版本
        try {
            $apiUrl = "https://api.github.com/repos/git-for-windows/git/releases/latest"
            $release = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing -Headers @{"User-Agent"="PowerShell"}

            # 尋找 64-bit 安裝器
            $asset = $release.assets | Where-Object { $_.name -like "*64-bit.exe" -and $_.name -notlike "*rc*" } | Select-Object -First 1
            if ($asset) {
                $downloadUrl = $asset.browser_download_url
                Write-Host "   - 檢測到最新版本：$($release.tag_name)" -ForegroundColor Cyan
            }
        } catch {
            Write-Host "   - 無法自動檢測版本，使用預設連結" -ForegroundColor Yellow
        }

        $installerPath = "$env:TEMP\GitInstaller.exe"

        Write-Host "   - 正在下載 Git 安裝器..." -ForegroundColor Gray
        Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing

        Write-Host "   - 正在執行安裝..." -ForegroundColor Gray
        Start-Process -FilePath $installerPath -ArgumentList "/VERYSILENT /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS" -Wait

        # 清理安裝器
        Remove-Item -Path $installerPath -Force -ErrorAction SilentlyContinue

        # 刷新環境變數並檢查
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        $gitExists = Get-Command git -ErrorAction SilentlyContinue

        if ($gitExists) {
            Write-Host "   - Git 安裝成功！" -ForegroundColor Green
            $installSuccess = $true
        } else {
            throw "Git 安裝後未找到 git 命令"
        }
    } catch {
        Write-Host "❌ Git 安裝失敗：$($_.Exception.Message)" -ForegroundColor Red
        Write-Host "   - 請手動從 https://git-scm.com/download/win 下載安裝" -ForegroundColor Yellow
        if (-not $NonInteractive) {
        Read-Host "按 Enter 鍵結束..."
        }
        exit 1
    }
}

# --- 完成 ---
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Git 安裝完成！"
Write-Host "請關閉此視窗，並「重新開啟一個新的 PowerShell 視窗」再繼續後續操作。"
Write-Host "========================================" -ForegroundColor Cyan

# 顯示版本資訊
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
$gitCheck = Get-Command git -ErrorAction SilentlyContinue
if ($gitCheck) {
    $gitVersion = git --version
    Write-Host "`n已安裝版本：$gitVersion" -ForegroundColor Green
}

Write-Host ""
if (-not $NonInteractive) {
Read-Host "按 Enter 鍵結束..."
}
exit 0
