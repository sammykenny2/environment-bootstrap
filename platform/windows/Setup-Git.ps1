<#
.SYNOPSIS
    Setup Git global configuration (user.name and user.email)

.DESCRIPTION
    Configures Git global user settings from .env file or command-line parameters.
    Supports three modes: install (skip if exists), upgrade (update if different), and force (always overwrite).
    Runs with normal user permissions (no admin required).

.PARAMETER UserName
    Git user name to set (overrides .env value)

.PARAMETER UserEmail
    Git user email to set (overrides .env value)

.PARAMETER Upgrade
    Update configuration if different from .env values

.PARAMETER Force
    Force overwrite existing configuration

.PARAMETER NonInteractive
    No user prompts (for automation)

.EXAMPLE
    .\Setup-Git.ps1
    Default: Set configuration if not already configured

.EXAMPLE
    .\Setup-Git.ps1 -Upgrade
    Update configuration if .env values differ from current settings

.EXAMPLE
    .\Setup-Git.ps1 -Force
    Force overwrite configuration with .env values

.EXAMPLE
    .\Setup-Git.ps1 -UserName "John Doe" -UserEmail "john@example.com"
    Set configuration using command-line parameters

.NOTES
    - No admin privileges required
    - Reads GIT_USER_NAME and GIT_USER_EMAIL from .env file
    - Falls back to .env.example if .env not found
    - Uses git config --global for user-level configuration
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$UserName,

    [Parameter(Mandatory=$false)]
    [string]$UserEmail,

    [Parameter(Mandatory=$false)]
    [switch]$Upgrade,

    [Parameter(Mandatory=$false)]
    [switch]$Force,

    [Parameter(Mandatory=$false)]
    [switch]$NonInteractive
)

Write-Host "--- Git 配置設定腳本 ---" -ForegroundColor Cyan

# 處理互斥參數
if ($Force -and $Upgrade) {
    Write-Host "⚠️  警告：不能同時使用 -Force 和 -Upgrade，將使用 -Force" -ForegroundColor Yellow
    $Upgrade = $false
}

# 步驟 1: 檢查 Git 是否已安裝
Write-Host "`n1. 正在檢查 Git 是否已安裝..." -ForegroundColor Yellow

$gitCommand = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitCommand) {
    Write-Host "❌ 未找到 Git" -ForegroundColor Red
    Write-Host "   - 請先執行：.\Install-Git-Admin.ps1" -ForegroundColor Yellow
    if (-not $NonInteractive) {
        Read-Host "按 Enter 鍵結束..."
    }
    exit 1
}

$gitVersion = (git --version 2>$null)
if ($gitVersion) {
    Write-Host "   - Git 檢查通過：$gitVersion" -ForegroundColor Green
} else {
    Write-Host "❌ Git 命令無法執行" -ForegroundColor Red
    exit 1
}

# 步驟 2: 讀取 .env 文件
Write-Host "`n2. 正在讀取配置..." -ForegroundColor Yellow

# Setup-Git.ps1 位於 platform\windows\，需要往上兩層到 repository root
$ScriptRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$envPath = Join-Path $ScriptRoot ".env"
$envExamplePath = Join-Path $ScriptRoot ".env.example"

$envGitUserName = ""
$envGitUserEmail = ""

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
        $envGitUserName = $envVars['GIT_USER_NAME']
        $envGitUserEmail = $envVars['GIT_USER_EMAIL']
    }
} elseif (Test-Path $envExamplePath) {
    Write-Host "   - .env 不存在，讀取 .env.example..." -ForegroundColor Yellow
    $envVars = Read-EnvFile -FilePath $envExamplePath
    if ($envVars) {
        $envGitUserName = $envVars['GIT_USER_NAME']
        $envGitUserEmail = $envVars['GIT_USER_EMAIL']
    }
    Write-Host "   - 建議：複製 .env.example 為 .env 並自定義配置" -ForegroundColor Cyan
}

# 參數優先於 .env 文件
if ($UserName) {
    $envGitUserName = $UserName
    Write-Host "   - 使用命令行參數：UserName = $UserName" -ForegroundColor Gray
}

if ($UserEmail) {
    $envGitUserEmail = $UserEmail
    Write-Host "   - 使用命令行參數：UserEmail = $UserEmail" -ForegroundColor Gray
}

# 驗證是否有配置值可用（空值視為未設置）
if (-not $envGitUserName -or -not $envGitUserEmail -or `
    $envGitUserName.Trim() -eq "" -or $envGitUserEmail.Trim() -eq "") {
    Write-Host "❌ 未找到 Git 配置值或值為空" -ForegroundColor Red
    Write-Host ""
    Write-Host "請執行以下操作之一：" -ForegroundColor Yellow
    Write-Host "   1. 編輯 .env 文件並設置 GIT_USER_NAME 和 GIT_USER_EMAIL" -ForegroundColor White
    Write-Host "      cp .env.example .env  # 如果 .env 不存在" -ForegroundColor Gray
    Write-Host "      然後編輯 .env 填入您的信息" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   2. 使用命令行參數：" -ForegroundColor White
    Write-Host "      .\Setup-Git.ps1 -UserName `"Your Name`" -UserEmail `"your@email.com`"" -ForegroundColor Gray
    Write-Host ""
    if (-not $NonInteractive) {
        Read-Host "按 Enter 鍵結束..."
    }
    exit 1
}

Write-Host "   - 配置讀取成功 ✓" -ForegroundColor Green

# 步驟 3: 檢查現有 Git 配置
Write-Host "`n3. 正在檢查現有 Git 配置..." -ForegroundColor Yellow

$currentUserName = git config --global user.name 2>$null
$currentUserEmail = git config --global user.email 2>$null

if ($currentUserName) {
    Write-Host "   - 當前 user.name: $currentUserName" -ForegroundColor Gray
} else {
    Write-Host "   - 當前 user.name: (未設置)" -ForegroundColor Gray
}

if ($currentUserEmail) {
    Write-Host "   - 當前 user.email: $currentUserEmail" -ForegroundColor Gray
} else {
    Write-Host "   - 當前 user.email: (未設置)" -ForegroundColor Gray
}

# 步驟 4: 根據參數決定行為
$needsUpdate = $false

if ($Force) {
    Write-Host "`n4. 使用 -Force 參數，將強制覆蓋配置..." -ForegroundColor Yellow
    $needsUpdate = $true
} elseif ($Upgrade) {
    Write-Host "`n4. 使用 -Upgrade 參數，檢查是否需要更新..." -ForegroundColor Yellow

    if ($currentUserName -eq $envGitUserName -and $currentUserEmail -eq $envGitUserEmail) {
        Write-Host "   - Git 配置已是最新，無需更新" -ForegroundColor Green
        Write-Host "   - user.name: $currentUserName ✓" -ForegroundColor Gray
        Write-Host "   - user.email: $currentUserEmail ✓" -ForegroundColor Gray
        if (-not $NonInteractive) {
            Read-Host "按 Enter 鍵結束..."
        }
        exit 0
    } else {
        Write-Host "   - 檢測到配置差異，將進行更新" -ForegroundColor Yellow
        if ($currentUserName -ne $envGitUserName) {
            Write-Host "     user.name: `"$currentUserName`" → `"$envGitUserName`"" -ForegroundColor Cyan
        }
        if ($currentUserEmail -ne $envGitUserEmail) {
            Write-Host "     user.email: `"$currentUserEmail`" → `"$envGitUserEmail`"" -ForegroundColor Cyan
        }
        $needsUpdate = $true
    }
} else {
    # 默認模式（Install）
    Write-Host "`n4. 檢查是否需要配置..." -ForegroundColor Yellow

    if ($currentUserName -and $currentUserEmail) {
        Write-Host "   - Git 配置已存在，跳過設置" -ForegroundColor Green
        Write-Host "   - user.name: $currentUserName ✓" -ForegroundColor Gray
        Write-Host "   - user.email: $currentUserEmail ✓" -ForegroundColor Gray
        Write-Host ""
        Write-Host "如需更新配置：" -ForegroundColor Cyan
        Write-Host "   - 升級模式：.\Setup-Git.ps1 -Upgrade" -ForegroundColor White
        Write-Host "   - 強制覆蓋：.\Setup-Git.ps1 -Force" -ForegroundColor White
        if (-not $NonInteractive) {
            Read-Host "按 Enter 鍵結束..."
        }
        exit 0
    } else {
        Write-Host "   - Git 配置未完整設置，將進行配置" -ForegroundColor Yellow
        $needsUpdate = $true
    }
}

# 步驟 5: 設置 Git 配置
if ($needsUpdate) {
    Write-Host "`n5. 正在設置 Git 配置..." -ForegroundColor Yellow

    try {
        # 設置 user.name
        git config --global user.name "$envGitUserName" 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   - ✓ user.name = $envGitUserName" -ForegroundColor Green
        } else {
            throw "設置 user.name 失敗"
        }

        # 設置 user.email
        git config --global user.email "$envGitUserEmail" 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   - ✓ user.email = $envGitUserEmail" -ForegroundColor Green
        } else {
            throw "設置 user.email 失敗"
        }

        Write-Host ""
        Write-Host "✅ Git 配置設置成功！" -ForegroundColor Green

        # 驗證配置
        $verifyName = git config --global user.name
        $verifyEmail = git config --global user.email

        Write-Host ""
        Write-Host "配置驗證：" -ForegroundColor Cyan
        Write-Host "   user.name  = $verifyName" -ForegroundColor White
        Write-Host "   user.email = $verifyEmail" -ForegroundColor White
        Write-Host ""
        Write-Host "配置文件位置：" -ForegroundColor Gray
        Write-Host "   $env:USERPROFILE\.gitconfig" -ForegroundColor DarkGray

        if (-not $NonInteractive) {
            Read-Host "按 Enter 鍵結束..."
        }
        exit 0

    } catch {
        Write-Host ""
        Write-Host "❌ Git 配置設置失敗：$($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        Write-Host "手動設置方法：" -ForegroundColor Yellow
        Write-Host "   git config --global user.name `"$envGitUserName`"" -ForegroundColor White
        Write-Host "   git config --global user.email `"$envGitUserEmail`"" -ForegroundColor White

        if (-not $NonInteractive) {
            Read-Host "按 Enter 鍵結束..."
        }
        exit 1
    }
}
