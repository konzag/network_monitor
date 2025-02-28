#!/bin/bash
set -e  # Stop script on error
#set -x  # Enable debug mode (show commands being executed)

# Define file paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "$0")"
DB_PATH="$SCRIPT_DIR/network_devices.db"
CONFIG_FILE="$SCRIPT_DIR/pushover_configuration.enc"
LOG_DIR="$SCRIPT_DIR/Logs"
LOG_FILE="$LOG_DIR/network_monitor.log"
CREATE_DB_SCRIPT="$SCRIPT_DIR/create_device_list_db.sh"

# Required tools
REQUIRED_TOOLS=("gpg" "openssl" "sqlite3" "ip" "crontab" "curl")

# Function to check required tools
check_and_install_tools() {
    for tool in "${REQUIRED_TOOLS[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_message "⚠️ $tool not found!"
            if [[ $EUID -ne 0 ]]; then
                log_message "⚠️ Run this script as root (sudo) to install missing packages."
                exit 1
            fi
            log_message "Installing $tool..."
            apt update && apt install -y "$tool"
        else
            log_message "✅ $tool is already installed."
        fi
    done
}

# Ensure Logs directory exists
setup_logs() {
    if [[ ! -d "$LOG_DIR" ]]; then
        log_message "📂 Creating Logs directory..."
        mkdir -p "$LOG_DIR"
        chmod 755 "$LOG_DIR"
    fi
}

# Function to log messages with timestamps
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Error handling function
handle_error() {
    log_message "❌ ERROR: $1"
    exit 1
}

# Check if script is scheduled in cron
check_cron_job() {
    log_message "🔍 Checking if script is scheduled in cron..."
    CRON_JOB="*/3 * * * * $SCRIPT_DIR/$SCRIPT_NAME"
    
    if ! crontab -l 2>/dev/null | grep -Fq "$CRON_JOB"; then
        log_message "❌ ERROR: Script is not scheduled to run every 3 minutes in cron!"
        send_notification "Cron Job Missing" "The network monitoring script is not scheduled in cron. Please add it."
        (crontab -l 2>/dev/null; echo "$CRON_JOB") | sort -u | crontab -
    fi
    log_message "✅ Script is correctly scheduled in cron."
}

# Ensure configuration file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    log_message "❌ Error: Configuration file $CONFIG_FILE not found!"
    exit 1
fi

log_message "🔄 Starting network device monitoring script..."

# Initial Setup
check_and_install_tools
setup_logs
check_cron_job

# Ensure the database script exists before running it
if [[ ! -f "$CREATE_DB_SCRIPT" ]]; then
    handle_error "Database creation script $CREATE_DB_SCRIPT not found!"
fi

log_message "📂 Running database creation script..."
#bash "$CREATE_DB_SCRIPT"

# Validate database file existence
if [[ ! -f "$DB_PATH" ]]; then
    handle_error "Database file $DB_PATH not found!"
fi

log_message "📂 Database file found: $DB_PATH"

# Function to send notifications via Pushover
send_notification() {
    local title="$1"
    local message="$2"

    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_message "❌ Error: Encrypted Pushover configuration file not found!"
        return 1
    fi

    # Retrieve encryption key securely
    get_encryption_key() {
        ENCRYPTION_KEY=$(gpg --decrypt ~/.network_monitor_key.gpg 2>/dev/null) || {
            read -s -p "❌ GPG decryption failed! Enter encryption key manually: " ENCRYPTION_KEY
            echo
        }
    }

    # Execute the function to store ENCRYPTION_KEY
    get_encryption_key

    # Create a temporary file to store the encryption key
    KEY_FILE=$(mktemp)
    echo -n "$ENCRYPTION_KEY" > "$KEY_FILE"

    # Decrypt Pushover credentials
    DECRYPTED_CONFIG=$(openssl enc -aes-256-cbc -d -pbkdf2 -in "$CONFIG_FILE" -pass file:"$KEY_FILE" 2>/dev/null)

    # Remove the temporary file for security
    rm -f "$KEY_FILE"

    # Check if decryption was successful
    if [[ -z "$DECRYPTED_CONFIG" ]]; then
        log_message "❌ Error: Failed to decrypt Pushover credentials!"
        return 1
    fi

    # Extract API credentials from the decrypted config
    USER_KEY=$(echo "$DECRYPTED_CONFIG" | awk -F= '/^USER_KEY/ {print $2}')
    API_TOKEN=$(echo "$DECRYPTED_CONFIG" | awk -F= '/^API_TOKEN/ {print $2}')

    # Check if credentials are missing
    if [[ -z "$USER_KEY" || -z "$API_TOKEN" ]]; then
        log_message "❌ Error: Missing Pushover API credentials!"
        return 1
    fi

    # Send notification using Pushover API
    curl -s --form-string "token=$API_TOKEN" \
        --form-string "user=$USER_KEY" \
        --form-string "title=$title" \
        --form-string "message=$message" \
        https://api.pushover.net/1/messages.json

    log_message "📩 Pushover notification sent: $title - $message"
}

# Validate table existence
if ! sqlite3 "$DB_PATH" "SELECT 1 FROM devices LIMIT 1;" &>/dev/null; then
    handle_error "Table 'devices' does not exist in $DB_PATH!"
fi

log_message "🔄 Checking devices in the database..."
sqlite3 "$DB_PATH" "SELECT id, ipv4, status FROM devices" | while IFS='|' read -r id ip status; do
    log_message "🔍 Checking device: ID=$id, IP=$ip, Current Status=$status"
    
    if ping -c 2 -w 5 "$ip" &>/dev/null; then
        new_status="Online"
        log_message "✅ Device $ip is online."
    else
        new_status="Offline"
        log_message "❌ Device $ip is offline."
    fi

    if [[ "$status" != "$new_status" ]]; then
        log_message "🔄 Status change detected for device $ip: $status ➡ $new_status"
        sqlite3 "$DB_PATH" "UPDATE devices SET status='$new_status' WHERE id=$id" || handle_error "Failed to update device status."
        send_notification "Device Status Changed" "Device $ip changed to $new_status"
    else
        log_message "ℹ️ No status change detected for device $ip."
    fi

done

log_message "🎉 Network monitoring script completed successfully."
