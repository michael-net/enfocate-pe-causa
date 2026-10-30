# Privacidad y seguridad

## Qué datos maneja

La app funciona solo en tu Mac. No se conecta a internet, no tiene cuentas ni analíticas, y no recopila ni envía datos a nadie.

Todo lo que guarda está en tu Mac:

| Archivo | Contenido |
|---|---|
| `/Library/Application Support/focus/sites`, `apps` y `auto-skip` | Tu lista de bloqueos |
| `/Library/Application Support/focus/status` y `sesion.state` | Fase actual y hora en que termina |
| `/Library/Application Support/focus/lock` | Hora de fin y lista bloqueada durante una sesión |
| `/etc/hosts` | Los sitios bloqueados durante una sesión |

No guarda tu historial, qué sitios intentas abrir, cuánto usas cada app ni estadísticas. `./macos/uninstall.sh` borra todo lo anterior.

Tu contraseña la pide macOS mediante `sudo`. La app no la lee ni la guarda.

## Qué permisos usa

- **Root:** el servicio necesita editar `/etc/hosts` y cerrar apps. Es lo que impide saltarse una sesión, y por eso conviene leer el código antes de instalarlo.
- **Cerrar apps:** solo durante un bloqueo, solo las de tu lista y solo procesos de tu usuario.

## Límites

- Tus listas se pueden leer desde cualquier cuenta de esta Mac, aunque solo root puede cambiarlas.
- Otros programas que se ejecuten con tu usuario pueden enviar órdenes al servicio, como iniciar una sesión o cambiar tu lista sin sesión activa. No pueden terminar una sesión ni acortarla.
- Quien tenga la contraseña de administrador puede saltarse el bloqueo.
- macOS guarda las notificaciones en su propio centro de notificaciones.
- Los comandos del sistema (`dscacheutil`, `launchctl`, `pkill`) pueden dejar registros normales de macOS, que se quedan en tu Mac.

## Cómo comprobarlo

El código no contiene llamadas de red. Puedes revisarlo con:

```bash
grep -rnEi 'curl|wget|URLSession|https?://|socket|nc ' macos
```

Con la app abierta, este comando no debería mostrar conexiones:

```bash
lsof -nP -i -a -c Enfocate
```

## Reportar un problema

Si encuentras un problema de seguridad, abre un issue en este repositorio sin incluir datos personales.
