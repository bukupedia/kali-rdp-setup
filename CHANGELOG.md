# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v1.0.0] - 2026-05-05

### Added
- Initial release of Kali Linux RDP Desktop Setup script

### Features
- **LXDE Desktop**: Lightweight X11 Desktop Environment for low RAM usage
- **xrdp Integration**: 
  - Automatic start on boot via systemd
  - Configured to prevent black screen issues
  - Listens on port 3389
  - Supports existing non-root users (auto-detection)
- **User Session Configuration**:
  - `.xsession` file creation for session startup
  - Polkit configuration for passwordless authentication
  - PAM integration
- **System Optimization**:
  - Disabled services: bluetooth, cups, snapd, apache2, nginx, mariadb, mysql, postgresql
  - Swappiness optimization (set to 10)
  - Memory cache dropping
- **Pre-installed Applications**:
  - wget - Download utility
  - git - Version control
  - openssh-client - SSH client
  - openssh-server - SSH server
  - nano - Text editor
  - synaptic - GUI package manager

### Robustness
- `set -e` for strict error handling
- Idempotent design (safe to run multiple times)
- Extensive logging to `/var/log/rdp-setup.log`
- User validation (checks for valid login shell)
- Fallback handling for package failures

### Documentation
- Inline comments throughout script
- README with usage instructions
- This changelog

### Technical Details
- **Script Size**: 403 lines
- **Minimum Requirements**: 
  - Kali Linux 2025 / Debian-based
  - 2 CPU cores
  - 2 GB RAM
  - 20 GB storage
  - Non-root user with valid login shell