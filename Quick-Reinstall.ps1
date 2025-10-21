#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Quick reinstall script for development environment

.DESCRIPTION
    Force reinstalls all platform tools to their latest versions.
    Reinstalls tools even if they are already installed.

.EXAMPLE
    .\Quick-Reinstall.ps1
    Force reinstalls all tools
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
Write-Host ""

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host ""
    Write-Host "❌ This script must be run as Administrator" -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

# Reinstall all platform tools
Write-Step "Reinstalling Platform Tools"

$PlatformDir = Join-Path $ScriptDir "platform\windows"
$InstallScripts = Get-ChildItem -Path $PlatformDir -Filter "Install-*.ps1" -ErrorAction SilentlyContinue

if (-not $InstallScripts) {
    Write-Warning "No installation scripts found in $PlatformDir"
} else {
    Write-Info "Found $($InstallScripts.Count) installation script(s)"
    Write-Host ""

    foreach ($script in $InstallScripts) {
        $toolName = $script.BaseName -replace '^Install-', ''
        Write-Info "Reinstalling $toolName..."

        # Pass -Force parameter to install scripts
        & $script.FullName -Force

        if ($LASTEXITCODE -ne 0 -and -not $?) {
            Write-Host ""
            Write-Host "❌ $toolName reinstallation failed" -ForegroundColor Red
            Write-Host "Reinstall cannot continue" -ForegroundColor Red
            Write-Host "Please check the error messages above and try again" -ForegroundColor Yellow
            Write-Host ""
            Read-Host "Press Enter to exit"
            exit 1
        }

        Write-Success "$toolName reinstallation completed"
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
