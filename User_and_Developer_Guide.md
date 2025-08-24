# Nextcloud AIO Management Tool - User and Developer Guide

## Overview

This guide explains how to use and customize the Nextcloud AIO Management Tool for both normal users and developers. The tool provides both GUI (Zenity) and CLI interfaces for managing Nextcloud AIO installations.

## For Normal Users

### Installation

1. Download the script:
```bash
wget https://raw.githubusercontent.com/yourusername/nextcloud-aio-management-tool/main/nxcloud-tool.sh
```

2. Make it executable:
```bash
chmod +x nxcloud-tool.sh
```

3. Install dependencies:
```bash
# On Debian/Ubuntu
sudo apt-get install sshpass zenity

# On Fedora/RHEL
sudo dnf install sshpass zenity
```

### First-Time Setup

1. Run the script:
```bash
./nxcloud-tool.sh
```

2. Choose your preferred interface mode (GUI or CLI)

3. Configure your SSH connection details when prompted:
   - SSH Address (IP or hostname of your Nextcloud server)
   - SSH Username (typically your server username)
   - SSH Port (usually 22)
   - Remote Sudo Password (your server's sudo password)
   - Nextcloud Path (default: /var/www/nextcloud)
   - Nextcloud Data Path (default: /var/www/nextcloud/data)

4. Test the SSH connection to ensure everything is working

### Common Tasks

#### Update Nextcloud
- GUI: Select "Update Nextcloud" from the main menu
- CLI: Navigate to "Nextcloud Operations" → "Update Nextcloud"

#### Fix File Permissions
- GUI: Select "Fix File Permissions" and choose the directory
- CLI: Navigate to "User & Permissions" → "Fix File Permissions"

#### Clean Logs
- GUI: Select "Clean Logs" from the main menu
- CLI: Navigate to "Logs & Security" → "Clean Logs"

#### Reset Bruteforce Attempts
- GUI: Select "Reset Bruteforce Attempts" and enter the IP address
- CLI: Navigate to "Logs & Security" → "Reset Bruteforce Attempts"

### Troubleshooting

1. If SSH connections fail:
   - Verify your SSH credentials
   - Ensure the remote server allows SSH connections
   - Check that the remote user has sudo privileges

2. If commands fail:
   - Check the log file at `~/.nxcloud/log`
   - Verify Docker is installed on the remote server
   - Confirm the Nextcloud paths are correct

## For Developers

### Script Structure

The script is organized into several sections:

1. **Configuration**: Variables and setup
2. **Utility Functions**: Logging, dependency checking, config loading/saving
3. **SSH Functions**: Connection testing and remote command execution
4. **GUI Functions**: Zenity-based dialogs and menus
5. **CLI Functions**: Text-based menus and prompts
6. **Feature Functions**: Nextcloud-specific operations
7. **Initialization**: Mode selection and startup

### Customization Options

#### Adding New Features

1. Create a new function for your feature:
```bash
my_new_feature() {
    if $USE_GUI; then
        # GUI implementation
        zenity --info --text="My new feature"
    else
        # CLI implementation
        echo "My new feature"
    fi
    log_action "Ran my new feature"
}
```

2. Add it to the appropriate menu:
```bash
# For GUI menu
"My New Feature") my_new_feature ;;

# For CLI menu
"My New Feature") my_new_feature ;;
```

#### Modifying Existing Features

To modify an existing feature, locate its function and update the implementation. Most functions have both GUI and CLI implementations.

#### Changing Configuration Storage

The configuration is stored in `~/.nxcloud/config`. To change this location, modify the `CONFIG_DIR` and `CONFIG_FILE` variables at the top of the script.

#### Adding New Configuration Options

1. Add the new variable to the configuration section:
```bash
MY_NEW_CONFIG="default_value"
```

2. Update the `load_config` function to load the value:
```bash
MY_NEW_CONFIG="${MY_NEW_CONFIG:-default_value}"
```

3. Update the `save_config` function to save the value:
```bash
echo 'MY_NEW_CONFIG="'"$MY_NEW_CONFIG"'"' >> "$CONFIG_FILE"
```

4. Update the configuration dialog to get the value from the user

### Extending SSH Functionality

The `execute_remote` function handles all remote command execution. You can extend it to support additional authentication methods or error handling.

### Adding Support for Other Nextcloud Installations

The script currently targets Nextcloud AIO installations. To support other installation types:

1. Modify the remote commands in each feature function
2. Update the configuration to include installation-specific paths
3. Add installation type detection if needed

### Testing Your Changes

1. Test both GUI and CLI modes:
```bash
# Test GUI mode
./nxcloud-tool.sh

# Test CLI mode
./nxcloud-tool.sh --cli
```

2. Verify the log file for errors:
```bash
tail -f ~/.nxcloud/log
```

3. Test SSH connectivity after changes:
```bash
# Use the test function in the script
test_ssh_connection
```

### Contributing Back

If you've made improvements to the script:

1. Fork the repository on GitHub
2. Create a feature branch for your changes
3. Test your changes thoroughly
4. Submit a pull request with a description of your changes

## Security Considerations

- The script stores SSH credentials in a configuration file. Ensure this file has proper permissions (chmod 600)
- Consider using SSH keys instead of passwords for more secure authentication
- Regularly update the script to incorporate security fixes

## Performance Tips

- For frequently used operations, consider creating shortcut commands
- The CLI mode is generally faster for experienced users
- You can create aliases for common tasks in your shell profile

## Support

If you encounter issues:

1. Check the log file at `~/.nxcloud/log`
2. Verify all prerequisites are installed
3. Ensure your SSH connection is working
4. Consult the script's comments for implementation details

For bugs or feature requests, please use the GitHub issue tracker.

---

This guide is a living document. Please contribute improvements and updates as you work with the script.
