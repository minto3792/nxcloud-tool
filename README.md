# NXcloud Management Tool For Nextcloud AIO

A hybrid GUI/CLI tool for managing Nextcloud All-in-One (AIO) Docker installations with both graphical (Zenity) and command-line interfaces.

## The Story Behind This Tool

I created this script to simplify the maintenance of my self-hosted Nextcloud setup. As someone who runs multiple self-hosted services, I found myself repeatedly executing the same series of commands for routine Nextcloud maintenance. Rather than keeping a list of commands in a text file or trying to remember them all, I decided to create a tool that would make these tasks accessible through both a graphical interface and a command-line interface.

This tool is my contribution back to the open-source community that has provided me with so many valuable resources. It's designed to make Nextcloud management more accessible to users with different preferences and skill levels - some may prefer the visual guidance of a GUI, while others may prefer the speed and scriptability of a CLI.

## Features

- **Dual Interface**: Choose between GUI (Zenity) or CLI mode based on your preference
- **SSH Management**: Configure and test SSH connections to your Nextcloud server
- **Update Management**: Update Nextcloud core and all apps with a single click/command
- **Maintenance Tools**: Run maintenance repairs and fix file permissions easily
- **Security Features**: Reset bruteforce attempts and clean logs
- **NVIDIA Support**: Configure NVIDIA runtime for GPU acceleration
- **User Management**: Add users to www-data group and set phone regions

## Prerequisites

- Bash shell
- sshpass (for SSH password authentication)
- Zenity (for GUI mode)
- Nextcloud AIO Docker installation
- SSH access to the Nextcloud server

## Installation

1. Download the script to your local machine:
```bash
wget https://github.com/minto3792/nxcloud-tool/blob/main/nxcloud.sh
```

2. Make the script executable:
```bash
chmod +x nxcloud-tool.sh
```

3. Install dependencies:

On Debian/Ubuntu:
```bash
sudo apt-get install sshpass zenity
```

On Fedora/RHEL:
```bash
sudo dnf install sshpass zenity
```

## Usage

### GUI Mode (Default)
```bash
./nxcloud-tool.sh
```

### CLI Mode
```bash
./nxcloud-tool.sh --cli
```

Or choose mode at startup when prompted.

### First-Time Setup

1. The tool will prompt you to configure your SSH connection details
2. Enter your server's SSH address, username, port, and sudo password
3. Specify your Nextcloud installation and data paths
4. Test the connection to ensure everything is working

## Configuration

The tool stores configuration in `~/.nxcloud/config` with the following settings:
- SSH connection details
- Nextcloud paths
- Remote sudo password (encrypted)

## Commands Used in the Script

For transparency and to help users understand what the script does, here are the key commands used:

### SSH Connection
```bash
# Test SSH connection
sshpass -p "$REMOTE_SUDO_PASSWORD" ssh -o StrictHostKeyChecking=no -p "$SSH_PORT" "$SSH_USERNAME@$SSH_ADDRESS" "echo 'SSH connection successful'"

# Execute remote command with sudo
sshpass -p "$REMOTE_SUDO_PASSWORD" ssh -o StrictHostKeyChecking=no -p "$SSH_PORT" "$SSH_USERNAME@$SSH_ADDRESS" "sudo -S <<< '$REMOTE_SUDO_PASSWORD' bash -c '$cmd'"
```

### Nextcloud Operations
```bash
# Enable maintenance mode
docker exec --user www-data nextcloud-aio-nextcloud php occ maintenance:mode --on

# Run Nextcloud updater
docker exec --user www-data nextcloud-aio-nextcloud php updater/updater.phar --no-interaction --no-backup

# Enable AIO app
docker exec --user www-data nextcloud-aio-nextcloud php occ app:enable nextcloud-aio --force

# Disable maintenance mode
docker exec --user www-data nextcloud-aio-nextcloud php occ maintenance:mode --off

# Switch release channel
docker exec --user www-data nextcloud-aio-nextcloud php occ config:system:set updater.release.channel --value=$channel

# Database maintenance
docker exec --user www-data nextcloud-aio-nextcloud php occ db:add-missing-indices

# Repair maintenance
docker exec --user www-data nextcloud-aio-nextcloud php occ maintenance:repair --include-expensive

# Update all apps
docker exec --user www-data nextcloud-aio-nextcloud php occ app:update --all

# Set phone region
docker exec --user www-data nextcloud-aio-nextcloud php occ config:system:set default_phone_region --value='$region'

# Reset bruteforce attempts
docker exec --user www-data nextcloud-aio-nextcloud php occ security:bruteforce:reset '$ip'
```

### File Operations
```bash
# Fix permissions
chown -R www-data:users '$path' && chmod 770 -R '$path'

# Clean logs
truncate -s 0 /var/lib/docker/volumes/nextcloud_aio_nextcloud/_data/data/nextcloud.log

# View logs
tail -50 /var/lib/docker/volumes/nextcloud_aio_nextcloud/_data/data/nextcloud.log
```

### User Management
```bash
# Add user to www-data group
usermod -aG www-data '$username'
```

### Docker Configuration
```bash
# Configure NVIDIA runtime
cat > /etc/docker/daemon.json << 'EOF'
{
    "data-root": "/var/lib/docker",
    "runtimes": {
        "nvidia": {
            "path": "nvidia-container-runtime",
            "runtimeArgs": []
        }
    },
    "default-runtime": "nvidia"
}
EOF

# Reload and restart Docker
systemctl daemon-reload && systemctl restart docker

# Check Docker runtime info
docker info | grep -i runtime
```

## Features Overview

### SSH Management
- Configure SSH connection settings
- Test SSH connectivity

### Nextcloud Operations
- Update Nextcloud core
- Switch release channels (stable/beta)
- Run maintenance repairs
- Update all apps

### User & Permissions
- Set default phone region
- Add users to www-data group
- Fix file permissions

### Logs & Security
- Clean Nextcloud logs
- Reset bruteforce attempts
- View recent logs

### Advanced
- Configure NVIDIA runtime for GPU acceleration

## Troubleshooting

### Common Issues
1. **SSH Connection Failed**: Check your SSH credentials and ensure the remote server allows SSH connections
2. **Permission Denied**: Ensure the remote user has sudo privileges
3. **Docker Command Not Found**: Docker must be installed on the remote server
4. **Nextcloud Path Incorrect**: Verify the Nextcloud path in your configuration

### Logs
Check the tool's log file for detailed error information:
```bash
cat ~/.nxcloud/log
```

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Disclaimer

This tool is provided for personal use only. Users must review and understand the script before running it. The author is not responsible for any damages or losses resulting from the use of this script.

This tool is designed specifically for Nextcloud AIO Docker setups. Use at your own risk.

## Contributing

1. Fork the project
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

## Support

If you encounter any issues:
1. Check the logs in `~/.nxcloud/log`
2. Ensure all prerequisites are installed
3. Verify your SSH connection details

For bug reports and feature requests, please use the GitHub issue tracker.

## Acknowledgments

- Thanks to the open-source community for inspiration and support
- Nextcloud team for their excellent AIO Docker setup
- Zenity developers for the GUI framework
- All contributors and users of this tool

---

*This tool is not officially affiliated with Nextcloud GmbH.*
