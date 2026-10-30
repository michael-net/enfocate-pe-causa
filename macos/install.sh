#!/bin/bash
# Compila e instala Enfócate pe causa. Uso: ./macos/install.sh
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
APP="$HOME/Applications/Enfócate pe causa.app"
AGENT="$HOME/Library/LaunchAgents/com.focus.sesion.widget.plist"

[ "$(uname)" = Darwin ] || { echo "Este instalador es para macOS. En Windows usa windows\\instalar.cmd."; exit 1; }
[ "$(id -u)" != 0 ] || { echo "Ejecútalo sin sudo: ./macos/install.sh. Te pedirá la contraseña cuando haga falta."; exit 1; }
MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
[ "$MAJOR" -ge 13 ] || { echo "Necesitas macOS 13 Ventura o superior. Tienes $(sw_vers -productVersion)."; exit 1; }
# /usr/bin/swiftc existe aunque falten las herramientas: xcode-select dice si están instaladas.
if ! xcode-select -p >/dev/null 2>&1 || ! command -v swiftc >/dev/null; then
  echo "Faltan las herramientas de línea de comandos de Xcode. Se abrirá una ventana para instalarlas."
  echo "Cuando termine, vuelve a ejecutar ./macos/install.sh"
  xcode-select --install 2>/dev/null || true
  exit 1
fi

# Si descargaste el ZIP, macOS marca los archivos como descargados de internet.
xattr -dr com.apple.quarantine "$HERE/.." 2>/dev/null || true

echo "Compilando el widget..."
mkdir -p "$APP/Contents/MacOS" "$HOME/Library/LaunchAgents"
swiftc -O "$HERE/app/main.swift" -o "$APP/Contents/MacOS/Enfocate" || {
  echo "No se pudo compilar. Si actualizaste macOS hace poco, reinstala las herramientas:"
  echo "  sudo rm -rf /Library/Developer/CommandLineTools && xcode-select --install"
  exit 1
}
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
