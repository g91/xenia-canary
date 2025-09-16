# OpenVPN Installation Script

This directory contains utility scripts for the Xenia Canary project, including an automated OpenVPN installation script for secure network connections.

## install-openvpn.sh

A comprehensive bash script that automatically installs OpenVPN on Debian/Ubuntu systems and sets up client connections. This script is particularly useful for gamers who want to establish secure VPN connections for netplay gaming.

### Features

- **System Requirements Check**: Automatically verifies Debian/Ubuntu compatibility, root privileges, and internet connectivity
- **Automated Installation**: Installs OpenVPN and all necessary dependencies
- **Client Configuration**: Sets up proper directory structure with secure permissions
- **Service Management**: Provides easy start/stop/restart functionality for VPN connections
- **Security Hardening**: Implements proper file permissions and backup procedures
- **User-Friendly Interface**: Clear progress indicators, error handling, and comprehensive help
- **Logging**: Detailed logging for troubleshooting and audit purposes

### Compatibility

- Debian 10+ (Buster and later)
- Ubuntu 18.04+ (Bionic and later)
- Other Debian-based distributions (Linux Mint, Pop!_OS, Elementary OS, etc.)

### Requirements

- Root access or sudo privileges
- Internet connectivity
- Debian-based Linux distribution

### Usage

#### Basic Installation
```bash
./scripts/install-openvpn.sh
```

#### Installation with Verbose Output
```bash
./scripts/install-openvpn.sh --verbose
```

#### Preview Changes (Dry Run)
```bash
./scripts/install-openvpn.sh --dry-run
```

#### Install with Custom Configuration
```bash
./scripts/install-openvpn.sh --config /path/to/your/client.ovpn
```

#### Get Help
```bash
./scripts/install-openvpn.sh --help
```

### Post-Installation Setup

After running the installation script, you'll need to:

1. **Add your VPN configuration file**:
   ```bash
   sudo cp your-config.ovpn /etc/openvpn/client/myvpn.conf
   ```

2. **Add certificates and keys** to the appropriate directories:
   - Certificate Authority: `/etc/openvpn/certs/ca.crt`
   - Client Certificate: `/etc/openvpn/certs/client.crt`
   - Client Private Key: `/etc/openvpn/keys/client.key`

3. **Start your VPN connection**:
   ```bash
   sudo systemctl start openvpn-client@myvpn
   ```

4. **Check connection status**:
   ```bash
   sudo systemctl status openvpn-client@myvpn
   ```

### Service Management

The script sets up OpenVPN as a systemd service for easy management:

```bash
# Start VPN connection
sudo systemctl start openvpn-client@CONFIG_NAME

# Stop VPN connection  
sudo systemctl stop openvpn-client@CONFIG_NAME

# Check connection status
sudo systemctl status openvpn-client@CONFIG_NAME

# Enable auto-start on boot
sudo systemctl enable openvpn-client@CONFIG_NAME

# View connection logs
sudo journalctl -u openvpn-client@CONFIG_NAME -f
```

### Directory Structure

After installation, the following directory structure will be created:

```
/etc/openvpn/
├── client/          # Client configuration files (.conf)
├── certs/           # Certificate files (.crt)
├── keys/            # Private key files (.key)
└── backup/          # Configuration backups
```

### Security Features

- **Secure Permissions**: All OpenVPN directories are set to mode 700 (owner-only access)
- **Root Ownership**: All configuration files are owned by root
- **Configuration Backup**: Automatic backup of existing configurations before installation
- **Audit Logging**: Comprehensive logging to `/var/log/openvpn-install.log`

### Troubleshooting

#### Common Issues

1. **Permission Denied Errors**:
   - Ensure you're running with sudo or as root
   - Check file permissions with `ls -la /etc/openvpn/`

2. **Connection Failures**:
   - Verify server address and port in configuration
   - Check certificates are in correct locations
   - Review logs: `sudo journalctl -u openvpn-client@CONFIG_NAME`

3. **DNS Issues**:
   - Install resolvconf: `sudo apt install resolvconf`
   - Add DNS servers to config file
   - Check `/etc/resolv.conf` after connection

4. **Firewall Blocking**:
   - Allow OpenVPN through firewall: `sudo ufw allow 1194/udp`
   - Check iptables rules: `sudo iptables -L`

#### Debug Mode

For detailed troubleshooting, run OpenVPN manually:

```bash
sudo openvpn --config /etc/openvpn/client/myvpn.conf --verb 6
```

### Logging

The script creates detailed logs at `/var/log/openvpn-install.log` for troubleshooting and audit purposes. Log rotation is automatically configured to prevent disk space issues.

### Gaming with VPN

This script is particularly useful for Xenia Canary netplay users who want to:

- Connect securely to gaming servers
- Reduce latency through optimized routing
- Protect gaming traffic from ISP throttling
- Access region-locked gaming content
- Create secure private networks for multiplayer gaming

### Contributing

Contributions to improve the script are welcome! Please ensure any changes:

- Maintain compatibility with supported distributions
- Include appropriate error handling
- Follow the existing code style
- Add tests for new functionality

### License

This script is released under the same license as the Xenia Canary project (BSD License).

### Support

For issues related to this script:

1. Check the troubleshooting section above
2. Review the installation logs
3. Open an issue on the [Xenia Canary repository](https://github.com/g91/xenia-canary)

For OpenVPN-specific issues, consult the [OpenVPN documentation](https://openvpn.net/community-resources/reference-manual-for-openvpn-2-4/).