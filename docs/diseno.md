# Diseño

## Principios

1. **Solo lo necesario.** El widget responde dos preguntas: ¿hay una sesión? y ¿cuánto falta?
2. **Nativo en cada sistema.** Misma estructura y mismas palabras, con los iconos, la tipografía y los menús de cada plataforma.
3. **Sin emojis.** Los emojis se ven distintos en cada sistema y no se adaptan a la barra clara u oscura. Se usan iconos monocromos.
4. **Calma.** Sin colores de alerta ni animaciones. La herramienta no compite por tu atención.

## Iconos

Cada estado tiene un icono con el mismo significado en ambos sistemas.

| Estado | macOS (SF Symbols) | Windows (Fluent UI System Icons) |
|---|---|---|
| Sin sesión y sesión de enfoque | `scope` | `Target` |
| Pomodoro, trabajo | `timer` | `Timer` |
| Pomodoro, descanso | `cup.and.saucer` | `DrinkCoffee` |
| Servicio sin respuesta | `exclamationmark.triangle` | `Warning` |

SF Symbols solo se puede usar en plataformas de Apple, y por eso Windows necesita su propio conjunto. Fluent UI System Icons es de Microsoft y tiene licencia MIT. Los nombres de Windows deben confirmarse al implementar.

## Barra de menú y bandeja

| Estado | Se muestra |
|---|---|
| Sin sesión | Icono |
| Con sesión | Icono y tiempo restante: `1:23:45` o `23:41` |

Las cifras tienen ancho fijo para que la barra no se mueva cada segundo. Las rondas van dentro del menú, no en la barra.

## Sesión activa

Durante una sesión, una tarjeta muestra el nombre, el tiempo que falta en grande y un detalle.

| Fase | Título | Detalle |
|---|---|---|
| Sesión de enfoque | Sesión de enfoque activa | Termina a las 11:48 |
| Pomodoro, trabajo | Pomodoro activo | Ronda 2 de 4 |
| Pomodoro, descanso | Descanso | Ronda 2 de 4 |

La tarjeta encabeza el menú. También aparece como aviso flotante arriba a la derecha durante 10 segundos cuando empieza una sesión o ronda, y al encender o abrir la Mac con una sesión en curso. El aviso no quita el foco y se cierra con un clic. En Windows iría abajo a la derecha, junto a la bandeja.

## Menú

**Sin sesión**
- Sesión de enfoque ▸ 1 hora · 1 h 30 min · 2 horas · 3 horas
- Pomodoro
- Qué bloquear…

**Sesión de enfoque**
- *Tarjeta de la sesión, con el contador*
- Extender 30 min

**Pomodoro, trabajo**
- *Tarjeta del pomodoro, con el contador*
- Agregar ronda
- Quitar ronda

**Pomodoro, descanso**
- *Tarjeta del descanso, con el contador*
- Agregar ronda
- Quitar ronda
- Terminar pomodoro

Lo que no se puede hacer no aparece: durante el trabajo no se ofrece terminar.

## Qué bloquear

Una ventana con los grupos Sitios y Apps. Cada fila tiene un icono, el nombre, un botón para quitar y un interruptor. Al final de cada grupo se puede agregar uno nuevo.

Un tercer grupo, "Al encender o abrir la Mac", elige qué apps activas bloquea la sesión automática de 45 minutos.

- Solo está disponible sin sesión activa. Si empieza una sesión, la ventana se cierra.
- Si no hay nada activado, no se puede iniciar una sesión, y el menú lo indica.
- Usa los controles nativos de cada sistema: `Form` en macOS y `ToggleSwitch` en Windows.

## Diferencias por sistema

| | macOS | Windows |
|---|---|---|
| Ubicación | Barra de menú, arriba a la derecha | Bandeja del sistema, abajo a la derecha |
| Abrir el menú | Clic | Clic izquierdo o derecho |
| Tiempo restante | Siempre visible junto al icono | Al pasar el cursor, porque la bandeja de Windows solo admite iconos |
| Tipografía | San Francisco | Segoe UI Variable |
| Claro y oscuro | Icono de plantilla, automático | Variantes clara y oscura, según el tema |
| Notificaciones | Centro de notificaciones | Notificaciones de Windows |

En Windows, el contador no cabe en la bandeja. Se puede mostrar el tiempo restante en minutos dentro del propio icono, como hacen otras apps de bandeja, o en un panel pequeño al hacer clic. Esa decisión queda abierta.

## Textos

| Momento | Texto |
|---|---|
| Inicia descanso | Descanso de 5 minutos. Sitios y apps libres. |
| Termina sesión de enfoque | Sesión de enfoque terminada. |
| Termina pomodoro | Pomodoro terminado. |

## Pendiente

- Icono de la app y logo.
- Notificaciones propias: hoy salen desde `osascript`, con el icono de ese sistema.
- Versión para Windows: bloqueo con el archivo `hosts` de Windows, un servicio de Windows y un icono de bandeja.
