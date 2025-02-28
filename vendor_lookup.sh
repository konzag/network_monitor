#!/bin/bash
set -e  # Stop on error
#set -x  # Enable debug mode (show commands being executed)

# Define file paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_FILE="$SCRIPT_DIR/network_devices.db"
LOG_DIR="$SCRIPT_DIR/Logs"
LOG_FILE="$LOG_DIR/vendor_update.log"

# Required tools
REQUIRED_TOOLS=("sqlite3" "awk" "date")

# Function to check and install required tools
check_and_install_tools() {
    for tool in "${REQUIRED_TOOLS[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_message "⚠️  $tool not found!"
            if [[ $EUID -ne 0 ]]; then
                log_message "⚠️  Run this script as root (sudo) to install missing packages."
                exit 1
            fi
            log_message "Installing $tool..."
            apt update && apt install -y "$tool"
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

log_message "🔄 Starting vendor update script..."

# Initial Setup
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
fi

log_message "✅ Database is not locked."

# Check if database is writable
if [[ ! -w "$DB_FILE" ]]; then
    handle_error "Database file is read-only. Check permissions!"
fi

log_message "✅ Database file is writable."

# Check if tables exist
TABLES=("oui_data" "devices" "device_status_history")
for table in "${TABLES[@]}"; do
    if ! sqlite3 "$DB_FILE" "SELECT name FROM sqlite_master WHERE type='table' AND name='$table';" | grep -q "$table"; then
        handle_error "Table '$table' does not exist in database!"
    fi
    log_message "✅ Table '$table' exists."

    # Check if vendor column exists, if not, create it
    if ! sqlite3 "$DB_FILE" "PRAGMA table_info($table);" | awk -F'|' '$2 == "vendor" {print $2}' | grep -q "vendor"; then
        log_message "Adding missing 'vendor' column to '$table' table."
        sqlite3 "$DB_FILE" "ALTER TABLE $table ADD COLUMN vendor TEXT;"
    else
        log_message "✅ Column 'vendor' already exists in '$table'."
    fi

done

# Function to update vendor information for a given table
update_vendor_info() {
    local table=$1
    log_message "🔄 Fetching MAC addresses from $table table..."
    MAC_LIST=$(sqlite3 "$DB_FILE" "SELECT mac FROM $table;")

    if [[ -z "$MAC_LIST" ]]; then
        handle_error "No MAC addresses found in $table table!"
    fi

    log_message "✅ Found $(echo "$MAC_LIST" | wc -l) MAC addresses to process in $table."

    # Process each MAC address
    while IFS= read -r mac; do
        log_message "🔍 Processing MAC address: $mac for table $table"

        # Extract OUI (first 6 digits, without ':')
        OUI=$(echo "$mac" | awk -F: '{print toupper($1$2$3)}')
        log_message "🔢 Extracted OUI: $OUI"

        # Find vendor from oui_data table
        VENDOR=$(sqlite3 "$DB_FILE" "SELECT vendor FROM oui_data WHERE prefix = '$OUI';")

        # If vendor not found, set as "Unknown"
        if [[ -z "$VENDOR" ]]; then
            VENDOR="Unknown"
            log_message "⚠️  Vendor not found for OUI $OUI. Setting as 'Unknown'."
        else
            log_message "✅ Found vendor: $VENDOR"
        fi

        # Update table with vendor
        sqlite3 "$DB_FILE" "UPDATE $table SET vendor = '$VENDOR' WHERE mac = '$mac';"
        log_message "✔ Updated $mac -> $VENDOR in $table"

    done <<< "$MAC_LIST"
}

# Update vendor info for both tables
update_vendor_info "devices"
update_vendor_info "device_status_history"

log_message "🎉 SUCCESS: Vendor lookup completed successfully."

exit 0
