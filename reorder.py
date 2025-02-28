import sqlite3
import ipaddress
import logging
import os
import sys
import subprocess

# ✅ Debug mode toggle
DEBUG_MODE = False  # Set to False to disable debug messages

print("🔍 reorder.py script started.", file=sys.stderr)  # Print stderr for logs

def check_and_install_packages():
    """
    Checks and installs required packages if missing.
    """
    required_modules = ["sqlite3", "ipaddress", "logging", "os"]
    for module in required_modules:
        try:
            __import__(module)
            logging.debug(f"✅ Module {module} is already installed.")
        except ImportError:
            print(f"⚠️ Module {module} not found. Attempting to install...")
            subprocess.run([sys.executable, "-m", "pip", "install", module], check=True)
            logging.info(f"✅ Module {module} installed successfully.")

def setup_logger():
    """
    Sets up the logging configuration to log both to a file and to the console.
    """
    logs_folder = "Logs"
    if not os.path.exists(logs_folder):
        os.makedirs(logs_folder)
    log_file = os.path.join(logs_folder, "reorder.log")

    log_level = logging.DEBUG if DEBUG_MODE else logging.INFO  # 🛠️ Enable debug logging if needed

    # Create logger
    logger = logging.getLogger()
    logger.setLevel(log_level)

    # Log format
    formatter = logging.Formatter("%(asctime)s - %(levelname)s - %(message)s")

    # **File Handler** (Save logs to a file)
    file_handler = logging.FileHandler(log_file)
    file_handler.setFormatter(formatter)
    logger.addHandler(file_handler)

    # **Stream Handler** (Print logs to terminal)
    console_handler = logging.StreamHandler(sys.stdout)  # Print to stdout
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)

    logging.info("Logger initialized.")
    if DEBUG_MODE:
        print("🛠️ Debug mode is ON.")

def normalize_database(db_path):
    """
    Normalizes the database by sorting devices based on their IPv4 addresses
    and updating their IDs sequentially.
    """
    logging.info("Starting database normalization process.")
    if not os.path.exists(db_path):
        print("❌ Database file not found! Please check the path and try again.")
        logging.error("Database file '%s' not found.", db_path)
        return

    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()

        logging.debug("Connected to database successfully.")
        
        # Retrieve column names
        cursor.execute("PRAGMA table_info(devices)")
        columns = cursor.fetchall()
        column_names = [col[1] for col in columns]  # Extract column names
        logging.info("Table structure retrieved: %s", column_names)

        if DEBUG_MODE:
            print(f"📊 Table Columns: {column_names}")

        # Find the index of the IPv4 column dynamically
        ipv4_column = next((col for col in column_names if "ipv4" in col.lower()), None)
        if not ipv4_column:
            print("❌ Could not find an IPv4 column in the table.")
            logging.error("IPv4 column not found in devices table.")
            return

        logging.debug("Found IPv4 column: %s", ipv4_column)

        # Fetch all device records
        cursor.execute(f"SELECT * FROM devices")
        devices = cursor.fetchall()

        if not devices:
            print("⚠️ No devices found in the database.")
            logging.warning("No devices found in the database.")
            return

        logging.info("Found %d devices. Sorting and updating...", len(devices))

        # Get the index of the IPv4 column
        ipv4_index = column_names.index(ipv4_column)

        # Sort devices by IPv4 address
        try:
            devices_sorted = sorted(devices, key=lambda x: ipaddress.ip_address(x[ipv4_index]))
            logging.debug("Devices sorted successfully.")
        except ValueError as e:
            print("❌ Error sorting IP addresses. Ensure all IPv4 values are valid.")
            logging.error("IP sorting error: %s", e)
            return

        if DEBUG_MODE:
            print(f"🛠️ First sorted device: {devices_sorted[0]}")

        logging.info("First row after sorting: %s", str(devices_sorted[0]))

        # Update the IDs sequentially while keeping all other columns unchanged
        updated_devices = [(idx + 1, *device[1:]) for idx, device in enumerate(devices_sorted)]
        logging.debug("ID reassignment completed.")

        # Clear table before inserting updated records
        cursor.execute("DELETE FROM devices")
        query = f"INSERT INTO devices ({', '.join(column_names)}) VALUES ({', '.join(['?'] * len(column_names))})"
        cursor.executemany(query, updated_devices)
        logging.info("New data inserted successfully.")

        conn.commit()
        conn.close()

        print("✅ Database successfully reordered and updated.")
        logging.info("Database successfully reordered and updated.")

    except sqlite3.Error as e:
        print("❌ An error occurred while processing the database.")
        logging.error("SQLite error: %s", e)
        if DEBUG_MODE:
            print(f"🛠️ SQLite Error: {e}")

    except Exception as e:
        print("❌ Unexpected error occurred.")
        logging.error("Unexpected error: %s", e)
        if DEBUG_MODE:
            print(f"🛠️ Unexpected Error: {e}")

# Check dependencies and setup logging
check_and_install_packages()
setup_logger()

# Automatically run the database normalization
normalize_database("network_devices.db")
