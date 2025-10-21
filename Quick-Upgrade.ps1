#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Quick upgrade script for development environment

.DESCRIPTION
    Upgrades all platform tools to their latest versions.
    Installs tools that are missing.

.EXAMPLE
    .\Quick-Upgrade.ps1
    Upgrades all tools to latest versions
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
║        Environment Bootstrap - Quick Upgrade              ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Info "Platform: Windows"
Write-Host ""

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host ""
    Write-Host "❌ This script must be run as Administrator" -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

# Upgrade all platform tools
Write-Step "Upgrading Platform Tools"

$PlatformDir = Join-Path $ScriptDir "platform\windows"

# Step 1: Upgrade winget first (prerequisite for other tools)
$WingetScript = Join-Path $PlatformDir "Install-Winget.ps1"
if (Test-Path $WingetScript) {
    Write-Info "Upgrading Winget (prerequisite)..."
    & $WingetScript -Upgrade

    if ($LASTEXITCODE -ne 0 -and -not $?) {
        Write-Host ""
        Write-Host "❌ Winget upgrade failed" -ForegroundColor Red
        Write-Host "Upgrade cannot continue" -ForegroundColor Red
        Write-Host "Please check the error messages above and try again" -ForegroundColor Yellow
        Write-Host ""
        Read-Host "Press Enter to exit"
        exit 1
    }

    Write-Success "Winget upgrade completed"
    Write-Host ""
}

# Step 2: Upgrade other tools (excluding winget)
$InstallScripts = Get-ChildItem -Path $PlatformDir -Filter "Install-*.ps1" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne "Install-Winget.ps1" }

if (-not $InstallScripts) {
    Write-Warning "No additional installation scripts found in $PlatformDir"
} else {
    Write-Info "Found $($InstallScripts.Count) additional installation script(s)"
    Write-Host ""

    foreach ($script in $InstallScripts) {
        $toolName = $script.BaseName -replace '^Install-', ''
        Write-Info "Upgrading $toolName..."

        # Pass -Upgrade parameter to install scripts
        & $script.FullName -Upgrade

        if ($LASTEXITCODE -ne 0 -and -not $?) {
            Write-Host ""
            Write-Host "❌ $toolName upgrade failed" -ForegroundColor Red
            Write-Host "Upgrade cannot continue" -ForegroundColor Red
            Write-Host "Please check the error messages above and try again" -ForegroundColor Yellow
            Write-Host ""
            Read-Host "Press Enter to exit"
            exit 1
        }

        Write-Success "$toolName upgrade completed"
        Write-Host ""
    }
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
Write-Host "║                Upgrade Complete! 🎉                       ║" -ForegroundColor Green
Write-Host "║                                                           ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Success "All tools upgraded successfully"
Write-Host ""
Write-Info "Next steps:"
Write-Host "  1. Close this PowerShell window"
Write-Host "  2. Open a NEW PowerShell window (to load updated PATH)"
Write-Host "  3. Start developing!"
Write-Host ""
Write-Info "For help, see: README.md"
