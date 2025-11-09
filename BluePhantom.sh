#!/usr/bin/env bash
# Blueutil + Sox simple bluetooth recorder
# by ChatGPT 😎

echo "🔍 Bluetooth cihazlar taranıyor..."
devices=()
names=()

i=1
while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    # MAC adresini ve cihaz adını düzgün şekilde ayıkla
    mac=$(echo "$line" | sed -n 's/.*address: \([A-Fa-f0-9:-]*\).*/\1/p')
    name=$(echo "$line" | sed -n 's/.*name: "\(.*\)".*/\1/p')

    # boş satırları atla
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

filename="recording_$(date +%Y%m%d_%H%M%S).wav"
echo "🎙️ Kayıt başlatılıyor... CTRL+C ile durdur."
echo "💾 Kaydedileceği yer: $(pwd)/$filename"

trap "echo; echo '🛑 Kayıt durduruldu. Bağlantı kesiliyor...'; blueutil --disconnect \"$mac\"; exit 0" SIGINT

sox -t coreaudio default "$filename"

