# Arquitectura

## macOS

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

### Comunicación

- **Órdenes:** el widget crea un archivo `cmd-*` por orden en `/Users/Shared/focus-sesion/`. El servicio solo acepta archivos normales del dueño de la Mac y estas órdenes: `auto`, `focus60`, `focus90`, `focus120`, `focus180`, `extend`, `pomodoro`, `add`, `remove`, `stop`, y para las listas `site+`, `site-`, `siteX`, `app+`, `app-`, `appX`, `skip+` y `skip-` seguidas del nombre, que se valida.
- **Estado:** el servicio escribe `/Library/Application Support/focus/status` con `phase` (`idle`, `focus`, `work`, `break`), `end`, `round`, `rounds` y `updated`. El widget solo lo lee.
- **Listas:** `sites`, `apps` y `auto-skip` (apps que la sesión automática no bloquea), en esa misma carpeta de root. Solo el servicio y la CLI con `sudo` pueden escribirlas. Una línea con `#` está desactivada.

La carpeta de órdenes la puede escribir cualquier usuario, así que el servicio no sigue enlaces simbólicos ahí y nunca escribe en ella.

### Reglas de una sesión

| Fase | Órdenes aceptadas |
|---|---|
| `idle` | `auto`, `focus*`, `pomodoro`, cambios en las listas |
| `focus` | `extend` |
| `work` | `add`, `remove` (solo rondas futuras) |
| `break` | `add`, `remove` (solo rondas futuras), `stop` |

Los cambios en las listas también se rechazan si hay un bloqueo creado desde la terminal.

Si una fase venció hace más de 10 minutos, la Mac estuvo apagada o dormida: la sesión se da por terminada. Así, al encender vuelve a empezar la sesión automática de 45 minutos en lugar de seguir un pomodoro antiguo.
Las mismas reglas valen en Windows.

### Nombres internos

El comando `focus` y los identificadores `com.focus.*` vienen del proyecto original y no se ven en la interfaz.

## Windows

Las mismas piezas y las mismas reglas, con dos diferencias: el servicio y el enforcer son un solo programa, y la bandeja lee los minutos que faltan en vez de mostrarlos junto al icono.

```
Bandeja (usuario)  --orden-->  Servicio EnfocateSesion (SYSTEM)  --> hosts
       ^                               |                          --> cierra apps
       +-------- estado <--------------+
```

| Pieza | Archivo | Se instala en | Qué hace |
|---|---|---|---|
| Bandeja | `windows/app/Bandeja.cs` | `C:\Program Files\Enfócate pe causa\Enfocate.exe` | Muestra el estado y envía órdenes |
| Servicio | `windows/servicio/Servicio.cs` | `C:\Program Files\Enfócate pe causa\EnfocateServicio.exe` | Lleva el tiempo, decide qué órdenes acepta y reaplica el bloqueo cada 2 s |
| Común | `windows/Comun.cs` | Se compila en ambos | Rutas, lectura del estado y validación de nombres |

El instalador compila con el `csc.exe` de .NET Framework 4, que viene con Windows 10 y 11. Por eso el código usa solo C# 5.

### Comunicación

- **Órdenes:** la bandeja crea un archivo `cmd-*` por orden en `C:\ProgramData\Enfocate\ordenes\`. Cualquier usuario puede crear archivos ahí, pero el servicio solo acepta los que tienen como dueño la cuenta que instaló la app (`owner`), y descarta los enlaces. Las órdenes son las mismas que en macOS.
- **Estado y listas:** `status`, `sesion.state`, `sites`, `apps` y `auto-skip` en `C:\ProgramData\Enfocate\`, con el mismo formato que en macOS. Solo SYSTEM y los administradores pueden escribirlos.
- **Bloqueo:** el servicio escribe el mismo bloque marcado en `C:\Windows\System32\drivers\etc\hosts` mientras la fase es `focus` o `work`, y lo quita en `break` e `idle`. Cierra las apps de la lista que se abran en la sesión de la consola.
- **Inicio:** la bandeja se abre al iniciar sesión desde la clave `Run` de tu usuario. Envía `auto` al abrirse y al despertar la PC. Como en algunos equipos Windows no avisa de la suspensión, también la detecta cuando el reloj salta más de 2 minutos.
