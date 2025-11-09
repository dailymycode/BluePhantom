#!/usr/bin/env bash
# BluePhantom v2.0 - Auto-select connected Bluetooth & Record

VERSION="2.0"
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
     
                    BluePhantom v2.0 - @dailymycode
BANNER
echo

# --- Dependency check ---
for dep in blueutil sox lame; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  $dep not found. Install it with: brew install $dep${RESET}"
        exit 1
    fi
done

# --- UTILITIES ---
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

# --- COMMANDS ---
cmd_scan() {
    echo -e "${CYAN}🔍 Nearby devices:${RESET}"
    i=1
    blueutil --inquiry | while read -r line; do
        mac=$(echo "$line" | awk '{print $1}')
        name=$(echo "$line" | awk '{print substr($0,index($0,$2))}')
        echo "$i. $name -> $mac"
        ((i++))
    done
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

cmd_record() {
    local last_device
    last_device=$(cat "$LAST_CONNECTED_DEVICE")
    if [ -z "$last_device" ]; then
        echo -e "${RED}❌ No device connected. Connect first.${RESET}"
        return
    fi

    local fmt="$1"
    local fname="$2"
    [ -z "$fmt" ] && fmt="wav"
    [ -z "$fname" ] && fname="bluephantom_$(date +%Y%m%d_%H%M%S)"

    echo -e "${GREEN}🎙️ Recording from $last_device ... saving as ~/Desktop/$fname.$fmt (Ctrl+C to stop)${RESET}"

    if [ "$fmt" = "mp3" ]; then
        sox -t coreaudio "$last_device" "$HOME/Desktop/$fname.mp3"
    else
        sox -t coreaudio "$last_device" "$HOME/Desktop/$fname.wav"
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
            # record [mp3|wav] [filename]
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
