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
     
              🎧  BluePhantom v1.2  -  by dailymycode
BANNER
echo -e "${RESET}"

# --- DEPENDENCY CHECKS ---
command_exists() { command -v "$1" >/dev/null 2>&1; }

check_and_install_deps() {
  echo -e "${CYAN}🔍 Checking system dependencies...${RESET}"

  # Check for Homebrew
  if ! command_exists brew ; then
    echo -e "${YELLOW}⚙️  Homebrew not found. Installing...${RESET}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if ! command_exists brew ; then
      echo -e "${RED}❌ Homebrew installation failed. Please install manually and re-run.${RESET}"
      exit 1
    fi
  fi

  # Check for blueutil
  if ! command_exists blueutil ; then
    echo -e "${YELLOW}📦 Installing blueutil...${RESET}"
    brew install blueutil
  fi

  # Check for sox
  if ! command_exists sox ; then
    echo -e "${YELLOW}📦 Installing sox...${RESET}"
    brew install sox
  fi

  # Final validation
  if command_exists brew && command_exists blueutil && command_exists sox ; then
    echo -e "${GREEN}✅ All dependencies installed and ready.${RESET}"
  else
    echo -e "${RED}❌ One or more dependencies failed to install.${RESET}"
    exit 1
  fi
}

check_and_install_deps
sleep 1

# --- SCAN BLUETOOTH DEVICES ---
echo
echo -e "${CYAN}🔍 Scanning for nearby Bluetooth devices...${RESET}"
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
echo -e "${CYAN}🔗 Connecting to ${YELLOW}$name${CYAN} ($mac)...${RESET}"
blueutil --connect "$mac"
sleep 3

# --- START RECORDING ---
filename="recording_$(date +%Y%m%d_%H%M%S).wav"
output_path="$HOME/Desktop/$filename"

echo
echo -e "${GREEN}🎧 Recording from device: ${CYAN}$name${RESET}"
echo -e "${YELLOW}💾 File will be saved to: ${CYAN}$output_path${RESET}"
echo -e "${GREEN}🎙️  Recording started...${RESET}"
echo -e "${RED}🛑 Press CTRL+C to stop.${RESET}"
echo

trap "echo; echo -e '${YELLOW}🛑 Recording stopped. Disconnecting device...${RESET}'; blueutil --disconnect \"$mac\"; exit 0" SIGINT

sox -t coreaudio "$name" "$output_path"

