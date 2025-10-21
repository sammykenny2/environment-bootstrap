<#
.SYNOPSIS
    Quick reinstall script for development environment

.DESCRIPTION
    Force reinstalls all platform tools and development packages to their latest versions.
    Install-* scripts will self-elevate when needed (UAC prompts).
    Setup-* scripts run with normal user permissions.

.EXAMPLE
    .\Quick-Reinstall.ps1
    Force reinstalls all tools and packages
#>

# === Reject Admin Execution ===
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isAdmin) {
    Write-Host "❌ 錯誤：此腳本不應以管理員權限執行" -ForegroundColor Red
    Write-Host ""
    Write-Host "原因：" -ForegroundColor Yellow
    Write-Host "  - 此腳本會自動管理權限" -ForegroundColor Yellow
    Write-Host "  - 子腳本需要 admin 時會自動提權（彈出 UAC）" -ForegroundColor Yellow
    Write-Host "  - 以 admin 執行會導致 user 權限的腳本失敗" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "請以「一般用戶權限」重新執行此腳本" -ForegroundColor Cyan
    Write-Host ""
    Read-Host "按 Enter 鍵結束..."
    exit 1
}

# Color output functions
function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Cyan
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

function Write-Step {
    param([string]$Message)
    Write-Host "`n🚀 $Message" -ForegroundColor Magenta
    Write-Host ("=" * 60) -ForegroundColor DarkGray
}

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Banner
Clear-Host
Write-Host @"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║        Environment Bootstrap - Quick Reinstall            ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Info "Platform: Windows"
Write-Info "Note: Install-* scripts will prompt for UAC when needed"
Write-Host ""

# Process all Install-* and Setup-* scripts
Write-Step "Reinstalling Tools and Packages"

$PlatformDir = Join-Path $ScriptDir "platform\windows"

# Define admin scripts execution order (dependencies matter)
$adminScripts = @(
    "Install-Winget-Admin.ps1",       # Foundation: package manager for other tools
    "Install-Git-Admin.ps1",          # Version control (depends on winget, has fallback)
    "Install-PowerShell-Admin.ps1",   # Optional: upgrade to PowerShell 7
    "Install-NodeJS-Admin.ps1"        # Depends on winget
)

# Step 1: Execute Install-* scripts in specified order
Write-Info "Phase 1: Reinstalling system tools (may require UAC)"
Write-Host ""

foreach ($scriptName in $adminScripts) {
    $scriptPath = Join-Path $PlatformDir $scriptName

    if (-not (Test-Path $scriptPath)) {
        Write-Warning "$scriptName not found, skipping..."
        continue
    }

    $toolName = $scriptName -replace '^Install-(.+)-Admin\.ps1$', '$1'
    Write-Info "Reinstalling $toolName (may require UAC)..."

    & $scriptPath -Force

    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "❌ $toolName reinstall failed with exit code $LASTEXITCODE" -ForegroundColor Red
        Write-Host "Reinstall cannot continue" -ForegroundColor Red
        Write-Host "Please check the error messages above and try again" -ForegroundColor Yellow
        Write-Host ""
        Read-Host "Press Enter to exit"
        exit 1
    }

    Write-Success "$toolName reinstall completed"
    Write-Host ""
}

# Step 2: Execute Setup-* scripts in specified order
Write-Info "Phase 2: Reinstalling development packages"
Write-Host ""

# Define user scripts execution order (dependencies matter)
$userScripts = @(
    "Setup-NodeJS.ps1",         # Configure npm environment
    "Install-NodePackages.ps1", # Depends on Setup-NodeJS.ps1
    "Install-Python.ps1",       # Install pyenv-win and Python
    "Install-PythonPackages.ps1"  # Depends on Install-Python.ps1
)

foreach ($scriptName in $userScripts) {
    $scriptPath = Join-Path $PlatformDir $scriptName

    if (-not (Test-Path $scriptPath)) {
        Write-Warning "$scriptName not found, skipping..."
        continue
    }

    $toolName = $scriptName -replace '^(Setup|Install)-(.+)\.ps1$', '$2'
    Write-Info "Reinstalling $toolName..."

    & $scriptPath -Force

    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "❌ $toolName reinstall failed with exit code $LASTEXITCODE" -ForegroundColor Red
        Write-Host "Reinstall cannot continue" -ForegroundColor Red
        Write-Host "Please check the error messages above and try again" -ForegroundColor Yellow
        Write-Host ""
        Read-Host "Press Enter to exit"
        exit 1
    }

    Write-Success "$toolName reinstall completed"
    Write-Host ""
}

# Environment check
Write-Step "Environment Check"
$CheckScript = Join-Path $ScriptDir "shared\windows\Check-Environment.ps1"
if (Test-Path $CheckScript) {
    Write-Info "Verifying environment setup..."
    & $CheckScript
} else {
    Write-Warning "Environment check script not found"
    Write-Info "Skipping environment verification"
}

# Summary
Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                                                           ║" -ForegroundColor Green
Write-Host "║               Reinstall Complete! 🎉                      ║" -ForegroundColor Green
Write-Host "║                                                           ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Success "All tools reinstalled successfully"
Write-Host ""
Write-Info "Next steps:"
Write-Host "  1. Close this PowerShell window"
Write-Host "  2. Open a NEW PowerShell window (to load updated PATH)"
Write-Host "  3. Start developing!"
Write-Host ""
Write-Info "For help, see: README.md"
