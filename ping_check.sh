#!/bin/bash

# File paths
IP_DATA_FILE="ip_data.json"
STATUS_FILE="status.json"
LAST_ONLINE_FILE="last_online.json"
UPTIME_FILE="uptime.json"
ORDER_FILE="ip_order.json"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

# --- Load and preserve IP order ---
declare -a ORDERED_IPS

# Load existing order if available
if [[ -f "$ORDER_FILE" ]]; then
  mapfile -t ORDERED_IPS < <(jq -r '.[]' "$ORDER_FILE")
fi

# Add new IPs from ip_data.json to order list (if missing)
while read -r ip; do
  if ! printf '%s\n' "${ORDERED_IPS[@]}" | grep -qx "$ip"; then
    ORDERED_IPS+=("$ip")
  fi
done < <(jq -r '.[].ip' "$IP_DATA_FILE")

# Save updated IP order
printf '%s\n' "${ORDERED_IPS[@]}" | jq -R . | jq -s . > "$ORDER_FILE"

# --- Load last_online data ---
declare -A LAST_ONLINE
if [[ -s "$LAST_ONLINE_FILE" ]]; then
  if jq -e . "$LAST_ONLINE_FILE" > /dev/null 2>&1; then
    while read -r line; do
      ip=$(echo "$line" | cut -d= -f1)
      timestamp=$(echo "$line" | cut -d= -f2-)
      LAST_ONLINE["$ip"]="$timestamp"
    done < <(jq -r '.[] | "\(.ip)=\(.last_online)"' "$LAST_ONLINE_FILE")
  fi
fi

# --- Load uptime data ---
declare -A TOTAL_CHECKS ONLINE_CHECKS
if [[ -s "$UPTIME_FILE" ]]; then
  if jq -e . "$UPTIME_FILE" > /dev/null 2>&1; then
    while read -r line; do
      ip=$(echo "$line" | cut -d= -f1)
      total=$(echo "$line" | cut -d= -f2 | cut -d, -f1)
      online=$(echo "$line" | cut -d= -f2 | cut -d, -f2)
      TOTAL_CHECKS["$ip"]=$total
      ONLINE_CHECKS["$ip"]=$online
    done < <(jq -r '.[] | "\(.ip)=\(.total_checks),\(.online_checks)"' "$UPTIME_FILE")
  fi
fi

# --- Ping check function ---
check_ip() {
  local ip="$1"
  local desc="$2"
  local file="$3"

  local output latency status last_seen total online uptime

  output=$(ping -c 4 -W 1 "$ip" 2>/dev/null)
  if [[ $? -eq 0 ]]; then
    status="online"
    latency=$(echo "$output" | awk -F'/' '/^rtt/ { print $5 }')
  else
    status="offline"
    latency="N/A"
  fi

  last_seen="${LAST_ONLINE[$ip]:-Never}"
  total=${TOTAL_CHECKS[$ip]:-0}
  online=${ONLINE_CHECKS[$ip]:-0}
  if [[ "$total" =~ ^[0-9]+$ && "$online" =~ ^[0-9]+$ && $total -gt 0 ]]; then
    uptime=$(echo "scale=1; 100 * $online / $total" | bc)
  else
    uptime="0.0"
  fi

  cat <<EOF > "$file"
{
  "ip": "$ip",
  "description": "$desc",
  "status": "$status",
  "checked_at": "$DATE",
  "last_online": "$last_seen",
  "uptime": "$uptime",
  "latency": "$latency"
}
EOF
}

# --- Run parallel checks ---
# Build map of descriptions for all IPs
declare -A DESCRIPTIONS
while read -r entry; do
  ip=$(echo "$entry" | jq -r '.ip')
  desc=$(echo "$entry" | jq -r '.description')
  DESCRIPTIONS["$ip"]="$desc"
done < <(jq -c '.[]' "$IP_DATA_FILE")

# Run checks in parallel
for ip in "${ORDERED_IPS[@]}"; do
  desc="${DESCRIPTIONS[$ip]}"
  tmpfile="$TMP_DIR/$ip.json"
  check_ip "$ip" "$desc" "$tmpfile" &
done

wait

# --- Process results and update uptime + last_online ---
STATUS_JSON="["
index=0
for ip in "${ORDERED_IPS[@]}"; do
  file="$TMP_DIR/$ip.json"
  if [[ -f "$file" ]]; then
    status=$(jq -r '.status' "$file")

    # Update uptime tracking
    TOTAL_CHECKS["$ip"]=$(( ${TOTAL_CHECKS[$ip]:-0} + 1 ))
    if [[ "$status" == "online" ]]; then
      ONLINE_CHECKS["$ip"]=$(( ${ONLINE_CHECKS[$ip]:-0} + 1 ))
      LAST_ONLINE["$ip"]="$DATE"
    fi

    [[ $index -gt 0 ]] && STATUS_JSON+=","
    STATUS_JSON+="
$(cat "$file")"
    ((index++))
  fi
done
STATUS_JSON+="
]"
echo "$STATUS_JSON" > "$STATUS_FILE"

# --- Save last_online.json in original order ---
LAST_ONLINE_JSON="["
index=0
for ip in "${ORDERED_IPS[@]}"; do
  last_seen="${LAST_ONLINE[$ip]:-Never}"
  [[ $index -gt 0 ]] && LAST_ONLINE_JSON+=","
  LAST_ONLINE_JSON+="
  {
    \"ip\": \"$ip\",
    \"last_online\": \"$last_seen\"
  }"
  ((index++))
done
LAST_ONLINE_JSON+="
]"
echo "$LAST_ONLINE_JSON" > "$LAST_ONLINE_FILE"

# --- Save uptime.json in original order ---
UPTIME_JSON="["
index=0
for ip in "${ORDERED_IPS[@]}"; do
  total=${TOTAL_CHECKS[$ip]:-0}
  online=${ONLINE_CHECKS[$ip]:-0}
  [[ $index -gt 0 ]] && UPTIME_JSON+=","
  UPTIME_JSON+="
  {
    \"ip\": \"$ip\",
    \"total_checks\": $total,
    \"online_checks\": $online
  }"
  ((index++))
done
UPTIME_JSON+="
]"
echo "$UPTIME_JSON" > "$UPTIME_FILE"
