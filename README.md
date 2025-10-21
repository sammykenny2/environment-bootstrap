# Environment Bootstrap

🚀 Automated development environment setup for Windows with zero-friction installation.

## Features

- 🎯 **One-Click Setup**: Bootstrap.bat for instant environment setup
- 🔄 **Smart Upgrade**: Detects already-installed packages to avoid redundant downloads
- 🌐 **Multi-Platform Tools**: Node.js, Python, Git, PowerShell 7, and more
- ⚡ **Fast & Efficient**: Download progress bars and intelligent caching
- 🔒 **User-Friendly**: Automatic admin elevation when needed
- 🛡️ **Safe Defaults**: User-scoped installations to avoid permission issues

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

# Check environment
.\shared\windows\Check-Environment.ps1
```

## Directory Structure

```
environment-bootstrap/
├── Bootstrap.ps1          Main bootstrap script (PowerShell)
├── Bootstrap.bat          Launcher with execution policy handling
├── Quick-Install.ps1      One-command full installation
├── Quick-Upgrade.ps1      Upgrade all installed tools
├── Quick-Reinstall.ps1    Force reinstall everything
│
├── platform/windows/      Platform tools with admin privileges
│   ├── Install-Winget-Admin.ps1      - Windows Package Manager
│   ├── Install-Git-Admin.ps1         - Git for Windows
│   ├── Install-PowerShell-Admin.ps1  - PowerShell 7
│   ├── Install-NodeJS-Admin.ps1      - Node.js LTS
│   ├── Install-Python.ps1            - Python with pyenv-win (no admin)
│   ├── Setup-NodeJS.ps1              - Configure npm (no admin)
│   ├── Install-NodePackages.ps1      - Global npm packages (no admin)
│   └── Install-PythonPackages.ps1    - Python packages (no admin)
│
└── shared/windows/        Shared utilities
    └── Check-Environment.ps1         - Verify installation
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

### User Scripts (No Admin Required)

These scripts run with normal user permissions:

| Script | Purpose | Parameters |
|--------|---------|------------|
| `Install-Python.ps1` | Python with pyenv-win | `-Upgrade`, `-Force`, `-PythonVersion` |
| `Setup-NodeJS.ps1` | Configure npm prefix | `-Upgrade` |
| `Install-NodePackages.ps1` | Global npm packages | `-Upgrade`, `-Force` |
| `Install-PythonPackages.ps1` | Python development packages | `-Upgrade`, `-Force` |

### Quick Scripts

| Script | Purpose |
|--------|---------|
| `Bootstrap.ps1` | Interactive full setup with choices |
| `Quick-Install.ps1` | Non-interactive full installation |
| `Quick-Upgrade.ps1` | Upgrade all tools to latest versions |
| `Quick-Reinstall.ps1` | Force reinstall everything |

## Recent Improvements (2025-10)

### Smart Upgrade Detection
- **Exit Code Recognition**: Correctly identifies winget exit code `-1978335189` as "already up-to-date"
- **No Redundant Downloads**: Skips downloads when packages are already latest version
- **Progress Feedback**: Download progress bars for better user experience

### Install-Python.ps1 Critical Fixes
- **Upgrade Mode Fix**: No longer reinstalls pyenv-win on every upgrade
- **Version Preservation**: Python installations are preserved during upgrades
- **Accurate Messaging**: "Checking" vs "Upgrading" based on actual operation

### UTF-8 BOM Support
- All PowerShell scripts now have UTF-8 BOM for Windows PowerShell compatibility
- Prevents Chinese character corruption and parser errors

### User Experience
- More accurate status messages ("Checking/Processing" instead of "Installing")
- Better version number extraction with robust regex matching
- Clearer operation feedback (install/upgrade/skip)

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

### Core Platform Tools
- **winget**: Windows Package Manager (foundation for all tools)
- **Git**: Version control with Git for Windows
- **PowerShell 7**: Modern PowerShell (optional)
- **Node.js**: JavaScript runtime with npm
- **Python**: Python with pyenv-win for version management

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

### Examples

```powershell
# Install Python 3.12 specifically
.\platform\windows\Install-Python.ps1 -PythonVersion "3.12.0"

# Upgrade Node.js to latest LTS
.\platform\windows\Install-NodeJS-Admin.ps1 -Upgrade

# Force reinstall Git
.\platform\windows\Install-Git-Admin.ps1 -Force

# Automated upgrade (no prompts)
.\Quick-Upgrade.ps1
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
- [ ] macOS support
- [ ] Linux support (Ubuntu, Fedora)
- [ ] Docker Desktop installation
- [ ] IDE setup automation (VS Code)
- [ ] Git configuration templates

## Support

For issues or feature requests, please open an issue on GitHub.

---

**Last Updated**: 2025-10-22
**Version**: 1.1.0 (fix/polish-scripts)
