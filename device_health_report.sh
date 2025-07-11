#!/bin/bash

# === CONFIG ===
DEVICE_FILE="devices.txt"
REPORT_FILE="health_report_$(date +'%Y-%m-%d_%H-%M-%S').csv"
EMAIL="you@example.com"
# ==============

echo "Hostname,IP,Uptime,CPU_Load(%),Memory_Used(%),Disk_Used(%),OS" > "$REPORT_FILE"

while read -r line; do
    IP=$(echo $line | awk '{print $1}')
    OS_TYPE=$(echo $line | awk '{print $2}')
    USER=$(echo $line | awk '{print $3}')
    PASS=$(echo $line | awk '{print $4}')

    echo " Connecting to $IP..."

    # Run health checks using SSH
    HOSTNAME=$(sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no "$USER@$IP" "hostname" 2>/dev/null)
    UPTIME=$(sshpass -p "$PASS" ssh "$USER@$IP" "uptime -p" 2>/dev/null)
    CPU_LOAD=$(sshpass -p "$PASS" ssh "$USER@$IP" "top -bn1 | grep 'Cpu(s)' | awk '{print 100 - \$8}'" 2>/dev/null)
    MEM_USED=$(sshpass -p "$PASS" ssh "$USER@$IP" "free | awk '/Mem:/ {printf(\"%.2f\", \$3/\$2 * 100)}'" 2>/dev/null)
    DISK_USED=$(sshpass -p "$PASS" ssh "$USER@$IP" "df -h / | awk 'NR==2 {gsub(\"%\", \"\", \$5); print \$5}'" 2>/dev/null)
    OS_NAME=$(sshpass -p "$PASS" ssh "$USER@$IP" "grep -oP '^PRETTY_NAME=\"\K[^\"]+' /etc/os-release" 2>/dev/null)

    # Save to CSV
    echo "$HOSTNAME,$IP,$UPTIME,$CPU_LOAD,$MEM_USED,$DISK_USED,$OS_NAME" >> "$REPORT_FILE"

done < "$DEVICE_FILE"

# Optional: Email the report
mail -s " Device Health Report" "$EMAIL" < "$REPORT_FILE"

echo " Report saved to $REPORT_FILE and sent to $EMAIL"
