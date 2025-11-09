
# 🎧 BluePhantom v2.0

BluePhantom v2.0 is a macOS Bash script that allows you to automatically connect to Bluetooth devices and record audio.

---

## ⚡ Features

- Scans and lists available Bluetooth devices.
- Connects to the selected device.
- 5-second countdown before recording starts.
- Saves recordings in `.wav` format on the desktop.
- Shows real-time connection status and progress during recording.

---

## 💻 Platform Support

- **macOS** ✅ Fully supported  
  - Requires `blueutil` and `sox`. The script can automatically install them via Homebrew.  
- **Linux** ⚠️ Limited support  
  - Can be tried with `bluespy` or similar tools.  
  - The script may not work directly on Linux without modifications.  
- **Windows** ❌ Not supported  
  - Running on Windows requires WSL or other adaptations.

---

## 🛠 Requirements (macOS)

- [Homebrew]
- [blueutil]
- [sox]

The script automatically checks and installs missing dependencies.

---

## 🚀 Installation

1. Clone the repository:

```bash
git clone https://github.com/username/BluePhantom.git
cd BluePhantom
chmod +x bluephantom.sh

bash bluephantom.sh
