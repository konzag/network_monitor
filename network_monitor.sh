#!/bin/bash
set -x  # Ενεργοποίηση debug mode
# 1. Φόρτωση κρυπτογραφημένων ρυθμίσεων Pushover
CONFIG_FILE="/home/pi/.config/pushover_config.enc"
if [ -f "$CONFIG_FILE" ]; then
    DECRYPTED_CONFIG=$(openssl enc -d -aes-256-cbc -in "$CONFIG_FILE" -pass pass:mysecretpassword)
    eval "$DECRYPTED_CONFIG"
else
    echo "Error: Pushover config file not found!"
    exit 1
fi

# 2. Φόρτωση του δικτύου
NETWORK_CONFIG="/path/to/network_config"
if [ -f "$NETWORK_CONFIG" ]; then
    NETWORK=$(cat "$NETWORK_CONFIG")
else
    echo "Error: Network config file not found!"
    exit 1
fi

# 3. Αρχείο γνωστών συσκευών
KNOWN_HOSTS_FILE="/path/to/known_hosts"

# 4. Εντοπισμός συσκευών με Nmap
nmap -sn $NETWORK -oG - | awk '/Up$/{print $2, $3}' > /tmp/current_devices.txt

# 5. Σύγκριση με τις γνωστές συσκευές
while read -r ip mac; do
    if ! grep -q "$mac" "$KNOWN_HOSTS_FILE"; then
        # Νέα συσκευή
        manufacturer=$(curl -s "https://api.macvendors.com/$mac")
        message="Νέα συσκευή συνδέθηκε: $mac ($manufacturer) - IP: $ip"
        echo "$mac $ip" >> "$KNOWN_HOSTS_FILE"

        # Ειδοποίηση στο desktop
        notify-send "Νέα συσκευή" "$message"

        # Ειδοποίηση στο Android μέσω Pushover
        curl -s --form-string "token=$API_TOKEN" --form-string "user=$USER_KEY" --form-string "message=$message" https://api.pushover.net/1/messages.json
    fi
done < /tmp/current_devices.txt

# 6. Έλεγχος για αποσυνδεδεμένες συσκευές
while read -r mac ip; do
    if ! grep -q "$mac" /tmp/current_devices.txt; then
        # Αποσυνδεδεμένη συσκευή
        manufacturer=$(curl -s "https://api.macvendors.com/$mac")
        message="Η συσκευή αποσυνδέθηκε: $mac ($manufacturer) - IP: $ip"

        # Ειδοποίηση στο desktop
        notify-send "Αποσυνδέθηκε συσκευή" "$message"

        # Ειδοποίηση στο Android μέσω Pushover
        curl -s --form-string "token=$API_TOKEN" --form-string "user=$USER_KEY" --form-string "message=$message" https://api.pushover.net/1/messages.json

        # Αφαίρεση από τη λίστα γνωστών συσκευών
        sed -i "/$mac/d" "$KNOWN_HOSTS_FILE"
    fi
done < "$KNOWN_HOSTS_FILE"
