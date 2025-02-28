Network Monitoring Scripts

📌 Overview

This repository contains various scripts designed to monitor network devices, check their connectivity status, update vendor information using OUI databases, and manage a network monitoring database.

📂 Project Structure

network_monitor/
│── create_device_list_db.sh     # Creates and initializes the SQLite database
│── setup_status.sh              # Checks and updates the status of devices
│── monitor_status.sh            # Monitors network devices and sends alerts
│── vendor_lookup.sh             # Updates vendor information based on MAC addresses
│── oui_update.sh                # Downloads and updates OUI database
│── reorder.py                   # Reorders the database for better readability
│── create_config_file.sh        # Encrypts configuration files
│── run_all.sh                   # Executes all scripts in sequence
│── exported_scripts.txt         # Contains exported versions of all scripts
│── Logs/                        # Directory for log files
│── network_devices.db           # SQLite database storing network device data

🛠️ Prerequisites

Ensure that the following dependencies are installed on your system:

sqlite3

ip

ping

nmap

python3

openssl

gpg

crontab

curl

To install missing dependencies, run:

sudo apt update && sudo apt install -y sqlite3 iputils-ping nmap python3 openssl gpg curl

🚀 Installation & Setup

Clone the repository:

git clone https://github.com/yourusername/network_monitor.git
cd network_monitor

Run the setup script:

bash create_device_list_db.sh

This will create the network_devices.db file and initialize the necessary tables.

Update the OUI database:

bash oui_update.sh

This will download and update the vendor MAC address database.

Schedule network monitoring in cron:

crontab -e

Add the following line to execute monitoring every 3 minutes:

*/3 * * * * /path/to/network_monitor/monitor_status.sh

📊 Usage

1️⃣ Check Device Status

bash setup_status.sh

This script checks the connectivity status of devices stored in the database.

2️⃣ Monitor Network Devices

bash monitor_status.sh

Runs network checks and logs device status changes.

3️⃣ Update Vendor Information

bash vendor_lookup.sh

Fetches vendor details based on MAC addresses and updates the database.

4️⃣ Reorder Database Entries

python3 reorder.py

Sorts devices by IP address for better organization.

5️⃣ Run All Scripts in Order

bash run_all.sh

Executes all scripts sequentially to ensure a full update cycle.

📜 Logging

All logs are stored in the Logs/ directory for easy debugging and tracking script execution.
To view logs:

tail -f Logs/*.log

🔐 Secure Configuration

To encrypt configuration files containing sensitive information:

bash create_config_file.sh

🤖 Automating Updates

You can automate OUI database updates by adding the following to your cron jobs:

0 0 1 * * /path/to/network_monitor/oui_update.sh

This will update the OUI database on the first day of every month.

📌 License

This project is licensed under the MIT License.

✉️ Support

For issues or improvements, open an issue on GitHub or contact the maintainer.

📢 Developed by me

