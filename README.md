# Enfócate pe causa

Una herramienta para dejar la costumbre de tener las redes sociales siempre a la mano.

Bloquea los sitios y las apps que tú elijas durante sesiones que no puedes cancelar a medias. Vive en la barra de menú y solo muestra lo necesario: un icono y el tiempo que falta.

> **Plataformas:** funciona en macOS. La versión para Windows está diseñada, pero todavía no existe ([diseño](docs/diseno.md)).

## Dos tipos de sesión

| | Sesión de enfoque | Pomodoro |
|---|---|---|
| **Para qué** | Clases, reuniones, bloques largos | Estudiar |
| **Duración** | 1 h, 1 h 30 min, 2 h o 3 h | 25 min de trabajo y 5 de descanso, 4 rondas |
| **Durante la sesión** | Puedes extender 30 min | Puedes agregar rondas o quitar rondas futuras |
| **Terminar antes** | No se puede | Solo durante un descanso |

Además, cada vez que enciendes tu Mac, inicias sesión o la abres después de suspenderla, empieza sola una sesión de enfoque de 45 minutos si no hay otra activa. Por defecto, esa sesión no bloquea WhatsApp. Puedes elegir qué apps bloquea en **Qué bloquear…**.

## Instalación

Necesitas macOS 13 o superior y las herramientas de línea de comandos de Xcode (`xcode-select --install`).

```bash
git clone https://github.com/michael-net/enfocate-pe-causa.git
cd enfocate-pe-causa
./macos/install.sh
```

Te pedirá tu contraseña porque el servicio de bloqueo se ejecuta como root. Al terminar aparece un icono en la barra de menú.

## Qué bloquear

Abre el icono de la barra de menú y elige **Qué bloquear…**. Ahí activas, desactivas, agregas o quitas sitios y apps.

Esta opción solo aparece cuando no hay ninguna sesión activa. Durante una sesión, lo que se bloquea no se puede cambiar.

`/etc/hosts` no acepta comodines, así que cada subdominio se agrega aparte (por ejemplo `m.youtube.com`).

También se pueden agregar desde la terminal con `macos/cli/focus block instagram.com` y `macos/cli/focus blockapp WhatsApp`.

## Privacidad

La app no se conecta a internet, no tiene cuentas ni analíticas, y no recopila ni envía datos. Solo guarda en tu Mac tu lista de bloqueos y el estado de la sesión actual. [Ver el detalle](docs/privacidad.md).

## Limitaciones

- **Quien tenga la contraseña de administrador puede saltarse el bloqueo**, editando `/etc/hosts`, deteniendo el servicio o cambiando la hora del sistema. La herramienta frena el impulso, no a un administrador decidido.
- **DNS sobre HTTPS:** si un navegador lo tiene activado, puede ignorar `/etc/hosts`. Desactívalo en los ajustes del navegador, por ejemplo en Firefox.
- **Apps nativas:** se cierran hasta 2 segundos después de abrirse. Solo se cierran durante un bloqueo activo.
- **Fuera de las sesiones:** sin una sesión activa, nada está bloqueado.

## Desinstalar

```bash
./macos/uninstall.sh
```

No funciona durante una sesión activa.

## Documentación

- [Arquitectura](docs/arquitectura.md)
- [Diseño para macOS y Windows](docs/diseno.md)
- [Privacidad y seguridad](docs/privacidad.md)

## Créditos

Basado en [screen-block](https://github.com/ponchodelosrios98/screen-block), de Alfonso de los Rios. Licencia [MIT](LICENSE).
