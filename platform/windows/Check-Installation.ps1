<#
.SYNOPSIS
    Check development environment setup

.DESCRIPTION
    Checks if all required tools and environment variables are properly configured.
    This is a read-only diagnostic script.

.PARAMETER Full
    Check full installation (includes WSL2, Docker, Ngrok). Default: Quick mode only.

.PARAMETER AllowAdmin
    Allow execution with admin privileges (for Administrator accounts only)

.EXAMPLE
    .\Check-Installation.ps1
    Check Quick installation (Node.js, Python, Git, PowerShell)

.EXAMPLE
    .\Check-Installation.ps1 -Full
    Check Full installation (includes WSL2, Docker, Ngrok)

.EXAMPLE
    .\Check-Installation.ps1 -AllowAdmin
    For Administrator accounts: allow execution with admin privileges
#>

param(
    [Parameter(Mandatory=$false)]
    [switch]$Full,

    [Parameter(Mandatory=$false)]
    [switch]$AllowAdmin
)

# === Reject Admin Execution (unless explicitly allowed) ===
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isAdmin -and -not $AllowAdmin) {
    Write-Host "❌ 錯誤：檢測到以管理員權限執行" -ForegroundColor Red
    Write-Host ""
    Write-Host "原因：" -ForegroundColor Yellow
    Write-Host "  - 環境檢查應以實際使用者權限執行" -ForegroundColor Yellow
    Write-Host "  - 以 admin 執行可能顯示不正確的環境資訊" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "如果您是 Administrator 帳戶且確定要繼續，請使用：" -ForegroundColor Cyan
    Write-Host "  .\Check-Environment.ps1 -AllowAdmin" -ForegroundColor White
    Write-Host ""
    Read-Host "按 Enter 鍵結束..."
    exit 1
}

if ($AllowAdmin -and $isAdmin) {
    Write-Host "⚠️  警告：以 Admin 權限執行（已使用 -AllowAdmin 參數）" -ForegroundColor Yellow
    Write-Host ""
}

# --- 腳本開始 ---
Write-Host "===================================" -ForegroundColor Cyan
Write-Host "檢查開發環境設定" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan
Write-Host ""

$missing = $false

Write-Host "[系統工具檢查]" -ForegroundColor Yellow

# 檢查 Node.js
try {
    $nodeVersion = node --version 2>$null
    if ($nodeVersion) {
        Write-Host "✅ Node.js: $nodeVersion" -ForegroundColor Green
        $nodePath = (Get-Command node).Source
        Write-Host "   └─ 路徑: $nodePath" -ForegroundColor DarkGreen
    }
} catch {
    Write-Host "❌ Node.js: 未安裝或不在 PATH 中" -ForegroundColor Red
    $missing = $true
}

# 檢查 npm
try {
    $npmVersion = npm --version 2>$null
    if ($npmVersion) {
        Write-Host "✅ npm: v$npmVersion" -ForegroundColor Green
    }
} catch {
    Write-Host "❌ npm: 未安裝或不在 PATH 中" -ForegroundColor Red
    $missing = $true
}

# 檢查 Python
try {
    $pythonVersion = python --version 2>$null
    if ($pythonVersion) {
        Write-Host "✅ Python: $pythonVersion" -ForegroundColor Green
        $pythonPath = (Get-Command python).Source
        Write-Host "   └─ 路徑: $pythonPath" -ForegroundColor DarkGreen
    }
} catch {
    Write-Host "⚪ Python: 未安裝或不在 PATH 中" -ForegroundColor Gray
}

# 檢查 pyenv
try {
    $pyenvVersion = pyenv --version 2>$null
    if ($pyenvVersion) {
        Write-Host "✅ pyenv: $pyenvVersion" -ForegroundColor Green
    }
} catch {
    Write-Host "⚪ pyenv: 未安裝" -ForegroundColor Gray
}

# 檢查 Git
try {
    $gitVersion = git --version 2>$null
    if ($gitVersion) {
        Write-Host "✅ Git: $gitVersion" -ForegroundColor Green
    }
} catch {
    Write-Host "⚪ Git: 未安裝或不在 PATH 中" -ForegroundColor Gray
}

# Full 模式才檢查以下工具
if ($Full) {
    # 檢查 WSL2
    try {
        $wslVersion = wsl --version 2>$null
        if ($LASTEXITCODE -eq 0 -and $wslVersion) {
            Write-Host "✅ WSL2: 已安裝" -ForegroundColor Green

            # 列出已安裝的發行版
            $distros = wsl --list --quiet 2>$null
            if ($distros) {
                $distroList = $distros | Where-Object { $_ -and $_ -notmatch "^Windows" }
                if ($distroList) {
                    $distroCount = ($distroList | Measure-Object).Count
                    Write-Host "   └─ 已安裝 $distroCount 個發行版" -ForegroundColor DarkGreen
                }
            }
        }
    } catch {
        Write-Host "❌ WSL2: 未安裝" -ForegroundColor Red
        $missing = $true
    }

    # 檢查 Docker
    try {
        $dockerVersion = docker --version 2>$null
        if ($dockerVersion) {
            Write-Host "✅ Docker: $dockerVersion" -ForegroundColor Green

            # 檢查 Docker Engine 是否運行
            $dockerInfo = docker info 2>$null
            if ($LASTEXITCODE -eq 0 -and $dockerInfo) {
                Write-Host "   └─ Docker Engine: 運行中" -ForegroundColor DarkGreen
            } else {
                Write-Host "   └─ Docker Engine: 未運行（請啟動 Docker Desktop）" -ForegroundColor Yellow
            }
        }
    } catch {
        Write-Host "❌ Docker: 未安裝" -ForegroundColor Red
        $missing = $true
    }

    # 檢查 Ngrok
    try {
        $ngrokVersionOutput = ngrok version 2>$null
        if ($ngrokVersionOutput -match 'ngrok version ([\d\.]+)') {
            $ngrokVersion = $matches[1]
            Write-Host "✅ Ngrok: v$ngrokVersion" -ForegroundColor Green
        } elseif ($ngrokVersionOutput) {
            Write-Host "✅ Ngrok: 已安裝" -ForegroundColor Green
        }
    } catch {
        Write-Host "❌ Ngrok: 未安裝" -ForegroundColor Red
        $missing = $true
    }

    # 檢查 Cursor Agent CLI（在 WSL 中）
    try {
        # 檢查 WSL 是否可用
        $wslCommand = Get-Command wsl -ErrorAction SilentlyContinue
        if ($wslCommand) {
            # 嘗試在預設 WSL 發行版中檢查 cursor-agent
            $checkCommand = "command -v cursor-agent >/dev/null 2>&1 && cursor-agent --version 2>&1 || echo 'not-installed'"
            $cursorAgentCheck = wsl bash -c $checkCommand 2>$null

            if ($cursorAgentCheck -and $cursorAgentCheck -ne "not-installed") {
                Write-Host "✅ Cursor Agent CLI: 已安裝" -ForegroundColor Green
                if ($cursorAgentCheck -notmatch "not-installed") {
                    Write-Host "   └─ 版本：$($cursorAgentCheck.Trim())" -ForegroundColor DarkGreen
                }
            } else {
                Write-Host "❌ Cursor Agent CLI: 未安裝" -ForegroundColor Red
                $missing = $true
            }
        } else {
            Write-Host "⚪ Cursor Agent CLI: 需要 WSL2（未檢查）" -ForegroundColor Gray
        }
    } catch {
        Write-Host "❌ Cursor Agent CLI: 未安裝或檢查失敗" -ForegroundColor Red
        $missing = $true
    }
}

Write-Host ""
Write-Host "[環境變數]" -ForegroundColor Yellow

# 檢查常用環境變數
$commonVars = @{
    "PATH" = if ($env:PATH) { "(已設定)" } else { $null }
    "USERPROFILE" = $env:USERPROFILE
}

foreach ($var in $commonVars.GetEnumerator()) {
    if ([string]::IsNullOrEmpty($var.Value)) {
        Write-Host "⚪ $($var.Key): 未設定" -ForegroundColor Gray
    } else {
        Write-Host "✅ $($var.Key): $($var.Value)" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "[PATH 環境變數內容]" -ForegroundColor Yellow
$pathDirs = $env:PATH -split ';'
$relevantPaths = $pathDirs | Where-Object {
    $_ -match 'node|npm|git|python|docker|ngrok|wsl' -or
    $_ -match 'Program Files.*node' -or
    $_ -match 'Program Files.*git' -or
    $_ -match 'Program Files.*python' -or
    $_ -match 'Program Files.*Docker' -or
    $_ -match 'Program Files.*ngrok'
}

if ($relevantPaths) {
    Write-Host "相關路徑:" -ForegroundColor Cyan
    foreach ($path in $relevantPaths) {
        Write-Host "  • $path" -ForegroundColor DarkGray
    }
} else {
    Write-Host "未找到相關程式路徑" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "===================================" -ForegroundColor Cyan
if ($missing) {
    Write-Host "❌ 有必要項目未設定，請先完成設定" -ForegroundColor Red
} else {
    Write-Host "✅ 環境設定檢查通過！" -ForegroundColor Green
}
Write-Host "===================================" -ForegroundColor Cyan

# 提供設定建議
if ($missing) {
    Write-Host ""
    Write-Host "建議設定步驟:" -ForegroundColor Yellow
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        Write-Host "1. 安裝 Node.js:" -ForegroundColor White
        Write-Host "   執行 .\platform\windows\Install-NodeJS.ps1" -ForegroundColor DarkGray
    }
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Host "2. npm 通常會隨 Node.js 一起安裝" -ForegroundColor White
        Write-Host "   如果缺失，請重新安裝 Node.js" -ForegroundColor DarkGray
    }
    if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
        Write-Host "3. 安裝 Python:" -ForegroundColor White
        Write-Host "   執行 .\platform\windows\Install-Python.ps1" -ForegroundColor DarkGray
    }
}

Write-Host ""
Read-Host "按 Enter 鍵結束"
