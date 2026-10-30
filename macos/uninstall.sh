#!/bin/bash
# Desinstala Enfócate pe causa. No funciona durante una sesión activa.
# Uso: ./macos/uninstall.sh
set -euo pipefail
LOCK="/Library/Application Support/focus/lock"
if [ -f "$LOCK" ] && [ "$(date +%s)" -lt "$(sed -n '1p' "$LOCK")" ]; then
  echo "Hay una sesión activa. Podrás desinstalar cuando termine."
  exit 1
fi

launchctl bootout "gui/$(id -u)/com.focus.sesion.widget" 2>/dev/null || true
pkill -x Enfocate 2>/dev/null || true
rm -rf "$HOME/Applications/Enfócate pe causa.app"
rm -f "$HOME/Library/LaunchAgents/com.focus.sesion.widget.plist"

sudo launchctl bootout system/com.focus.sesion 2>/dev/null || true
sudo rm -f /Library/LaunchDaemons/com.focus.sesion.plist \
           /usr/local/libexec/focus-sesion /usr/local/libexec/focus-cli
sudo rm -rf "/Library/Application Support/focus" /Users/Shared/focus-sesion
sudo sed -i '' '/^# >>> focus block >>>$/,/^# <<< focus block <<<$/d' /etc/hosts
sudo dscacheutil -flushcache 2>/dev/null || true
sudo killall -HUP mDNSResponder 2>/dev/null || true
echo "Desinstalado. No queda ningún dato de la app en tu Mac."
