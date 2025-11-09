#!/usr/bin/env bash
# BluePhantom v2.1 - Auto-select connected Bluetooth & Record

VERSION="2.1"
PROFILES="$HOME/.bluephantom_profiles"
LAST_CONNECTED_DEVICE="$HOME/.bluephantom_last_device"
touch "$PROFILES" "$LAST_CONNECTED_DEVICE"

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
     
                BluePhantom v2.1 - @dailymycode
BANNER
echo

# --- Dependency check ---
for dep in blueutil sox lame; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  $dep not found. Install it with: brew install $dep${RESET}"
        exit 1
    fi
done

# --- Utilities ---
resolve_mac() {
    local key="$1"
    if [[ "$key" =~ ^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$ ]]; then
        echo "$key"
    else
        grep -E "^$key:" "$PROFILES" | cut -d':' -f2
    fi
}

save_profile() {
    local name="$1"
    local mac="$2"
    grep -vE "^$name:" "$PROFILES" > "$PROFILES.tmp" 2>/dev/null
    echo "$name:$mac" >> "$PROFILES.tmp"
    mv "$PROFILES.tmp" "$PROFILES"
    echo -e "${GREEN}💾 Saved profile '$name' -> $mac${RESET}"
}

list_profiles() {
    if [ ! -s "$PROFILES" ]; then
        echo "(no profiles saved)"
    else
        awk -F: '{print $1 " -> " $2}' "$PROFILES"
    fi
}

# --- Commands ---
cmd_scan() {
    echo -e "${CYAN}🔍 Nearby devices:${RESET}"
    i=1
    while read -r line; do
        mac=$(echo "$line" | awk '{print $1}')
        name=$(echo "$line" | awk '{print substr($0,index($0,$2))}')
        echo "$i) $name -> $mac"
        ((i++))
    done < <(blueutil --inquiry)
}

cmd_list() {
    echo -e "${CYAN}🔗 Paired Devices:${RESET}"
    blueutil --paired
}

cmd_connect() {
    local mac
    mac=$(resolve_mac "$1")
    if [ -z "$mac" ]; then
        echo -e "${RED}❌ MAC not found.${RESET}"
        return
    fi
    echo -e "${CYAN}🔌 Connecting to $mac ...${RESET}"
    blueutil --connect "$mac"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Connected to $mac${RESET}"
        echo "$mac" > "$LAST_CONNECTED_DEVICE"
    else
        echo -e "${RED}⚠️ Connection failed.${RESET}"
    fi
}

cmd_disconnect() {
    local mac
    mac=$(resolve_mac "$1")
    if [ -z "$mac" ]; then
        echo -e "${RED}❌ MAC not found.${RESET}"
        return
    fi
    blueutil --disconnect "$mac"
    echo -e "${YELLOW}🔴 Disconnected.${RESET}"
}

# --- Recording Function ---
cmd_record() {
    local dev
    # Varsayılan cihaz: son bağlanılan cihaz
    dev=$(<"$LAST_CONNECTED_DEVICE")
    if [ -z "$dev" ]; then
        echo -e "${RED}❌ No device connected. Use connect first.${RESET}"
        return
    fi

    local fmt="wav"
    local fname="bluephantom_$(date +%Y%m%d_%H%M%S)"

    # Eğer parametre verilmişse
    [ -n "$1" ] && fmt="$1"
    [ -n "$2" ] && fname="$2"

    echo -e "${GREEN}Recording from \"$dev\" -> ~/Desktop/$fname.$fmt (Ctrl+C to stop)${RESET}"

    # Sox ile kayıt
    sox -t coreaudio "$dev" "$HOME/Desktop/$fname.$fmt"
    rc=$?

    if [ $rc -eq 0 ]; then
        echo -e "${CYAN}✔ Recording finished: ~/Desktop/$fname.$fmt${RESET}"
    else
        echo -e "${YELLOW}✖ sox failed. Make sure the device exists and is connected.${RESET}"
    fi
}

# --- MAIN LOOP ---
while true; do
    read -p "bluephantom> " cmd args
    case "$cmd" in
        scan) cmd_scan ;;
        list) cmd_list ;;
        connect) cmd_connect "$args" ;;
        disconnect) cmd_disconnect "$args" ;;
        save)
            read -r name mac <<< "$args"
            save_profile "$name" "$mac"
            ;;
        profiles) list_profiles ;;
        record)
            read -ra arr <<< "$args"
            cmd_record "${arr[0]}" "${arr[1]}"
            ;;
        help)
            echo "Commands:"
            echo "  scan                       - Scan nearby Bluetooth devices"
            echo "  list                       - Show paired devices"
            echo "  connect <MAC|profile>      - Connect to a device"
            echo "  disconnect <MAC|profile>   - Disconnect from device"
            echo "  save <name> <MAC>          - Save device profile"
            echo "  profiles                   - List saved profiles"
            echo "  record [mp3|wav] [filename] - Record audio from last connected device"
            echo "  help                       - Show help"
            echo "  exit                       - Quit"
            ;;
        exit|quit) echo "Goodbye!"; break ;;
        *) echo "Unknown command. Type 'help'." ;;
    esac
done

