#!/bin/bash
# Nextcloud Loud Updater - Zenity GUI Edition
# Version 1.3
# Requires: zenity, ssh, sshpass, sudo access on remote server

# Check for required packages
if ! command -v sshpass &> /dev/null; then
    zenity --error --width=400 --text="sshpass is required but not installed. Please install it first.\n\nOn Ubuntu/Debian: sudo apt install sshpass\nOn CentOS/RHEL: sudo yum install sshpass" 2>/dev/null
    exit 1
fi

# Main log directory and file
LOG_DIR="$HOME/nextloudupdater"
mkdir -p "$LOG_DIR"
MAIN_LOG="$LOG_DIR/nextcloud_updater_$(date +%Y%m%d_%H%M%S).log"

# Initialize main log
echo "Nextcloud Loud Updater - $(date)" > "$MAIN_LOG"
echo "=================================" >> "$MAIN_LOG"

# Function to log messages with timestamp
log() {
    local msg="$1"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $msg" | tee -a "$MAIN_LOG"
}

# Function to display error and exit
error_exit() {
    zenity --error --width=400 --text="$1" 2>/dev/null
    log "ERROR: $1"
    exit 1
}

# Step 1: Get server and authentication information
server_info=$(zenity --forms \
    --title="Nextcloud Server Connection" \
    --text="Enter Server Connection Details" \
    --add-entry="Server IP Address:" \
    --add-entry="SSH Username (default: $USER):" \
    --add-entry="SSH Port (default: 22):" \
    --add-password="SSH Password:" \
    --add-password="Remote sudo Password:" \
    2>/dev/null)

[ -z "$server_info" ] && error_exit "Operation canceled by user"

# Parse server information
IFS='|' read -r server_ip ssh_user ssh_port ssh_password sudo_password <<< "$server_info"

[ -z "$server_ip" ] && error_exit "Server IP is required"
[ -z "$ssh_user" ] && ssh_user="$USER"
[ -z "$ssh_port" ] && ssh_port=22
[ -z "$ssh_password" ] && error_exit "SSH password is required"
[ -z "$sudo_password" ] && error_exit "Remote sudo password is required"

log "Connecting to server: $ssh_user@$server_ip:$ssh_port"

# Verify SSH connection
SSHPASS="$ssh_password" sshpass -e ssh -q -o StrictHostKeyChecking=no -p "$ssh_port" "$ssh_user@$server_ip" exit
if [ $? -ne 0 ]; then
    error_exit "SSH connection failed!\n\nCheck: 
- Network connectivity
- SSH credentials
- Server firewall settings
- SSH service status
- Password correctness"
fi

# Function to execute remote commands with progress and password handling
run_remote_command() {
    local title="$1"
    local command="$2"
    local step="$3"
    local logfile="/tmp/step$step.log"
    local exitcode_file="/tmp/step$step.exitcode"
    
    (
        echo "0"
        echo "# Preparing to execute: $title"
        sleep 2
        
        log "Executing Step $step: $command"
        echo "20"
        echo "# Connecting to server..."
        
        SSHPASS="$ssh_password" sshpass -e ssh -o StrictHostKeyChecking=no -p "$ssh_port" "$ssh_user@$server_ip" \
            "echo '$sudo_password' | sudo -S bash -c '$command'" > "$logfile" 2>&1
        exit_code=$?
        echo $exit_code > "$exitcode_file"
        
        if [ $exit_code -eq 0 ]; then
            echo "100"
            echo "# Operation completed successfully!"
        else
            echo "100"
            echo "# Operation encountered errors (code $exit_code)"
        fi
        sleep 1
    ) | zenity --progress \
        --title="$title" \
        --width=500 \
        --auto-close \
        --percentage=0
    
    exit_code=$(cat "$exitcode_file" 2>/dev/null)
    rm -f "$exitcode_file"
    
    if [ $exit_code -ne 0 ]; then
        zenity --error --width=500 \
            --text="Step $step failed with exit code $exit_code\n\nCheck logs for details" \
            2>/dev/null
        log "Step $step FAILED. Exit code: $exit_code"
        log "Command output:"
        cat "$logfile" >> "$MAIN_LOG"
        echo "---------------------------------" >> "$MAIN_LOG"
        return 1
    else
        log "Step $step completed successfully"
        log "Command output:"
        cat "$logfile" >> "$MAIN_LOG"
        echo "---------------------------------" >> "$MAIN_LOG"
        return 0
    fi
}

# Main menu loop
while true; do
    choice=$(zenity --list --title="Nextcloud Loud Updater" \
        --width=600 --height=400 \
        --column="Action" --column="Description" \
        "1" "Run Nextcloud Updater" \
        "2" "Maintenance Repair" \
        "3" "Database Optimization (add missing indices)" \
        "4" "Disable Maintenance Mode" \
        "5" "Update All Nextcloud Apps" \
        "6" "View Logs" \
        "7" "Exit" \
        2>/dev/null)

    case $choice in
        "1")
            run_remote_command "Step 1: Running Nextcloud Updater" \
            "docker exec --user www-data nextcloud-aio-nextcloud php updater/updater.phar --no-interaction --no-backup && docker exec --user www-data nextcloud-aio-nextcloud php occ app:enable nextcloud-aio --force" \
            1
            ;;
        "2")
            run_remote_command "Step 2: Maintenance Repair" \
            "docker exec --user www-data nextcloud-aio-nextcloud php occ maintenance:repair --include-expensive" \
            2
            ;;
        "3")
            run_remote_command "Step 3: Database Optimization" \
            "docker exec --user www-data nextcloud-aio-nextcloud php occ db:add-missing-indices" \
            3
            ;;
        "4")
            run_remote_command "Step 4: Disable Maintenance Mode" \
            "docker exec --user www-data nextcloud-aio-nextcloud php occ maintenance:mode --off" \
            4
            ;;
        "5")
            run_remote_command "Step 5: Update All Nextcloud Apps" \
            "docker exec --user www-data nextcloud-aio-nextcloud php occ app:update --all" \
            5
            ;;
        "6")
            zenity --text-info --width=800 --height=600 \
                --title="View Logs" \
                --filename="$MAIN_LOG" \
                2>/dev/null
            ;;
        "7")
            log "User exited the updater."
            zenity --info --width=400 \
                --title="Exit" \
                --text="Exiting Nextcloud Loud Updater.\nLogs saved at:\n$MAIN_LOG" \
                2>/dev/null
            exit 0
            ;;
        *)
            ;;
    esac
done

# Clean up sensitive variables
unset ssh_password
unset sudo_password
