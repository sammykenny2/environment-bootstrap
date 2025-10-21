# Check-Environment.ps1
# 檢查開發環境設定

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

# 檢查 Docker
try {
    $dockerVersion = docker --version 2>$null
    if ($dockerVersion) {
        Write-Host "✅ Docker: $dockerVersion" -ForegroundColor Green
    }
} catch {
    Write-Host "⚪ Docker: 未安裝 (容器化部署需要)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "[環境變數]" -ForegroundColor Yellow

# 檢查常用環境變數
$commonVars = @{
    "NODE_ENV" = $env:NODE_ENV
    "PATH" = if ($env:PATH) { "(已設定)" } else { $null }
    "HOME" = $env:HOME
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
    $_ -match 'node|npm|git|python|docker' -or
    $_ -match 'Program Files.*node' -or
    $_ -match 'Program Files.*git' -or
    $_ -match 'Program Files.*python' -or
    $_ -match 'Program Files.*Docker'
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
