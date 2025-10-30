# Environment Bootstrap

🚀 Automated development environment setup for Windows with zero-friction installation.

## Features

- 🎯 **One-Click Setup**: Bootstrap.bat for instant environment setup
- 🔄 **Smart Upgrade**: Detects already-installed packages to avoid redundant downloads
- 🌐 **Multi-Platform Tools**: Node.js, Python, Git, PowerShell 7, WSL2, Docker, Ngrok, Cursor Agent CLI
- ⚡ **Fast & Efficient**: Download progress bars and intelligent caching
- 🔒 **User-Friendly**: Automatic admin elevation when needed
- 🛡️ **Safe Defaults**: User-scoped installations to avoid permission issues
- 🐳 **Full Mode**: Complete containerized environment with WSL2 and Docker Desktop
- ⚙️ **Auto-Configuration**: Git and Ngrok setup from .env file

## Quick Start

### Method 1: Bootstrap.bat (Recommended)

Double-click `Bootstrap.bat` to automatically:
- Configure PowerShell execution policy (RemoteSigned for future runs)
- Run Bootstrap.ps1 with bypass policy (guaranteed execution)
- Handle UAC prompts as needed

### Method 2: Manual PowerShell

```powershell
# Initial installation
.\Bootstrap.ps1

# Or use quick install
.\Quick-Install.ps1

# Upgrade all tools to latest versions
.\Quick-Upgrade.ps1

# Force reinstall everything
.\Quick-Reinstall.ps1

# Full installation (includes WSL2, Docker, Ngrok, Cursor Agent)
.\Full-Install.ps1

# Full upgrade
.\Full-Upgrade.ps1

# Full reinstall
.\Full-Reinstall.ps1
```

### Common Operations

```powershell
# Install/upgrade specific tools
.\platform\windows\Install-NodeJS-Admin.ps1 -Upgrade
.\platform\windows\Install-Python.ps1 -Upgrade

# Force reinstall a tool
.\platform\windows\Install-Git-Admin.ps1 -Force

# Install development packages
.\platform\windows\Install-NodePackages.ps1
.\platform\windows\Install-PythonPackages.ps1

# Check installation (Quick mode)
.\platform\windows\Check-Installation.ps1

# Check installation (Full mode - includes WSL2/Docker/Ngrok/Cursor Agent)
.\platform\windows\Check-Installation.ps1 -Full

# Setup Git configuration from .env
.\platform\windows\Setup-Git.ps1

# Setup Ngrok authtoken from .env
.\platform\windows\Setup-Ngrok.ps1
```

## Directory Structure

```
environment-bootstrap/
├── Bootstrap.ps1          Main bootstrap script (PowerShell)
├── Bootstrap.bat          Launcher with execution policy handling
├── .env.example           Configuration template
│
├── Quick-Install.ps1      Quick mode: Essential dev tools
├── Quick-Upgrade.ps1      Quick mode: Upgrade all tools
├── Quick-Reinstall.ps1    Quick mode: Force reinstall
│
├── Full-Install.ps1       Full mode: Complete environment (Quick + WSL2/Docker/Ngrok/Cursor Agent)
├── Full-Upgrade.ps1       Full mode: Upgrade everything
├── Full-Reinstall.ps1     Full mode: Force reinstall everything
│
├── platform/windows/      Platform-specific tools and utilities
│   ├── Check-Installation.ps1        - Verify installation status
│   ├── Install-Winget-Admin.ps1      - Windows Package Manager
│   ├── Install-Git-Admin.ps1         - Git for Windows
│   ├── Install-PowerShell-Admin.ps1  - PowerShell 7
│   ├── Install-NodeJS-Admin.ps1      - Node.js LTS
│   ├── Install-WSL2-Admin.ps1        - Windows Subsystem for Linux 2
│   ├── Install-Docker-Admin.ps1      - Docker Desktop
│   ├── Install-Ngrok-Admin.ps1       - Ngrok tunneling tool
│   ├── Install-CursorAgent-Admin.ps1 - Cursor Agent CLI (in WSL2)
│   ├── Install-Python.ps1            - Python with pyenv-win (no admin)
│   ├── Setup-Git.ps1                 - Configure Git from .env (no admin)
│   ├── Setup-NodeJS.ps1              - Configure npm (no admin)
│   ├── Setup-Ngrok.ps1               - Configure Ngrok authtoken from .env (no admin)
│   ├── Install-NodePackages.ps1      - Global npm packages (no admin)
│   └── Install-PythonPackages.ps1    - Python packages (no admin)
│
└── shared/windows/        Reserved for future shared utilities
```

## Available Scripts

### Admin Scripts (Require UAC)

These scripts automatically request admin privileges when needed:

| Script | Purpose | Parameters |
|--------|---------|------------|
| `Install-Winget-Admin.ps1` | Windows Package Manager | `-Upgrade`, `-Force` |
| `Install-Git-Admin.ps1` | Git for Windows | `-Upgrade`, `-Force` |
| `Install-PowerShell-Admin.ps1` | PowerShell 7 | `-Upgrade`, `-Force` |
| `Install-NodeJS-Admin.ps1` | Node.js LTS | `-Upgrade`, `-Force`, `-Version` |
| `Install-WSL2-Admin.ps1` | Windows Subsystem for Linux 2 | `-Upgrade`, `-Force`, `-Distro` |
| `Install-Docker-Admin.ps1` | Docker Desktop | `-Upgrade`, `-Force` |
| `Install-Ngrok-Admin.ps1` | Ngrok tunneling tool | `-Upgrade`, `-Force` |
| `Install-CursorAgent-Admin.ps1` | Cursor Agent CLI (in WSL2) | `-Upgrade`, `-Force`, `-Distro` |

### User Scripts (No Admin Required)

These scripts run with normal user permissions:

| Script | Purpose | Parameters |
|--------|---------|------------|
| `Install-Python.ps1` | Python with pyenv-win | `-Upgrade`, `-Force`, `-PythonVersion` |
| `Setup-Git.ps1` | Configure Git user.name/email from .env | `-Upgrade`, `-Force`, `-UserName`, `-UserEmail` |
| `Setup-NodeJS.ps1` | Configure npm prefix | `-Upgrade` |
| `Setup-Ngrok.ps1` | Configure Ngrok authtoken from .env | `-Upgrade`, `-Force`, `-AuthToken` |
| `Install-NodePackages.ps1` | Global npm packages | `-Upgrade`, `-Force` |
| `Install-PythonPackages.ps1` | Python development packages | `-Upgrade`, `-Force` |

### Quick Scripts

| Script | Purpose |
|--------|---------|
| `Bootstrap.ps1` | Interactive full setup with choices |
| `Quick-Install.ps1` | Quick mode: Install essential dev tools |
| `Quick-Upgrade.ps1` | Quick mode: Upgrade all tools |
| `Quick-Reinstall.ps1` | Quick mode: Force reinstall everything |
| `Full-Install.ps1` | Full mode: Install complete environment (Quick + WSL2/Docker/Ngrok/Cursor Agent) |
| `Full-Upgrade.ps1` | Full mode: Upgrade everything |
| `Full-Reinstall.ps1` | Full mode: Force reinstall everything |

## Recent Improvements (2025-10-30)

### Full Installation Suite
- **Full Mode Scripts**: Complete environment setup including WSL2, Docker Desktop, Ngrok, Cursor Agent CLI
- **WSL2 Integration**: Automated Windows Subsystem for Linux 2 installation with Ubuntu
- **Docker Desktop**: Full Docker Desktop installation with automatic instance handling
- **Ngrok Support**: Tunneling tool installation with authtoken configuration
- **Cursor Agent CLI**: AI coding agent installation in WSL2 with curl dependency auto-install and SSL fallback

### Configuration Management
- **Setup-Git.ps1**: Automated Git configuration from .env file (user.name and user.email)
- **Setup-Ngrok.ps1**: Automated Ngrok authtoken setup from .env file
- **.env.example Cleanup**: Removed unused variables, empty defaults with examples in comments
- **Consistent Behavior**: All Setup scripts follow Install/Upgrade/Force parameter logic

### Enhanced Installation Checking
- **Check-Installation.ps1**: Now supports `-Full` parameter to verify all tools in Full mode
- **Quick Mode**: Checks essential dev tools only (Git, Node.js, Python, PowerShell)
- **Full Mode**: Additionally checks WSL2, Docker, Ngrok, and Cursor Agent CLI

### Earlier Improvements (2025-10)
- **Smart Upgrade Detection**: Recognizes winget exit code `-1978335189` as "already up-to-date"
- **No Redundant Downloads**: Skips downloads when packages are already latest version
- **Fallback Support**: Version detection for Git, PowerShell, Winget, NodeJS
- **UTF-8 BOM Support**: All scripts properly encoded for Chinese character support
- **Progress Feedback**: Download progress bars for better user experience

## Integration with Other Projects

This repository is designed to be integrated via **Git Subtree**.

### Adding to Your Project

```bash
# Add as subtree
git subtree add --prefix=scripts/bootstrap \
  https://github.com/sammykenny2/environment-bootstrap.git main --squash

# Update from upstream
git subtree pull --prefix=scripts/bootstrap \
  https://github.com/sammykenny2/environment-bootstrap.git main --squash

# Push improvements back
git subtree push --prefix=scripts/bootstrap \
  https://github.com/sammykenny2/environment-bootstrap.git main
```

### Usage After Integration

```powershell
# Your project structure
your-project/
├── scripts/
│   └── bootstrap/     ← This repository via subtree
└── ...

# Run from your project
.\scripts\bootstrap\Bootstrap.bat
.\scripts\bootstrap\Quick-Install.ps1
```

## Installed Tools

### Quick Mode (Essential Development Tools)
- **winget**: Windows Package Manager (foundation for all tools)
- **Git**: Version control with Git for Windows
- **PowerShell 7**: Modern PowerShell (optional)
- **Node.js**: JavaScript runtime with npm
- **Python**: Python with pyenv-win for version management

### Full Mode (Additional Tools)
All Quick Mode tools plus:
- **WSL2**: Windows Subsystem for Linux 2 with Ubuntu
- **Docker Desktop**: Complete Docker environment with WSL2 backend
- **Ngrok**: Secure tunneling to localhost
- **Cursor Agent CLI**: AI coding agent (installed in WSL2)

### Development Packages

**Node.js Global Packages** (configured in `Install-NodePackages.ps1`):
```powershell
# Example packages (uncomment to use)
# "@anthropic-ai/claude-code"
# "@google/gemini-cli"
```

**Python Packages** (configured in `Install-PythonPackages.ps1`):
```powershell
# Example packages (uncomment to use)
# "black"      - Code formatter
# "pylint"     - Linter
# "pytest"     - Testing framework
# "ipython"    - Enhanced REPL
```

## Parameters Reference

### Common Parameters

All install scripts support these parameters:

- `-Upgrade`: Upgrade to latest version (skips if already latest)
- `-Force`: Force reinstall even if already installed
- `-NonInteractive`: Run without user prompts (for automation)
- `-AllowAdmin`: Allow execution with admin privileges (for Administrator accounts)

### Configuration File

Create `.env` file from `.env.example` for automatic configuration:

```bash
# Copy and edit
cp .env.example .env

# Configure Git
GIT_USER_NAME=Your Name
GIT_USER_EMAIL=your.email@example.com

# Configure Ngrok (optional, for Full mode)
NGROK_AUTHTOKEN=your_token_here
```

### Examples

```powershell
# Install Python 3.12 specifically
.\platform\windows\Install-Python.ps1 -PythonVersion "3.12.0"

# Upgrade Node.js to latest LTS
.\platform\windows\Install-NodeJS-Admin.ps1 -Upgrade

# Force reinstall Git
.\platform\windows\Install-Git-Admin.ps1 -Force

# Setup Git configuration from .env
.\platform\windows\Setup-Git.ps1

# Setup Ngrok authtoken from .env
.\platform\windows\Setup-Ngrok.ps1 -Force

# Install WSL2 with specific distribution
.\platform\windows\Install-WSL2-Admin.ps1 -Distro "Ubuntu-22.04"

# Automated full upgrade (no prompts)
.\Full-Upgrade.ps1
```

## Troubleshooting

### PowerShell Execution Policy Error

If you see "cannot be loaded because running scripts is disabled":

1. **Use Bootstrap.bat** (automatically handles this)
2. Or manually set policy:
   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
   ```

### UTF-8 Encoding Issues

If you see parser errors with Chinese characters:
- All scripts now have UTF-8 BOM (fixed in version 2025-10)
- Update to latest version via git subtree pull

### Winget Not Found

If winget commands fail:
1. Install from Microsoft Store: "App Installer"
2. Or run `.\platform\windows\Install-Winget-Admin.ps1`
3. Restart PowerShell after installation

### Python/Node.js Not in PATH

Close and reopen PowerShell to refresh environment variables.

## Contributing

Contributions are welcome! This repository aims to be a universal environment setup tool.

### Guidelines

1. **Test on clean systems** before submitting
2. **Add UTF-8 BOM** to all PowerShell scripts
3. **Use consistent naming**: `Install-*-Admin.ps1` for admin scripts, `Install-*.ps1` for user scripts
4. **Support NonInteractive mode** for automation
5. **Document changes** in this README

### Code Style

```powershell
# Good: Descriptive messages
Write-Host "檢查 $package..." -ForegroundColor Gray
Write-Host "   ✓ 已安裝，跳過" -ForegroundColor DarkGray

# Bad: Misleading messages
Write-Host "安裝 $package..." # When actually just checking
```

## License

MIT License - see [LICENSE](LICENSE) file for details

## Roadmap

- [x] Windows environment bootstrap
- [x] Smart upgrade detection (winget exit codes)
- [x] UTF-8 BOM support for Chinese characters
- [x] Download progress bars
- [x] Docker Desktop installation
- [x] WSL2 integration
- [x] Git configuration automation
- [x] Ngrok setup automation
- [x] Cursor Agent CLI support
- [ ] macOS support
- [ ] Linux support (Ubuntu, Fedora)
- [ ] IDE setup automation (VS Code)
- [ ] Multiple Git profile management

## Support

For issues or feature requests, please open an issue on GitHub.

---

**Last Updated**: 2025-10-30
**Version**: 1.2.0 (feature/add-utility-scripts)
