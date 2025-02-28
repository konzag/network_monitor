#!/bin/bash
set -e  # Stop script on error
#set -x  # Enable debug mode (show commands being executed)

# Define file paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_FILE="$SCRIPT_DIR/network_devices.db"
LOG_DIR="$SCRIPT_DIR/Logs"
LOG_FILE="$LOG_DIR/check_status.log"

# Required tools
REQUIRED_TOOLS=("sqlite3" "ip" "ping")

# Function to check and install required tools
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

log_message "🔄 Starting create device status list script..."

# Initial Setup
log_message "🚀 Starting network scan script."
check_and_install_tools
setup_logs

# Check if database exists
if [[ ! -f "$DB_FILE" ]]; then
    handle_error "Database file $DB_FILE not found!"
fi

log_message "✅ Database file exists: $DB_FILE"

# Check if the database is locked
if fuser "$DB_FILE" >/dev/null 2>&1; then
    handle_error "Database is locked by another process."
else
    log_message "✅ Database is not locked."
fi

# Check if database is writable
if [[ ! -w "$DB_FILE" ]]; then
    handle_error "Database file is read-only. Check permissions!"
fi

log_message "✅ Database file is writable."

# Check if tables exist
TABLES=("devices" "device_status_history")
for table in "${TABLES[@]}"; do
    if ! sqlite3 "$DB_FILE" "SELECT name FROM sqlite_master WHERE type='table' AND name='$table';" | grep -q "$table"; then
        log_message "🚀 Creating missing table: $table"
        if [[ "$table" == "device_status_history" ]]; then
            sqlite3 "$DB_FILE" "CREATE TABLE device_status_history (id INTEGER PRIMARY KEY AUTOINCREMENT, ipv4 TEXT, mac TEXT, vendor TEXT, previous_status TEXT, new_status TEXT, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP);"
        else
            handle_error "Table '$table' does not exist in database!"
        fi
    fi
    log_message "✅ Table '$table' exists."

done

# Check if status column exists, if not, create it
if ! sqlite3 "$DB_FILE" "PRAGMA table_info(devices);" | awk -F'|' '$2 == "status" {print $2}' | grep -q "status"; then
    log_message "Adding missing 'status' column to 'devices' table."
    sqlite3 "$DB_FILE" "ALTER TABLE devices ADD COLUMN status TEXT;"
else
    log_message "✅ Column 'status' already exists."
fi

# Retrieve all IPs from the 'devices' table
log_message "🔄 Fetching IP addresses from devices table..."
DEVICE_LIST=$(sqlite3 "$DB_FILE" "SELECT id, ipv4 FROM devices;")

# Check connectivity for each device
while IFS='|' read -r ID IP; do
    if [[ -z "$ID" || -z "$IP" ]]; then
        continue # Skip empty lines
    fi

    # Use the ping command to check if the device is active
    if ping -c 1 -W 1 "$IP" > /dev/null 2>&1; then
        STATUS="Online"
    else
        STATUS="Offline"
    fi

    # Update the database with the device's status
    sqlite3 "$DB_FILE" "UPDATE devices SET status='$STATUS' WHERE id=$ID;"
    log_message "Device with IP $IP is $STATUS"

    # Log status change in history table
    if [[ "$PREV_STATUS" != "$STATUS" ]]; then
        sqlite3 "$DB_FILE" "INSERT INTO device_status_history (ipv4, mac, vendor, previous_status, new_status) VALUES ('$IP', '$MAC', '$VENDOR', '$PREV_STATUS', '$STATUS');"
        log_message "📊 Status change logged for device with IP $IP."
    fi

done <<< "$DEVICE_LIST"