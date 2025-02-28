#!/bin/bash
set -e  # Stop script on errors
#set -x  # Enable debug mode (show commands being executed)

# Define file paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUI_DIR="$SCRIPT_DIR/oui_db"
LOG_DIR="$SCRIPT_DIR/Logs"
LOG_FILE="$LOG_DIR/oui_update.log"
IEEE_OUI_FILE="$OUI_DIR/IEEE_oui.txt"
NMAP_OUI_FILE="$OUI_DIR/Nmap_oui.txt"
DB_FILE="$SCRIPT_DIR/network_devices.db"

# Define OUI sources
declare -A OUI_SOURCES
OUI_SOURCES["IEEE"]="https://standards-oui.ieee.org/oui/oui.txt"
OUI_SOURCES["Nmap"]="https://raw.githubusercontent.com/nmap/nmap/master/nmap-mac-prefixes"

# Ensure required tools are installed
REQUIRED_TOOLS=("sqlite3")

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
        echo "📂 Creating Logs directory..."
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
    echo "❌ ERROR: $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1" >> "$LOG_FILE"
    exit 1
}

log_message "🚀 Starting oui update script."

# Initial Setup
check_and_install_tools
setup_logs

# Ensure OUI database directory exists
setup_oui_db() {
    if [[ ! -d "$OUI_DIR" ]]; then
        log_message "📂 Creating OUI database directory..."
        mkdir -p "$OUI_DIR"
        chmod 755 "$OUI_DIR"
    fi
}

# Ensure OUI files exist and update if older than 2 months
update_oui_files() {
    local source_name="$1"
    local source_url="$2"
    local file_path="$OUI_DIR/${source_name}_oui.txt"
    
    if [[ ! -f "$file_path" || $(find "$file_path" -mtime +60 -print) ]]; then
        log_message "🔄 Downloading $source_name OUI database..."
        curl -s -o "$file_path" "$source_url" || log_message "❌ Failed to download $source_name OUI database!"
        log_message "✅ $source_name OUI database updated successfully!"
    else
        log_message "ℹ️ $source_name OUI database is up to date."
    fi
}

# Updating OUI database
populate_oui_db() {
    
    log_message "🔄 Updating OUI database..."

    # Ensure the database and tables exist
    sqlite3 "$DB_FILE" "CREATE TABLE IF NOT EXISTS oui_data (prefix TEXT PRIMARY KEY, vendor TEXT);"

    # Delete old data
    sqlite3 "$DB_FILE" "DELETE FROM oui_data WHERE vendor LIKE '%(base 16)%';"

    # Insert IEEE OUI Data
    awk '/\(base 16\)/ {prefix=$1; vendor=$2; for (i=3; i<=NF; i++) vendor = vendor " " $i; gsub(/-/, "", prefix); gsub(/\(base 16\) /, "", vendor); print prefix "|" vendor;}' "$IEEE_OUI_FILE" | \
    while IFS="|" read -r prefix vendor; do
        vendor=$(echo "$vendor" | sed "s/'/''/g")  # Escape single quotes for SQL
        echo "📌 Inserting: $prefix - $vendor" | tee -a "$LOG_FILE"
        sqlite3 "$DB_FILE" "INSERT OR IGNORE INTO oui_data (prefix, vendor) VALUES ('$prefix', '$vendor');"
    done

    # Insert Nmap OUI Data
    awk 'NF>=2 {prefix=toupper($1); vendor=$2; for (i=3; i<=NF; i++) vendor = vendor " " $i; gsub(/\(base 16\) /, "", vendor); print prefix "|" vendor;}' "$NMAP_OUI_FILE" | \
    while IFS="|" read -r prefix vendor; do
        vendor=$(echo "$vendor" | sed "s/'/''/g")  # Escape single quotes for SQL
        echo "📌 Inserting: $prefix - $vendor" | tee -a "$LOG_FILE"
        sqlite3 "$DB_FILE" "INSERT OR IGNORE INTO oui_data (prefix, vendor) VALUES ('$prefix', '$vendor');"
    done

    log_message "✅ OUI database updated successfully!"
}

# Run all setup functions
setup_oui_db

for source in "${!OUI_SOURCES[@]}"; do
    update_oui_files "$source" "${OUI_SOURCES[$source]}"
done

populate_oui_db

log_message "🎉 SUCCESS: Vendor database updated successfully."

exit 0
