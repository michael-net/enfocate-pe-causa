#!/bin/bash
# Servicio de root de "Enfócate pe causa". Dos modos:
#   - Sesión de enfoque: un bloque continuo. No se cancela ni se acorta, solo se extiende.
#   - Pomodoro: rondas de trabajo (bloqueado) y descanso (libre). Solo se puede
#     terminar durante un descanso, y solo se quitan rondas futuras.
# El widget solo envía órdenes: las reglas se cumplen aquí.
set -u
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin"

OWNER_UID="__UID__"
BASE="/Library/Application Support/focus"
DIR="/Users/Shared/focus-sesion"
# Todo lo que escribe este servicio vive en una carpeta de root. $DIR la puede
# modificar cualquier usuario: aquí solo se leen órdenes, nunca se escribe.
STATUS="$BASE/status"
STATE="$BASE/sesion.state"
SITES="$BASE/sites"
APPS="$BASE/apps"
AUTO_SKIP="$BASE/auto-skip"   # apps que la sesión automática no bloquea
LOCK="$BASE/lock"
FOCUS="/usr/local/libexec/focus-cli"

AUTO_S=2700       # sesión automática: 45 min
EXTEND_S=1800     # +30 min
MAX_S=43200       # tope: 12 h restantes
WORK_S=1500       # pomodoro: 25 min
BREAK_S=300       # pomodoro: 5 min
DEF_ROUNDS=4
MAX_ROUNDS=20
OVERDUE_S=600     # si una fase venció hace más de esto, la Mac estuvo apagada o dormida

phase=idle; end=0; round=0; rounds=0; auto=0
if [ -f "$STATE" ]; then
  while IFS='=' read -r k v; do
    case "$k" in
      phase) case "$v" in idle|focus|work|break) phase=$v ;; esac ;;
      end|round|rounds|auto) case "$v" in ''|*[!0-9]*) ;; *) printf -v "$k" '%s' "$v" ;; esac ;;
    esac
  done < "$STATE"
fi

save() {
  printf 'phase=%s\nend=%s\nround=%s\nrounds=%s\nauto=%s\n' "$phase" "$end" "$round" "$rounds" "$auto" > "$STATE.tmp" \
    && mv "$STATE.tmp" "$STATE"
}

write_status() {
  printf 'phase=%s\nend=%s\nround=%s\nrounds=%s\nupdated=%s\n' \
    "$phase" "$end" "$round" "$rounds" "$(date +%s)" > "$STATUS.tmp" \
    && chmod 644 "$STATUS.tmp" && mv "$STATUS.tmp" "$STATUS"
}

go_idle() { phase=idle; end=0; round=0; rounds=0; auto=0; }

lock_active() {
  [ -f "$LOCK" ] || return 1
  local until_epoch
  until_epoch="$(sed -n '1p' "$LOCK" 2>/dev/null)"
  case "$until_epoch" in ''|*[!0-9]*) return 1 ;; esac
  [ "$(date +%s)" -lt "$until_epoch" ]
}

# Cambia un elemento de una lista sin alterar el orden.
# Una línea que empieza con # es un elemento desactivado.
list_set() { # archivo, valor, on|off|del
  touch "$1"
  awk -v v="$2" -v s="$3" '
    BEGIN { r = (s == "on") ? v : "#" v }
    $0 == v || $0 == "#" v { found = 1; if (s != "del") print r; next }
    { print }
    END { if (!found && s != "del") print r }
  ' "$1" > "$1.tmp" && chmod 644 "$1.tmp" && mv "$1.tmp" "$1"
}

# Las listas solo se pueden editar sin ninguna sesión ni bloqueo activos.
edit_list() { # sites|apps, on|off|del, valor
  [ "$phase" = idle ] && ! lock_active || return 0
  case "$1" in
    sites) [[ "$3" =~ ^[a-z0-9][a-z0-9.-]*$ ]] && list_set "$SITES" "$3" "$2" ;;
    skip) [[ "$3" =~ ^[A-Za-z0-9][A-Za-z0-9\ ._-]*$ ]] && list_set "$AUTO_SKIP" "$3" "$2" ;;
    apps) [[ "$3" =~ ^[A-Za-z0-9][A-Za-z0-9\ ._-]*$ ]] && list_set "$APPS" "$3" "$2" ;;
  esac
}

run_cmd() {
  local now c="$1"
  now=$(date +%s)
  case "$c" in
    focus60|focus90|focus120|focus180)
      if [ "$phase" = idle ]; then start_focus "${c#focus}"; fi ;;
    auto)
      if [ "$phase" = idle ]; then start_auto; fi ;;
    extend)
      if [ "$phase" = focus ]; then
        new_end=$(( end + EXTEND_S ))
        flag=""
        if [ "$auto" = 1 ]; then flag="--auto"; fi
        # shellcheck disable=SC2086
        if [ $(( new_end - now )) -le "$MAX_S" ] \
           && "$FOCUS" lock "$(( new_end - now ))s" $flag >/dev/null 2>&1; then
          end=$new_end
        fi
      fi ;;
    pomodoro)
      if [ "$phase" = idle ]; then rounds=$DEF_ROUNDS; round=1; start_work; fi ;;
    stop)   # solo durante un descanso
      if [ "$phase" = break ]; then go_idle; fi ;;
    add)
      if { [ "$phase" = work ] || [ "$phase" = break ]; } && [ "$rounds" -lt "$MAX_ROUNDS" ]; then
        rounds=$(( rounds + 1 ))
      fi ;;
    remove)  # solo rondas futuras
      if { [ "$phase" = work ] || [ "$phase" = break ]; } && [ "$rounds" -gt "$round" ]; then
        rounds=$(( rounds - 1 ))
      fi ;;
    "site+ "*) edit_list sites on "${c#* }" ;;
    "site- "*) edit_list sites off "${c#* }" ;;
    "siteX "*) edit_list sites del "${c#* }" ;;
    "app+ "*) edit_list apps on "${c#* }" ;;
    "app- "*) edit_list apps off "${c#* }" ;;
    "appX "*) edit_list apps del "${c#* }" ;;
    "skip+ "*) edit_list skip on "${c#* }" ;;
    "skip- "*) edit_list skip del "${c#* }" ;;
  esac
}

start_focus() { # $1 = minutos
  local secs=$(( $1 * 60 ))
  if "$FOCUS" lock "${secs}s" >/dev/null 2>&1; then
    phase=focus; end=$(( $(date +%s) + secs ))
  fi
}

# Al encender o abrir la Mac: no bloquea las apps de $AUTO_SKIP.
start_auto() {
  if "$FOCUS" lock "${AUTO_S}s" --auto >/dev/null 2>&1; then
    phase=focus; auto=1; end=$(( $(date +%s) + AUTO_S ))
  fi
}

start_work() {
  if "$FOCUS" lock "${WORK_S}s" >/dev/null 2>&1; then
    phase=work; end=$(( $(date +%s) + WORK_S ))
  else
    go_idle
  fi
}

mkdir -p "$DIR"; chmod 1777 "$DIR"
save; write_status

while true; do
  # Cada orden es un archivo propio, para no perder órdenes seguidas.
  # Solo se aceptan archivos normales del dueño de la Mac.
  for f in "$DIR"/cmd-*; do
    [ -e "$f" ] || [ -L "$f" ] || continue
    c=""
    if [ -f "$f" ] && [ ! -L "$f" ] && [ "$(stat -f %u "$f")" = "$OWNER_UID" ]; then
      c="$(head -c 200 "$f" 2>/dev/null | head -n 1 | tr -d '\r')"
    fi
    rm -f "$f"
    run_cmd "$c"
    save
  done

  now=$(date +%s)
  if [ "$phase" != idle ] && [ "$now" -ge $(( end + OVERDUE_S )) ]; then
    go_idle
    save
  elif [ "$phase" != idle ] && [ "$now" -ge "$end" ]; then
    case "$phase" in
      focus) go_idle ;;
      work)
        if [ "$round" -ge "$rounds" ]; then go_idle
        else phase=break; end=$(( now + BREAK_S )); fi ;;
      break)
        if [ "$round" -ge "$rounds" ]; then go_idle
        else round=$(( round + 1 )); start_work; fi ;;
    esac
    save
  fi

  write_status
  sleep 1
done
