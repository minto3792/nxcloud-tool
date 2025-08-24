#!/bin/bash

# NxCloud Management Tool (Hybrid GUI/CLI Version)
# 
# DISCLAIMER:
# This tool is provided for personal use only. Users must review and understand
# the script before running it. The author is not responsible for any damages
# or losses resulting from the use of this script.
#
# This tool is designed specifically for Nextcloud AIO Docker setups.
# Use at your own risk.
# Supports Zenity GUI *and* CLI menus.

# Configuration
CONFIG_DIR="$HOME/nxcloud"
CONFIG_FILE="$CONFIG_DIR/config"
MAIN_LOG="$CONFIG_DIR/log"
SSH_KEY="$CONFIG_DIR/ssh_key"
USE_GUI=true   # default mode

# Create config directory if it doesn't exist
mkdir -p "$CONFIG_DIR"
touch "$CONFIG_FILE" "$MAIN_LOG"

# Function to log actions
log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$MAIN_LOG"
}

# Check dependencies
check_dependencies() {
    if ! command -v sshpass &> /dev/null; then
        if $USE_GUI; then
            zenity --error --text="sshpass is not installed. Please install it first:\n\nsudo apt-get install sshpass" \
                   --width=400 2>/dev/null
        else
            echo "sshpass is not installed. Please install it first: sudo apt-get install sshpass"
        fi
        exit 1
    fi
    
    if $USE_GUI && ! command -v zenity &> /dev/null; then
        echo "Zenity not installed. Switching to CLI mode..."
        USE_GUI=false
    fi
}

# Load saved configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    else
        # Set default values
        SSH_ADDRESS=""
        SSH_USERNAME="$USER"
        SSH_PORT="22"
        REMOTE_SUDO_PASSWORD=""
        NEXTCLOUD_PATH="/var/www/nextcloud"
        NEXTCLOUD_DATA_PATH="/var/www/nextcloud/data"
    fi
}

# Save configuration
save_config() {
    cat > "$CONFIG_FILE" << EOF
SSH_ADDRESS="$SSH_ADDRESS"
SSH_USERNAME="$SSH_USERNAME"
SSH_PORT="$SSH_PORT"
REMOTE_SUDO_PASSWORD="$REMOTE_SUDO_PASSWORD"
NEXTCLOUD_PATH="$NEXTCLOUD_PATH"
NEXTCLOUD_DATA_PATH="$NEXTCLOUD_DATA_PATH"
EOF
    chmod 600 "$CONFIG_FILE"
}

# SSH connection test
test_ssh_connection() {
    if [ -z "$SSH_ADDRESS" ] || [ -z "$SSH_USERNAME" ]; then
        if $USE_GUI; then
            zenity --warning --text="Please configure SSH connection first" --width=300 2>/dev/null
        else
            echo "Please configure SSH connection first."
        fi
        return 1
    fi
    
    local result
    if [ -n "$REMOTE_SUDO_PASSWORD" ]; then
        result=$(sshpass -p "$REMOTE_SUDO_PASSWORD" ssh -o StrictHostKeyChecking=no -p "$SSH_PORT" "$SSH_USERNAME@$SSH_ADDRESS" "echo 'SSH connection successful'" 2>&1)
    else
        result=$(ssh -o StrictHostKeyChecking=no -p "$SSH_PORT" "$SSH_USERNAME@$SSH_ADDRESS" "echo 'SSH connection successful'" 2>&1)
    fi
    
    if [[ $? -eq 0 ]]; then
        if $USE_GUI; then
            zenity --info --text="SSH connection test successful!" --width=300 2>/dev/null
        else
            echo "SSH connection test successful!"
        fi
        return 0
    else
        if $USE_GUI; then
            zenity --error --text="SSH connection failed:\n$result" --width=500 2>/dev/null
        else
            echo "SSH connection failed: $result"
        fi
        return 1
    fi
}

# Execute remote command
execute_remote() {
    local cmd="$1"
    local result
    
    if [ -n "$REMOTE_SUDO_PASSWORD" ]; then
        result=$(sshpass -p "$REMOTE_SUDO_PASSWORD" ssh -o StrictHostKeyChecking=no -p "$SSH_PORT" "$SSH_USERNAME@$SSH_ADDRESS" "sudo -S <<< '$REMOTE_SUDO_PASSWORD' bash -c '$cmd'" 2>&1)
    else
        result=$(ssh -o StrictHostKeyChecking=no -p "$SSH_PORT" "$SSH_USERNAME@$SSH_ADDRESS" "sudo bash -c '$cmd'" 2>&1)
    fi
    
    local exit_code=$?
    echo "$result"
    return $exit_code
}

# Configuration dialog (GUI)
config_dialog() {
    local form_output
    form_output=$(zenity --forms --title="SSH Connection Configuration" \
        --text="Enter SSH connection details" \
        --add-entry="SSH Address (IP/Hostname):" \
        --add-entry="SSH Username:" \
        --add-entry="SSH Port:" \
        --add-password="Remote Sudo Password:" \
        --add-entry="Nextcloud Path:" \
        --add-entry="Nextcloud Data Path:" \
        --width=500 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    IFS='|' read -ra values <<< "$form_output"
    SSH_ADDRESS="${values[0]}"
    SSH_USERNAME="${values[1]}"
    SSH_PORT="${values[2]:-22}"
    REMOTE_SUDO_PASSWORD="${values[3]}"
    NEXTCLOUD_PATH="${values[4]:-/var/www/nextcloud}"
    NEXTCLOUD_DATA_PATH="${values[5]:-/var/www/nextcloud/data}"
    
    save_config
    if $USE_GUI; then
        zenity --info --text="Configuration saved successfully!" --width=300 2>/dev/null
    else
        echo "Configuration saved successfully!"
    fi
}

# Configuration dialog (CLI)
config_dialog_cli() {
    read -rp "SSH Address (IP/Hostname): " SSH_ADDRESS
    read -rp "SSH Username [${SSH_USERNAME:-$USER}]: " SSH_USERNAME
    SSH_USERNAME=${SSH_USERNAME:-$USER}
    read -rp "SSH Port [${SSH_PORT:-22}]: " SSH_PORT
    SSH_PORT=${SSH_PORT:-22}
    read -srp "Remote Sudo Password: " REMOTE_SUDO_PASSWORD; echo
    read -rp "Nextcloud Path [${NEXTCLOUD_PATH:-/var/www/nextcloud}]: " NEXTCLOUD_PATH
    NEXTCLOUD_PATH=${NEXTCLOUD_PATH:-/var/www/nextcloud}
    read -rp "Nextcloud Data Path [${NEXTCLOUD_DATA_PATH:-/var/www/nextcloud/data}]: " NEXTCLOUD_DATA_PATH
    NEXTCLOUD_DATA_PATH=${NEXTCLOUD_DATA_PATH:-/var/www/nextcloud/data}
    save_config
    echo "Configuration saved."
}

# Update Nextcloud
update_nextcloud() {
    if $USE_GUI; then
        (
            echo "10" ; sleep 1
            execute_remote "docker exec --user www-data nextcloud-aio-nextcloud php occ maintenance:mode --on"
            echo "30" ; sleep 1
            execute_remote "docker exec --user www-data nextcloud-aio-nextcloud php updater/updater.phar --no-interaction --no-backup"
            echo "60" ; sleep 1
            execute_remote "docker exec --user www-data nextcloud-aio-nextcloud php occ app:enable nextcloud-aio --force"
            echo "80" ; sleep 1
            execute_remote "docker exec --user www-data nextcloud-aio-nextcloud php occ maintenance:mode --off"
            echo "100" ; sleep 1
        ) | zenity --progress \
            --title="Updating Nextcloud" \
            --text="Please wait..." \
            --percentage=0 \
            --auto-close \
            --width=300 2>/dev/null
    else
        echo "Starting Nextcloud update..."
        echo "10% - Enabling maintenance mode"
        execute_remote "docker exec --user www-data nextcloud-aio-nextcloud php occ maintenance:mode --on"
        echo "30% - Running updater"
        execute_remote "docker exec --user www-data nextcloud-aio-nextcloud php updater/updater.phar --no-interaction --no-backup"
        echo "60% - Enabling AIO app"
        execute_remote "docker exec --user www-data nextcloud-aio-nextcloud php occ app:enable nextcloud-aio --force"
        echo "80% - Disabling maintenance mode"
        execute_remote "docker exec --user www-data nextcloud-aio-nextcloud php occ maintenance:mode --off"
        echo "100% - Update complete"
    fi
    
    if [ $? -eq 0 ]; then
        if $USE_GUI; then
            zenity --info --text="Nextcloud updated successfully!" --width=300 2>/dev/null
        else
            echo "Nextcloud updated successfully!"
        fi
        log_action "Nextcloud updated"
    else
        if $USE_GUI; then
            zenity --error --text="Nextcloud update failed. Check logs for details." --width=400 2>/dev/null
        else
            echo "Nextcloud update failed. Check logs for details."
        fi
        log_action "Nextcloud update failed"
    fi
}

# Switch release channel
switch_channel() {
    local channel
    
    if $USE_GUI; then
        channel=$(zenity --list \
            --title="Select Release Channel" \
            --column="Channel" "stable" "beta" \
            --height=200 \
            --width=300 2>/dev/null)
    else
        echo "Select release channel:"
        echo "1) stable"
        echo "2) beta"
        read -rp "Enter choice [1/2]: " choice
        case $choice in
            1) channel="stable" ;;
            2) channel="beta" ;;
            *) echo "Invalid choice"; return ;;
        esac
    fi
    
    [ -z "$channel" ] && return
    
    execute_remote "docker exec --user www-data nextcloud-aio-nextcloud php occ config:system:set updater.release.channel --value=$channel"
    
    if [ $? -eq 0 ]; then
        if $USE_GUI; then
            zenity --info --text="Channel switched to $channel successfully!" --width=300 2>/dev/null
        else
            echo "Channel switched to $channel successfully!"
        fi
        log_action "Release channel switched to $channel"
    else
        if $USE_GUI; then
            zenity --error --text="Failed to switch channel. Check logs for details." --width=400 2>/dev/null
        else
            echo "Failed to switch channel. Check logs for details."
        fi
        log_action "Failed to switch release channel to $channel"
    fi
}

# Maintenance repair
maintenance_repair() {
    if $USE_GUI; then
        (
            echo "20" ; sleep 1
            execute_remote "docker exec --user www-data nextcloud-aio-nextcloud php occ db:add-missing-indices"
            echo "40" ; sleep 1
            execute_remote "docker exec --user www-data nextcloud-aio-nextcloud php occ maintenance:repair --include-expensive"
            echo "60" ; sleep 1
            execute_remote "docker exec nextcloud-aio-nextcloud sudo -u www-data php occ status"
            echo "80" ; sleep 1
            execute_remote "docker exec --user www-data nextcloud-aio-nextcloud php occ maintenance:mode --on"
            echo "90" ; sleep 1
            execute_remote "docker exec --user www-data nextcloud-aio-nextcloud php occ maintenance:mode --off"
            echo "100" ; sleep 1
        ) | zenity --progress \
            --title="Running Maintenance" \
            --text="Please wait..." \
            --percentage=0 \
            --auto-close \
            --width=300 2>/dev/null
    else
        echo "Running maintenance repair..."
        echo "20% - Adding missing indices"
        execute_remote "docker exec --user www-data nextcloud-aio-nextcloud php occ db:add-missing-indices"
        echo "40% - Running repair"
        execute_remote "docker exec --user www-data nextcloud-aio-nextcloud php occ maintenance:repair --include-expensive"
        echo "60% - Checking status"
        execute_remote "docker exec nextcloud-aio-nextcloud sudo -u www-data php occ status"
        echo "80% - Enabling maintenance mode"
        execute_remote "docker exec --user www-data nextcloud-aio-nextcloud php occ maintenance:mode --on"
        echo "90% - Disabling maintenance mode"
        execute_remote "docker exec --user www-data nextcloud-aio-nextcloud php occ maintenance:mode --off"
        echo "100% - Maintenance complete"
    fi
    
    if [ $? -eq 0 ]; then
        if $USE_GUI; then
            zenity --info --text="Maintenance completed successfully!" --width=300 2>/dev/null
        else
            echo "Maintenance completed successfully!"
        fi
        log_action "Maintenance repair completed"
    else
        if $USE_GUI; then
            zenity --error --text="Maintenance failed. Check logs for details." --width=400 2>/dev/null
        else
            echo "Maintenance failed. Check logs for details."
        fi
        log_action "Maintenance repair failed"
    fi
}

# Update all apps
update_apps() {
    local result
    result=$(execute_remote "docker exec --user www-data nextcloud-aio-nextcloud php occ app:update --all")
    
    if [ $? -eq 0 ]; then
        if $USE_GUI; then
            zenity --info --text="All apps updated successfully!" --width=300 2>/dev/null
        else
            echo "All apps updated successfully!"
        fi
        log_action "All apps updated"
    else
        if $USE_GUI; then
            zenity --error --text="App update failed:\n$result" --width=500 2>/dev/null
        else
            echo "App update failed: $result"
        fi
        log_action "App update failed: $result"
    fi
}

# Fix phone region
fix_phone_region() {
    local region
    
    if $USE_GUI; then
        region=$(zenity --entry --title="Phone Region" --text="Enter default phone region (e.g. US):" --width=300 2>/dev/null)
    else
        read -rp "Enter default phone region (e.g. US): " region
    fi
    
    [ -z "$region" ] && return
    
    execute_remote "docker exec --user www-data nextcloud-aio-nextcloud php occ config:system:set default_phone_region --value='$region'"
    
    if [ $? -eq 0 ]; then
        if $USE_GUI; then
            zenity --info --text="Phone region set to $region successfully!" --width=300 2>/dev/null
        else
            echo "Phone region set to $region successfully!"
        fi
        log_action "Phone region set to $region"
    else
        if $USE_GUI; then
            zenity --error --text="Failed to set phone region. Check logs for details." --width=400 2>/dev/null
        else
            echo "Failed to set phone region. Check logs for details."
        fi
        log_action "Failed to set phone region to $region"
    fi
}

# Add user to www-data group
add_user_group() {
    local username
    
    if $USE_GUI; then
        username=$(zenity --entry --title="Add User to Group" --text="Enter username:" --width=300 2>/dev/null)
    else
        read -rp "Enter username: " username
    fi
    
    [ -z "$username" ] && return
    
    execute_remote "usermod -aG www-data '$username'"
    
    if [ $? -eq 0 ]; then
        if $USE_GUI; then
            zenity --info --text="User $username added to www-data group successfully!" --width=300 2>/dev/null
        else
            echo "User $username added to www-data group successfully!"
        fi
        log_action "User $username added to www-data group"
    else
        if $USE_GUI; then
            zenity --error --text="Failed to add user to group. Check logs for details." --width=400 2>/dev/null
        else
            echo "Failed to add user to group. Check logs for details."
        fi
        log_action "Failed to add user $username to www-data group"
    fi
}

# Fix permissions
fix_permissions() {
    local path
    
    if $USE_GUI; then
        path=$(zenity --file-selection --directory --title="Select Directory" --width=700 2>/dev/null)
    else
        read -rp "Enter directory path: " path
    fi
    
    [ -z "$path" ] && return
    
    execute_remote "chown -R www-data:users '$path' && chmod 770 -R '$path'"
    
    if [ $? -eq 0 ]; then
        if $USE_GUI; then
            zenity --info --text="Permissions fixed for $path successfully!" --width=300 2>/dev/null
        else
            echo "Permissions fixed for $path successfully!"
        fi
        log_action "Permissions fixed for $path"
    else
        if $USE_GUI; then
            zenity --error --text="Failed to fix permissions. Check logs for details." --width=400 2>/dev/null
        else
            echo "Failed to fix permissions. Check logs for details."
        fi
        log_action "Failed to fix permissions for $path"
    fi
}

# Clean logs
clean_logs() {
    execute_remote "truncate -s 0 /var/lib/docker/volumes/nextcloud_aio_nextcloud/_data/data/nextcloud.log"
    
    if [ $? -eq 0 ]; then
        if $USE_GUI; then
            zenity --info --text="Logs cleaned successfully!" --width=300 2>/dev/null
        else
            echo "Logs cleaned successfully!"
        fi
        log_action "Logs cleaned"
    else
        if $USE_GUI; then
            zenity --error --text="Failed to clean logs. Check logs for details." --width=400 2>/dev/null
        else
            echo "Failed to clean logs. Check logs for details."
        fi
        log_action "Failed to clean logs"
    fi
}

# Reset bruteforce
reset_bruteforce() {
    local ip
    
    if $USE_GUI; then
        ip=$(zenity --entry --title="Reset Bruteforce" --text="Enter IP Address:" --width=300 2>/dev/null)
    else
        read -rp "Enter IP Address: " ip
    fi
    
    [ -z "$ip" ] && return
    
    execute_remote "docker exec --user www-data nextcloud-aio-nextcloud php occ security:bruteforce:reset '$ip'"
    
    if [ $? -eq 0 ]; then
        if $USE_GUI; then
            zenity --info --text="Bruteforce counter reset for $ip successfully!" --width=300 2>/dev/null
        else
            echo "Bruteforce counter reset for $ip successfully!"
        fi
        log_action "Bruteforce counter reset for $ip"
    else
        if $USE_GUI; then
            zenity --error --text="Failed to reset bruteforce counter. Check logs for details." --width=400 2>/dev/null
        else
            echo "Failed to reset bruteforce counter. Check logs for details."
        fi
        log_action "Failed to reset bruteforce counter for $ip"
    fi
}

# View logs
view_logs() {
    local log_content
    log_content=$(execute_remote "tail -50 /var/lib/docker/volumes/nextcloud_aio_nextcloud/_data/data/nextcloud.log")
    
    if $USE_GUI; then
        zenity --text-info --width=800 --height=600 \
            --title="Nextcloud Logs" \
            --filename=<(echo "$log_content") \
            2>/dev/null
    else
        echo "=== Nextcloud Logs ==="
        echo "$log_content"
        echo "======================"
    fi
}

# NVIDIA setup
nvidia_setup() {
    if $USE_GUI; then
        zenity --warning --text="This will modify docker configuration. Continue?" \
            --ok-label="Continue" --cancel-label="Cancel" --width=300 2>/dev/null || return
    else
        read -rp "This will modify docker configuration. Continue? (y/n): " answer
        [[ ! "$answer" =~ ^[Yy]$ ]] && return
    fi

    execute_remote "cat > /etc/docker/daemon.json << 'EOF'
{
    \"data-root\": \"/var/lib/docker\",
    \"runtimes\": {
        \"nvidia\": {
            \"path\": \"nvidia-container-runtime\",
            \"runtimeArgs\": []
        }
    },
    \"default-runtime\": \"nvidia\"
}
EOF"

    execute_remote "systemctl daemon-reload && systemctl restart docker"
    
    local runtime_info
    runtime_info=$(execute_remote "docker info | grep -i runtime")
    
    if $USE_GUI; then
        zenity --text-info --width=600 --height=200 \
            --title="Docker Runtime Info" \
            --filename=<(echo "$runtime_info") \
            2>/dev/null
    else
        echo "=== Docker Runtime Info ==="
        echo "$runtime_info"
        echo "==========================="
    fi
    
    if [ $? -eq 0 ]; then
        if $USE_GUI; then
            zenity --info --text="NVIDIA runtime configured successfully!" --width=300 2>/dev/null
        else
            echo "NVIDIA runtime configured successfully!"
        fi
        log_action "NVIDIA runtime configured"
    else
        if $USE_GUI; then
            zenity --error --text="Failed to configure NVIDIA runtime. Check logs for details." --width=400 2>/dev/null
        else
            echo "Failed to configure NVIDIA runtime. Check logs for details."
        fi
        log_action "Failed to configure NVIDIA runtime"
    fi
}

# Main menu (GUI)
main_menu() {
    while true; do
        local choice
        choice=$(zenity --list \
            --title="Nextcloud AIO Management" \
            --width=700 --height=500 \
            --column="Option" \
            "Configure SSH Connection" \
            "Test SSH Connection" \
            "Update Nextcloud" \
            "Switch Release Channel" \
            "Maintenance Repair" \
            "Update All Nextcloud Apps" \
            "Fix Phone Region" \
            "Add User to www-data Group" \
            "Fix File Permissions" \
            "Clean Logs" \
            "Reset Bruteforce Attempts" \
            "View Logs" \
            "NVIDIA Runtime Setup" \
            "Exit" \
            2>/dev/null)
        
        case "$choice" in
            "Configure SSH Connection") config_dialog ;;
            "Test SSH Connection") test_ssh_connection ;;
            "Update Nextcloud") update_nextcloud ;;
            "Switch Release Channel") switch_channel ;;
            "Maintenance Repair") maintenance_repair ;;
            "Update All Nextcloud Apps") update_apps ;;
            "Fix Phone Region") fix_phone_region ;;
            "Add User to www-data Group") add_user_group ;;
            "Fix File Permissions") fix_permissions ;;
            "Clean Logs") clean_logs ;;
            "Reset Bruteforce Attempts") reset_bruteforce ;;
            "View Logs") view_logs ;;
            "NVIDIA Runtime Setup") nvidia_setup ;;
            "Exit") exit 0 ;;
            *) exit 0 ;;
        esac
    done
}

# CLI Menus
cli_main_menu() {
    while true; do
        echo -e "\n--- Nextcloud AIO Management ---"
        options=(
            "Configure SSH Connection"
            "Test SSH Connection"
            "Nextcloud Operations"
            "User & Permissions"
            "Logs & Security"
            "NVIDIA Runtime Setup"
            "Exit"
        )
        select opt in "${options[@]}"; do
            case $REPLY in
                1) config_dialog_cli ;;
                2) test_ssh_connection ;;
                3) cli_nextcloud_menu ;;
                4) cli_user_permissions_menu ;;
                5) cli_logs_security_menu ;;
                6) nvidia_setup ;;
                7) echo "Goodbye!"; exit 0 ;;
                *) echo "Invalid option" ;;
            esac
            break
        done
    done
}

cli_nextcloud_menu() {
    while true; do
        echo -e "\n--- Nextcloud Operations ---"
        options=("Update Nextcloud" "Switch Release Channel" "Maintenance Repair" "Update All Apps" "Back")
        select opt in "${options[@]}"; do
            case $REPLY in
                1) update_nextcloud ;;
                2) switch_channel ;;
                3) maintenance_repair ;;
                4) update_apps ;;
                5) return ;;
                *) echo "Invalid option" ;;
            esac
            break
        done
    done
}

cli_user_permissions_menu() {
    while true; do
        echo -e "\n--- User & Permissions ---"
        options=("Fix Phone Region" "Add User to www-data Group" "Fix File Permissions" "Back")
        select opt in "${options[@]}"; do
            case $REPLY in
                1) fix_phone_region ;;
                2) add_user_group ;;
                3) fix_permissions ;;
                4) return ;;
                *) echo "Invalid option" ;;
            esac
            break
        done
    done
}

cli_logs_security_menu() {
    while true; do
        echo -e "\n--- Logs & Security ---"
        options=("Clean Logs" "Reset Bruteforce Attempts" "View Logs" "Back")
        select opt in "${options[@]}"; do
            case $REPLY in
                1) clean_logs ;;
                2) reset_bruteforce ;;
                3) view_logs ;;
                4) return ;;
                *) echo "Invalid option" ;;
            esac
            break
        done
    done
}

# Initialization
# Mode selection
if [[ $# -gt 0 && "$1" == "--cli" ]]; then
    USE_GUI=false
else
    echo "Choose interface mode:"
    echo "1) GUI (Zenity)"
    echo "2) CLI (Terminal)"
    read -rp "Enter choice [1/2]: " mode

    if [[ "$mode" == "2" ]]; then
        USE_GUI=false
    else
        USE_GUI=true
    fi
fi

check_dependencies
load_config

if $USE_GUI; then
    zenity --info --text="Welcome to Nextcloud AIO Management Tool\n\nPlease configure your SSH connection first." \
           --width=400 2>/dev/null
else
    echo "Welcome to Nextcloud AIO Management Tool"
fi

# Initial config if missing
if [ -z "$SSH_ADDRESS" ]; then
    if $USE_GUI; then
        config_dialog || exit 1
    else
        config_dialog_cli || exit 1
    fi
fi

# Test SSH connection
test_ssh_connection || {
    if $USE_GUI; then
        zenity --question --text="SSH connection failed. Would you like to reconfigure?" \
               --width=300 2>/dev/null && config_dialog || exit 1
    else
        read -rp "SSH connection failed. Reconfigure? (y/n): " ans
        [[ "$ans" =~ ^[Yy]$ ]] && config_dialog_cli || exit 1
    fi
}

# Launch correct menu
if $USE_GUI; then
    main_menu
else
    cli_main_menu
fi
