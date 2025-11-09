#!/usr/bin/env bash
# BluePhantom v1.0 - simple bluetooth recorder with ASCII banner

VERSION="1.0"
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
     
                BluePhantom v1.0 - @dailymycode
BANNER
echo

# --- Dependency check ---
for dep in blueutil sox lame; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        echo -e "${YELLOW}$dep not found. Install with: brew install $dep${RESET}"
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
    local full_input="$*"

    # Cihaz adını tırnaklar içinden al (baş/son boşlukları da temizle)
    local dev=$(echo "$full_input" | grep -oE '"[^"]+"' | tr -d '"' | sed 's/^ *//;s/ *$//')

    # Kalan argümanları al
    local rest=$(echo "$full_input" | sed -E 's/"[^"]+"//g' | xargs)
    local fmt=$(echo "$rest" | awk '{print $1}')
    local fname=$(echo "$rest" | awk '{print $2}')

    # Varsayılan değerler
    [ -z "$fmt" ] && fmt="wav"
    [ -z "$fname" ] && fname="bluephantom_$(date +%Y%m%d_%H%M%S)"

    if [ -z "$dev" ]; then
        echo "Usage: record \"Device Name\" [mp3|wav] [filename]"
        return
    fi

    echo -e "${GREEN}Recording from \"$dev\" ... saving as $fname.$fmt (Ctrl+C to stop)${RESET}"

    # Gerçek kayıt komutu
    if [ "$fmt" = "mp3" ]; then
        eval "sox -t coreaudio \"$dev\" \"$HOME/Desktop/$fname.mp3\""
    else
        eval "sox -t coreaudio \"$dev\" \"$HOME/Desktop/$fname.wav\""
    fi
}


# --- Interactive Loop ---
while true; do
    echo -n "bluephantom> "
    IFS= read -r input

    cmd=$(echo "$input" | awk '{print $1}')
    args="${input#"$cmd"}"
    args=$(echo "$args" | xargs)

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
        record) cmd_record "$args" ;;
        help)
            echo "Commands:"
            echo "  scan                       - Scan for nearby devices"
            echo "  list                       - Show paired devices"
            echo "  connect <MAC|profile>      - Connect to device"
            echo "  disconnect <MAC|profile>   - Disconnect device"
            echo "  save <name> <MAC>          - Save device profile"
            echo "  profiles                   - List saved profiles"
            echo "  record \"Device\" [mp3|wav] [filename] - Record audio"
            echo "  help                       - Show this message"
            echo "  exit                       - Quit"
            ;;
        exit) break ;;
        *) echo "Unknown command. Type help." ;;
    esac
done

