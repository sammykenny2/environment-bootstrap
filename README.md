# Environment Bootstrap

🚀 Zero-to-hero automation scripts for setting up development and deployment environments.

## Features

- 🐳 **Container-first**: Docker and Docker Compose support
- 💻 **Multi-platform**: Windows, macOS, and Linux
- ⚡ **Flexible**: Bare-metal deployment support for legacy systems
- 🔧 **Modular**: Pick only what you need

## Quick Start

### Windows

```powershell
# Container-based deployment (recommended)
.\Quick-Setup.ps1 -DeploymentMode container

# Bare-metal deployment (legacy)
.\Quick-Setup.ps1 -DeploymentMode baremetal

# Hybrid mode (both)
.\Quick-Setup.ps1 -DeploymentMode hybrid
```

### macOS/Linux

```bash
# Coming soon
./quick-setup.sh --mode container
```

## Directory Structure

```
environment-bootstrap/
├── platform/          Platform tools (Docker, Git, IDE, etc.)
│   ├── windows/           - Windows platform setup scripts
│   ├── macos/             - macOS platform setup scripts (planned)
│   └── linux/             - Linux platform setup scripts (planned)
│
├── containers/        Container definitions (recommended deployment)
│   ├── base/              - Base container images
│   └── n8n/               - Example: n8n containers
│
├── baremetal/         Traditional installation (legacy support)
│   ├── dev/               - Development tools
│   │   └── windows/
│   └── runtime/           - Runtime dependencies
│       └── windows/
│
├── shared/            Shared utilities across all modes
│   └── windows/
│
├── Quick-Setup.ps1    Main entry point (Windows)
└── .env.example       Environment variable template
```

## Available Scripts

### Platform Tools (platform/windows/)

| Script | Purpose |
|--------|---------|
| `Install-NodeJS-Environment.ps1` | Install Node.js with version manager (volta/nvm) |
| `Install-Pyenv-Environment.ps1` | Install Python with pyenv-win |

### Shared Utilities (shared/windows/)

| Script | Purpose |
|--------|---------|
| `Check-Environment.ps1` | Verify environment setup |

## Integration with Other Projects

This repository is designed to be integrated into other projects via **Git Subtree**.

### Adding to Your Project

```bash
# Add as subtree to your project
git subtree add --prefix=scripts/setup \
  https://github.com/sammykenny2/environment-bootstrap.git main --squash

# Update from upstream
git subtree pull --prefix=scripts/setup \
  https://github.com/sammykenny2/environment-bootstrap.git main --squash

# Push improvements back
git subtree push --prefix=scripts/setup \
  https://github.com/sammykenny2/environment-bootstrap.git main
```

### Usage After Integration

```powershell
# Your project structure
your-project/
├── scripts/
│   └── setup/         ← This repository via subtree
└── ...

# Run setup from your project
.\scripts\setup\Quick-Setup.ps1 -DeploymentMode container
```

## Deployment Modes

### Container Mode (Recommended)

Installs Docker Desktop and uses containerized deployments.

**Pros:**
- ✅ Isolated environments
- ✅ Reproducible builds
- ✅ Easy to scale
- ✅ Platform-independent

**Use when:**
- Starting new projects
- Need environment isolation
- Deploying to cloud/Kubernetes

### Bare-metal Mode (Legacy)

Installs runtime dependencies directly on the host machine.

**Pros:**
- ✅ Direct access to system resources
- ✅ Simpler debugging
- ✅ No containerization overhead

**Use when:**
- Working with legacy systems
- Need direct hardware access
- Container overhead is unacceptable

### Hybrid Mode

Installs both Docker and bare-metal runtimes.

**Use when:**
- Transitioning from bare-metal to containers
- Need flexibility during development

## Environment Variables

Copy `.env.example` to `.env` and customize:

```bash
# Platform versions
NODE_VERSION=20.x
PYTHON_VERSION=3.11

# Deployment mode
DEPLOYMENT_MODE=container

# Docker settings (if using containers)
DOCKER_COMPOSE_VERSION=2.x
```

## Contributing

Contributions are welcome! This repository aims to be a universal environment setup tool.

### Guidelines

1. Keep scripts **platform-agnostic** where possible
2. Avoid project-specific logic (this is for generic environments)
3. Test on clean systems before submitting
4. Document any new scripts in this README

## License

MIT License - see [LICENSE](LICENSE) file for details

## Roadmap

- [ ] macOS support
- [ ] Linux support (Ubuntu, Fedora, Arch)
- [ ] Docker Desktop installation scripts
- [ ] IDE setup automation (VS Code, JetBrains)
- [ ] Git configuration templates
- [ ] CI/CD integration examples
- [ ] Kubernetes development environment support

## Support

For issues or feature requests, please open an issue on GitHub.
