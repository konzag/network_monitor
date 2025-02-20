#!/bin/bash
set -x  # Ενεργοποίηση debug mode

CONFIG_DIR="/home/pi/.config"
CONFIG_FILE="$CONFIG_DIR/pushover_config.enc"
KNOWN_HOSTS_FILE="/home/pi/.config/known_hosts"
NETWORK_CONFIG="/home/pi/.config/network_config"

# Βεβαιώσου ότι το config directory υπάρχει
mkdir -p "$CONFIG_DIR"

# Ζήτα από τον χρήστη τα API Token & User Key
read -p "Enter your Pushover API Token: " API_TOKEN
read -p "Enter your Pushover User Key: " USER_KEY

# Κρυπτογράφηση των credentials
echo "API_TOKEN=\"$API_TOKEN\"" > /tmp/pushover_config
echo "USER_KEY=\"$USER_KEY\"" >> /tmp/pushover_config
openssl enc -aes-256-cbc -salt -in /tmp/pushover_config -out "$CONFIG_FILE" -pass pass:mysecretpassword
rm /tmp/pushover_config

echo "Pushover credentials saved securely."

# Ζήτα από τον χρήστη το δίκτυο που θα σαρώνεται
read -p "Enter the network to scan (e.g., 192.168.1.0/24): " NETWORK
echo "$NETWORK" > "$NETWORK_CONFIG"

# Δημιουργία αρχείου known_hosts αν δεν υπάρχει
touch "$KNOWN_HOSTS_FILE"

# Δώσε τα κατάλληλα δικαιώματα
chmod 600 "$CONFIG_FILE"
chmod 644 "$KNOWN_HOSTS_FILE"
chmod 644 "$NETWORK_CONFIG"

echo "Setup complete. You can now run ./network_monitor.sh"

