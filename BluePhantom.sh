#!/usr/bin/env bash
# Simple Bluetooth Audio Recorder (blueutil + sox)


echo "🔍 Bluetooth cihazlar taranıyor..."
devices=()
names=()

# cihazları listele (sadece isim ve MAC)
i=1
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    mac=$(echo "$line" | awk '{print $1}')
    name=$(echo "$line" | awk '{$1=""; print substr($0,2)}')
    devices+=("$mac")
    names+=("$name")
    echo "$i) $name -> $mac"
    ((i++))
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

# kayıt dosyası adını oluştur
filename="recording_$(date +%Y%m%d_%H%M%S).wav"
echo "🎙️ Kayıt başlatılıyor... CTRL+C ile durdurabilirsin."
echo "💾 Kaydedileceği yer: $(pwd)/$filename"

# CTRL+C sinyali yakala
trap "echo; echo '🛑 Kayıt durduruldu. Bağlantı kesiliyor...'; blueutil --disconnect \"$mac\"; exit 0" SIGINT

# kayıt başlat
sox -t coreaudio default "$filename"
