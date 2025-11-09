#!/usr/bin/env bash
# Blueutil + Sox Audio Recorder (otomatik kayıt)
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
    echo "Geçersiz seçim."
    exit 1
fi

echo "🔗 $name ($mac) cihazına bağlanılıyor..."
blueutil --connect "$mac"
sleep 2

# --- Bağlanan cihaza ait CoreAudio input cihazını tahmin et ---
# Tüm input cihazlarını listeler ve MAC veya isimle eşleştirir
input_device=$(sox -t coreaudio -n stat 2>&1 | grep -i "$name" | head -n1)

# Eğer cihaz adıyla eşleşmezse default input kullan
if [ -z "$input_device" ]; then
    echo "⚠️ CoreAudio input cihazı bulunamadı, default kullanılıyor."
    input_device="default"
else
    echo "🎧 Bağlanan cihazın input cihazı: $input_device"
fi

# --- Kayıt dosyası ---
filename="recording_$(date +%Y%m%d_%H%M%S).wav"
echo "🎙️ Kayıt başlatılıyor... CTRL+C ile durdur."
echo "💾 Kaydedileceği yer: $(pwd)/$filename"

trap "echo; echo '🛑 Kayıt durduruldu. Bağlantı kesiliyor...'; blueutil --disconnect \"$mac\"; exit 0" SIGINT

# --- Kayıt başlat ---
sox -t coreaudio "$input_device" "$filename"


# kayıt başlat
sox -t coreaudio "$input_device" "$filename"
