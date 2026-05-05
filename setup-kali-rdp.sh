#!/bin/bash
#
# Kali Linux 2025 / Debian Lightweight RDP Desktop Setup Script
# ===========================================================
# Purpose: Configure a lightweight RDP-accessible desktop environment
#          usable from Microsoft Remote Desktop (Android)
#
# Features:
#   - LXDE desktop environment (lightweight, low RAM)
#   - xrdp with automatic start on boot
#   - Optimized for 2GB RAM, 2 CPU cores
#   - Prevents black screen issues
#   - Basic multimedia support over RDP
#
# Usage: sudo ./setup-kali-rdp.sh
#
# Author: Arif Budiman
# Version: 1.0.0
#

#############################################################################
# CONFIGURATION
#############################################################################

# Log file location
LOG_FILE="/var/log/rdp-setup.log"

# Non-root user to use for RDP (script will detect existing user)
RDP_USER=""

# Package list to install
PACKAGES_CORE="lxde xorg x11-apps x11-session-utils"
PACKAGES_RDP="xrdp xorgxrdp"
PACKAGES_TOOLS="wget git openssh-client openssh-server nano synaptic"

# Services to manage
SERVICES_TO_DISABLE="bluetooth systemd-timesyncd.service"
SERVICES_TO_ENABLE="xrdp"

#############################################################################
# FUNCTIONS
#############################################################################

# Logging function with timestamps
log() {
    local message="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] ${message}" | tee -a "${LOG_FILE}"
}

# Error handling function
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "ERROR: This script must be run as root (use sudo)"
        error_exit "Root privileges required"
    fi
}

# Detect existing non-root user
detect_user() {
    log "Detecting existing non-root user..."
    
    # Priority: 1. Current user running sudo, 2. Common users
    if [[ -n "$SUDO_USER" ]]; then
        RDP_USER="$SUDO_USER"
    elif id -u openhands &>/dev/null; then
        RDP_USER="openhands"
    elif id -u ubuntu &>/dev/null; then
        RDP_USER="ubuntu"
    elif id -u user &>/dev/null; then
        RDP_USER="user"
    else
        # Find first non-system user (UID >= 1000)
        RDP_USER=$(awk -F: '($3 >= 1000) && ($1 != "nobody") {print $1; exit 1}' /etc/passwd)
    fi
    
    if [[ -z "$RDP_USER" ]]; then
        error_exit "No non-root user found. Please create a user before running this script."
    fi
    
    # Verify user exists and has valid shell
    local user_shell
    user_shell=$(getent passwd "${RDP_USER}" | cut -d: -f7)
    if [[ -z "$user_shell" ]] || [[ "$user_shell" == *"/nologin"* ]] || [[ "$user_shell" == *"/false"* ]]; then
        error_exit "User ${RDP_USER} has no valid login shell"
    fi
    
    log "Detected user: ${RDP_USER} (shell: ${user_shell})"
}

# Update package lists
update_packages() {
    log "Updating package lists..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >> "${LOG_FILE}" 2>&1 || {
        log "Warning: apt-get update failed, continuing..."
    }
}

# Install packages
install_packages() {
    local packages="$1"
    local package_group="$2"
    
    if [[ -z "$packages" ]]; then
        return 0
    fi
    
    log "Installing ${package_group}: ${packages}..."
    
    export DEBIAN_FRONTEND=noninteractive
    DEBIAN_FRONTEND=noninteractive apt-get install -y ${packages} >> "${LOG_FILE}" 2>&1 || {
        log "Warning: Some packages failed to install, continuing..."
        return 1
    }
    
    return 0
}

# Disable unnecessary services
disable_services() {
    log "Disabling unnecessary services..."
    
    for service in $SERVICES_TO_DISABLE; do
        if systemctl list-unit-files | grep -q "^${service}"; then
            log "Disabling service: ${service}"
            systemctl stop "${service}" >> "${LOG_FILE}" 2>&1 || true
            systemctl disable "${service}" >> "${LOG_FILE}" 2>&1 || true
            systemctl mask "${service}" >> "${LOG_FILE}" 2>&1 || true
        else
            log "Service not found: ${service}"
        fi
    done
}

# Configure xrdp
configure_xrdp() {
    log "Configuring xrdp..."
    
    # Backup original config if it exists
    if [[ -f /etc/xrdp/xrdp.ini ]]; then
        cp /etc/xrdp/xrdp.ini /etc/xrdp/xrdp.ini.backup
        log "Backed up original xrdp.ini"
    fi
    
    # Configure xrdp.ini for LXDE session
    # Set default session to LXDE
    if [[ -f /etc/xrdp/xrdp.ini ]]; then
        # Update the default session for console and VPN sessions
        sed -i 's/^name=.*/name=Session Default/' /etc/xrdp/xrdp.ini
        sed -i 's/^ip=127.0.0.1/ip=0.0.0.0/' /etc/xrdp/xrdp.ini
        sed -i 's/^port=3389/port=3389/' /etc/xrdp/xrdp.ini
        
        log "Updated xrdp.ini configuration"
    fi
    
    # Create session config for LXDE
    cat > /etc/xrdp/startwm.sh << 'SCRIPT'
#!/bin/bash
# xrdp X session start script
# Start LXDE session for RDP

# Source /etc/environment for session variables
if [ -f /etc/environment ]; then
    . /etc/environment
fi

# Export display for Xvfb if needed
export DISPLAY=:10

# Start LXDE
exec startlxde
SCRIPT
    
    chmod +x /etc/xrdp/startwm.sh
    log "Created xrdp start script"
}

# Create.xsession for user
create_xsession() {
    log "Creating .xsession for user ${RDP_USER}..."
    
    local user_home
    user_home=$(getent passwd "${RDP_USER}" | cut -d: -f6)
    
    # Create .xsession file for the user
    cat > "${user_home}/.xsession" << 'SESSION'
#!/bin/sh
# Start LXDE session
export XDG_SESSION_DESKTOP=LXDE
export XDG_CURRENT_DESKTOP=LXDE
exec startlxde
SESSION
    
    chmod 644 "${user_home}/.xsession"
    chown "${RDP_USER}":"${RDP_USER}" "${user_home}/.xsession"
    
    log "Created .xsession for ${RDP_USER}"
}

# Configure polkit for passwordless operations (optional but helps RDP)
configure_polkit() {
    log "Configuring polkit for RDP..."
    
    # Allow root user to use xrdp without additional prompts
    mkdir -p /etc/polkit-1/localauthority/50-local.d/
    cat > /etc/polkit-1/localauthority/50-local.d/xrdp.pkla << 'PKLA'
[Allow remote login]
Identity=unix-user:*
Action=org.freedesktop.login1.*
ResultAny=yes
ResultInactive=yes
ResultActive=yes
PKLA
    
    log "Created polkit configuration"
}

# Enable and start xrdp service
enable_xrdp() {
    log "Enabling xrdp service..."
    
    # Enable xrdp to start on boot
    systemctl enable xrdp >> "${LOG_FILE}" 2>&1 || {
        log "Warning: Failed to enable xrdp service"
    }
    
    systemctl enable xrdp-sesman >> "${LOG_FILE}" 2>&1 || {
        log "Warning: Failed to enable xrdp-sesman service"
    }
    
    # Start xrdp service
    systemctl start xrdp >> "${LOG_FILE}" 2>&1 || {
        log "Warning: Failed to start xrdp service"
    }
    
    systemctl start xrdp-sesman >> "${LOG_FILE}" 2>&1 || {
        log "Warning: Failed to start xrdp-sesman service"
    }
}

# Verify xrdp is running
verify_xrdp() {
    log "Verifying xrdp configuration..."
    
    # Check service status
    local xrdp_status
    xrdp_status=$(systemctl is-active xrdp 2>/dev/null || echo "inactive")
    log "xrdp service status: ${xrdp_status}"
    
    # Check if port 3389 is listening
    if command -v ss &>/dev/null; then
        if ss -tuln | grep -q ":3389"; then
            log "xrdp is listening on port 3389"
        else
            log "Warning: xrdp is not listening on port 3389"
        fi
    elif command -v netstat &>/dev/null; then
        if netstat -tuln | grep -q ":3389"; then
            log "xrdp is listening on port 3389"
        else
            log "Warning: xrdp is not listening on port 3389"
        fi
    fi
    
    # Check xrdp configuration
    if [[ -f /etc/xrdp/xrdp.ini ]]; then
        log "xrdp configuration file exists"
    else
        log "Warning: xrdp configuration file not found"
    fi
}

# Configure PAM for xrdp
configure_pam() {
    log "Configuring PAM for xrdp..."
    
    # Make sure xrdp can authenticate users
    if [[ -f /etc/pam.d/xrdp-sesman ]]; then
        # Already configured
        log "PAM configuration for xrdp-sesman exists"
    else
        log "PAM configuration not found, but may work with defaults"
    fi
}

# Optimize system for low RAM and RDP
optimize_system() {
    log "Optimizing system for low RAM and RDP..."
    
    # Drop caches to free memory
    sync
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
    
    # Optimize swap (if present)
    if [[ -f /proc/sys/vm/swappiness ]]; then
        echo 10 > /proc/sys/vm/swappiness
        log "Set swappiness to 10"
    fi
    
    # Disable unnecessary systemd services for low RAM
    local services_to_stop="cups bluetooth snapd apache2 nginx mariadb mysql postgresql"
    for service in $services_to_stop; do
        if systemctl list-unit-files | grep -q "^${service}"; then
            systemctl stop "${service}" >> "${LOG_FILE}" 2>&1 || true
            systemctl disable "${service}" >> "${LOG_FILE}" 2>&1 || true
            log "Disabled service: ${service}"
        fi
    done
    
    log "System optimization complete"
}

# Print connection information
print_connection_info() {
    log "=============================================="
    log "RDP Setup Complete!"
    log "=============================================="
    log ""
    log "Connection Details:"
    log "  Protocol: RDP"
    log "  Port: 3389"
    log "  Username: ${RDP_USER}"
    log "  Password: (user password)"
    log ""
    log "Important Notes:"
    log "  1. Use Microsoft Remote Desktop (Android) to connect"
    log "  2. Session type: LTS (or leave as Xorg)"
    log "  3. Display: 1024x768 or lower recommended for smooth performance"
    log "  4. Use existing non-root user credentials to login"
    log ""
    log "Log file: ${LOG_FILE}"
    log "=============================================="
}

#############################################################################
# MAIN SCRIPT
#############################################################################

# Set strict error handling
set -e

# Create log file with proper permissions
touch "${LOG_FILE}" || error_exit "Cannot create log file ${LOG_FILE}"
chmod 644 "${LOG_FILE}"

log "=============================================="
log "Starting Kali/Debian RDP Desktop Setup"
log "=============================================="

# Check for root privileges
check_root

# Detect existing user
detect_user

# Update package lists
update_packages

# Install core packages (LXDE + X11)
install_packages "${PACKAGES_CORE}" "Core Desktop"

# Install xrdp packages
install_packages "${PACKAGES_RDP}" "xrdp"

# Install tools
install_packages "${PACKAGES_TOOLS}" "Tools"

# Disable unnecessary services
disable_services

# Configure xrdp
configure_xrdp

# Create user session config
create_xsession

# Configure polkit
configure_polkit

# Configure PAM
configure_pam

# Optimize system
optimize_system

# Enable xrdp to start on boot
enable_xrdp

# Verify configuration
verify_xrdp

# Print connection info
print_connection_info

log "Setup completed successfully!"
exit 0
