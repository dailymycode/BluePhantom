#!/usr/bin/env bash
# BluePhantom - simple bluetooth recorder with ASCII banner

VERSION="0.9"
PROFILES="$HOME/.bluephantom_profiles"
touch "$PROFILES"

# --- COLORS ---
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
RESET='\033[0m'

# --- BANNER ---
echo
cat <<'BANNER'
___.   .__                       .__                   __                  
\_ |__ |  |  __ __   ____ ______ |  |__ _____    _____/  |_  ____   _____  
 | __ \|  | |  |  \_/ __ \\____ \|  |  \\__  \  /    \   __\/  _ \ /     \ 
 | \_\ \  |_|  |  /\  ___/|  |_> >   Y  \/ __ \|   |  \  | (  <_> )  Y Y  \
 |___  /____/____/  \___  >   __/|___|  (____  /___|  /__|  \____/|__|_|  /
     \/                 \/|__|        \/     \/     \/                  \/ 
     
                BluePhantom v0.9 - @dailymycode
BANNER
echo

# --- Dependency check ---
for dep in blueutil sox lame; do
    if ! command -v $dep >/dev/null 2>&1; then
        echo -e "${YELLOW}$dep not found. Install it using: brew install $dep${RESET}"
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
    echo -e "${GREEN}Saved profile '$name' -> $mac${RESET}"
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
    echo -e "${CYAN}--- Scanning for Nearby Devices ---${RESET}"
    blueutil --inquiry | while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        mac=$(echo "$line" | awk '{print $1}')
        name=$(echo "$line" | awk '{print substr($0,index($0,$2))}')
        if [ -n "$mac" ] && [ -n "$name" ]; then
            echo "$mac -> $name"
        fi
    done
}

cmd_list() {
    echo -e "${CYAN}--- Paired Devices ---${RESET}"
    blueutil --paired
}

cmd_connect() {
    local mac
    mac=$(resolve_mac "$1")
    if [ -z "$mac" ]; then
        echo "MAC not found."
        return
    fi
    blueutil --connect "$mac"
    echo -e "${GREEN}Connected to $mac${RESET}"
}

cmd_disconnect() {
    local mac
    mac=$(resolve_mac "$1")
    if [ -z "$mac" ]; then
        echo "MAC not found."
        return
    fi
    blueutil --disconnect "$mac"
    echo -e "${YELLOW}Disconnected from $mac${RESET}"
}

# --- Recording Function ---
cmd_record() {
    local dev="$1"
    local fmt="$2"
    local fname="$3"

    if [ -z "$dev" ]; then
        echo "No device specified."
        return
    fi

    if [ -z "$fmt" ]; then
        fmt="wav"
    fi

    if [ -z "$fname" ]; then
        fname="recording_$(date +%Y%m%d_%H%M%S)"
    fi

    echo -e "${GREEN}Recording from $dev -> $fname.$fmt${RESET}"
    
    # Örnek: sox kullanarak Bluetooth cihazından kayıt
    # sox -t coreaudio "$dev" "$fname.$fmt"
}

# --- Interactive loop ---
while true; do
    read -p "bluephantom> " cmd args
    case "$cmd" in
        list) cmd_list ;;
        scan) cmd_scan ;;
        connect) cmd_connect "$args" ;;
        disconnect) cmd_disconnect "$args" ;;
        save)
            read -r name mac <<< "$args"
            save_profile "$name" "$mac"
            ;;
        profiles) list_profiles ;;
        record)
            read -ra allargs <<< "$args"
            dev="${allargs[0]}"
            fmt="${allargs[1]}"
            fname="${allargs[2]}"
            cmd_record "$dev" "$fmt" "$fname"
            ;;
        help)
            echo "Commands:"
            echo "  scan                       - Scan for nearby devices"
            echo "  list                       - Show paired devices"
            echo "  connect <MAC|profile>      - Connect to device"
            echo "  disconnect <MAC|profile>   - Disconnect device"
            echo "  save <name> <MAC>          - Save device profile"
            echo "  profiles                   - List saved profiles"
            echo "  record <device> [mp3] [filename] - Record audio from device"
            echo "  help                       - Show this message"
            echo "  exit                       - Quit"
            ;;
        exit) break ;;
        *) echo "Unknown command. Type help." ;;
    esac
done

