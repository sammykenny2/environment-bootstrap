<#
.SYNOPSIS
    Quick upgrade script for development environment

.DESCRIPTION
    Upgrades all platform tools and development packages to their latest versions.
    Install-* scripts will self-elevate when needed (UAC prompts).
    Setup-* scripts run with normal user permissions.

.EXAMPLE
    .\Quick-Upgrade.ps1
    Upgrades all tools and packages to latest versions
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
Write-Info "Note: Install-* scripts will prompt for UAC when needed"
Write-Host ""

# Process all Install-* and Setup-* scripts
Write-Step "Upgrading Tools and Packages"

$PlatformDir = Join-Path $ScriptDir "platform\windows"

# Get all Install-* and Setup-* scripts, sorted alphabetically
# This ensures Install-* scripts run before Setup-* scripts
$allScripts = Get-ChildItem -Path $PlatformDir -Filter "*.ps1" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^(Install|Setup)-.*\.ps1$' } |
    Sort-Object Name

if (-not $allScripts) {
    Write-Warning "No installation or setup scripts found in $PlatformDir"
    exit 0
}

Write-Info "Found $($allScripts.Count) script(s) to upgrade"
Write-Host ""

foreach ($script in $allScripts) {
    # Determine script type and tool name
    if ($script.Name -match '^Install-(.+)\.ps1$') {
        $toolName = $Matches[1]
        Write-Info "Upgrading $toolName (may require UAC)..."
    } elseif ($script.Name -match '^Setup-(.+)\.ps1$') {
        $toolName = $Matches[1]
        Write-Info "Upgrading $toolName..."
    } else {
        continue
    }

    # Execute script with -Upgrade parameter
    & $script.FullName -Upgrade

    # Check exit code
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "❌ $toolName upgrade failed with exit code $LASTEXITCODE" -ForegroundColor Red
        Write-Host "Upgrade cannot continue" -ForegroundColor Red
        Write-Host "Please check the error messages above and try again" -ForegroundColor Yellow
        Write-Host ""
        Read-Host "Press Enter to exit"
        exit 1
    }

    Write-Success "$toolName upgrade completed"
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
