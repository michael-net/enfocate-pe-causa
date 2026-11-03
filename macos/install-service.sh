#!/bin/bash
# Instala las partes de root. Lo ejecuta install.sh con sudo.
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Ejecuta con sudo: sudo bash $0"; exit 1; }
HERE="$(cd "$(dirname "$0")" && pwd)"
U="${SUDO_USER:?falta SUDO_USER}"
UH="$(dscl . -read "/Users/$U" NFSHomeDirectory | awk '{print $2}')"
UID_OWNER="$(id -u "$U")"
FDIR="/Library/Application Support/focus"
LABEL="com.focus.sesion"
PLIST="/Library/LaunchDaemons/$LABEL.plist"

# Versión anterior (pomodoro, y estado en la carpeta compartida)
launchctl bootout "system/com.focus.pomodoro" 2>/dev/null || true
rm -f /Library/LaunchDaemons/com.focus.pomodoro.plist /usr/local/libexec/focus-pomodoro \
      "/Library/Application Support/focus/pomo.state"
rm -rf /Users/Shared/focus-pomodoro
rm -f /Users/Shared/focus-sesion/status /Users/Shared/focus-sesion/status.tmp

mkdir -p /usr/local/libexec "$FDIR" /Users/Shared/focus-sesion
chmod 1777 /Users/Shared/focus-sesion
rm -f /Users/Shared/focus-sesion/cmd

# Las listas pasan de tu carpeta personal a la carpeta de root
migrate() { # archivo antiguo, archivo nuevo, patrón válido
  if [ ! -f "$2" ]; then
    if [ -f "$1" ]; then grep -E "$3" "$1" > "$2" || true; else : > "$2"; fi
    chmod 644 "$2"
  fi
  rm -f "$1"
}
migrate "$UH/.focus-sites" "$FDIR/sites" '^[a-z0-9][a-z0-9.-]*$'
migrate "$UH/.focus-apps" "$FDIR/apps" '^[A-Za-z0-9][A-Za-z0-9 ._-]*$'

# Por defecto, la sesión automática deja libre WhatsApp
if [ ! -f "$FDIR/auto-skip" ]; then
  echo "WhatsApp" > "$FDIR/auto-skip"
  chmod 644 "$FDIR/auto-skip"
fi

# Sin sesión activa no debe quedar nada bloqueado
if [ ! -f "$FDIR/lock" ]; then
  # Se escribe sobre el mismo archivo: si se reemplaza, macOS deja de notar los cambios en /etc/hosts.
  T="$(mktemp)"
  sed '/^# >>> focus block >>>$/,/^# <<< focus block <<<$/d' /etc/hosts > "$T"
  cmp -s "$T" /etc/hosts || tee /etc/hosts < "$T" > /dev/null
  rm -f "$T"
  dscacheutil -flushcache 2>/dev/null || true
  killall mDNSResponder 2>/dev/null || true
fi

# Firefox puede usar su propio DNS cifrado e ignorar /etc/hosts. Una política del sistema lo apaga
# para que use el DNS de la Mac. Si el archivo de políticas no existía, se anota para borrarlo al desinstalar.
FFPOL="/Library/Preferences/org.mozilla.firefox"
[ -f "$FFPOL.plist" ] || touch "$FDIR/firefox-politica"
defaults write "$FFPOL" EnterprisePoliciesEnabled -bool true
defaults write "$FFPOL" DNSOverHTTPS -dict Enabled -bool false Locked -bool true
# Firefox guarda direcciones 2 minutos y usa HTTP/3, que mantiene conexiones abiertas por UDP.
# Sin eso, al empezar una sesión sigue entrando a los sitios que ya había visitado.
locked() { echo "<key>$1</key><dict><key>Value</key>$2<key>Status</key><string>locked</string></dict>"; }
defaults write "$FFPOL" Preferences "<dict>$(locked network.dnsCacheExpiration '<integer>0</integer>')$(locked network.dnsCacheExpirationGracePeriod '<integer>0</integer>')$(locked network.http.http3.enable '<false/>')</dict>"
chmod 644 "$FFPOL.plist"

install -m 755 -o root -g wheel "$HERE/cli/focus" /usr/local/libexec/focus-cli
sed "s#__UID__#$UID_OWNER#" "$HERE/daemon/focus-sesion-daemon.sh" > /usr/local/libexec/focus-sesion
chown root:wheel /usr/local/libexec/focus-sesion
chmod 755 /usr/local/libexec/focus-sesion

cat > "$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>/usr/local/libexec/focus-sesion</string></array>
  <key>KeepAlive</key><true/>
  <key>RunAtLoad</key><true/>
</dict></plist>
PL
chown root:wheel "$PLIST"
chmod 644 "$PLIST"
launchctl bootout "system/$LABEL" 2>/dev/null || true
launchctl bootstrap system "$PLIST"
echo "Servicio instalado."
