<#
.SYNOPSIS
    Full install script for complete development environment

.DESCRIPTION
    Installs all platform tools including Docker/WSL2 and sets up development packages.
    Install-* scripts will self-elevate when needed (UAC prompts).
    Setup-* scripts run with normal user permissions.
    Includes: Winget, Git, PowerShell, NodeJS, WSL2, Docker, Ngrok, Cursor Agent CLI, Python

.PARAMETER AllowAdmin
    Allow execution with admin privileges (for Administrator accounts only)

.EXAMPLE
    .\Full-Install.ps1
    Installs complete development environment

.EXAMPLE
    .\Full-Install.ps1 -AllowAdmin
    For Administrator accounts: allow execution with admin privileges
#>

param(
    [Parameter(Mandatory=$false)]
    [switch]$AllowAdmin
)

# === Reject Admin Execution (unless explicitly allowed) ===
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isAdmin -and -not $AllowAdmin) {
    Write-Host "❌ 錯誤：檢測到以管理員權限執行" -ForegroundColor Red
    Write-Host ""
    Write-Host "原因：" -ForegroundColor Yellow
    Write-Host "  - 以 admin 執行會導致 user 權限的腳本失敗" -ForegroundColor Yellow
    Write-Host "  - npm/pip packages 會安裝到系統目錄（權限問題）" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "如果您是 Administrator 帳戶且確定要繼續，請使用：" -ForegroundColor Cyan
    Write-Host "  .\Full-Install.ps1 -AllowAdmin" -ForegroundColor White
    Write-Host ""
    Read-Host "按 Enter 鍵結束..."
    exit 1
}

if ($AllowAdmin -and $isAdmin) {
    Write-Host "⚠️  警告：以 Admin 權限執行（已使用 -AllowAdmin 參數）" -ForegroundColor Yellow
    Write-Host ""
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
║        Environment Bootstrap - Full Install               ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Info "Platform: Windows"
Write-Info "Note: Install-* scripts will prompt for UAC when needed"
Write-Host ""

# Process all Install-* and Setup-* scripts
Write-Step "Installing Tools and Setting Up Environment"

$PlatformDir = Join-Path $ScriptDir "platform\windows"

# Define admin scripts execution order (dependencies matter)
$adminScripts = @(
    "Install-Winget-Admin.ps1",       # Foundation: package manager for other tools
    "Install-Git-Admin.ps1",          # Version control (depends on winget, has fallback)
    "Install-PowerShell-Admin.ps1",   # Optional: upgrade to PowerShell 7
    "Install-NodeJS-Admin.ps1",       # Depends on winget (has fallback)
    "Install-WSL2-Admin.ps1",         # Windows Subsystem for Linux 2
    "Install-Docker-Admin.ps1",       # Docker Desktop (depends on WSL2)
    "Install-CursorAgent-Admin.ps1",  # Cursor Agent CLI (depends on WSL2)
    "Install-Ngrok-Admin.ps1"         # Ngrok tunneling tool
)

# Step 1: Execute Install-* scripts in specified order
Write-Info "Phase 1: Installing system tools (may require UAC)"
Write-Host ""

foreach ($scriptName in $adminScripts) {
    $scriptPath = Join-Path $PlatformDir $scriptName

    if (-not (Test-Path $scriptPath)) {
        Write-Warning "$scriptName not found, skipping..."
        continue
    }

    $toolName = $scriptName -replace '^Install-(.+)-Admin\.ps1$', '$1'
    Write-Info "Installing $toolName (may require UAC)..."

    & $scriptPath -NonInteractive

    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "❌ $toolName installation failed with exit code $LASTEXITCODE" -ForegroundColor Red
        Write-Host "Setup cannot continue" -ForegroundColor Red
        Write-Host "Please check the error messages above and try again" -ForegroundColor Yellow
        Write-Host ""
        Read-Host "Press Enter to exit"
        exit 1
    }

    Write-Success "$toolName installation completed"
    Write-Host ""
}

# Step 2: Execute Setup-* scripts in specified order
Write-Info "Phase 2: Setting up development environment"
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
    Write-Info "Setting up $toolName..."

    & $scriptPath

    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "❌ $toolName setup failed with exit code $LASTEXITCODE" -ForegroundColor Red
        Write-Host "Setup cannot continue" -ForegroundColor Red
        Write-Host "Please check the error messages above and try again" -ForegroundColor Yellow
        Write-Host ""
        Read-Host "Press Enter to exit"
        exit 1
    }

    Write-Success "$toolName setup completed"
    Write-Host ""
}

# Environment check
Write-Step "Environment Check"
$CheckScript = Join-Path $ScriptDir "platform\windows\Check-Installation.ps1"
if (Test-Path $CheckScript) {
    Write-Info "Verifying environment setup..."
    & $CheckScript -Full
} else {
    Write-Warning "Environment check script not found"
    Write-Info "Skipping environment verification"
}

# Reload PATH for current session
Write-Host ""
Write-Info "Refreshing environment variables for current session..."
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "User") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "Machine")

# Summary
Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                                                           ║" -ForegroundColor Green
Write-Host "║                Install Complete! 🎉                       ║" -ForegroundColor Green
Write-Host "║                                                           ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Success "All tools installed successfully"
Write-Host ""
Write-Info "Installed tools:"
Write-Host "  - Winget, Git, PowerShell 7, Node.js, npm" -ForegroundColor White
Write-Host "  - WSL2, Docker Desktop, Ngrok, Cursor Agent CLI" -ForegroundColor White
Write-Host "  - Python (via pyenv-win), pip" -ForegroundColor White
Write-Host ""
Write-Info "Next steps:"
Write-Host "  1. Close this PowerShell window"
Write-Host "  2. Open a NEW PowerShell window"
Write-Host "  3. Start Docker Desktop (if not auto-started)"
Write-Host "  4. Test: docker run hello-world"
Write-Host "  5. Test: wsl"
Write-Host ""
Write-Info "Note: New PowerShell window required for environment changes to take effect"
Write-Host ""
Write-Info "For help, see: README.md"
