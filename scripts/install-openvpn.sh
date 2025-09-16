#!/usr/bin/env bash

# OpenVPN Installation Script for Debian/Ubuntu Systems
# This script automatically installs OpenVPN and sets up client configuration
# Compatible with Debian 10+, Ubuntu 18.04+, and other Debian-based distributions
#
# Author: Xenia Canary Project
# License: BSD (same as parent project)

set -euo pipefail

# Configuration variables
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/openvpn-install.log"
OPENVPN_CONFIG_DIR="/etc/openvpn"
OPENVPN_CLIENT_DIR="/etc/openvpn/client"
OPENVPN_BACKUP_DIR="/etc/openvpn/backup"
SYSTEMD_SERVICE="openvpn-client@"

# Color codes for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global variables
CUSTOM_CONFIG_PATH=""
VERBOSE=false
DRY_RUN=false

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" | sudo tee -a "$LOG_FILE" >/dev/null 2>&1 || true
    
    case "$level" in
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message" >&2
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message"
            ;;
        "INFO")
            echo -e "${GREEN}[INFO]${NC} $message"
            ;;
        "DEBUG")
            if [[ "$VERBOSE" == true ]]; then
                echo -e "${BLUE}[DEBUG]${NC} $message"
            fi
            ;;
        *)
            echo "$message"
            ;;
    esac
}

# Progress indicator function
show_progress() {
    local message="$1"
    echo -e "${CYAN}>>> $message${NC}"
}

# Error handling function
error_exit() {
    log "ERROR" "$1"
    exit 1
}

# Display usage information
usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

A comprehensive script to install OpenVPN on Debian/Ubuntu systems and set up client connections.

OPTIONS:
    -c, --config PATH       Specify custom OpenVPN configuration file path
    -v, --verbose          Enable verbose output
    -d, --dry-run          Show what would be done without making changes
    -h, --help             Display this help message

EXAMPLES:
    $SCRIPT_NAME                                    # Basic installation
    $SCRIPT_NAME --verbose                          # Installation with verbose output
    $SCRIPT_NAME --config /path/to/client.ovpn     # Install with custom config
    $SCRIPT_NAME --dry-run                          # Preview actions without changes

FEATURES:
    • System requirements verification
    • Automatic OpenVPN and dependency installation
    • Client configuration directory setup
    • Service management functions
    • Security hardening with proper permissions
    • Configuration backup and restore
    • Comprehensive logging and error handling

REQUIREMENTS:
    • Debian 10+ or Ubuntu 18.04+ (or compatible distribution)
    • Root privileges (sudo access)
    • Internet connectivity

For more information, visit: https://github.com/g91/xenia-canary
EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--config)
                CUSTOM_CONFIG_PATH="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                error_exit "Unknown option: $1. Use --help for usage information."
                ;;
        esac
    done
}

# Check if running as root or with sudo
check_privileges() {
    show_progress "Checking privileges..."
    
    if [[ $EUID -eq 0 ]]; then
        log "INFO" "Running as root user"
        return 0
    fi
    
    if ! command -v sudo >/dev/null 2>&1; then
        error_exit "This script requires root privileges. Please install sudo or run as root."
    fi
    
    if ! sudo -n true >/dev/null 2>&1; then
        log "WARN" "Sudo access required. You may be prompted for your password."
        if ! sudo true; then
            error_exit "Failed to obtain sudo privileges"
        fi
    fi
    
    log "INFO" "Sudo privileges confirmed"
}

# Detect the operating system
detect_os() {
    show_progress "Detecting operating system..."
    
    if [[ ! -f /etc/os-release ]]; then
        error_exit "Cannot detect operating system. /etc/os-release not found."
    fi
    
    # Source the os-release file
    . /etc/os-release
    
    log "DEBUG" "Detected OS: $NAME $VERSION"
    
    # Check if it's a Debian-based system
    case "$ID" in
        debian|ubuntu|linuxmint|pop|elementary)
            log "INFO" "Debian-based system detected: $PRETTY_NAME"
            ;;
        *)
            case "$ID_LIKE" in
                *debian*|*ubuntu*)
                    log "INFO" "Debian-compatible system detected: $PRETTY_NAME"
                    ;;
                *)
                    error_exit "Unsupported operating system: $PRETTY_NAME. This script supports Debian-based distributions only."
                    ;;
            esac
            ;;
    esac
    
    # Check version compatibility
    case "$ID" in
        debian)
            if [[ ${VERSION_ID%%.*} -lt 10 ]]; then
                error_exit "Debian version $VERSION_ID is not supported. Please use Debian 10 or later."
            fi
            ;;
        ubuntu)
            if [[ ${VERSION_ID%.*} -lt 18 ]] || [[ ${VERSION_ID%.*} -eq 18 && ${VERSION_ID#*.} -lt 04 ]]; then
                error_exit "Ubuntu version $VERSION_ID is not supported. Please use Ubuntu 18.04 or later."
            fi
            ;;
    esac
}

# Check internet connectivity
check_internet() {
    show_progress "Checking internet connectivity..."
    
    local test_urls=("http://deb.debian.org" "http://archive.ubuntu.com" "https://www.google.com")
    
    for url in "${test_urls[@]}"; do
        if curl --connect-timeout 10 --max-time 15 -s --head "$url" >/dev/null 2>&1; then
            log "INFO" "Internet connectivity confirmed via $url"
            return 0
        fi
        log "DEBUG" "Failed to connect to $url"
    done
    
    error_exit "No internet connectivity detected. Please check your network connection."
}

# Update package repositories
update_repositories() {
    show_progress "Updating package repositories..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log "INFO" "[DRY RUN] Would update package repositories"
        return 0
    fi
    
    log "INFO" "Updating package lists..."
    if ! sudo apt-get update -qq; then
        error_exit "Failed to update package repositories"
    fi
    
    log "INFO" "Package repositories updated successfully"
}

# Install OpenVPN and dependencies
install_openvpn() {
    show_progress "Installing OpenVPN and dependencies..."
    
    local packages=(
        "openvpn"
        "easy-rsa"
        "openssl"
        "ca-certificates"
        "curl"
        "wget"
        "systemctl"
        "resolvconf"
        "network-manager-openvpn"
    )
    
    if [[ "$DRY_RUN" == true ]]; then
        log "INFO" "[DRY RUN] Would install packages: ${packages[*]}"
        return 0
    fi
    
    log "INFO" "Installing packages: ${packages[*]}"
    
    # Install packages, allowing some to fail (like network-manager-openvpn on server systems)
    local failed_packages=()
    for package in "${packages[@]}"; do
        if ! sudo apt-get install -y "$package" >/dev/null 2>&1; then
            failed_packages+=("$package")
            log "WARN" "Failed to install package: $package"
        else
            log "DEBUG" "Successfully installed: $package"
        fi
    done
    
    # Check if critical packages were installed
    if ! command -v openvpn >/dev/null 2>&1; then
        error_exit "OpenVPN installation failed"
    fi
    
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
        log "WARN" "Some non-critical packages failed to install: ${failed_packages[*]}"
    fi
    
    log "INFO" "OpenVPN installation completed successfully"
}

# Create necessary directories
create_directories() {
    show_progress "Creating OpenVPN directories..."
    
    local directories=(
        "$OPENVPN_CONFIG_DIR"
        "$OPENVPN_CLIENT_DIR"
        "$OPENVPN_BACKUP_DIR"
        "$OPENVPN_CONFIG_DIR/keys"
        "$OPENVPN_CONFIG_DIR/certs"
    )
    
    for dir in "${directories[@]}"; do
        if [[ "$DRY_RUN" == true ]]; then
            log "INFO" "[DRY RUN] Would create directory: $dir"
            continue
        fi
        
        if [[ ! -d "$dir" ]]; then
            sudo mkdir -p "$dir"
            log "DEBUG" "Created directory: $dir"
        else
            log "DEBUG" "Directory already exists: $dir"
        fi
    done
    
    log "INFO" "Directory structure created"
}

# Set proper permissions
set_permissions() {
    show_progress "Setting directory permissions..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log "INFO" "[DRY RUN] Would set secure permissions on OpenVPN directories"
        return 0
    fi
    
    # Set restrictive permissions for security
    sudo chmod 700 "$OPENVPN_CONFIG_DIR"
    sudo chmod 700 "$OPENVPN_CLIENT_DIR"
    sudo chmod 700 "$OPENVPN_BACKUP_DIR"
    sudo chmod 700 "$OPENVPN_CONFIG_DIR/keys"
    sudo chmod 700 "$OPENVPN_CONFIG_DIR/certs"
    
    # Set ownership to root
    sudo chown -R root:root "$OPENVPN_CONFIG_DIR"
    
    log "INFO" "Secure permissions applied"
}

# Create backup of existing configurations
backup_existing_config() {
    show_progress "Backing up existing configurations..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log "INFO" "[DRY RUN] Would backup existing configurations"
        return 0
    fi
    
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_file="$OPENVPN_BACKUP_DIR/config_backup_$timestamp.tar.gz"
    
    if [[ -d "$OPENVPN_CONFIG_DIR" ]] && [[ "$(ls -A "$OPENVPN_CONFIG_DIR" 2>/dev/null)" ]]; then
        sudo tar -czf "$backup_file" -C "$OPENVPN_CONFIG_DIR" . 2>/dev/null || true
        log "INFO" "Configuration backup created: $backup_file"
    else
        log "DEBUG" "No existing configuration to backup"
    fi
}

# Create example client configuration
create_example_config() {
    show_progress "Creating example client configuration..."
    
    local example_config="$OPENVPN_CLIENT_DIR/example-client.conf"
    
    if [[ "$DRY_RUN" == true ]]; then
        log "INFO" "[DRY RUN] Would create example configuration: $example_config"
        return 0
    fi
    
    sudo tee "$example_config" >/dev/null << 'EOF'
# OpenVPN Client Configuration Example
# Copy this file and modify for your VPN server
#
# Usage: 
#   1. Copy this file to a new name (e.g., myvpn.conf)
#   2. Update the server settings below
#   3. Add your certificates and keys
#   4. Start the connection: sudo systemctl start openvpn-client@myvpn

##############################################
# Connection Settings
##############################################

# Specify that we are a client
client

# Use the same setting as you are using on the server.
# On most systems, the VPN will not function unless
# you partially or fully disable the firewall for the TUN/TAP interface.
dev tun

# Protocol (udp or tcp)
proto udp

# The hostname/IP and port of the server.
# You can have multiple remote entries to load balance between the servers.
remote YOUR_SERVER_IP 1194

# Keep trying indefinitely to resolve the host name of the OpenVPN server.
resolv-retry infinite

# Most clients don't need to bind to a specific local port number.
nobind

# Try to preserve some state across restarts.
persist-key
persist-tun

# Wireless networks often produce a lot of duplicate packets.
# Set this flag to silence duplicate packet warnings.
;mute-replay-warnings

# SSL/TLS parms.
# See the server config file for more description.
# It's best to use a separate .crt/.key file pair for each client.
# A single ca file can be used for all clients.
ca certs/ca.crt
cert certs/client.crt
key keys/client.key

# Verify server certificate by checking that the
# certicate has the correct key usage set.
remote-cert-tls server

# Enable compression on the VPN link and push the option to the client
comp-lzo

# Set log file verbosity.
verb 3

# Silence repeating messages
;mute 20

##############################################
# Security Settings
##############################################

# Use a different cipher (optional)
;cipher AES-256-CBC

# Enable HMAC authentication (recommended)
;auth SHA256

# Additional security options
;tls-auth ta.key 1
;tls-cipher TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384:TLS-ECDHE-ECDSA-WITH-AES-256-GCM-SHA384:TLS-ECDHE-RSA-WITH-AES-256-CBC-SHA384:TLS-ECDHE-ECDSA-WITH-AES-256-CBC-SHA384

##############################################
# Advanced Options
##############################################

# Override DNS servers pushed by the server (optional)
;dhcp-option DNS 8.8.8.8
;dhcp-option DNS 8.8.4.4

# Route all traffic through VPN (optional)
;redirect-gateway def1

# Custom routes (optional)
;route 192.168.1.0 255.255.255.0

# Script hooks (optional)
;up /etc/openvpn/update-resolv-conf
;down /etc/openvpn/update-resolv-conf
EOF

    sudo chmod 600 "$example_config"
    log "INFO" "Example configuration created: $example_config"
}

# Handle custom configuration file
handle_custom_config() {
    if [[ -n "$CUSTOM_CONFIG_PATH" ]]; then
        show_progress "Processing custom configuration file..."
        
        if [[ ! -f "$CUSTOM_CONFIG_PATH" ]]; then
            error_exit "Custom configuration file not found: $CUSTOM_CONFIG_PATH"
        fi
        
        local config_name=$(basename "$CUSTOM_CONFIG_PATH" .ovpn)
        config_name=$(basename "$config_name" .conf)
        local target_config="$OPENVPN_CLIENT_DIR/$config_name.conf"
        
        if [[ "$DRY_RUN" == true ]]; then
            log "INFO" "[DRY RUN] Would copy $CUSTOM_CONFIG_PATH to $target_config"
            return 0
        fi
        
        sudo cp "$CUSTOM_CONFIG_PATH" "$target_config"
        sudo chmod 600 "$target_config"
        log "INFO" "Custom configuration copied to: $target_config"
        log "INFO" "You can start this VPN with: sudo systemctl start openvpn-client@$config_name"
    fi
}

# Configure OpenVPN service
configure_service() {
    show_progress "Configuring OpenVPN service..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log "INFO" "[DRY RUN] Would configure OpenVPN service"
        return 0
    fi
    
    # Enable OpenVPN service
    if ! sudo systemctl enable openvpn >/dev/null 2>&1; then
        log "WARN" "Failed to enable OpenVPN service (may not be critical)"
    fi
    
    # Ensure OpenVPN service is not running (let user start specific clients)
    if sudo systemctl is-active openvpn >/dev/null 2>&1; then
        sudo systemctl stop openvpn >/dev/null 2>&1 || true
    fi
    
    log "INFO" "OpenVPN service configured"
}

# Setup logging
setup_logging() {
    show_progress "Setting up logging..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log "INFO" "[DRY RUN] Would setup logging configuration"
        return 0
    fi
    
    # Create log directory if it doesn't exist
    sudo mkdir -p "$(dirname "$LOG_FILE")"
    
    # Create or touch the log file
    sudo touch "$LOG_FILE"
    sudo chmod 644 "$LOG_FILE"
    
    # Setup logrotate for OpenVPN logs
    local logrotate_config="/etc/logrotate.d/openvpn-custom"
    sudo tee "$logrotate_config" >/dev/null << EOF
/var/log/openvpn*.log {
    weekly
    rotate 4
    compress
    delaycompress
    missingok
    notifempty
    create 644 nobody nogroup
    postrotate
        /bin/systemctl reload-or-restart rsyslog > /dev/null 2>&1 || true
    endscript
}
EOF
    
    log "INFO" "Logging configuration completed"
}

# Verify installation
verify_installation() {
    show_progress "Verifying installation..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log "INFO" "[DRY RUN] Would verify installation (skipping actual checks)"
        return 0
    fi
    
    local errors=()
    
    # Check if OpenVPN is installed
    if ! command -v openvpn >/dev/null 2>&1; then
        errors+=("OpenVPN binary not found")
    else
        local version=$(openvpn --version | head -n1 | awk '{print $2}')
        log "INFO" "OpenVPN version: $version"
    fi
    
    # Check directories
    local required_dirs=("$OPENVPN_CONFIG_DIR" "$OPENVPN_CLIENT_DIR")
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            errors+=("Required directory missing: $dir")
        fi
    done
    
    # Check example configuration
    if [[ ! -f "$OPENVPN_CLIENT_DIR/example-client.conf" ]]; then
        errors+=("Example configuration file missing")
    fi
    
    if [[ ${#errors[@]} -gt 0 ]]; then
        log "ERROR" "Installation verification failed:"
        for error in "${errors[@]}"; do
            log "ERROR" "  - $error"
        done
        return 1
    fi
    
    log "INFO" "Installation verification completed successfully"
}

# Service management functions
print_service_management_info() {
    cat << 'EOF'

===========================================
OpenVPN Service Management
===========================================

To manage OpenVPN client connections, use these commands:

# Start a VPN connection:
sudo systemctl start openvpn-client@CONFIG_NAME

# Stop a VPN connection:
sudo systemctl stop openvpn-client@CONFIG_NAME

# Check connection status:
sudo systemctl status openvpn-client@CONFIG_NAME

# Enable auto-start on boot:
sudo systemctl enable openvpn-client@CONFIG_NAME

# Disable auto-start on boot:
sudo systemctl disable openvpn-client@CONFIG_NAME

# View connection logs:
sudo journalctl -u openvpn-client@CONFIG_NAME -f

Where CONFIG_NAME is the name of your .conf file without the extension.

Example: If your config file is /etc/openvpn/client/myvpn.conf
Use: sudo systemctl start openvpn-client@myvpn

===========================================
EOF
}

# Print post-installation instructions
print_post_installation_info() {
    cat << EOF

${GREEN}===========================================
OpenVPN Installation Complete!
===========================================${NC}

${CYAN}Configuration Directory:${NC} $OPENVPN_CLIENT_DIR
${CYAN}Example Configuration:${NC} $OPENVPN_CLIENT_DIR/example-client.conf
${CYAN}Log File:${NC} $LOG_FILE

${YELLOW}Next Steps:${NC}
1. Copy your .ovpn configuration file to: $OPENVPN_CLIENT_DIR/
2. Rename it to have a .conf extension (e.g., myvpn.conf)
3. Edit the configuration file to match your VPN server settings
4. Add your certificates and keys to: $OPENVPN_CONFIG_DIR/certs/ and $OPENVPN_CONFIG_DIR/keys/
5. Start your VPN connection using the service management commands above

${YELLOW}Configuration Files Needed:${NC}
- Client certificate (client.crt)
- Client private key (client.key)  
- Certificate Authority (ca.crt)
- Optional: TLS authentication key (ta.key)

${YELLOW}Example Configuration Setup:${NC}
sudo cp your-config.ovpn $OPENVPN_CLIENT_DIR/myvpn.conf
sudo systemctl start openvpn-client@myvpn

${YELLOW}Troubleshooting:${NC}
- Check logs: sudo journalctl -u openvpn-client@CONFIG_NAME
- Test connectivity: ping your-vpn-server
- Verify firewall: sudo ufw status
- Check routing: ip route show

For more help, visit: https://github.com/g91/xenia-canary

EOF
}

# Print troubleshooting information
print_troubleshooting_info() {
    cat << 'EOF'

===========================================
Troubleshooting Guide
===========================================

Common Issues and Solutions:

1. Connection fails immediately:
   - Check server address and port in config file
   - Verify certificates are in correct locations
   - Ensure firewall allows OpenVPN traffic

2. Authentication failures:
   - Verify certificate and key file paths
   - Check certificate expiration dates
   - Ensure CA certificate matches server

3. DNS resolution issues:
   - Add DNS servers to config: dhcp-option DNS 8.8.8.8
   - Check /etc/resolv.conf after connection
   - Install resolvconf: sudo apt install resolvconf

4. Routing problems:
   - Check routes: ip route show
   - Verify redirect-gateway setting
   - Check for IP conflicts

5. Permission errors:
   - Ensure config files have correct permissions (600)
   - Run OpenVPN as root or with sudo
   - Check directory ownership

Useful Commands:
- Test config: sudo openvpn --config /path/to/config.conf
- Check status: sudo systemctl status openvpn-client@config
- View logs: sudo journalctl -u openvpn-client@config -n 50
- Network debug: sudo openvpn --config config.conf --verb 6

===========================================
EOF
}

# Main installation function
main() {
    echo -e "${PURPLE}"
    echo "=============================================="
    echo "     OpenVPN Installation Script"
    echo "     For Debian/Ubuntu Systems"
    echo "=============================================="
    echo -e "${NC}"
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Start logging
    log "INFO" "Starting OpenVPN installation process"
    log "INFO" "Script version: 1.0.0"
    log "INFO" "Arguments: $*"
    
    # System checks
    check_privileges
    detect_os
    check_internet
    
    # Installation process
    update_repositories
    install_openvpn
    
    # Configuration setup
    backup_existing_config
    create_directories
    set_permissions
    create_example_config
    handle_custom_config
    configure_service
    setup_logging
    
    # Verification
    if ! verify_installation; then
        error_exit "Installation verification failed. Please check the errors above."
    fi
    
    # Success message and instructions
    log "INFO" "OpenVPN installation completed successfully"
    print_service_management_info
    print_post_installation_info
    
    if [[ "$VERBOSE" == true ]]; then
        print_troubleshooting_info
    fi
    
    echo -e "${GREEN}Installation completed successfully!${NC}"
    echo -e "Log file: ${CYAN}$LOG_FILE${NC}"
}

# Trap to handle script interruption
trap 'echo -e "\n${RED}Script interrupted. Check $LOG_FILE for details.${NC}"; exit 1' INT TERM

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi