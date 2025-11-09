#!/usr/bin/env bash
# Blueutil + Sox Audio Recorder (AirPods otomatik input)
# by ChatGPT 😎

echo "🔍 Bluetooth cihazlar taranıyor..."
devices=()
names=()

i=1
while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    # MAC adresi ve cihaz adı ayıklama
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

# input cihazını otomatik bul (AirPods Hands-Free veya Stereo)
input_device=$(sox -t coreaudio -n stat 2>&1 | grep -i "AirPods" | head -n1)
if [ -z "$input_device" ]; then
    echo "⚠️ AirPods input cihazı bulunamadı, default kullanılıyor."
    input_device="default"
else
    echo "🎧 AirPods input cihazı: $input_device"
fi

filename="recording_$(date +%Y%m%d_%H%M%S).wav"
echo "🎙️ Kayıt başlatılıyor... CTRL+C ile durdur."
echo "💾 Kaydedileceği yer: $(pwd)/$filename"

trap "echo; echo '🛑 Kayıt durduruldu. Bağlantı kesiliyor...'; blueutil --disconnect \"$mac\"; exit 0" SIGINT

# kayıt başlat
sox -t coreaudio "$input_device" "$filename"
