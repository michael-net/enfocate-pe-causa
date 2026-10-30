#!/bin/bash
# Compila e instala Enfócate pe causa. Uso: ./macos/install.sh
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
APP="$HOME/Applications/Enfócate pe causa.app"
AGENT="$HOME/Library/LaunchAgents/com.focus.sesion.widget.plist"

command -v swiftc >/dev/null || { echo "Falta swiftc. Instala con: xcode-select --install"; exit 1; }

echo "Compilando el widget..."
mkdir -p "$APP/Contents/MacOS" "$HOME/Library/LaunchAgents"
swiftc -O "$HERE/app/main.swift" -o "$APP/Contents/MacOS/Enfocate"
cp "$HERE/app/Info.plist" "$APP/Contents/Info.plist"
codesign --force -s - "$APP"

sudo bash "$HERE/install-service.sh"

cat > "$AGENT" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.focus.sesion.widget</string>
  <key>ProgramArguments</key><array><string>$APP/Contents/MacOS/Enfocate</string></array>
  <key>RunAtLoad</key><true/>
</dict></plist>
PL

# Se abre sin sesión automática: esa arranca desde el próximo inicio de sesión.
pkill -x Enfocate 2>/dev/null || true
sleep 1
nohup "$APP/Contents/MacOS/Enfocate" --sin-auto >/dev/null 2>&1 &
echo "Listo. Busca el icono en la barra de menú."
