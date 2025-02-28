#!/bin/bash

# Ενεργοποίηση αυστηρού mode για αποφυγή λαθών
set -e

# Καταγραφή logs για debugging
LOGFILE="script_execution.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "===== Εκκίνηση διαδικασίας ====="
echo "[$(date)] Ξεκινάει η εκτέλεση των scripts..."

# Εκτέλεση των scripts ένα προς ένα
SCRIPTS=(
    "create_device_list_db.sh"
    "setup_status.sh"
    "reorder.py"
    "vendor_lookup.sh"
    "monitor_status.sh"
)

for script in "${SCRIPTS[@]}"; do
    echo "[$(date)] Εκτελείται: $script..."
    
    # Ανάλογα με το αν είναι Bash ή Python script, το εκτελούμε σωστά
    if [[ "$script" == *.sh ]]; then
        bash "$script"
    elif [[ "$script" == *.py ]]; then
        python3 "$script"
    fi

    echo "[$(date)] Ολοκληρώθηκε: $script"
    echo "-------------------------"
done

echo "===== Η διαδικασία ολοκληρώθηκε επιτυχώς! ====="
