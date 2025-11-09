#!/usr/bin/env bash

# --- COLORS ---
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
RESET='\033[0m'

clear
echo -e "${CYAN}"
cat <<'BANNER'
___.   .__                       .__                   __                  
\_ |__ |  |  __ __   ____ ______ |  |__ _____    _____/  |_  ____   _____  
 | __ \|  | |  |  \_/ __ \\____ \|  |  \\__  \  /    \   __\/  _ \ /     \ 
 | \_\ \  |_|  |  /\  ___/|  |_> >   Y  \/ __ \|   |  \  | (  <_> )  Y Y  \
 |___  /____/____/  \___  >   __/|___|  (____  /___|  /__|  \____/|__|_|  /
     \/                 \/|__|        \/     \/     \/                  \/ 
     
               🎧  BluePhantom v1.0  -  by dailymycode
BANNER
echo -e "${RESET}"
sleep 1

echo -e "${CYAN}🔍 Scanning for Bluetooth devices...${RESET}"
devices=()
names=()

i=1
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    mac=$(echo "$line" | sed -n 's/.*address: \([A-Fa-f0-9:-]*\).*/\1/p')
    name=$(echo "$line" | sed -n 's/.*name: "\(.*\)".*/\1/p')
    if [[ -n "$mac" && -n "$name" ]]; then
        devices+=("$mac")
        names+=("$name")
        echo -e "${GREEN}$i)${RESET} ${YELLOW}$name${RESET} -> ${CYAN}$mac${RESET}"
        ((i++))
    fi
done < <(blueutil --inquiry)

if [ ${#devices[@]} -eq 0 ]; then
    echo -e "${RED}❌ No Bluetooth devices found.${RESET}"
    exit 1
fi

echo
read -p "👉 Enter the number of the device to connect: " choice
index=$((choice-1))
mac=${devices[$index]}
name=${names[$index]}

if [ -z "$mac" ]; then
    echo -e "${RED}❌ Invalid selection.${RESET}"
    exit 1
fi

echo
echo -e "${CYAN}🔗 Connecting to $name ($mac)...${RESET}"
blueutil --connect "$mac"
sleep 2


input_device="$name"
filename="recording_$(date +%Y%m%d_%H%M%S).wav"
output_path="$HOME/Desktop/$filename"

echo
echo -e "${GREEN}🎧 Input device: ${CYAN}$input_device${RESET}"
echo -e "${YELLOW}💾 Saving to: ${CYAN}$output_path${RESET}"
echo -e "${GREEN}🎙️  Recording started...${RESET}"
echo -e "${RED}🛑 Press CTRL+C to stop.${RESET}"
echo

trap "echo; echo -e '${YELLOW}🛑 Recording stopped. Disconnecting device...${RESET}'; blueutil --disconnect \"$mac\"; exit 0" SIGINT

# --- Start recording ---
sox -t coreaudio "$input_device" "$output_path"
