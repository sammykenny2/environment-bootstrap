<#
.SYNOPSIS
    Install or upgrade Node.js LTS using Windows Package Manager (winget)

.DESCRIPTION
    Checks and installs Node.js LTS. Includes npm automatically.
    Supports upgrade and force reinstall modes.
    Self-elevates to Administrator when needed.
    Fallback to direct download from nodejs.org if winget fails.

.PARAMETER Version
    Version to install. Options: LTS (default), Latest, or specific version (e.g., "20.10.0")

.PARAMETER Upgrade
    Upgrade existing installation to latest version

.PARAMETER Force
    Force reinstall even if already installed

.EXAMPLE
    .\Install-NodeJS.ps1
    Default: Install if missing, skip if already installed

.EXAMPLE
    .\Install-NodeJS.ps1 -Upgrade
    Upgrade to latest LTS if installed, install if missing

.EXAMPLE
    .\Install-NodeJS.ps1 -Force
    Force reinstall Node.js LTS

.EXAMPLE
    .\Install-NodeJS.ps1 -Version "18.19.0"
    Install specific version
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$Version = "LTS",

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
    if ($Version -ne "LTS") { $arguments += " -Version `"$Version`"" }
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
Write-Host "--- Node.js LTS 環境安裝腳本 ---" -ForegroundColor Cyan

# 處理互斥參數
if ($Force -and $Upgrade) {
    Write-Host "⚠️  警告：不能同時使用 -Force 和 -Upgrade，將使用 -Force" -ForegroundColor Yellow
    $Upgrade = $false
}

# 步驟 2: 檢查 Node.js 是否已安裝
Write-Host "`n2. 正在檢查 Node.js 是否已安裝..." -ForegroundColor Yellow
$nodeExists = Get-Command node -ErrorAction SilentlyContinue
if ($nodeExists) {
    $nodeVersion = (node -v).Trim()
    Write-Host "   - 您已安裝 Node.js，版本為 $nodeVersion。" -ForegroundColor Green

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
    Write-Host "   - 系統中未找到 Node.js，準備開始安裝。"
}

# 步驟 3: 檢查 Winget 工具是否存在
Write-Host "`n3. 正在檢查 Winget 套件管理器..." -ForegroundColor Yellow
$wingetExists = Get-Command winget -ErrorAction SilentlyContinue

if (-not $wingetExists) {
    Write-Host "⚠️  未找到 winget，將使用 fallback 方法" -ForegroundColor Yellow
    $useWinget = $false
} else {
    Write-Host "   - winget 檢查通過" -ForegroundColor Green
    $useWinget = $true
}

# 步驟 4: 準備安裝參數
Write-Host "`n4. 準備安裝參數..." -ForegroundColor Yellow

# 根據 Version 參數決定 package ID
switch ($Version) {
    "LTS" {
        $packageId = "OpenJS.NodeJS.LTS"
        $versionArg = ""
        Write-Host "   - 目標版本：最新 LTS 版本" -ForegroundColor Cyan
    }
    "Latest" {
        $packageId = "OpenJS.NodeJS"
        $versionArg = ""
        Write-Host "   - 目標版本：最新穩定版本（非 LTS）" -ForegroundColor Cyan
    }
    default {
        $packageId = "OpenJS.NodeJS"
        $versionArg = "--version $Version"
        Write-Host "   - 目標版本：$Version" -ForegroundColor Cyan
    }
}

# 步驟 5: 執行安裝/升級
$installSuccess = $false

if ($Upgrade -and $nodeExists) {
    Write-Host "`n5. 正在升級 Node.js..." -ForegroundColor Yellow
    Write-Host "   - 這可能需要幾分鐘時間，請稍候..."

    if ($useWinget) {
        # 方法 A: 使用 winget 升級
        Write-Host "   - 正在使用 winget 升級..." -ForegroundColor Gray

        try {
            $command = "winget upgrade --id $packageId -e --silent --accept-package-agreements --accept-source-agreements"
            if ($versionArg) {
                $command += " $versionArg"
            }

            Invoke-Expression $command 2>&1 | Out-Null
            $exitCode = $LASTEXITCODE

            # Winget exit codes:
            # 0 = Success
            # -1978335189 (0x8A15002B) = No applicable update found (already latest)

            if ($exitCode -eq 0) {
                Write-Host "   - Node.js 升級成功！" -ForegroundColor Green
                $installSuccess = $true
            } elseif ($exitCode -eq -1978335189) {
                Write-Host "   - Node.js 已是最新版本！" -ForegroundColor Green
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
        Write-Host "`n5. 正在強制重新安裝 Node.js..." -ForegroundColor Yellow
    } else {
        Write-Host "`n5. 正在安裝 Node.js..." -ForegroundColor Yellow
    }
    Write-Host "   - 這可能需要幾分鐘時間，請稍候..."

    if ($useWinget) {
        # 方法 A: 使用 winget 安裝
        Write-Host "   - 正在使用 winget 安裝..." -ForegroundColor Gray

        try {
            $command = "winget install --id $packageId -e --silent --accept-package-agreements --accept-source-agreements"
            if ($versionArg) {
                $command += " $versionArg"
            }
            if ($Force) {
                $command += " --force"
            }

            Invoke-Expression $command 2>&1 | Out-Null

            if ($LASTEXITCODE -eq 0) {
                Write-Host "   - Node.js 安裝成功！" -ForegroundColor Green
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

# 方法 B: Fallback - 從 nodejs.org 下載 MSI
if (-not $installSuccess) {
    Write-Host "`n5. 正在從 nodejs.org 下載 Node.js 安裝器..." -ForegroundColor Yellow

    try {
        # 取得最新版本資訊
        Write-Host "   - 正在查詢最新版本..." -ForegroundColor Gray
        $apiUrl = "https://nodejs.org/dist/index.json"
        $releases = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing

        # 根據 Version 參數決定要下載的版本
        $targetRelease = $null
        if ($Version -eq "LTS") {
            # 找最新的 LTS 版本
            $targetRelease = $releases | Where-Object { $_.lts -ne $false } | Select-Object -First 1
            $targetVersion = $targetRelease.version -replace '^v', ''
            Write-Host "   - 最新 LTS 版本：$targetVersion" -ForegroundColor Cyan
        } elseif ($Version -eq "Latest") {
            # 找最新版本
            $targetRelease = $releases | Select-Object -First 1
            $targetVersion = $targetRelease.version -replace '^v', ''
            Write-Host "   - 最新版本：$targetVersion" -ForegroundColor Cyan
        } else {
            # 特定版本
            $targetVersion = $Version
            $targetRelease = $releases | Where-Object { $_.version -eq "v$Version" } | Select-Object -First 1
            if (-not $targetRelease) {
                throw "找不到指定版本 $Version"
            }
            Write-Host "   - 目標版本：$targetVersion" -ForegroundColor Cyan
        }

        # 如果正在升級且已安裝 Node.js，檢查版本是否一致
        if ($Upgrade -and $nodeExists -and $targetVersion) {
            # 提取當前版本號 (v20.10.0 -> 20.10.0)
            $currentVersionRaw = node -v 2>$null
            if ($currentVersionRaw -match 'v?(.+)$') {
                $currentVersion = $matches[1].Trim()

                # 比較版本號
                if ($currentVersion -eq $targetVersion) {
                    Write-Host "   - Node.js 已是最新版本 ($currentVersion)，跳過安裝" -ForegroundColor Green
                    $installSuccess = $true
                } else {
                    Write-Host "   - 當前版本 $currentVersion 將升級到 $targetVersion" -ForegroundColor Yellow
                }
            }
        }

        # 如果已經確認版本一致，跳過下載和安裝
        if ($installSuccess) {
            # 版本檢查通過，無需下載
        } else {
            # 構建下載 URL
            $downloadUrl = "https://nodejs.org/dist/v$targetVersion/node-v$targetVersion-x64.msi"
            $msiPath = "$env:TEMP\node-v$targetVersion-x64.msi"

            # 下載 MSI (with progress)
            Write-Host "   - 正在下載 Node.js 安裝器..." -ForegroundColor Gray
            $ProgressPreference = 'Continue'  # Show download progress
            try {
                Invoke-WebRequest -Uri $downloadUrl -OutFile $msiPath -UseBasicParsing
                Write-Host "   - 下載完成！" -ForegroundColor Green
            } finally {
                $ProgressPreference = 'SilentlyContinue'  # Restore default
            }

            # 安裝 MSI
            Write-Host "   - 正在執行安裝..." -ForegroundColor Gray
            $msiArgs = @(
                "/i", $msiPath,
                "/qn",  # Quiet mode, no user interaction
                "/norestart"
            )

            if ($Force) {
                $msiArgs += "REINSTALLMODE=vamus"
                $msiArgs += "REINSTALL=ALL"
            }

            $installProcess = Start-Process msiexec.exe -ArgumentList $msiArgs -Wait -PassThru

            # 清理下載檔案
            Remove-Item -Path $msiPath -Force -ErrorAction SilentlyContinue

            if ($installProcess.ExitCode -eq 0) {
                Write-Host "   - Node.js 安裝成功！" -ForegroundColor Green
                $installSuccess = $true
            } else {
                throw "MSI 安裝失敗，退出碼：$($installProcess.ExitCode)"
            }
        }

    } catch {
        Write-Host "❌ Node.js 安裝失敗：$($_.Exception.Message)" -ForegroundColor Red
        Write-Host "   - 請手動從 https://nodejs.org/ 下載安裝" -ForegroundColor Yellow
        if (-not $NonInteractive) {
        Read-Host "按 Enter 鍵結束..."
        }
        exit 1
    }
}

# 驗證安裝成功
if (-not $installSuccess) {
    Write-Host "❌ Node.js 安裝/升級失敗" -ForegroundColor Red
    if (-not $NonInteractive) {
    Read-Host "按 Enter 鍵結束..."
    }
    exit 1
}

# --- 完成 ---
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Node.js 操作完成！"
Write-Host "請關閉此視窗，並「重新開啟一個新的 PowerShell 視窗」再繼續後續操作。"
Write-Host "========================================" -ForegroundColor Cyan

# 顯示版本資訊（刷新 PATH 後驗證）
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
$nodeCheck = Get-Command node -ErrorAction SilentlyContinue
if ($nodeCheck) {
    $nodeVersion = (node -v).Trim()
    $npmVersion = (npm -v).Trim()
    Write-Host "`n已安裝版本：" -ForegroundColor Green
    Write-Host "  - Node.js: $nodeVersion" -ForegroundColor Green
    Write-Host "  - npm: $npmVersion" -ForegroundColor Green
}

Write-Host ""
if (-not $NonInteractive) {
Read-Host "按 Enter 鍵結束..."
}
exit 0
