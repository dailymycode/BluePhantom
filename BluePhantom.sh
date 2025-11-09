#!/usr/bin/env bash
# bluephantom_simple.sh
# Basit: paired cihazları numaralandır, sayı ile seç, bağlan, sox ile kayıt al.
# Kullanım: ./bluephantom_simple.sh

PROFILES="$HOME/.bluephantom_profiles"
LAST_DEVICE_FILE="$HOME/.bluephantom_last_device"

# Renkler
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
RESET='\033[0m'

# Kontroller
for dep in blueutil sox; do
  if ! command -v "$dep" >/dev/null 2>&1; then
    echo -e "${RED}Gerekli komut bulunamadı: $dep. Yükleyin ve tekrar deneyin.${RESET}"
    exit 1
  fi
done

echo -e "${CYAN}==== Bluetooth Eşleşmiş (paired) Cihazlar ====${RESET}"
# blueutil --paired çıktısını satır satır oku
mapfile -t _lines < <(blueutil --paired 2>/dev/null)

if [ ${#_lines[@]} -eq 0 ]; then
  echo -e "${YELLOW}Eşleşmiş (paired) cihaz bulunamadı. Önce cihazı eşleştirin veya tarayın.${RESET}"
  exit 0
fi

# Dizi oluştur
declare -a dev_names
declare -a dev_macs

i=1
for line in "${_lines[@]}"; do
  # Expect: "MAC Name..." or other. Extract MAC as first token, rest as name.
  mac=$(echo "$line" | awk '{print $1}')
  name=$(echo "$line" | awk '{ $1=""; sub(/^ /,""); print }')
  # Trim
  name=$(echo "$name" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  if [ -n "$mac" ] && [ -n "$name" ]; then
    dev_names+=("$name")
    dev_macs+=("$mac")
    printf "%2d) %s  ->  %s\n" "$i" "$name" "$mac"
    i=$((i+1))
  fi
done

echo
# Seçim al
while true; do
  read -p $'Bağlamak istediğiniz cihazın numarasını girin (çıkmak için q): ' choice
  choice=$(echo "$choice" | tr -d '[:space:]')
  if [ -z "$choice" ]; then
    echo "Geçersiz giriş."
    continue
  fi
  if [[ "$choice" =~ ^[Qq]$ ]]; then
    echo "Çıkılıyor."
    exit 0
  fi
  if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
    echo "Lütfen geçerli bir sayı girin."
    continue
  fi
  if [ "$choice" -lt 1 ] || [ "$choice" -gt "${#dev_macs[@]}" ]; then
    echo "Seçim aralık dışında."
    continue
  fi
  break
done

idx=$((choice-1))
SEL_MAC="${dev_macs[$idx]}"
SEL_NAME="${dev_names[$idx]}"

echo
echo -e "${CYAN}Seçildi: ${GREEN}$SEL_NAME${RESET} ${CYAN}->${RESET} ${YELLOW}$SEL_MAC${RESET}"
echo -e "${CYAN}Cihaza bağlanılıyor...${RESET}"
blueutil --connect "$SEL_MAC"
sleep 3

# Basit bağlantı kontrol (blueutil --is-connected döndürülebilir, yoksa skip)
if command -v blueutil >/dev/null 2>&1; then
  # blueutil --is-connected <mac> döndürebilir; farklı sürümlerde değişebilir
  if blueutil --is-connected "$SEL_MAC" >/dev/null 2>&1; then
    echo -e "${GREEN}Bağlandı: $SEL_NAME${RESET}"
  else
    echo -e "${YELLOW}blueutil bağlantı durumunu doğrulayamadı. Devam ediliyor (sox açılırsa kayıt alır).${RESET}"
  fi
fi

# Varsayılan cihaz adı olarak seçilen isim
DEFAULT_CORE_NAME="$SEL_NAME"

# system_profiler'dan alternatif isim önermeye çalış (macOS)
if command -v system_profiler >/dev/null 2>&1; then
  candidate=$(system_profiler SPBluetoothDataType 2>/dev/null | awk -v mac="$SEL_MAC" 'BEGIN{RS="";FS="\n"}{for(i=1;i<=NF;i++){if($i ~ mac){for(j=1;j<=NF;j++){if($j ~ /Name: /){sub(/^[[:space:]]*Name: /,"",$j); print $j; exit}}}}}')
  candidate=$(echo "$candidate" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  if [ -n "$candidate" ]; then
    DEFAULT_CORE_NAME="$candidate"
  fi
fi

echo
echo -e "${CYAN}SoX ile kullanılacak cihaz adı önerisi:${RESET} ${GREEN}\"$DEFAULT_CORE_NAME\"${RESET}"
read -p "Bu isimle kayıt yapılsın mı? (E/n) " use_default
use_default=${use_default:-E}

if [[ "$use_default" =~ ^[Nn]$ ]]; then
  read -p "SoX için kullanılacak cihaz adını elle girin (tam ve doğru olmalı): " CUSTOM_NAME
  DEVICE_NAME="$CUSTOM_NAME"
else
  DEVICE_NAME="$DEFAULT_CORE_NAME"
fi

# Dosya adı sor
read -p "Kaydedilecek dosya adı (uzantı yazmayın, boş bırak default): " FNAME
if [ -z "$FNAME" ]; then
  FNAME="bluephantom_$(date +%Y%m%d_%H%M%S)"
fi
OUT="$HOME/Desktop/$FNAME.wav"

echo
echo -e "${GREEN}Kayıt başlıyor: cihaz=\"$DEVICE_NAME\"  →  $OUT${RESET}"
echo -e "${YELLOW}Kaydı manuel durdurmak için Ctrl+C yapın.${RESET}"
echo

# Trap ile Ctrl+C yakala ve kullanıcıya bilgi ver
trap 'echo; echo -e "${CYAN}Kayıt durduruldu. Dosya: $OUT${RESET}"; exit 0' INT

# sox ile kayıt (wav)
sox -t coreaudio "$DEVICE_NAME" "$OUT"
rc=$?

trap - INT

if [ $rc -eq 0 ]; then
  echo -e "${GREEN}✔ Kayıt tamamlandı: $OUT${RESET}"
else
  echo -e "${RED}✖ sox başarısız oldu (rc=$rc). Lütfen cihaz adını veya bağlantıyı kontrol edin.${RESET}"
  echo -e "${YELLOW}Öneri: şu komutla daha detaylı bilgi alın:${RESET}"
  echo "  sox -V1 -t coreaudio \"$DEVICE_NAME\" test.wav"
fi

# Son bağlı cihazı kaydet
echo "$SEL_NAME,$SEL_MAC" > "$LAST_DEVICE_FILE"

