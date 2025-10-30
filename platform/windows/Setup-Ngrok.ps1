<#
.SYNOPSIS
    Setup Ngrok authentication token

.DESCRIPTION
    Configures Ngrok authtoken from .env file or command-line parameters.
    Supports three modes: install (skip if exists), upgrade (update if different), and force (always overwrite).
    Runs with normal user permissions (no admin required).

.PARAMETER AuthToken
    Ngrok authentication token to set (overrides .env value)

.PARAMETER Upgrade
    Update configuration if different from .env value

.PARAMETER Force
    Force overwrite existing configuration

.PARAMETER NonInteractive
    No user prompts (for automation)

.EXAMPLE
    .\Setup-Ngrok.ps1
    Default: Set authtoken if not already configured

.EXAMPLE
    .\Setup-Ngrok.ps1 -Upgrade
    Update authtoken if .env value differs from current setting

.EXAMPLE
    .\Setup-Ngrok.ps1 -Force
    Force overwrite authtoken with .env value

.EXAMPLE
    .\Setup-Ngrok.ps1 -AuthToken "your_token_here"
    Set authtoken using command-line parameter

.NOTES
    - No admin privileges required
    - Reads NGROK_AUTHTOKEN from .env file
    - Get your authtoken from: https://dashboard.ngrok.com/get-started/your-authtoken
    - Ngrok must be installed before running this script
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$AuthToken,

    [Parameter(Mandatory=$false)]
    [switch]$Upgrade,

    [Parameter(Mandatory=$false)]
    [switch]$Force,

    [Parameter(Mandatory=$false)]
    [switch]$NonInteractive
)

Write-Host "--- Ngrok 配置設定腳本 ---" -ForegroundColor Cyan

# 處理互斥參數
if ($Force -and $Upgrade) {
    Write-Host "⚠️  警告：不能同時使用 -Force 和 -Upgrade，將使用 -Force" -ForegroundColor Yellow
    $Upgrade = $false
}

# 步驟 1: 檢查 Ngrok 是否已安裝
Write-Host "`n1. 正在檢查 Ngrok 是否已安裝..." -ForegroundColor Yellow

# 刷新環境變數
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

$ngrokCommand = Get-Command ngrok -ErrorAction SilentlyContinue
if (-not $ngrokCommand) {
    Write-Host "❌ 未找到 Ngrok" -ForegroundColor Red
    Write-Host "   - 請先執行：.\Install-Ngrok-Admin.ps1" -ForegroundColor Yellow
    if (-not $NonInteractive) {
        Read-Host "按 Enter 鍵結束..."
    }
    exit 1
}

$ngrokVersionOutput = ngrok version 2>$null
if ($ngrokVersionOutput) {
    Write-Host "   - Ngrok 檢查通過：$ngrokVersionOutput" -ForegroundColor Green
} else {
    Write-Host "❌ Ngrok 命令無法執行" -ForegroundColor Red
    exit 1
}

# 步驟 2: 讀取 .env 文件
Write-Host "`n2. 正在讀取配置..." -ForegroundColor Yellow

$ScriptRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$envPath = Join-Path $ScriptRoot ".env"
$envExamplePath = Join-Path $ScriptRoot ".env.example"

$envNgrokAuthToken = ""

# 函數：從 .env 文件讀取變量
function Read-EnvFile {
    param([string]$FilePath)

    if (-not (Test-Path $FilePath)) {
        return $null
    }

    $envVars = @{}
    Get-Content $FilePath | ForEach-Object {
        $line = $_.Trim()
        # 跳過空行和註釋
        if ($line -and -not $line.StartsWith('#')) {
            if ($line -match '^([^=]+)=(.*)$') {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()
                $envVars[$key] = $value
            }
        }
    }
    return $envVars
}

# 優先讀取 .env，如果不存在則讀取 .env.example
if (Test-Path $envPath) {
    Write-Host "   - 讀取 .env 文件..." -ForegroundColor Gray
    $envVars = Read-EnvFile -FilePath $envPath
    if ($envVars) {
        $envNgrokAuthToken = $envVars['NGROK_AUTHTOKEN']
    }
} elseif (Test-Path $envExamplePath) {
    Write-Host "   - .env 不存在，讀取 .env.example..." -ForegroundColor Yellow
    $envVars = Read-EnvFile -FilePath $envExamplePath
    if ($envVars) {
        $envNgrokAuthToken = $envVars['NGROK_AUTHTOKEN']
    }
    Write-Host "   - 建議：複製 .env.example 為 .env 並自定義配置" -ForegroundColor Cyan
}

# 參數優先於 .env 文件
if ($AuthToken) {
    $envNgrokAuthToken = $AuthToken
    Write-Host "   - 使用命令行參數：AuthToken = ********" -ForegroundColor Gray
}

# 驗證是否有配置值可用（空值視為未設置）
if (-not $envNgrokAuthToken -or $envNgrokAuthToken.Trim() -eq "") {
    Write-Host "❌ 未找到 Ngrok authtoken 或值為空" -ForegroundColor Red
    Write-Host ""
    Write-Host "請執行以下操作之一：" -ForegroundColor Yellow
    Write-Host "   1. 編輯 .env 文件並設置 NGROK_AUTHTOKEN" -ForegroundColor White
    Write-Host "      獲取 authtoken：https://dashboard.ngrok.com/get-started/your-authtoken" -ForegroundColor Gray
    Write-Host "      在 .env 中取消註釋並填入：NGROK_AUTHTOKEN=your_token_here" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   2. 使用命令行參數：" -ForegroundColor White
    Write-Host "      .\Setup-Ngrok.ps1 -AuthToken `"your_token_here`"" -ForegroundColor Gray
    Write-Host ""
    if (-not $NonInteractive) {
        Read-Host "按 Enter 鍵結束..."
    }
    exit 1
}

Write-Host "   - 配置讀取成功 ✓" -ForegroundColor Green

# 步驟 3: 檢查現有 Ngrok 配置
Write-Host "`n3. 正在檢查現有 Ngrok 配置..." -ForegroundColor Yellow

# Ngrok 配置文件位置（新版本和舊版本）
$ngrokConfigPaths = @(
    "$env:USERPROFILE\AppData\Local\ngrok\ngrok.yml",
    "$env:USERPROFILE\.ngrok2\ngrok.yml"
)

$currentAuthToken = $null
$configPath = $null

foreach ($path in $ngrokConfigPaths) {
    if (Test-Path $path) {
        $configPath = $path
        Write-Host "   - 找到配置文件：$path" -ForegroundColor Gray

        # 讀取配置文件查找 authtoken
        $configContent = Get-Content $path -Raw
        if ($configContent -match 'authtoken:\s*(.+)') {
            $currentAuthToken = $matches[1].Trim()
            Write-Host "   - 當前 authtoken: ********" -ForegroundColor Gray
            break
        }
    }
}

if (-not $configPath) {
    Write-Host "   - 當前 authtoken: (未配置)" -ForegroundColor Gray
}

# 步驟 4: 根據參數決定行為
$needsUpdate = $false

if ($Force) {
    Write-Host "`n4. 使用 -Force 參數，將強制覆蓋配置..." -ForegroundColor Yellow
    $needsUpdate = $true
} elseif ($Upgrade) {
    Write-Host "`n4. 使用 -Upgrade 參數，檢查是否需要更新..." -ForegroundColor Yellow

    if ($currentAuthToken -eq $envNgrokAuthToken) {
        Write-Host "   - Ngrok authtoken 已是最新，無需更新" -ForegroundColor Green
        Write-Host "   - authtoken: ******** ✓" -ForegroundColor Gray
        if (-not $NonInteractive) {
            Read-Host "按 Enter 鍵結束..."
        }
        exit 0
    } else {
        Write-Host "   - 檢測到 authtoken 差異，將進行更新" -ForegroundColor Yellow
        $needsUpdate = $true
    }
} else {
    # 默認模式（Install）
    Write-Host "`n4. 檢查是否需要配置..." -ForegroundColor Yellow

    if ($currentAuthToken) {
        Write-Host "   - Ngrok authtoken 已存在，跳過設置" -ForegroundColor Green
        Write-Host "   - authtoken: ******** ✓" -ForegroundColor Gray
        Write-Host ""
        Write-Host "如需更新配置：" -ForegroundColor Cyan
        Write-Host "   - 升級模式：.\Setup-Ngrok.ps1 -Upgrade" -ForegroundColor White
        Write-Host "   - 強制覆蓋：.\Setup-Ngrok.ps1 -Force" -ForegroundColor White
        if (-not $NonInteractive) {
            Read-Host "按 Enter 鍵結束..."
        }
        exit 0
    } else {
        Write-Host "   - Ngrok authtoken 未設置，將進行配置" -ForegroundColor Yellow
        $needsUpdate = $true
    }
}

# 步驟 5: 設置 Ngrok authtoken
if ($needsUpdate) {
    Write-Host "`n5. 正在設置 Ngrok authtoken..." -ForegroundColor Yellow

    try {
        # 執行 ngrok authtoken 命令
        $output = ngrok authtoken $envNgrokAuthToken 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host "   - ✓ authtoken 設置成功" -ForegroundColor Green

            Write-Host ""
            Write-Host "✅ Ngrok authtoken 配置成功！" -ForegroundColor Green

            # 顯示配置文件位置
            Write-Host ""
            Write-Host "配置信息：" -ForegroundColor Cyan

            # 查找配置文件
            $finalConfigPath = $null
            foreach ($path in $ngrokConfigPaths) {
                if (Test-Path $path) {
                    $finalConfigPath = $path
                    break
                }
            }

            if ($finalConfigPath) {
                Write-Host "   配置文件: $finalConfigPath" -ForegroundColor White
            }

            Write-Host ""
            Write-Host "後續步驟：" -ForegroundColor Cyan
            Write-Host "   1. 測試連接：ngrok http 80" -ForegroundColor White
            Write-Host "   2. 或使用其他協議：ngrok tcp 22" -ForegroundColor White
            Write-Host "   3. 查看更多選項：ngrok --help" -ForegroundColor White
            Write-Host ""
            Write-Host "Web 界面：http://localhost:4040 (ngrok 運行時可用)" -ForegroundColor Gray

            if (-not $NonInteractive) {
                Read-Host "按 Enter 鍵結束..."
            }
            exit 0
        } else {
            throw "ngrok authtoken 命令失敗，退出碼：$LASTEXITCODE"
        }

    } catch {
        Write-Host ""
        Write-Host "❌ Ngrok authtoken 配置失敗：$($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        Write-Host "手動設置方法：" -ForegroundColor Yellow
        Write-Host "   ngrok authtoken your_token_here" -ForegroundColor White
        Write-Host ""
        Write-Host "獲取 authtoken：" -ForegroundColor Cyan
        Write-Host "   https://dashboard.ngrok.com/get-started/your-authtoken" -ForegroundColor White

        if (-not $NonInteractive) {
            Read-Host "按 Enter 鍵結束..."
        }
        exit 1
    }
}
