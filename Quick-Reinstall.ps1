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

# Define Install-* execution order (dependencies matter)
$installOrder = @(
    "Install-Winget.ps1",       # Foundation: package manager for other tools
    "Install-PowerShell.ps1",   # Optional: upgrade to PowerShell 7
    "Install-NodeJS.ps1"        # Depends on winget
)

# Step 1: Execute Install-* scripts in specified order
Write-Info "Phase 1: Reinstalling system tools (may require UAC)"
Write-Host ""

foreach ($scriptName in $installOrder) {
    $scriptPath = Join-Path $PlatformDir $scriptName

    if (-not (Test-Path $scriptPath)) {
        Write-Warning "$scriptName not found, skipping..."
        continue
    }

    $toolName = $scriptName -replace '^Install-(.+)\.ps1$', '$1'
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

# Define Setup-* execution order (dependencies matter)
$setupOrder = @(
    "Setup-Python.ps1",         # Install pyenv-win first
    "Setup-PythonPackages.ps1", # Depends on pyenv-win
    "Setup-NodePackages.ps1"    # Independent (Node.js already installed)
)

foreach ($scriptName in $setupOrder) {
    $scriptPath = Join-Path $PlatformDir $scriptName

    if (-not (Test-Path $scriptPath)) {
        Write-Warning "$scriptName not found, skipping..."
        continue
    }

    $toolName = $scriptName -replace '^Setup-(.+)\.ps1$', '$1'
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
