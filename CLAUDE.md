# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Windows development environment bootstrap system that automates installation of development tools (Node.js, Python, Git, PowerShell 7, WSL2, Docker, Ngrok, Cursor Agent CLI) with smart upgrade detection and zero-friction setup. Designed to be integrated into other projects via **git subtree**.

Supports two installation modes:
- **Quick Mode**: Essential development tools (Git, Node.js, Python, PowerShell)
- **Full Mode**: Complete environment including containers and WSL (Quick + WSL2, Docker Desktop, Ngrok, Cursor Agent CLI)

## Key Architecture Principles

### Admin Permission Model

**CRITICAL**: This project uses a hybrid permission model that must be preserved:

1. **Entry point scripts** (`Bootstrap.ps1`, `Quick-*.ps1`) REJECT admin execution by default
   - Prevents npm/pip packages from installing to system directories
   - User must explicitly pass `-AllowAdmin` flag if running as Administrator account

2. **Admin scripts** (`*-Admin.ps1`) self-elevate when needed
   - Use `Start-Process -Verb RunAs` to trigger UAC prompts
   - Preserve all parameters during elevation
   - Exit with child process exit code

3. **User scripts** (no `-Admin` suffix) run with normal permissions
   - Examples: `Install-Python.ps1`, `Setup-NodeJS.ps1`, `Setup-Git.ps1`, `Setup-Ngrok.ps1`, `Install-*Packages.ps1`
   - Never require UAC prompts

### Script Parameter Patterns

All install scripts follow consistent parameter conventions:
- `-Upgrade`: Upgrade to latest version if already installed
- `-Force`: Force reinstall even if present
- `-NonInteractive`: No user prompts (for automation)
- `-AllowAdmin`: Override admin execution check (entry scripts only)

Parameters are mutually exclusive: `-Force` takes precedence over `-Upgrade`.

### Winget Exit Code Handling

**CRITICAL for upgrade detection**: Winget returns `-1978335189` (0x8A15002B) when package is already up-to-date. Scripts must recognize this as success, not failure:

```powershell
if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) {
    # Success or already up-to-date
}
```

This prevents redundant downloads and provides accurate user feedback.

## Common Development Commands

### Testing Scripts Locally

```powershell
# Test individual install script
.\platform\windows\Install-NodeJS-Admin.ps1

# Test with upgrade mode
.\platform\windows\Install-Python.ps1 -Upgrade

# Test quick install (full flow)
.\Quick-Install.ps1

# Verify installations
.\platform\windows\Check-Installation.ps1
```

### Testing Admin Elevation

```powershell
# Test from normal PowerShell (will trigger UAC)
.\platform\windows\Install-Git-Admin.ps1

# Test admin rejection on entry scripts
.\Quick-Install.ps1  # Should fail if running as admin

# Override for Administrator accounts
.\Quick-Install.ps1 -AllowAdmin
```

## File Organization

- `platform/windows/`: Windows-specific installers and utilities
  - `*-Admin.ps1`: Require admin (self-elevate)
  - `*.ps1` (no suffix): User-level operations
  - `Check-Installation.ps1`: Renamed from `Check-Environment.ps1` (recently moved from shared/windows/)

- `shared/windows/`: Reserved for cross-platform shared utilities (currently empty)

- Root level: Entry points and orchestration scripts
  - `Bootstrap.ps1`: Download repo and execute (single-file distribution)
  - `Bootstrap.bat`: Launcher with execution policy handling
  - `Quick-*.ps1`: Quick mode orchestration scripts (Install/Upgrade/Reinstall) - basic dev tools
  - `Full-*.ps1`: Full mode orchestration scripts (Install/Upgrade/Reinstall) - includes WSL2/Docker/Ngrok/Cursor Agent

## Critical UTF-8 Encoding Requirement

**ALL PowerShell scripts MUST have UTF-8 BOM** to support Chinese characters and prevent parser errors in Windows PowerShell 5.1. This is non-negotiable for this project.

When creating or editing `.ps1` files:
1. Ensure UTF-8 with BOM encoding
2. Scripts without BOM will cause issues for Chinese-speaking users

## Git Integration Pattern

This repository is designed for git subtree integration, not submodules:

```bash
# Projects consume this repo via:
git subtree add --prefix=scripts/bootstrap \
  https://github.com/sammykenny2/environment-bootstrap.git main --squash
```

Keep this usage pattern in mind when suggesting structural changes - maintain self-contained, relocatable structure.

## Fallback Method Architecture

**CRITICAL**: Most `*-Admin.ps1` scripts implement a two-tier installation approach:

1. **Primary Method**: Use winget (Windows Package Manager)
   - Fast, standardized, handles dependencies
   - May fail due to network, source issues, or unavailability

2. **Fallback Method**: Direct download from official sources
   - **MUST include version detection** to avoid redundant downloads
   - Query official APIs (GitHub releases, nodejs.org, etc.) for latest version
   - Compare with installed version before downloading
   - Only download if version differs or on `-Force` flag

### Fallback Version Detection Pattern

```powershell
# Get latest version from API
$latestVersion = ... # from GitHub API / official API

# Get current installed version
$currentVersion = ... # from command output (git --version, node -v, etc.)

# Compare and skip if already latest
if ($currentVersion -eq $latestVersion) {
    Write-Host "Already latest version, skipping"
    $installSuccess = $true
} else {
    # Download and install
}
```

### Scripts with Fallback Support

| Script | Fallback Source | Version API |
|--------|----------------|-------------|
| **Install-Git-Admin.ps1** | GitHub Releases | `api.github.com/repos/git-for-windows/git/releases/latest` |
| **Install-PowerShell-Admin.ps1** | GitHub Releases | `api.github.com/repos/PowerShell/PowerShell/releases/latest` |
| **Install-Winget-Admin.ps1** | GitHub Releases | `api.github.com/repos/microsoft/winget-cli/releases/latest` |
| **Install-NodeJS-Admin.ps1** | nodejs.org | `nodejs.org/dist/index.json` |
| **Install-Ngrok-Admin.ps1** | ngrok.com | ⚠️ No API (uses stable URL, shows warning in `-Upgrade` mode) |
| **Install-Python.ps1** | pyenv-win + GitHub | Uses pyenv for version management (no version check needed in `-Upgrade` mode) |
| **Install-WSL2-Admin.ps1** | wsl --install | Native Windows feature (no fallback needed) |
| **Install-Docker-Admin.ps1** | docker.com | Direct download from official Docker Desktop installer |
| **Install-CursorAgent-Admin.ps1** | cursor.com | Installs in WSL2 via curl, includes SSL fallback for firewalls |

### Version String Extraction Notes

- **Git**: Returns `git version 2.51.2.windows.1` → Extract full string with `'git version (.+)$'`
- **PowerShell**: Returns `PowerShell 7.4.1` → Extract with `'[\d\.]+'`
- **Winget**: Returns `v1.7.10173` → Extract with `'[\d\.]+'`
- **NodeJS**: Returns `v20.10.0` → Extract with `'v?(.+)$'`

## Recent Changes Context

Recent improvements (2025-10-30) focused on:

### Full Installation Suite
- **Full-*.ps1 scripts**: Complete environment setup including WSL2, Docker Desktop, Ngrok, Cursor Agent CLI
- **Install-WSL2-Admin.ps1**: Automated WSL2 installation with Ubuntu distribution
- **Install-Docker-Admin.ps1**: Docker Desktop installation with running instance handling
- **Install-Ngrok-Admin.ps1**: Ngrok tunneling tool installation
- **Install-CursorAgent-Admin.ps1**: Cursor Agent CLI installation in WSL2 with curl dependency auto-install and SSL fallback
- **Check-Installation.ps1**: Enhanced with `-Full` parameter to check all tools in Full mode

### Configuration Management
- **Setup-Git.ps1**: Automated Git user.name and user.email configuration from .env
- **Setup-Ngrok.ps1**: Automated Ngrok authtoken configuration from .env
- **.env.example cleanup**: Removed unused variables, empty default values with examples in comments
- **Standard parameter behavior**: All Setup scripts follow Install/Upgrade/Force logic consistently

### Earlier Improvements
- **Fallback method version detection** (Git, PowerShell, Winget, NodeJS): Prevent redundant downloads
- **NodeJS fallback support**: nodejs.org direct download with full LTS/Latest/specific version support
- **Git version extraction fix**: Correctly parse `2.51.2.windows.1` format
- **Ngrok upgrade behavior**: Skip reinstall in `-Upgrade` mode when already installed
- Smart upgrade detection (winget exit code `-1978335189` recognition)
- UTF-8 BOM support for all scripts
- Progress bars for downloads

## User Experience Standards

Message conventions for operations:
- "檢查 X..." (Checking X) when verifying state
- "安裝 X..." (Installing X) when actually installing
- "升級 X..." (Upgrading X) when upgrading
- "✓ 已安裝，跳過" (Already installed, skipping) when up-to-date

Be precise with status messages - don't say "Installing" when only checking.

## Configuration via .env

The project uses `.env` file for user-specific configuration:

### Creating .env File

```bash
# Copy the example file
cp .env.example .env

# Edit and fill in your values
# All values are empty by default - examples are in comments
```

### Supported Configuration Variables

```bash
# Git user configuration (used by Setup-Git.ps1)
GIT_USER_NAME=          # Your name for git commits
GIT_USER_EMAIL=         # Your email for git commits

# Ngrok authentication (used by Setup-Ngrok.ps1)
NGROK_AUTHTOKEN=        # Get from https://dashboard.ngrok.com

# Optional proxy settings (commented out by default)
# HTTP_PROXY=
# HTTPS_PROXY=
# NO_PROXY=
```

### Setup Scripts Behavior

Setup scripts read from `.env` and follow standard parameter logic:

- **No parameter (default)**: Set if not configured, skip if already set
- **-Upgrade**: Update if .env value differs from current setting
- **-Force**: Always overwrite with .env value
- **Command-line parameters**: Override .env values

**Important**: Empty values in .env are treated as "not configured" and scripts will prompt or skip.
