#!/bin/bash

echo "==== Bluetooth Cihazlarını Listele ===="
blueutil --paired

read -p "Bağlamak istediğiniz cihazın MAC adresini girin: " MAC

echo "Cihaz bağlanıyor..."
blueutil --connect "$MAC"
sleep 5  # Bağlantının tamamlanması için bekle

read -p "Ses kaydı almak istediğiniz cihazın adını girin (örneğin 'AirPods Pro - Find My'): " DEVICE

echo "Ses kaydı başlatılıyor. Kaydı durdurmak için Ctrl+C yapın."
sox -t coreaudio "$DEVICE" ~/Desktop/output.wav

echo "Kayıt tamamlandı. Dosya Masaüstüne kaydedildi: output.wav"
