# Enfócate pe causa

Un bloqueador de redes sociales y distracciones para Mac y Windows, pensado desde el usuario: para cortar la costumbre de abrir el celular o la compu y caer directo en las apps.

Creado por **Michael Net**.

## Por qué existe

Casi todos tenemos el mismo ritual: despertamos, abrimos Instagram, TikTok o YouTube "un ratito", y cuando levantamos la cabeza ya se fue la mañana. Lo mismo pasa cuando nos sentamos a trabajar o a estudiar: basta una pestaña para salir de la concentración.

Esa cadena no se rompe con fuerza de voluntad en el momento del impulso. Se rompe decidiendo antes, cuando estás tranquilo, y poniendo un poco de fricción entre tú y la app.

Por eso **Enfócate pe causa** no es un bloqueador más hecho para controlar a otros. Está pensado para ti, que quieres recuperar tu tiempo:

- **Tú decides qué bloquear**, sin sesión activa y con la cabeza fría.
- **Una sesión no se cancela a medias.** Si el impulso llega a los 10 minutos, la app no te deja negociar contigo mismo.
- **Las mañanas empiezan enfocadas.** Al encender tu computadora, o al abrirla después de suspenderla, empieza sola una sesión de enfoque de 45 minutos. El primer gesto del día deja de ser abrir redes sociales.
- **Sesiones de trabajo de verdad**, con bloques largos o con pomodoros.
- **Calma.** Solo un icono y el tiempo que falta. Sin colores de alerta, sin rachas ni medallas que compitan por tu atención.
- **Privacidad.** No se conecta a internet, no tiene cuentas ni analíticas, y no sabe qué haces.

## ¿Funciona en mi computadora?

| Sistema | Estado | Requisitos |
|---|---|---|
| **macOS** 13 Ventura o superior (Intel y Apple Silicon) | Funciona | Cuenta de administrador y las herramientas de línea de comandos de Xcode (el instalador te las ofrece) |
| **Windows** 10 y 11 | Nuevo, en prueba | Cuenta de administrador. No hay que instalar nada más |
| iPhone y Android | En desarrollo en la rama [`movil`](https://github.com/michael-net/enfocate-pe-causa/tree/movil) ([plan](docs/plan-movil.md)) | |
| Linux | No disponible | |

La app se compila en tu propia computadora al instalarla. Así funciona en cualquier procesador y no hay que confiar en un archivo descargado.

## Instalación en Mac

1. Abre la app **Terminal** (búscala con `Cmd + Espacio`).
2. Copia y pega estas líneas, una por una, y presiona `Enter`:

```bash
git clone https://github.com/michael-net/enfocate-pe-causa.git
```

```bash
cd enfocate-pe-causa
```

```bash
bash macos/install.sh
```

3. Si es la primera vez, macOS te pedirá instalar las **herramientas de línea de comandos de Xcode**. Acepta, espera a que terminen y vuelve a ejecutar `bash macos/install.sh`.
4. Escribe tu contraseña de la Mac cuando te la pida. No se ve mientras la escribes, es normal.

Al terminar aparece un icono de diana en la barra de menú, arriba a la derecha.

**Sin git:** en esta página, pulsa **Code > Download ZIP**, descomprímelo, abre la Terminal, escribe `cd ` (con un espacio), arrastra la carpeta descomprimida a la ventana, presiona `Enter` y sigue desde el paso 3 con `bash macos/install.sh`.

## Instalación en Windows

1. En esta página, pulsa **Code > Download ZIP**.
2. Haz clic derecho en el ZIP descargado y elige **Extraer todo**. No lo ejecutes desde dentro del ZIP.
3. Abre la carpeta extraída, entra a `windows` y haz doble clic en **`instalar.cmd`**.
4. Si Windows muestra "Windows protegió tu PC", pulsa **Más información > Ejecutar de todas formas**. Pasa con cualquier script descargado de internet.
5. Acepta el permiso de administrador.

Al terminar aparece un icono de diana en la bandeja del sistema, abajo a la derecha. Si no lo ves, pulsa la flecha `^` de la bandeja y arrástralo a la barra de tareas.

El instalador usa el compilador de C# que ya trae Windows (.NET Framework 4). No descarga nada.

## Cómo se usa

Haz clic en el icono y elige el tipo de sesión.

| | Sesión de enfoque | Pomodoro |
|---|---|---|
| **Para qué** | Clases, reuniones, bloques largos de trabajo | Estudiar |
| **Duración** | 1 h, 1 h 30 min, 2 h o 3 h | 25 min de trabajo y 5 de descanso, 4 rondas |
| **Durante la sesión** | Puedes extender 30 min | Puedes agregar rondas o quitar rondas futuras |
| **Terminar antes** | No se puede | Solo durante un descanso |

Además, cada vez que enciendes la computadora, inicias sesión o la abres después de suspenderla, empieza sola una **sesión de enfoque de 45 minutos** si no hay otra activa. Por defecto, esa sesión no bloquea WhatsApp, para que no te pierdas mensajes importantes.

### Qué bloquear

En el icono, elige **Qué bloquear…**. Ahí activas, desactivas, agregas o quitas sitios y apps, y eliges qué apps bloquea la sesión automática.

- Esta opción solo aparece sin sesión activa. Durante una sesión, lo que se bloquea no se puede cambiar.
- Cada subdominio se agrega aparte, por ejemplo `m.youtube.com`, porque el archivo `hosts` no acepta comodines.
- **En Windows**, una app se agrega por el nombre de su programa, sin `.exe`. Si no sabes cuál es, ábrela y búscala en el **Administrador de tareas > Detalles**.
- **En Mac**, también se puede usar la terminal: `macos/cli/focus block instagram.com` y `macos/cli/focus blockapp WhatsApp`.

## Cómo funciona

Los sitios se bloquean desde el archivo `hosts` del sistema, y las apps se cierran si se abren durante una sesión. Un servicio del sistema lleva el tiempo y aplica las reglas, así que cerrar el icono no termina la sesión, y tampoco reiniciar.

| | Mac | Windows |
|---|---|---|
| Icono | Barra de menú, con el tiempo restante al lado | Bandeja del sistema, con los minutos restantes dentro del icono y el tiempo exacto al pasar el cursor |
| Servicio | `launchd`, como root | Servicio de Windows, como SYSTEM |
| Tus listas | `/Library/Application Support/focus/` | `C:\ProgramData\Enfocate\` |

Más detalle en [Arquitectura](docs/arquitectura.md).

## Navegadores

Al empezar una sesión, la app también corta las conexiones que el navegador ya tenía abiertas. Sin eso, una pestaña de Instagram abierta seguiría funcionando. Los navegadores reabren su conexión solos, sin cerrar pestañas.

| Navegador | Mac | Windows | Qué hace la app | Qué haces tú |
|---|---|---|---|---|
| **Safari** | Probado | No existe en Windows | Reinicia su proceso de red | Si usas **Relay Privado de iCloud** y Safari sigue abriendo los sitios, apágalo en Ajustes del Sistema > tu nombre > iCloud |
| **Chrome** | Probado | Probado | Reinicia su proceso de red | Nada |
| **Edge** | Probado | Probado | Reinicia su proceso de red | No uses **Secure Network** (la VPN de Edge) durante las sesiones |
| **Firefox** | Probado | Probado | Instala una política que apaga su DNS cifrado, su VPN, HTTP/3 y su caché de direcciones. Corta sus conexiones abiertas | Ciérralo y vuelve a abrirlo una vez después de instalar. Para comprobarlo, abre `about:policies` |
| **Opera** | Sin probar | Sin probar | Reinicia su proceso de red, como en Chrome | Apaga su **VPN** (Ajustes > Privacidad y seguridad). Opera no acepta políticas, así que la app no puede apagarla |
| **Brave**, **Vivaldi**, **Arc** | Sin probar | Sin probar | Reinicia su proceso de red, como en Chrome | No uses ventanas de Tor ni VPN del navegador |

"Probado" quiere decir que una prueba automática abre el navegador en una Mac y una PC reales, empieza una sesión y comprueba que los sitios bloqueados no cargan, también en pestañas que ya estaban abiertas. Está en [`pruebas/navegadores.py`](pruebas/navegadores.py).

**Por qué importan las VPN del navegador:** Opera, Edge, Firefox y Brave traen VPN o proxys integrados. Con ellos, la dirección del sitio la busca un servidor de afuera, y el archivo `hosts` de tu computadora no participa. Una VPN instalada en el sistema, en cambio, sí respeta el bloqueo.

## Privacidad

La app no se conecta a internet, no tiene cuentas ni analíticas, y no recopila ni envía datos. Solo guarda en tu computadora tu lista de bloqueos y el estado de la sesión actual. [Ver el detalle](docs/privacidad.md).

## Limitaciones

Es una herramienta para frenar el impulso, no un control parental.

- **Quien tenga la contraseña de administrador puede saltarse el bloqueo**, editando el archivo `hosts`, deteniendo el servicio o cambiando la hora del sistema.
- **VPN y proxys del navegador** se saltan el bloqueo de sitios. Mira [Navegadores](#navegadores).
- **Al empezar un bloqueo**, una descarga o videollamada en el navegador puede cortarse un instante, porque se reinicia su conexión.
- **Durante los primeros 3 minutos** se rechazan las direcciones reales de los sitios bloqueados. Si otro sitio comparte servidor con uno bloqueado, como YouTube con Google, puede fallar en esos minutos.
- **Windows con IPv6:** las conexiones IPv6 que Firefox ya tenía abiertas no se pueden cortar; las nuevas sí se bloquean.
- **Apps:** se cierran hasta 2 segundos después de abrirse, solo durante un bloqueo activo.
- **Fuera de las sesiones** nada está bloqueado.
- **Windows:** Microsoft Defender puede avisar de un cambio en el archivo `hosts`. Es este bloqueo.

## Desinstalar

**Mac:**

```bash
bash macos/uninstall.sh
```

**Windows:** doble clic en `windows\desinstalar.cmd`.

No funciona durante una sesión activa. Borra la app, el servicio y tus listas.

## Problemas frecuentes

- **El icono muestra un triángulo y "El servicio no responde".** Vuelve a ejecutar el instalador. Reinstalar no borra tus listas ni corta una sesión activa.
- **Mac: "No se pudo compilar" después de actualizar macOS.** Reinstala las herramientas con `sudo rm -rf /Library/Developer/CommandLineTools && xcode-select --install`.
- **Un sitio sigue abriendo en Firefox.** Instala la última versión de la app y reinicia Firefox. Para confirmar que la política está activa, abre `about:policies` en Firefox: deben aparecer `DNSOverHTTPS` y `Preferences`.
- **Un sitio sigue abriendo.** Revisa si entras con otro subdominio (`m.`, `web.`) y agrégalo, y que el navegador no tenga su VPN encendida.
- **No puedo iniciar una sesión.** Activa al menos un sitio o una app en **Qué bloquear…**.

Si algo no funciona, [abre un issue](https://github.com/michael-net/enfocate-pe-causa/issues) contando tu sistema y qué pasó.

## Documentación

- [Arquitectura](docs/arquitectura.md)
- [Diseño para macOS y Windows](docs/diseno.md)
- [Privacidad y seguridad](docs/privacidad.md)
- [Plan para iPhone y Android](docs/plan-movil.md)

## Créditos

**Enfócate pe causa** es un proyecto de **Michael Net** ([m@michaelnet.work](mailto:m@michaelnet.work)).

Parte de [screen-block](https://github.com/ponchodelosrios98/screen-block), de Alfonso de los Rios, que aportó la base del bloqueo con `/etc/hosts` y las sesiones con candado.

## Licencia

[MIT](LICENSE). Puedes usar, modificar y distribuir este proyecto, siempre que conserves el aviso de licencia con los nombres de sus autores.
