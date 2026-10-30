# Privacidad y seguridad

## Qué datos maneja

La app funciona solo en tu computadora. No se conecta a internet, no tiene cuentas ni analíticas, y no recopila ni envía datos a nadie.

Todo lo que guarda está en tu computadora. En Mac:

| Archivo | Contenido |
|---|---|
| `/Library/Application Support/focus/sites`, `apps` y `auto-skip` | Tu lista de bloqueos |
| `/Library/Application Support/focus/status` y `sesion.state` | Fase actual y hora en que termina |
| `/Library/Application Support/focus/lock` | Hora de fin y lista bloqueada durante una sesión |
| `/etc/hosts` | Los sitios bloqueados durante una sesión |

En Windows, lo mismo está en `C:\ProgramData\Enfocate\` (`sites`, `apps`, `auto-skip`, `status`, `sesion.state` y `owner`, el identificador de tu cuenta) y en `C:\Windows\System32\drivers\etc\hosts`.

No guarda tu historial, qué sitios intentas abrir, cuánto usas cada app ni estadísticas. `macos/uninstall.sh` y `windows\desinstalar.cmd` borran todo lo anterior.

Tu contraseña la pide el sistema (`sudo` en macOS, el aviso de administrador en Windows). La app no la lee ni la guarda.

## Qué permisos usa

- **Root en macOS, SYSTEM en Windows:** el servicio necesita editar el archivo `hosts` y cerrar apps. Es lo que impide saltarse una sesión, y por eso conviene leer el código antes de instalarlo.
- **Cerrar apps:** solo durante un bloqueo, solo las de tu lista y solo procesos de tu usuario.

## Límites

- Tus listas se pueden leer desde cualquier cuenta de esta computadora, aunque solo el servicio y los administradores pueden cambiarlas.
- Otros programas que se ejecuten con tu usuario pueden enviar órdenes al servicio, como iniciar una sesión o cambiar tu lista sin sesión activa. No pueden terminar una sesión ni acortarla.
- Quien tenga la contraseña de administrador puede saltarse el bloqueo.
- El sistema guarda las notificaciones en su propio centro de notificaciones.
- Los comandos del sistema (`dscacheutil`, `launchctl`, `pkill`) pueden dejar registros normales de macOS, y Windows anota en su registro de eventos cuando el servicio arranca o se detiene. Todo se queda en tu computadora.

## Cómo comprobarlo

El código no contiene llamadas de red. Puedes revisarlo con:

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

## iPhone y Android

Las apps de celular siguen las mismas reglas: funcionan solo en tu celular, no tienen cuentas, anuncios ni analíticas, y no recopilan ni envían datos.

| | iPhone | Android |
|---|---|---|
| Qué guarda | Tu configuración y las fichas opacas de las apps que elegiste, en el grupo de la app | Tu configuración y la lista de apps que elegiste, en el almacenamiento privado de la app |
| Cómo sabe qué bloquear | iOS le da fichas opacas: la app nunca sabe qué apps elegiste | Por el nombre del paquete de cada app que elegiste |
| Cómo mide el uso | Lo mide iOS. La app solo recibe el aviso de "se llegó al límite" | Lee los minutos que ya registra Android. No guarda un historial propio |
| Internet | Sin código de red | Sin permiso de internet: Android no la deja conectarse |
| Permisos | Tiempo de uso | Accesibilidad (sin leer la pantalla), acceso a uso y notificaciones |
| Copias en la nube | No | No (`allowBackup="false"`) |

Al desinstalar la app se borra todo lo que guardó.

## Reportar un problema

Si encuentras un problema de seguridad, abre un issue en este repositorio sin incluir datos personales.
