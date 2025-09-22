#!/bin/bash
#
# SMART monitor for /dev/sdb
# Logs changes in critical attributes, checks thresholds, and sends alerts
#

DEVICE="/dev/sda"
LOGFILE="/home/akshit/pi-home-server/scripts/logs/smart_monitor.log"
STATEFILE="/home/akshit/pi-home-server/scripts/logs/smart_monitor.state"
EMAIL="akshitv18@gmail.com"

# Attributes to monitor
# ID  Description
#  5  Reallocated_Sector_Ct
# 187 Reported_Uncorrect
# 188 Command_Timeout
# 193 Load_Cycle_Count
# 194 Temperature_Celsius
# 197 Current_Pending_Sector
# 198 Offline_Uncorrectable
# 199 UDMA_CRC_Error_Count
ATTRS="5 187 188 193 194 197 198 199"

# Thresholds (customize if needed)
MAX_TEMP=50          # Celsius
MAX_LOAD_INC=500     # Warn if Load_Cycle_Count increases >500 since last check
MAX_REALLOC=0        # Any >0 reallocated = alert
MAX_PENDING=0        # Any >0 pending = alert

SMART_DATA=$(smartctl -A "$DEVICE")
if [ $? -ne 0 ]; then
    echo "$(date): smartctl failed for $DEVICE" >> "$LOGFILE"
    exit 1
fi

if [ ! -f "$STATEFILE" ]; then
    touch "$STATEFILE"
fi

CHANGES=0
ALERT_MSG="SMART warnings for $DEVICE on $(date):\n"

for ID in $ATTRS; do
    VALUE=$(echo "$SMART_DATA" | awk -v id=$ID '$1 == id {print $10}')
    if [ -z "$VALUE" ]; then
        continue
    fi
    OLD=$(grep "^$ID " "$STATEFILE" | awk '{print $2}')

    # Detect changes
    if [ "$OLD" != "" ] && [ "$VALUE" != "$OLD" ]; then
        echo "$(date): Attribute $ID changed from $OLD to $VALUE" >> "$LOGFILE"
        ALERT_MSG+=" - Attribute $ID changed from $OLD to $VALUE\n"
        CHANGES=1
    fi

    # Threshold checks
    case $ID in
        5)  # Reallocated sectors
            if [ "$VALUE" -gt $MAX_REALLOC ]; then
                ALERT_MSG+=" - Reallocated sectors = $VALUE (danger!)\n"
                CHANGES=1
            fi
            ;;
        193) # Load_Cycle_Count
            if [ "$OLD" != "" ]; then
                DIFF=$((VALUE - OLD))
                if [ "$DIFF" -gt $MAX_LOAD_INC ]; then
                    ALERT_MSG+=" - Load_Cycle_Count increased by $DIFF (too frequent head parking)\n"
                    CHANGES=1
                fi
            fi
            ;;
        194) # Temperature
            if [ "$VALUE" -gt $MAX_TEMP ]; then
                ALERT_MSG+=" - Temperature high: ${VALUE}°C\n"
                CHANGES=1
            fi
            ;;
        197) # Current Pending
            if [ "$VALUE" -gt $MAX_PENDING ]; then
                ALERT_MSG+=" - Pending sectors = $VALUE (risk of failure)\n"
                CHANGES=1
            fi
            ;;
        198) # Offline Uncorrectable
            if [ "$VALUE" -gt 0 ]; then
                ALERT_MSG+=" - Offline uncorrectable sectors = $VALUE\n"
                CHANGES=1
            fi
            ;;
    esac

    # Update state file
    grep -v "^$ID " "$STATEFILE" > "$STATEFILE.tmp"
    echo "$ID $VALUE" >> "$STATEFILE.tmp"
    mv "$STATEFILE.tmp" "$STATEFILE"
done

if [ $CHANGES -eq 1 ]; then
    echo -e "$ALERT_MSG" >> "$LOGFILE"
    if command -v mail >/dev/null 2>&1; then
        echo -e "$ALERT_MSG" | mail -s "SMART Alert on $DEVICE" "$EMAIL"
    fi
fi
