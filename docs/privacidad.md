# Privacidad y seguridad

## Qué datos maneja

La app funciona solo en tu computadora. No tiene cuentas ni analíticas, y no recopila ni envía datos a nadie. Su única consulta de red es la dirección de tus sitios bloqueados, al empezar una sesión (ver [Qué permisos usa](#qué-permisos-usa)).

Todo lo que guarda está en tu computadora. En Mac:

| Archivo | Contenido |
|---|---|
| `/Library/Application Support/focus/sites`, `apps` y `auto-skip` | Tu lista de bloqueos |
| `/Library/Application Support/focus/status` y `sesion.state` | Fase actual y hora en que termina |
| `/Library/Application Support/focus/lock` | Hora de fin y lista bloqueada durante una sesión |
| `/etc/hosts` | Los sitios bloqueados durante una sesión |
| `/Library/Application Support/focus/pf-token` y `pf-hasta` | Mientras dura el corte de conexiones: el permiso del filtro de paquetes y la hora en que se quita |
| `/Library/Preferences/org.mozilla.firefox.plist` | La política que apaga el DNS cifrado de Firefox, para que respete el bloqueo |

En Windows, lo mismo está en `C:\ProgramData\Enfocate\` (`sites`, `apps`, `auto-skip`, `status`, `sesion.state` y `owner`, el identificador de tu cuenta) y en `C:\Windows\System32\drivers\etc\hosts`. La política de Firefox está en el registro, en `HKLM\SOFTWARE\Policies\Mozilla\Firefox\DNSOverHTTPS`.

No guarda tu historial, qué sitios intentas abrir, cuánto usas cada app ni estadísticas. `macos/uninstall.sh` y `windows\desinstalar.cmd` borran todo lo anterior.

Tu contraseña la pide el sistema (`sudo` en macOS, el aviso de administrador en Windows). La app no la lee ni la guarda.

## Qué permisos usa

- **Root en macOS, SYSTEM en Windows:** el servicio necesita editar el archivo `hosts` y cerrar apps. Es lo que impide saltarse una sesión, y por eso conviene leer el código antes de instalarlo.
- **Política de Firefox:** apaga el DNS sobre HTTPS de Firefox, su VPN integrada y HTTP/3, y deja su caché de direcciones en 1 segundo. Así Firefox consulta las direcciones con el DNS de tu computadora, como Safari, Chrome o Edge. No cambia nada más del navegador ni ve lo que visitas.
- **Cortar conexiones al empezar un bloqueo:** reinicia el proceso de red de los navegadores (no lee su contenido), reinicia el DNS del sistema y, por 3 minutos, rechaza el tráfico hacia las direcciones de los sitios bloqueados con el filtro de paquetes de macOS (`pf`) o una regla del firewall de Windows. Al terminar, la regla se quita.
- **Consultar las direcciones de tus sitios bloqueados:** para ese rechazo, el servicio pregunta la dirección de cada sitio de tu lista al mismo servidor DNS que ya usa tu computadora. Es la única consulta de red que hace la app, y no envía nada más.
- **Cerrar apps:** solo durante un bloqueo, solo las de tu lista y solo procesos de tu usuario.

## Límites

- Tus listas se pueden leer desde cualquier cuenta de esta computadora, aunque solo el servicio y los administradores pueden cambiarlas.
- Otros programas que se ejecuten con tu usuario pueden enviar órdenes al servicio, como iniciar una sesión o cambiar tu lista sin sesión activa. No pueden terminar una sesión ni acortarla.
- Quien tenga la contraseña de administrador puede saltarse el bloqueo.
- El sistema guarda las notificaciones en su propio centro de notificaciones.
- Los comandos del sistema (`dscacheutil`, `launchctl`, `pkill`) pueden dejar registros normales de macOS, y Windows anota en su registro de eventos cuando el servicio arranca o se detiene. Todo se queda en tu computadora.

## Cómo comprobarlo

Fuera de esa consulta DNS (`dig` en macOS, `Dns.GetHostAddresses` en Windows), el código no contiene llamadas de red. Puedes revisarlo con:

```bash
grep -rnEi 'curl|wget|URLSession|https?://|socket|nc ' macos
```

Con la app abierta, este comando no debería mostrar conexiones:

```bash
lsof -nP -i -a -c Enfocate
```

En Windows, el código está en `windows/` y se puede revisar igual:

```powershell
Select-String -Path windows\*.cs, windows\*\*.cs -Pattern 'WebClient|HttpClient|WebRequest|Socket|TcpClient'
```

## Reportar un problema

Si encuentras un problema de seguridad, abre un issue en este repositorio sin incluir datos personales.
