# Kali Linux RDP Desktop Setup

Bash script to configure Kali Linux 2025 (or Debian-based systems) as a lightweight RDP-accessible desktop environment.

## Overview

This script configures a Kali Linux cloud VM with:
- **LXDE Desktop Environment** - Lightweight, RAM-optimized
- **xrdp Remote Desktop** - Start on boot
- **Essential Tools** - wget, git, SSH, nano, synaptic
- **System Optimization** - Disabled unnecessary services for low RAM

## System Requirements

- OS: Kali Linux 2025 or Debian-based (apt package manager)
- CPU: 2 cores (Intel)
- RAM: 2 GB
- Storage: 20 GB
- User: Non-root user with valid login shell (must exist)

## Supported RDP Clients

- Microsoft Remote Desktop (Windows/macOS)
- Microsoft Remote Desktop (Android)
- Remmina (Linux)
- Any standard RDP client

## Quick Start

```bash
# Download or copy the script
sudo chmod +x setup-kali-rdp.sh
sudo ./setup-kali-rdp.sh
```

## Connection Details

After running the script:

| Parameter | Value |
|-----------|-------|
| Protocol | RDP |
| Port | 3389 |
| Username | Existing non-root user (auto-detected) |
| Password | User's password |
| Session | Xorg or LTS |

## Features

### Desktop Environment
- LXDE (Lightweight X11 Desktop Environment)
- X11 session utilities
- Basic multimedia codecs via RDP

### Remote Desktop
- xrdp with xorgxrdp
- Automatic start on boot (systemd)
- Persistent sessions across reboots
- Prevents black screen issues

### Pre-installed Applications
- wget - Download utility
- git - Version control
- openssh-client - SSH client
- openssh-server - SSH server
- nano - Text editor
- synaptic - GUI package manager

### System Optimization
- Disabled: bluetooth, cups, snapd, apache2, nginx, mariadb, mysql, postgresql
- Swappiness optimized to 10
- Memory cache dropping
- Minimal RAM footprint (~300-400MB with desktop)

## Troubleshooting

### Black Screen After Login
If you see a black screen after connecting via RDP:
1. Check that `.xsession` exists in user's home directory
2. Verify `startwm.sh` is executable: `ls -la /etc/xrdp/startwm.sh`
3. Try session type "Xorg" instead of "LTS"

### Cannot Connect
1. Verify xrdp is running: `systemctl status xrdp`
2. Check port 3389 is open: `ss -tuln | grep 3389`
3. Check firewall: `ufw status` or `iptables -L`

### Authentication Fails
1. Verify user has valid shell: `getent passwd username`
2. Check user can login locally
3. Verify polkit is configured: `ls /etc/polkit-1/localauthority/50-local.d/`

### High RAM Usage
1. Check running services: `systemctl list-units --type=service --state=running`
2. Disable unnecessary services
3. Reduce swappiness: `sysctl vm.swappiness=10`

## Log Files

All actions are logged to:
- `/var/log/rdp-setup.log`

## Version History

See [CHANGELOG.md](CHANGELOG.md) for version history.

## License

MIT License
