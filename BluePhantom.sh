#!/usr/bin/env bash
# BluePhantom v2.2 - Auto Bluetooth Connect & Record (Simplified)

VERSION="2.2"
PROFILES="$HOME/.bluephantom_profiles"
touch "$PROFILES"

# --- COLORS ---
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
RESET='\033[0m'

# --- BANNER ---
clear
cat <<'BANNER'
___.   .__                       .__                   __                  
\_ |__ |  |  __ __   ____ ______ |  |__ _____    _____/  |_  ____   _____  
 | __ \|  | |  |  \_/ __ \\____ \|  |  \\__  \  /    \   __\/  _ \ /     \ 
 | \_\ \  |_|  |  /\  ___/|  |_> >   Y  \/ __ \|   |  \  | (  <_> )  Y Y  \
 |___  /____/____/  \___  >   __/|___|  (____  /___|  /__|  \____/|__|_|  /
     \/                 \/|__|        \/     \/     \/                  \/ 
     
                  BluePhantom v2.2 - Auto Mode
BANNER
echo

# --- Dependency check ---
for dep in blueutil sox lame; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  $dep not found. Install with: brew install $dep${RESET}"
        exit 1
    fi
done

# --- SCAN & CHOOSE DEVICE ---
cmd_scan_and_select() {
    echo -e "${CYAN}🔍 Scanning nearby devices...${RESET}"
    mapfile -t devices < <(blueutil --inquiry | grep -E '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}')

    if [ ${#devices[@]} -eq 0 ]; then
        echo -e "${RED}❌ No Bluetooth devices found.${RESET}"
        return 1
    fi

    echo
    echo -e "${CYAN}📡 Found devices:${RESET}"
    for i in "${!devices[@]}"; do
        mac=$(echo "${devices[$i]}" | awk '{print $1}')
        name=$(echo "${devices[$i]}" | awk '{print substr($0,index($0,$2))}')
        echo "$((i+1)). $name -> $mac"
    done

    echo
    read -p "Enter the number of the device to connect: " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#devices[@]}" ]; then
        echo -e "${RED}⚠️ Invalid selection.${RESET}"
        return 1
    fi

    selected="${devices[$((choice-1))]}"
    mac=$(echo "$selected" | awk '{print $1}')
    name=$(echo "$selected" | awk '{print substr($0,index($0,$2))}')
    echo -e "${CYAN}🔌 Connecting to $name ($mac)...${RESET}"

    blueutil --connect "$mac"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Connected to $name${RESET}"
        echo "$name:$mac" > "$HOME/.bluephantom_last_device"
        start_recording "$name"
    else
        echo -e "${RED}❌ Connection failed.${RESET}"
    fi
}

# --- RECORD FUNCTION ---
start_recording() {
    local dev="$1"
    local fmt="wav"
    local fname="bluephantom_$(date +%Y%m%d_%H%M%S)"
    local output="$HOME/Desktop/$fname.$fmt"

    echo
    echo -e "${GREEN}🎙  Starting recording from \"$dev\"... (Ctrl+C to stop)${RESET}"
    echo -e "${YELLOW}Saving to: $output${RESET}"
    echo

    # Record using sox (CoreAudio input)
    sox -t coreaudio "$dev" "$output"
    rc=$?

    if [ $rc -eq 0 ]; then
        echo -e "${CYAN}✔ Recording finished: $output${RESET}"
    else
        echo -e "${RED}✖ Recording failed. Ensure device name matches CoreAudio input.${RESET}"
    fi
}

# --- MAIN ---
cmd_scan_and_select
echo
echo -e "${GREEN}✅ Done. You can run again anytime.${RESET}"
