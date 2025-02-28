#!/bin/bash
set -e  # Stop script on error
#set -x  # Enable debug mode (show commands being executed)

# Define file paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_FILE="$SCRIPT_DIR/network_devices.db"
LOG_DIR="$SCRIPT_DIR/Logs"
LOG_FILE="$LOG_DIR/device_scan.log"

# Required tools
REQUIRED_TOOLS=("sqlite3" "ip" "nmap" "python3")

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

log_message "🔄 Starting create device list script..."

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
else
    log_message "✅ Database is not locked."
fi

# Check if database is writable
if [[ ! -w "$DB_FILE" ]]; then
    handle_error "Database file is read-only. Check permissions!"
fi

log_message "✅ Database file is writable."

# Create the database if it does not exist
log_message "📂 Checking database: $DB_FILE"
sqlite3 "$DB_FILE" <<EOF || handle_error "Failed to create/access SQLite database"
PRAGMA synchronous=OFF;
CREATE TABLE IF NOT EXISTS devices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ipv4 TEXT NOT NULL,
    mac TEXT UNIQUE NOT NULL ON CONFLICT IGNORE
);
EOF

log_message "✅ Database initialized successfully."

# Detect all available subnets
log_message "🔎 Detecting available subnets..."
SUBNETS=$(ip -o -4 addr show | awk '{print $4}')
log_message "🌍 Detected subnets: $SUBNETS"
if [[ -z "$SUBNETS" ]]; then
    handle_error "No valid subnet detected."
fi

# Perform ARP scan
log_message "🔎 Performing ARP scan..."
ARP_DEVICES=$(arp -an | awk '{print $2, $4}' | sed 's/[()]//g' | grep -v "incomplete" | sort -u)
log_message "ℹ️ ARP scan output: $ARP_DEVICES"

if [[ -n "$ARP_DEVICES" ]]; then
    echo "$ARP_DEVICES" | awk '
    NF == 2 && $1 != "" && $2 != "" {
        printf "INSERT INTO devices (ipv4, mac) VALUES (\"%s\", \"%s\") ON CONFLICT(mac) DO UPDATE SET ipv4=excluded.ipv4;\n", $1, $2
    }' | sqlite3 "$DB_FILE"
    log_message "✅ ARP scan complete. Entries updated."
else
    log_message "⚠️ No valid ARP devices found. Ensure devices are active and connected."
fi

# Perform Nmap scan
log_message "🔍 Running Nmap scan..."
if [[ $EUID -eq 0 ]]; then
    NMAP_OUTPUT=$(nmap -sn "$SUBNETS" | awk '/Nmap scan report/{ip=$NF} /MAC Address/{print ip, $3}')
else
    log_message "⚠️ Running Nmap without root privileges may not detect all devices."
    NMAP_OUTPUT=$(nmap -sn "$SUBNETS" --unprivileged | awk '/Nmap scan report/{ip=$NF} /MAC Address/{print ip, $3}')
fi
log_message "ℹ️ Nmap scan output: $NMAP_OUTPUT"

if [[ -n "$NMAP_OUTPUT" ]]; then
    echo "$NMAP_OUTPUT" | awk '
    NF == 2 && $1 != "" && $2 != "" {
        printf "INSERT INTO devices (ipv4, mac) VALUES (\"%s\", LOWER(\"%s\")) ON CONFLICT(mac) DO UPDATE SET ipv4=excluded.ipv4;\n", $1, $2
    }' | sqlite3 "$DB_FILE"
    log_message "✅ Nmap scan complete."
else
    log_message "⚠️ Nmap scan found no devices."
fi

# Remove duplicate MAC entries
log_message "🔄 Checking and removing duplicate MAC entries..."
sqlite3 "$DB_FILE" "DELETE FROM devices WHERE id NOT IN (SELECT MIN(id) FROM devices GROUP BY mac);"

log_message "✅ Duplicate MAC entries removed."

log_message "🎉 Network device list has been successfully updated!"

exit 0
