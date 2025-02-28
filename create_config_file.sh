#!/bin/bash
set -e  # Stop script on error
#set -x  # Enable debug mode (show commands being executed)

# Define file paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/Logs"
LOG_FILE="$LOG_DIR/create_config.log"

# Required tools
REQUIRED_TOOLS=("gpg" "openssl")

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

# Retrieve encryption key securely
get_encryption_key() {
    ENCRYPTION_KEY=$(gpg --decrypt ~/.network_monitor_key.gpg 2>/dev/null) || {
        read -s -p "❌ GPG decryption failed! Enter encryption key manually: " ENCRYPTION_KEY
        echo
    }
}

# Prompt user for settings filename
get_config_name() {
    while [[ -z "$CONFIG_NAME" || "$CONFIG_NAME" =~ [^a-zA-Z0-9_-] ]]; do
        read -p "Enter a valid settings file name (letters, numbers, _ or - only): " CONFIG_NAME
    done
}

# Encrypt configuration file
encrypt_config() {
    if [[ -z "$ENCRYPTION_KEY" ]]; then
        log_message "❌ Error: Encryption key is empty!"
        exit 1
    fi

    TEMP_FILE=$(mktemp) || { log_message "❌ Error: Failed to create temp file!"; exit 1; }
    trap 'rm -f "$TEMP_FILE"' EXIT

    read -s -p "Enter the API Token: " API_TOKEN
    echo
    read -s -p "Enter the User Key: " USER_KEY
    echo

    echo "API_TOKEN=$API_TOKEN" > "$TEMP_FILE"
    echo "USER_KEY=$USER_KEY" >> "$TEMP_FILE"

    if ! openssl enc -aes-256-cbc -salt -pbkdf2 -in "$TEMP_FILE" -out "$CONFIG_FILE" -pass file:<(echo "$ENCRYPTION_KEY"); then
        log_message "❌ Error: Encryption failed!"
        exit 1
    fi

    log_message "✅ Configuration file encrypted: $CONFIG_FILE"
}

log_message "🔄 Starting script..."

# Initial Setup
check_and_install_tools
setup_logs
get_encryption_key
get_config_name

CONFIG_FILE="$SCRIPT_DIR/${CONFIG_NAME}.enc"

if [ -f "$CONFIG_FILE" ]; then
    log_message "ℹ️ Configuration file already exists: $CONFIG_FILE"
else
    log_message "Creating new encrypted configuration file..."
    encrypt_config
fi

log_message "🎉 Setup Completed Successfully"
