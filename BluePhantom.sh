#!/usr/bin/env bash


# ---------- CONFIG ----------
BP_DIR="$HOME/.bluephantom"
PROFILES_FILE="$BP_DIR/profiles"
LOG_DIR="$BP_DIR/logs"
VERSION="0.9"

mkdir -p "$BP_DIR"
mkdir -p "$LOG_DIR"
touch "$PROFILES_FILE"

# ---------- COLORS & BANNER ----------
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
RESET='\033[0m'

banner() {
cat <<'BANNER'
___.   .__                       .__                   __                  
\_ |__ |  |  __ __   ____ ______ |  |__ _____    _____/  |_  ____   _____  
 | __ \|  | |  |  \_/ __ \\____ \|  |  \\__  \  /    \   __\/  _ \ /     \ 
 | \_\ \  |_|  |  /\  ___/|  |_> >   Y  \/ __ \|   |  \  | (  <_> )  Y Y  \
 |___  /____/____/  \___  >   __/|___|  (____  /___|  /__|  \____/|__|_|  /
     \/                 \/|__|        \/     \/     \/                  \/ 
                       BluePhantom v0.9
BANNER
echo -e "${CYAN}Hacker vibe CLI for macOS Bluetooth + recording${RESET}"
echo
}

# ---------- DEPENDENCY CHECKS ----------
command_exists() { command -v "$1" >/dev/null 2>&1; }

install_brew_if_needed() {
  if ! command_exists brew ; then
    echo -e "${YELLOW}Homebrew not found. Installing Homebrew...${RESET}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # After Homebrew install, make sure brew in PATH (on macOS ARM may need to source)
    if ! command_exists brew ; then
      echo -e "${RED}brew still not found. Please follow Homebrew messages and re-run.${RESET}"
      exit 1
    fi
  fi
}

ensure_dep() {
  dep="$1"
  if ! command_exists "$dep" ; then
    echo -e "${YELLOW}$dep not found. Installing $dep...${RESET}"
    brew install "$dep"
    if ! command_exists "$dep" ; then
      echo -e "${RED}Failed to install $dep. Please install manually.${RESET}"
      exit 1
    fi
  fi
}

bootstrap_deps() {
  install_brew_if_needed
  ensure_dep blueutil
  ensure_dep sox
  ensure_dep lame   # for mp3 support
  # fzf optional (nice-to-have)
  if ! command_exists fzf ; then
    echo -e "${YELLOW}Optional: install fzf for fuzzy selection? (y/n)${RESET}"
    read -r ans
    if [ "$ans" = "y" ] || [ "$ans" = "Y" ] ; then
      brew install fzf
    fi
  fi
}

# ---------- UTILITIES ----------
log() {
  ts=$(date +"%Y-%m-%d_%H%M%S")
  echo "[$ts] $*" >> "$LOG_DIR/session.log"
}

is_mac_address() {
  # rudimentary MAC regex
  [[ "$1" =~ ^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$ ]]
}

resolve_mac() {

  key="$1"
  if is_mac_address "$key" ; then
    echo "$key"
    return 0
  fi

  if [ -f "$PROFILES_FILE" ]; then
    line=$(grep -E "^$key:" "$PROFILES_FILE" | tail -n1)
    if [ -n "$line" ]; then
      echo "${line#*:}"
      return 0
    fi
  fi
  # not found
  echo ""
  return 1
}

save_profile() {
  name="$1"
  mac="$2"
  if [ -z "$name" ] || [ -z "$mac" ]; then
    echo "Usage: save <name> <MAC>"
    return 1
  fi
  # replace existing
  grep -vE "^$name:" "$PROFILES_FILE" > "$PROFILES_FILE.tmp" || true
  echo "$name:$mac" >> "$PROFILES_FILE.tmp"
  mv "$PROFILES_FILE.tmp" "$PROFILES_FILE"
  chmod 600 "$PROFILES_FILE"
  echo "Saved profile '$name' -> $mac"
}

list_profiles() {
  if [ ! -s "$PROFILES_FILE" ]; then
    echo "(no profiles)"
    return
  fi
  nl -ba -w2 -s'. ' "$PROFILES_FILE" | sed 's/:/ -> /'
}

# Try to extract human-readable name for a Bluetooth device via system_profiler using MAC
guess_coreaudio_name_by_mac() {
  mac="$1"
  # system_profiler prints Address: XX-XX-...
  # We'll search for the block containing Address and Name lines.
  sysprof=$(system_profiler SPBluetoothDataType 2>/dev/null)
  if [ -z "$sysprof" ] ; then
    echo ""
    return 1
  fi
  # Normalize MAC format: system_profiler uses ":" typically; try both
  mac_colon=$(echo "$mac" | tr '[:upper:]' '[:lower:]' | sed 's/-/:/g')
  # find the section that contains the address
  name=$(echo "$sysprof" | awk -v m="$mac_colon" '
    BEGIN{RS=""; FS="\n"}
    {
      for(i=1;i<=NF;i++){
        if($i ~ /Address:.*'"'"'$m'"'"'/){
          for(j=1;j<=NF;j++){
            if($j ~ /^ *Manufacturer/){ next }
            if($j ~ /^ *Name: /){ sub(/^ *Name: /,"",$j); print $j; exit }
          }
        }
      }
    }' | head -n1)
  if [ -n "$name" ]; then
    echo "$name"
    return 0
  fi
  echo ""
  return 1
}

# ---------- COMMANDS ----------
cmd_list() {
  echo -e "${GREEN}Paired devices:${RESET}"
  blueutil --paired
  echo
  echo -e "${GREEN}Available (inquiry) devices (may take ~5s):${RESET}"
  blueutil --inquiry | sed -n '1,20p'
}

cmd_scan() {
  echo "Scanning (inquiry). Press Ctrl+C to stop."
  blueutil --inquiry
}

cmd_connect() {
  arg="$1"
  if [ -z "$arg" ]; then
    echo "Usage: connect <MAC_or_profile_name>"
    return
  fi
  mac=$(resolve_mac "$arg")
  if [ -z "$mac" ]; then
    echo "Profile not found, checking if argument is MAC..."
    if is_mac_address "$arg"; then
      mac="$arg"
    else
      echo "Could not resolve MAC for '$arg'. Use 'list' to see paired devices or 'save' to add profile."
      return
    fi
  fi
  echo "Connecting to $mac ..."
  log "connect request $mac"
  blueutil --connect "$mac"
  sleep 3
  echo "Status after connect:"
  blueutil --info "$mac" 2>/dev/null || true
}

cmd_disconnect() {
  arg="$1"
  if [ -z "$arg" ]; then
    echo "Usage: disconnect <MAC_or_profile_name>"
    return
  fi
  mac=$(resolve_mac "$arg")
  if [ -z "$mac" ]; then
    if is_mac_address "$arg"; then mac="$arg"; else
      echo "Could not resolve MAC for '$arg'."
      return
    fi
  fi
  echo "Disconnecting $mac ..."
  log "disconnect request $mac"
  blueutil --disconnect "$mac"
}

cmd_select() {
  # list paired devices and let user pick (fzf if available)
  mapfile -t lines < <(blueutil --paired)
  if [ "${#lines[@]}" -eq 0 ]; then
    echo "No paired devices found."
    return
  fi
  if command_exists fzf ; then
    choice=$(printf "%s\n" "${lines[@]}" | fzf --height 10 --ansi --prompt="Select device> ")
    if [ -z "$choice" ]; then echo "No selection"; return; fi
    echo "You selected: $choice"
    # parse MAC from line: blueutil prints like "XX:XX:XX:XX:XX:XX DeviceName"
    mac=$(echo "$choice" | awk '{print $1}')
    echo "Connecting to $mac ..."
    blueutil --connect "$mac"
    sleep 2
  else
    echo "fzf not installed. Listing devices with index:"
    nl -w2 -s'. ' -ba < <(printf "%s\n" "${lines[@]}")
    read -r -p "Pick index: " idx
    sel=$(printf "%s\n" "${lines[@]}" | sed -n "${idx}p")
    mac=$(echo "$sel" | awk '{print $1}')
    blueutil --connect "$mac"
    sleep 2
  fi
}

cmd_record() {
  # record <device_coreaudio_name> [mp3] [filename]
  device_name="$1"
  format="$2"
  fname="$3"

  if [ -z "$device_name" ]; then
    echo "Usage: record <coreaudio_device_name_or_profile_or_MAC> [mp3] [filename]"
    echo "If you pass a profile name or MAC, script will try to guess coreaudio name."
    return
  fi

  # If argument is a profile or mac, try to resolve and guess coreaudio name
  if ! is_mac_address "$device_name" && ! printf '%s\n' "$(blueutil --paired 2>/dev/null)" | grep -qF "$device_name"; then
    # maybe it's a profile name
    maybe_mac=$(resolve_mac "$device_name")
    if [ -n "$maybe_mac" ]; then
      guessed=$(guess_coreaudio_name_by_mac "$maybe_mac")
      if [ -n "$guessed" ]; then
        device_core="$guessed"
        echo "Auto-detected coreaudio device name: $device_core"
      else
        echo "Could not auto-detect coreaudio name from MAC $maybe_mac."
        read -r -p "Enter coreaudio device name as shown by ffmpeg -list_devices or Audio MIDI Setup: " device_core
      fi
    else
      # assume the user passed the coreaudio name
      device_core="$device_name"
    fi
  else
    # if it's a MAC directly
    if is_mac_address "$device_name"; then
      guessed=$(guess_coreaudio_name_by_mac "$device_name")
      if [ -n "$guessed" ]; then
        device_core="$guessed"
        echo "Auto-detected coreaudio device name: $device_core"
      else
        read -r -p "Enter coreaudio device name: " device_core
      fi
    else
      device_core="$device_name"
    fi
  fi

  # format handling
  outfmt="wav"
  if [ "$format" = "mp3" ]; then outfmt="mp3"; fi
  if [ -z "$fname" ]; then
    TS=$(date +"%Y%m%d_%H%M%S")
    outname="$HOME/Desktop/bluephantom_record_${TS}.$outfmt"
  else
    outname="$HOME/Desktop/${fname}.$outfmt"
  fi

  echo "Recording from '$device_core' -> $outname"
  echo "Press Ctrl+C to stop recording."
  log "record start device='$device_core' outfile='$outname'"

  if [ "$outfmt" = "wav" ]; then
    sox -t coreaudio "$device_core" "$outname"
  else
    # sox can write mp3 via lame
    sox -t coreaudio "$device_core" -t wav - | lame -V2 - "$outname"
  fi

  echo "Recording finished: $outname"
  log "record end outfile='$outname'"
}

cmd_save() {
  name="$1"
  mac="$2"
  if [ -z "$name" ] || [ -z "$mac" ]; then
    echo "Usage: save <name> <MAC>"
    return
  fi
  save_profile "$name" "$mac"
}

cmd_profiles() {
  echo "Saved profiles:"
  list_profiles
}

cmd_logs() {
  ls -1 "$LOG_DIR" | sed -n '1,50p'
  echo "To view a log: tail -n 200 $LOG_DIR/session.log"
}

cmd_help() {
  cat <<EOF
BluePhantom v$VERSION - commands:
  list                         - show paired + inquiry devices
  scan                         - run inquiry (may list discoverable devices)
  select                       - fuzzy-select a paired device (requires fzf)
  connect <MAC|profile>        - connect to device
  disconnect <MAC|profile>     - disconnect device
  save <name> <MAC>            - save profile mapping name->MAC
  profiles                     - list saved profiles
  record <device|profile|MAC> [mp3] [filename] 
                               - record from device. device can be coreaudio name,
                                 or profile name or MAC (script will try to detect coreaudio name).
                                 Optional 'mp3' to save mp3. Optional filename (no extension).
  logs                         - show logs folder listing
  help                         - this help
  exit                         - quit
EOF
}

# ---------- MAIN ----------
banner
echo -e "${GREEN}Checking dependencies...${RESET}"
bootstrap_deps
echo -e "${GREEN}Ready. Type 'help' for commands.${RESET}"
log "BluePhantom started"

# interactive loop
while true; do
  # show prompt with connected device count
  conn_count=$(blueutil --connected 2>/dev/null | wc -l)
  printf "\n${CYAN}BP[%s]> ${RESET}" "$conn_count"
  read -r line || break
  cmd=$(echo "$line" | awk '{print $1}')
  rest=$(echo "$line" | cut -s -d' ' -f2-)

  case "$cmd" in
    list) cmd_list ;;
    scan) cmd_scan ;;
    select) cmd_select ;;
    connect) cmd_connect $rest ;;
    disconnect) cmd_disconnect $rest ;;
    save) cmd_save $(echo $rest | awk '{print $1, $2}') ;;
    profiles) cmd_profiles ;;
    record)
      # parse args: device [mp3] [filename]
      # we want to preserve spaces inside device name if quoted
      # naive: split rest into token1 token2 token3
      device=$(echo "$rest" | awk '{print $1}')
      # if rest begins with quote, handle it
      if echo "$rest" | grep -q '^"' ; then
        device=$(echo "$rest" | sed -E 's/^"([^"]+)".*/\1/')
        rest2=$(echo "$rest" | sed -E 's/^"([^"]+)"[[:space:]]*(.*)/\2/')
      else
        rest2=$(echo "$rest" | cut -s -d' ' -f2-)
      fi
      fmt=$(echo "$rest2" | awk '{print $1}')
      fname=$(echo "$rest2" | awk '{print $2}')
      cmd_record "$device" "$fmt" "$fname"
      ;;
    logs) cmd_logs ;;
    help) cmd_help ;;
    exit) echo "Bye."; log "BluePhantom exit"; break ;;
    "") ;; # ignore empty
    *)
      echo "Unknown command: $cmd  (type help)"
      ;;
  esac
done
