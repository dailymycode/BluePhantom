#!/usr/bin/env bash
# Simple Bluetooth Audio Recorder using blueutil + sox

echo "🔍 Bluetooth cihazlar taranıyor..."
devices=()
names=()

# cihazları listele
i=1
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    mac=$(echo "$line" | awk '{print $1}')
    name=$(echo "$line" | awk '{$1=""; print substr($0,2)}')
    devices+=("$mac")
    names+=("$name")
    echo "$i) $name ($mac)"
    ((i++))
done < <(blueutil --inquiry)

if [ ${#devices[@]} -eq 0 ]; then
    echo "❌ Hiç cihaz bulunamadı."
    exit 1
fi

# kullanıcıdan seçim al
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

# ses kaydı
filename="recording_$(date +%Y%m%d_%H%M%S).wav"
echo "🎙️ Kayıt başlatılıyor... Çıkmak için CTRL+C"
trap "echo; echo '🛑 Kayıt durduruldu. Bağlantı kesiliyor...'; blueutil --disconnect \"$mac\"; exit 0" SIGINT

sox -t coreaudio default "$filename"

# (Ctrl+C ile kayıt bitince trap devreye girer)
