#!/bin/bash

DEVICE_FILE="devices.txt"
ALERT_LOG="alerts_$(date +'%Y-%m-%d_%H-%M-%S').log"
EMAIL="you@example.com"
TMP_OUT="temp_output.txt"

echo " Running Extended Health Checks..."
> "$ALERT_LOG"

while read -r line; do
    IP=$(echo $line | awk '{print $1}')
    TYPE=$(echo $line | awk '{print $2}')
    USER_OR_COMMUNITY=$(echo $line | awk '{print $3}')
    PASS=$(echo $line | awk '{print $4}')
    METHOD=$(echo $line | awk '{print $5}')

    echo "📡 Checking $IP..."

    # Step 1: Ping check
    ping -c 2 "$IP" > /dev/null
    if [[ $? -ne 0 ]]; then
        echo " $IP is unreachable." >> "$ALERT_LOG"
        continue
    fi

    if [[ "$METHOD" == "ssh" ]]; then
        # Step 2: CPU load %
        CPU=$(sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no "$USER_OR_COMMUNITY@$IP" \
            "top -bn1 | grep 'Cpu(s)' | awk '{print 100 - \$8}'" 2>/dev/null)
        MEM_USED=$(sshpass -p "$PASS" ssh "$USER_OR_COMMUNITY@$IP" \
            "free | awk '/Mem:/ {printf(\"%.2f\", \$3/\$2 * 100)}'" 2>/dev/null)
        DISK_USED=$(sshpass -p "$PASS" ssh "$USER_OR_COMMUNITY@$IP" \
            "df / | awk 'NR==2 {gsub(\"%\", \"\", \$5); print \$5}'" 2>/dev/null)
        
        RAM_SIZE=$(sshpass -p "$PASS" ssh "$USER_OR_COMMUNITY@$IP" \
            "free -h | awk '/Mem:/ {print \$2}'" 2>/dev/null)
        CPU_MODEL=$(sshpass -p "$PASS" ssh "$USER_OR_COMMUNITY@$IP" \
            "lscpu | grep 'Model name' | awk -F ':' '{print \$2}'" 2>/dev/null)

        echo " $IP - CPU: ${CPU}% | MEM: ${MEM_USED}% | DISK: ${DISK_USED}% | RAM: $RAM_SIZE | CPU Model: $CPU_MODEL"

        if (( $(echo "$CPU > 85" | bc -l) )); then
            echo " High CPU usage on $IP: ${CPU}%" >> "$ALERT_LOG"
        fi
        if (( $(echo "$MEM_USED > 90" | bc -l) )); then
            echo " High Memory usage on $IP: ${MEM_USED}%" >> "$ALERT_LOG"
        fi
        if (( "$DISK_USED" > 90 )); then
            echo " High Disk usage on $IP: ${DISK_USED}%" >> "$ALERT_LOG"
        fi

    elif [[ "$METHOD" == "snmp" ]]; then
        # Step 3: SNMP version info
        echo " Running SNMP check on $IP"
        snmpget -v2c -c "$USER_OR_COMMUNITY" "$IP" 1.3.6.1.2.1.1.1.0 > "$TMP_OUT" 2>/dev/null

        if [[ $? -eq 0 ]]; then
            SYS_DESC=$(cat "$TMP_OUT" | cut -d'=' -f2- | sed 's/^ //')
            echo " $IP SNMP Description: $SYS_DESC" >> "$ALERT_LOG"
        else
            echo " SNMP failed on $IP" >> "$ALERT_LOG"
        fi
    fi

done < "$DEVICE_FILE"

# Step 4: Alert email if any issues
if [[ -s "$ALERT_LOG" ]]; then
    mail -s " Device Alert Report" "$EMAIL" < "$ALERT_LOG"
    echo " Alert sent to $EMAIL"
else
    echo " All systems healthy."
fi

rm -f "$TMP_OUT"
