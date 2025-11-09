#!/usr/bin/env bash
# BluePhantom - BlueSpy-like flow (scan -> choose -> connect -> record)
# v2.3 (bash)
#
# KULLANIM: ./BluePhantom-BlueSpyLike.sh
# Gereksinimler: blueutil, sox, lame (mp3 çıkışı isteniyorsa)
#
# !!! Yasal uyarı: yalnızca kendi ya da izin verilen cihazlarda kullanın.

VERSION="2.3"
PROFILES="$HOME/.bluephantom_profiles"
LAST_DEVICE="$HOME/.bluephantom_last_device"
touch "$PROFILES" "$LAST_DEVICE"

# renkler
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
RESET='\033[0m'

banner() {
  clear
  cat <<'BANNER'
 ____  _                ____  _                      
|  _ \| | __ _  ___ ___|  _ \| |__   ___  _ __  _   _ 
| |_) | |/ _` |/ __/ _ \ |_) | '_ \ / _ \| '_ \| | | |
|  __/| | (_| | (_|  __/  __/| | | | (_) | | | | |_| |
|_|   |_|\__,_|\___\___|_|   |_| |_|\___/|_| |_|\__,_|
            BluePhantom - BlueSpy-like (v2.3)
BANNER
  echo
  echo -e "${CYAN}Not: Sadece izinli cihazlarda kullanın.${RESET}"
  echo
}

# dependency check
deps_ok=true
for dep in blueutil sox lame; do
  if ! command -v "$dep" >/dev/null 2>&1; then
    echo -e "${YELLOW}Eksik dependency: $dep. (brew install $dep)${RESET}"
    deps_ok=false
  fi
done
if [ "$deps_ok" = false ]; then
  echo -e "${RED}Gerekli bağımlılıklar eksik. Yükleyip tekrar çalıştırın.${RESET}"
  exit 1
fi

# Utility: trim
_trim() { echo "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' ; }

# Scan: numaralandırılmış liste oluşturur (devices_name[], devices_mac[])
scan_devices() {
  echo -e "${CYAN}🔍 Scanning for nearby Bluetooth devices (inquiry)...${RESET}"
  devices_name=()
  devices_mac=()
  mapfile -t raw < <(blueutil --inquiry 2>/dev/null)
  if [ ${#raw[@]} -eq 0 ]; then
    echo -e "${YELLOW}Tarama sonucu boş. Cihaz pairing/reveal modunda mı?${RESET}"
    return 1
  fi
  idx=1
  for line in "${raw[@]}"; do
    # beklenen format: MAC Name...
    mac=$(echo "$line" | awk '{print $1}')
    name=$(echo "$line" | awk '{ $1=""; sub(/^ /,""); print }')
    name=$(_trim "$name")
    if [ -n "$mac" ] && [ -n "$name" ]; then
      devices_name+=("$name")
      devices_mac+=("$mac")
      printf "%2d) %s  ->  %s\n" "$idx" "$name" "$mac"
      idx=$((idx+1))
    fi
  done
  echo
  return 0
}

# Connect by index (from devices arrays)
connect_by_index() {
  local idx="$1"
  if ! [[ "$idx" =~ ^[0-9]+$ ]] ; then
    echo -e "${RED}Geçersiz seçim (sayı girin).${RESET}"
    return 1
  fi
  if [ "$idx" -lt 1 ] || [ "$idx" -gt "${#devices_mac[@]}" ]; then
    echo -e "${RED}Seçim aralık dışı.${RESET}"
    return 1
  fi
  local mac="${devices_mac[$((idx-1))]}"
  local name="${devices_name[$((idx-1))]}"
  echo -e "${CYAN}🔌 Connecting to ${name} [${mac}] ...${RESET}"
  blueutil --connect "$mac"
  rc=$?
  if [ $rc -ne 0 ]; then
    echo -e "${RED}Bağlantı başarısız (blueutil returned $rc).${RESET}"
    return 2
  fi
  echo "$name,$mac" > "$LAST_DEVICE"
  echo -e "${GREEN}✅ Connected: $name${RESET}"
  return 0
}

# Attempt to determine a CoreAudio input name for the device.
# On macOS, some BT devices don't expose microphone as "AirPods ..."; may require checking system_profiler or Audio MIDI Setup.
# We'll try a best-effort: look into system_profiler SPBluetoothDataType for matching Address or Name and return possible CoreAudio label.
find_coreaudio_name_for_last_connected() {
  if [ ! -f "$LAST_DEVICE" ]; then
    echo ""
    return 1
  fi
  local entry
  entry=$(cat "$LAST_DEVICE")
  local devname=${entry%%,*}
  local devmac=${entry##*,}
  # Try to find a name in system_profiler Bluetooth section
  mapfile -t lines < <(system_profiler SPBluetoothDataType 2>/dev/null)
  # Try to find block that contains MAC or name and extract "Address" or "Device" fields
  local candidate=""
  # simple heuristic: if system_profiler has "Address: <mac>" near a "Name: <name>" - use the Name
  candidate=$(system_profiler SPBluetoothDataType 2>/dev/null | awk -v mac="$devmac" 'BEGIN{RS="";FS="\n"}{for(i=1;i<=NF;i++){if($i ~ mac){for(j=1;j<=NF;j++){if($j ~ /Name: /){sub(/^[[:space:]]*Name: /,"",$j); print $j; exit}}}}}')
  candidate=$(_trim "$candidate")
  if [ -n "$candidate" ]; then
    echo "$candidate"
    return 0
  fi
  # fallback: just use the device name saved
  echo "$devname"
  return 0
}

# Check if sox can open the CoreAudio device (quick probe)
sox_probe_device() {
  local devname="$1"
  # Try a very short test record (0.1s) into /dev/null or temp file
  tmpf=$(mktemp /tmp/bluephantom_probe.XXXX.wav)
  # suppress sox output, only care rc
  sox -t coreaudio "$devname" "$tmpf" trim 0 0.1 >/dev/null 2>&1
  rc=$?
  rm -f "$tmpf"
  return $rc
}

# Start recording (device name as seen by CoreAudio)
start_recording() {
  local coredev="$1"
  local fmt="$2"
  local fname="$3"
  [ -z "$fmt" ] && fmt="wav"
  [ -z "$fname" ] && fname="bluephantom_$(date +%Y%m%d_%H%M%S)"
  out="$HOME/Desktop/$fname.$fmt"

  echo
  echo -e "${GREEN}🎙  Recording from: ${coredev}${RESET}"
  echo -e "${YELLOW}Saving to: ${out}${RESET}"
  echo -e "${CYAN}Press Ctrl+C to stop recording.${RESET}"
  echo

  if [ "$fmt" = "mp3" ]; then
    # record wav then pipe to lame (reduce chance of sox/lame issues)
    sox -t coreaudio "$coredev" -t wav - | lame -V2 - "$out"
    rc=$?
  else
    sox -t coreaudio "$coredev" "$out"
    rc=$?
  fi

  if [ $rc -eq 0 ]; then
    echo -e "${GREEN}✔ Recording saved: $out${RESET}"
  else
    echo -e "${RED}✖ Recording failed (sox rc=$rc). Check device is a valid CoreAudio INPUT device.${RESET}"
    echo -e "${YELLOW}Tip: run 'sox -V1 -t coreaudio \"${coredev}\" test.wav' to get verbose debug output.${RESET}"
  fi
  return $rc
}

# Main interactive flow (like BlueSpy demo screenshot)
main_flow() {
  banner
  if ! scan_devices; then
    return 1
  fi

  read -p $'Enter the number of the device to connect: ' choice
  choice=$(_trim "$choice")
  if ! connect_by_index "$choice"; then
    echo -e "${RED}Cannot connect to selected device.${RESET}"
    return 2
  fi

  # find CoreAudio name
  coredev=$(find_coreaudio_name_for_last_connected)
  coredev=$(_trim "$coredev")
  echo -e "${CYAN}Detected CoreAudio device name (best effort): ${GREEN}${coredev}${RESET}"

  # probe if sox can open it
  if sox_probe_device "$coredev"; then
    echo -e "${GREEN}sox probe OK — starting recording.${RESET}"
    # ask user for duration or manual ctrl+c
    read -p "Record duration in seconds (enter for manual Ctrl+C): " dur
    dur=$(_trim "$dur")
    if [[ -n "$dur" && "$dur" =~ ^[0-9]+$ ]]; then
      fname="bluephantom_$(date +%Y%m%d_%H%M%S)"
      out="$HOME/Desktop/$fname.wav"
      echo -e "${CYAN}Recording for $dur seconds to $out ...${RESET}"
      sox -t coreaudio "$coredev" "$out" trim 0 "$dur"
      rc=$?
      if [ $rc -eq 0 ]; then
        echo -e "${GREEN}✔ Recorded: $out${RESET}"
      else
        echo -e "${RED}✖ sox failed (rc=$rc).${RESET}"
      fi
    else
      # manual stop
      start_recording "$coredev" "wav"
    fi
  else
    echo -e "${YELLOW}sox cannot open '${coredev}' as input. Device might not expose microphone profile.${RESET}"
    echo -e "${YELLOW}You can try connecting system input manually (Audio MIDI Setup) or choose another device.${RESET}"
  fi

  echo
  echo -e "${CYAN}Done.${RESET}"
}

# Run main
main_flow

