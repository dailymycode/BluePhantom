#!/usr/bin/env bash
# Bluetooth cihaz seç, bağlan, otomatik kayda başla
# by ChatGPT 😎

echo "🔍 Bluetooth cihazlar taranıyor..."
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
        echo "$i) $name -> $mac"
        ((i++))
    fi
done < <(blueutil --inquiry)

if [ ${#devices[@]} -eq 0 ]; then
    echo "❌ Hiç cihaz bulunamadı."
    exit 1
fi

read -p "Bağlanmak istediğin cihazın numarasını gir: " choice
index=$((choice-1))
mac=${devices[$index]}
name=${names[$index]}

if [ -z "$mac" ]; then
    echo "❌ Geçersiz seçim."
    exit 1
fi

echo "🔗 $name ($mac) cihazına bağlanılıyor..."
blueutil --connect "$mac"
sleep 2

# --- Cihaz ismini direkt input olarak kullan ---
input_device="$name"

echo "🎧 Kayıt input cihazı: $input_device"

filename="recording_$(date +%Y%m%d_%H%M%S).wav"
output_path="$HOME/Desktop/$filename"

echo "🎙️ Kayıt başlatılıyor..."
echo "💾 Kaydedileceği yer: $output_path"
echo "🛑 Durdurmak için CTRL+C"

trap "echo; echo '🛑 Kayıt durduruldu, bağlantı kesiliyor...'; blueutil --disconnect \"$mac\"; exit 0" SIGINT

# --- Kayıt başlat ---
sox -t coreaudio "$input_device" "$output_path"
