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
     
              🎧  BluePhantom v2.0  -  by ChatGPT
BANNER
echo -e "${RESET}"

# --- FUNCTIONS ---
command_exists() { command -v "$1" >/dev/null 2>&1; }

spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\'
  while ps -p $pid >/dev/null 2>&1; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
  printf "    \b\b\b\b"
}

check_and_install_deps() {
  echo -e "${CYAN}🔍 Checking dependencies...${RESET}"

  # Check for Homebrew
  if ! command_exists brew ; then
    echo -e "${YELLOW}⚙️  Installing Homebrew...${RESET}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" &
    spinner $!
    echo -e "${GREEN}✅ Homebrew installed.${RESET}"
  fi

  # Check for blueutil
  if ! command_exists blueutil ; then
    echo -e "${YELLOW}📦 Installing blueutil...${RESET}"
    brew install blueutil &>/dev/null &
    spinner $!
    echo -e "${GREEN}✅ blueutil installed.${RESET}"
  fi

  # Check for sox
  if ! command_exists sox ; then
    echo -e "${YELLOW}📦 Installing sox...${RESET}"
    brew install sox &>/dev/null &
    spinner $!
    echo -e "${GREEN}✅ sox installed.${RESET}"
  fi

  echo -e "${GREEN}✅ All dependencies ready!${RESET}\n"
}

check_and_install_deps
sleep 1

# --- SCAN DEVICES ---
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

# --- CONNECT WITH ANIMATION ---
echo
echo -ne "${CYAN}🔗 Connecting to ${YELLOW}$name${CYAN}...${RESET}"
blueutil --connect "$mac" &>/dev/null &
spinner $!
sleep 1
echo -e "\n${GREEN}✅ Connected successfully!${RESET}"

# --- COUNTDOWN BEFORE RECORDING ---
echo
echo -e "${YELLOW}🎙️  Recording will start in:${RESET}"
for i in {5..1}; do
  echo -ne "${CYAN}$i...${RESET}\r"
  sleep 1
done
echo -e "${GREEN}🎧 Recording started!${RESET}\n"

# --- RECORDING ---
filename="recording_$(date +%Y%m%d_%H%M%S).wav"
output_path="$HOME/Desktop/$filename"

echo -e "${YELLOW}💾 Saving to: ${CYAN}$output_path${RESET}"
echo -e "${RED}🛑 Press CTRL+C to stop.${RESET}"
echo

trap "echo; echo -e '${YELLOW}🛑 Recording stopped. Disconnecting device...${RESET}'; blueutil --disconnect \"$mac\"; exit 0" SIGINT

sox -t coreaudio "$name" "$output_path"
