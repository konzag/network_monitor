#!/bin/bash
set -x  # Ενεργοποίηση debug mode

# 1. Δημιουργία αρχείου known_hosts
KNOWN_HOSTS_FILE="/path/to/known_hosts"
if [ ! -f "$KNOWN_HOSTS_FILE" ]; then
    touch "$KNOWN_HOSTS_FILE"
    echo "Το αρχείο known_hosts δημιουργήθηκε: $KNOWN_HOSTS_FILE"
else
    echo "Το αρχείο known_hosts υπάρχει ήδη: $KNOWN_HOSTS_FILE"
fi

# 2. Ρώτηση για API Token και User Key
echo "Παρακαλώ εισάγετε το API Token του Pushover:"
read -r API_TOKEN
echo "Παρακαλώ εισάγετε το User Key του Pushover:"
read -r USER_KEY

# 3. Αποθήκευση σε κρυπτογραφημένο αρχείο
CONFIG_FILE="/home/pi/.config/pushover_config.enc"
echo "API_TOKEN=$API_TOKEN" > /tmp/pushover_config.tmp
echo "USER_KEY=$USER_KEY" >> /tmp/pushover_config.tmp

# Κρυπτογράφηση του αρχείου με openssl
openssl enc -aes-256-cbc -salt -in /tmp/pushover_config.tmp -out "$CONFIG_FILE" -pass pass:mysecretpassword
rm /tmp/pushover_config.tmp

echo "Τα στοιχεία αποθηκεύτηκαν κρυπτογραφημένα στο: $CONFIG_FILE"

# 4. Ρώτηση για το δίκτυο
echo "Παρακαλώ εισάγετε το δίκτυο που θέλετε να παρακολουθείτε (π.χ. 192.168.1.0/24):"
read -r NETWORK

# Αποθήκευση του δικτύου σε αρχείο
echo "$NETWORK" > /path/to/network_config
echo "Το δίκτυο αποθηκεύτηκε: $NETWORK"

# 5. Ορισμός δικαιωμάτων
chmod 600 "$CONFIG_FILE"
chmod 600 "$KNOWN_HOSTS_FILE"
chmod 600 /path/to/network_config

echo "Τα δικαιώματα ορίστηκαν σωστά."

# 6. Εκτέλεση του κύριου script
echo "Εκτέλεση του κύριου script..."
/path/to/network_monitor.sh
