# Arquitectura (macOS)

Tres piezas con permisos distintos. La regla principal: **las reglas se cumplen en el servicio de root, nunca en la interfaz.** Por eso el widget no puede saltarse una sesión.

```
Widget (usuario)  --orden-->  Servicio de sesiones (root)  --lock-->  Enforcer (root)
       ^                               |                                 |
       +-------- estado <--------------+                                 +--> /etc/hosts
                                                                         +--> cierra apps
```

| Pieza | Archivo | Se instala en | Qué hace |
|---|---|---|---|
| Widget | `macos/app/main.swift` | `~/Applications/Enfócate pe causa.app` | Muestra el estado y envía órdenes |
| Servicio de sesiones | `macos/daemon/focus-sesion-daemon.sh` | `/usr/local/libexec/focus-sesion` | Lleva el tiempo y decide qué órdenes acepta |
| CLI | `macos/cli/focus` | `/usr/local/libexec/focus-cli` | Edita las listas y crea el bloqueo |
| Enforcer | Lo genera la CLI | `/usr/local/libexec/focus-enforcer` | Reaplica el bloqueo cada 2 s y se elimina al terminar |

## Comunicación

- **Órdenes:** el widget crea un archivo `cmd-*` por orden en `/Users/Shared/focus-sesion/`. El servicio solo acepta archivos normales del dueño de la Mac y estas órdenes: `auto`, `focus60`, `focus90`, `focus120`, `focus180`, `extend`, `pomodoro`, `add`, `remove`, `stop`, y para las listas `site+`, `site-`, `siteX`, `app+`, `app-`, `appX`, `skip+` y `skip-` seguidas del nombre, que se valida.
- **Estado:** el servicio escribe `/Library/Application Support/focus/status` con `phase` (`idle`, `focus`, `work`, `break`), `end`, `round`, `rounds` y `updated`. El widget solo lo lee.
- **Listas:** `sites`, `apps` y `auto-skip` (apps que la sesión automática no bloquea), en esa misma carpeta de root. Solo el servicio y la CLI con `sudo` pueden escribirlas. Una línea con `#` está desactivada.

La carpeta de órdenes la puede escribir cualquier usuario, así que el servicio no sigue enlaces simbólicos ahí y nunca escribe en ella.

## Reglas de una sesión

| Fase | Órdenes aceptadas |
|---|---|
| `idle` | `auto`, `focus*`, `pomodoro`, cambios en las listas |
| `focus` | `extend` |
| `work` | `add`, `remove` (solo rondas futuras) |
| `break` | `add`, `remove` (solo rondas futuras), `stop` |

Los cambios en las listas también se rechazan si hay un bloqueo creado desde la terminal.

Si una fase venció hace más de 10 minutos, la Mac estuvo apagada o dormida: la sesión se da por terminada. Así, al encender vuelve a empezar la sesión automática de 45 minutos en lugar de seguir un pomodoro antiguo.

## Nombres internos

El comando `focus` y los identificadores `com.focus.*` vienen del proyecto original y no se ven en la interfaz.
