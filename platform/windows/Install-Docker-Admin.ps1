<#
.SYNOPSIS
    Install or upgrade Docker Desktop for Windows

.DESCRIPTION
    Checks and installs Docker Desktop. Requires WSL2.
    Supports upgrade and force reinstall modes.
    Self-elevates to Administrator when needed.
    Handles running Docker Desktop instances automatically.
    Fallback to direct download if winget fails.

.PARAMETER Upgrade
    Upgrade existing installation to latest version

.PARAMETER Force
    Force reinstall even if already installed

.PARAMETER NonInteractive
    No user prompts (for automation). Automatically stops Docker Desktop if needed.

.EXAMPLE
    .\Install-Docker-Admin.ps1
    Default: Install if missing, skip if already installed

.EXAMPLE
    .\Install-Docker-Admin.ps1 -Upgrade
    Upgrade to latest version if installed, install if missing

.EXAMPLE
    .\Install-Docker-Admin.ps1 -Force
    Force reinstall Docker Desktop
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

# === Helper Functions ===
function Stop-DockerDesktop {
    Write-Host "   - 正在停止 Docker Desktop..." -ForegroundColor Gray

    try {
        # 方法 1: 使用 Docker Desktop 的 quit 命令
        $dockerDesktopPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
        if (Test-Path $dockerDesktopPath) {
            Start-Process $dockerDesktopPath -ArgumentList "-Quit" -WindowStyle Hidden -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 3
        }

        # 方法 2: 停止 Docker 服務
        $services = @("com.docker.service")
        foreach ($svc in $services) {
            $service = Get-Service $svc -ErrorAction SilentlyContinue
            if ($service -and $service.Status -eq "Running") {
                Stop-Service $svc -Force -ErrorAction SilentlyContinue
            }
        }

        # 方法 3: 終止進程（最後手段）
        Start-Sleep -Seconds 2
        $processes = @("Docker Desktop", "com.docker.backend", "com.docker.vpnkit", "com.docker.proxy")
        foreach ($procName in $processes) {
            $procs = Get-Process $procName -ErrorAction SilentlyContinue
            if ($procs) {
                $procs | Stop-Process -Force -ErrorAction SilentlyContinue
            }
        }

        # 等待進程完全停止
        Start-Sleep -Seconds 3

        Write-Host "   - Docker Desktop 已停止" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "⚠️  無法自動停止 Docker Desktop：$($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
}

# === Already have Admin, continue with actual work ===
Write-Host "--- Docker Desktop 安裝腳本 ---" -ForegroundColor Cyan

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
    Write-Host "   - Docker Desktop 需要 WSL2" -ForegroundColor Yellow
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

# 步驟 2: 檢查 winget
Write-Host "`n2. 正在檢查 Winget 套件管理器..." -ForegroundColor Yellow
$wingetExists = Get-Command winget -ErrorAction SilentlyContinue

if (-not $wingetExists) {
    Write-Host "⚠️  未找到 winget，將使用 fallback 方法" -ForegroundColor Yellow
    $useWinget = $false
} else {
    Write-Host "   - winget 檢查通過" -ForegroundColor Green
    $useWinget = $true
}

# 步驟 3: 檢查 Docker Desktop 是否已安裝
Write-Host "`n3. 正在檢查 Docker Desktop 是否已安裝..." -ForegroundColor Yellow

# 刷新環境變數
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

$dockerExists = Get-Command docker -ErrorAction SilentlyContinue
$dockerRunning = Get-Process "Docker Desktop" -ErrorAction SilentlyContinue

if ($dockerExists) {
    try {
        $dockerVersion = docker version --format '{{.Server.Version}}' 2>$null
        if ($dockerVersion) {
            Write-Host "   - 您已安裝 Docker Desktop，版本為 $dockerVersion。" -ForegroundColor Green
        } else {
            Write-Host "   - 您已安裝 Docker Desktop。" -ForegroundColor Green
        }
    } catch {
        Write-Host "   - 您已安裝 Docker Desktop。" -ForegroundColor Green
    }

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

    # 處理運行中的 Docker Desktop
    if ($dockerRunning) {
        Write-Host ""
        Write-Host "⚠️  檢測到 Docker Desktop 正在運行" -ForegroundColor Yellow

        if ($NonInteractive) {
            # 自動模式：直接停止
            $stopped = Stop-DockerDesktop
            if (-not $stopped) {
                Write-Host "❌ 無法自動停止 Docker Desktop" -ForegroundColor Red
                Write-Host "   - 請手動關閉 Docker Desktop 後重試" -ForegroundColor Yellow
                exit 1
            }
        } else {
            # 互動模式：詢問用戶
            Write-Host "升級/重新安裝 Docker Desktop 需要先停止運行的實例。" -ForegroundColor Yellow
            $response = Read-Host "是否停止 Docker Desktop 並繼續？(Y/N)"

            if ($response -ne 'Y' -and $response -ne 'y') {
                Write-Host "已取消安裝" -ForegroundColor Yellow
                exit 0
            }

            $stopped = Stop-DockerDesktop
            if (-not $stopped) {
                Write-Host ""
                Write-Host "請手動關閉 Docker Desktop，然後按 Enter 繼續..." -ForegroundColor Yellow
                Read-Host
            }
        }

        # 等待確保完全停止
        Write-Host "   - 等待 Docker Desktop 完全停止..." -ForegroundColor Gray
        Start-Sleep -Seconds 5
    }
} else {
    Write-Host "   - 系統中未找到 Docker Desktop，準備開始安裝。"
}

# 步驟 4: 執行安裝/升級
$installSuccess = $false

if ($Upgrade -and $dockerExists) {
    Write-Host "`n4. 正在升級 Docker Desktop..." -ForegroundColor Yellow
    Write-Host "   - 這可能需要幾分鐘時間，請稍候..."

    if ($useWinget) {
        # 方法 A: 使用 winget 升級
        Write-Host "   - 正在使用 winget 升級..." -ForegroundColor Gray

        try {
            $command = "winget upgrade --id Docker.DockerDesktop -e --silent --accept-package-agreements --accept-source-agreements"
            Invoke-Expression $command 2>&1 | Out-Null
            $exitCode = $LASTEXITCODE

            # Winget exit codes:
            # 0 = Success
            # -1978335189 (0x8A15002B) = No applicable update found (already latest)

            if ($exitCode -eq 0) {
                Write-Host "   - Docker Desktop 升級成功！" -ForegroundColor Green
                $installSuccess = $true
            } elseif ($exitCode -eq -1978335189) {
                Write-Host "   - Docker Desktop 已是最新版本！" -ForegroundColor Green
                $installSuccess = $true
            } else {
                Write-Host "⚠️  winget 升級失敗 (exit code: $exitCode)" -ForegroundColor Yellow
                Write-Host "⚠️  將嘗試 fallback 方法" -ForegroundColor Yellow
                $installSuccess = $false
            }
        } catch {
            Write-Host "⚠️  winget 升級發生錯誤：$($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "   - 將嘗試 fallback 方法" -ForegroundColor Yellow
            $installSuccess = $false
        }
    }
} else {
    # 安裝或強制重裝
    if ($Force) {
        Write-Host "`n4. 正在強制重新安裝 Docker Desktop..." -ForegroundColor Yellow
    } else {
        Write-Host "`n4. 正在安裝 Docker Desktop..." -ForegroundColor Yellow
    }
    Write-Host "   - 這可能需要幾分鐘時間，請稍候..."

    if ($useWinget) {
        # 方法 A: 使用 winget 安裝
        Write-Host "   - 正在使用 winget 安裝..." -ForegroundColor Gray

        try {
            $command = "winget install --id Docker.DockerDesktop -e --silent --accept-package-agreements --accept-source-agreements"
            if ($Force) {
                $command += " --force"
            }

            Invoke-Expression $command 2>&1 | Out-Null

            if ($LASTEXITCODE -eq 0) {
                Write-Host "   - Docker Desktop 安裝成功！" -ForegroundColor Green
                $installSuccess = $true
            } else {
                Write-Host "⚠️  winget 安裝失敗 (exit code: $LASTEXITCODE)" -ForegroundColor Yellow
                Write-Host "⚠️  將嘗試 fallback 方法" -ForegroundColor Yellow
                $installSuccess = $false
            }
        } catch {
            Write-Host "⚠️  winget 安裝發生錯誤：$($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "   - 將嘗試 fallback 方法" -ForegroundColor Yellow
            $installSuccess = $false
        }
    }
}

# 方法 B: Fallback - 從官網下載安裝器
if (-not $installSuccess) {
    Write-Host "`n4. 正在從官網下載 Docker Desktop 安裝器..." -ForegroundColor Yellow

    try {
        # Docker Desktop for Windows 下載連結
        $downloadUrl = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
        $installerPath = "$env:TEMP\DockerDesktopInstaller.exe"

        Write-Host "   - 正在下載 Docker Desktop..." -ForegroundColor Gray
        Write-Host "   - 這可能需要幾分鐘時間（檔案約 500MB）..." -ForegroundColor Gray

        $ProgressPreference = 'Continue'  # Show download progress
        try {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing
            Write-Host "   - 下載完成！" -ForegroundColor Green
        } finally {
            $ProgressPreference = 'SilentlyContinue'  # Restore default
        }

        Write-Host "   - 正在執行安裝..." -ForegroundColor Gray
        $installArgs = @("install", "--quiet")
        if ($Force) {
            $installArgs += "--accept-license"
        }

        $installProcess = Start-Process $installerPath -ArgumentList $installArgs -Wait -PassThru

        # 清理安裝器
        Remove-Item -Path $installerPath -Force -ErrorAction SilentlyContinue

        if ($installProcess.ExitCode -eq 0) {
            Write-Host "   - Docker Desktop 安裝成功！" -ForegroundColor Green
            $installSuccess = $true
        } else {
            throw "Docker Desktop 安裝失敗，退出碼：$($installProcess.ExitCode)"
        }

    } catch {
        Write-Host "❌ Docker Desktop 安裝失敗：$($_.Exception.Message)" -ForegroundColor Red
        Write-Host "   - 請手動從 https://www.docker.com/products/docker-desktop/ 下載安裝" -ForegroundColor Yellow
        if (-not $NonInteractive) {
            Read-Host "按 Enter 鍵結束..."
        }
        exit 1
    }
}

# 驗證安裝成功
if (-not $installSuccess) {
    Write-Host "❌ Docker Desktop 安裝/升級失敗" -ForegroundColor Red
    if (-not $NonInteractive) {
        Read-Host "按 Enter 鍵結束..."
    }
    exit 1
}

# --- 完成 ---
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Docker Desktop 安裝完成！"
Write-Host "========================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "後續步驟：" -ForegroundColor Yellow
Write-Host "1. 啟動 Docker Desktop（首次啟動需要幾分鐘）" -ForegroundColor White
Write-Host "2. 等待 Docker Engine 完全啟動" -ForegroundColor White
Write-Host "3. 測試安裝：docker run hello-world" -ForegroundColor White

Write-Host ""
Write-Host "提示：" -ForegroundColor Cyan
Write-Host "- Docker Desktop 已配置為使用 WSL2 後端" -ForegroundColor Gray
Write-Host "- 第一次啟動可能需要下載 Docker images" -ForegroundColor Gray
Write-Host "- 可在系統托盤找到 Docker Desktop 圖示" -ForegroundColor Gray

Write-Host ""
if (-not $NonInteractive) {
    Read-Host "按 Enter 鍵結束..."
}
exit 0
