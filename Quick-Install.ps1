<#
.SYNOPSIS
    Quick install script for development environment

.DESCRIPTION
    Installs all missing platform tools and sets up development packages.
    Install-* scripts will self-elevate when needed (UAC prompts).
    Setup-* scripts run with normal user permissions.

.EXAMPLE
    .\Quick-Install.ps1
    Installs all tools and sets up development environment
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
║        Environment Bootstrap - Quick Install              ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Info "Platform: Windows"
Write-Info "Note: Install-* scripts will prompt for UAC when needed"
Write-Host ""

# Process all Install-* and Setup-* scripts
Write-Step "Installing Tools and Setting Up Environment"

$PlatformDir = Join-Path $ScriptDir "platform\windows"

# Define Install-* execution order (dependencies matter)
$installOrder = @(
    "Install-Winget.ps1",       # Foundation: package manager for other tools
    "Install-PowerShell.ps1",   # Optional: upgrade to PowerShell 7
    "Install-NodeJS.ps1"        # Depends on winget
)

# Step 1: Execute Install-* scripts in specified order
Write-Info "Phase 1: Installing system tools (may require UAC)"
Write-Host ""

foreach ($scriptName in $installOrder) {
    $scriptPath = Join-Path $PlatformDir $scriptName

    if (-not (Test-Path $scriptPath)) {
        Write-Warning "$scriptName not found, skipping..."
        continue
    }

    $toolName = $scriptName -replace '^Install-(.+)\.ps1$', '$1'
    Write-Info "Installing $toolName (may require UAC)..."

    & $scriptPath

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

# Define Setup-* execution order (dependencies matter)
$setupOrder = @(
    "Setup-Python.ps1",         # Install pyenv-win and Python
    "Setup-PythonPackages.ps1", # Depends on Setup-Python.ps1
    "Setup-NodeJS.ps1",         # Configure npm environment
    "Setup-NodePackages.ps1"    # Depends on Setup-NodeJS.ps1
)

foreach ($scriptName in $setupOrder) {
    $scriptPath = Join-Path $PlatformDir $scriptName

    if (-not (Test-Path $scriptPath)) {
        Write-Warning "$scriptName not found, skipping..."
        continue
    }

    $toolName = $scriptName -replace '^Setup-(.+)\.ps1$', '$1'
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
Write-Host "║                Install Complete! 🎉                       ║" -ForegroundColor Green
Write-Host "║                                                           ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Success "All tools installed successfully"
Write-Host ""
Write-Info "Next steps:"
Write-Host "  1. Close this PowerShell window"
Write-Host "  2. Open a NEW PowerShell window (to load updated PATH)"
Write-Host "  3. Start developing!"
Write-Host ""
Write-Info "For help, see: README.md"
