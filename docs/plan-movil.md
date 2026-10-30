# Plan para iPhone y Android

Investigación de octubre de 2026. Las reglas de Apple y Google cambian seguido: revisa las fuentes del final antes de empezar cada fase.

## Resumen

- **Sí se puede llevar Enfócate pe causa al celular**, con las mismas ideas que en la computadora: tú decides antes, el bloqueo no se negocia a medias y la app no sabe nada de ti.
- **No se puede reutilizar el código de escritorio.** En el celular no hay archivo `hosts` ni servicios de root. Cada sistema tiene su propia forma de bloquear apps: Screen Time en iPhone y un servicio de accesibilidad en Android. Hay que escribir dos apps nativas: Swift en iOS y Kotlin en Android.
- **iPhone:** en la práctica **necesita la App Store** (o TestFlight para pruebas). Además, Apple tiene que aprobar un permiso especial, Family Controls, y esa aprobación puede tardar semanas. Conviene pedirlo el primer día.
- **Android:** **no necesita Play Store.** Se puede distribuir desde GitHub o F-Droid. Play Store es posible, pero su revisión es estricta con apps de bloqueo, y con una cuenta personal nueva hay que conseguir antes 12 personas que prueben la app durante 14 días.
- **Batería y privacidad:** las dos versiones pueden funcionar sin procesos permanentes en segundo plano y sin acceso a internet. En Android se puede demostrar quitando el permiso de internet.

## Qué hace la versión para celular

Igual que en la computadora, pero pensada para los momentos en que el celular genera más ansiedad: al despertar y antes de dormir. No hay pomodoro.

| Regla | Qué pasa | Valor por defecto |
|---|---|---|
| **Mañana** | Al empezar el día, las redes sociales quedan bloqueadas | 45 minutos desde que empiezas a usar el celular |
| **Noche** | Antes de dormir, las redes sociales quedan bloqueadas hasta una hora fija | De 22:00 a 6:00. Tú eliges las dos horas |
| **Pases de 5 minutos** | Durante un bloqueo de la mañana o de la noche, un pase abre la app que elijas por 5 minutos | 2 pases al día |
| **Límite diario** | Cada red social se puede usar como máximo este tiempo al día. Después queda bloqueada hasta medianoche | 15 min por app |
| **Sesión de enfoque** | Bloquea todo lo que elijas. No se cancela, solo se extiende | 1 h, 1 h 30 min, 2 h o 3 h. Extender 30 min |

- **Qué cuenta como red social:** la eliges tú. Se sugieren Instagram, TikTok, Facebook, X, YouTube, Snapchat, Threads y Reddit. WhatsApp y las apps de mensajes quedan fuera por defecto, como en la sesión automática de escritorio.
- **Tienes 2 pases al día**, para la app que quieras. Puedes usar uno en la mañana y otro en la noche, o los dos en el mismo bloqueo. Se renuevan a medianoche.
- **Un pase es para una app.** Al intentar abrir una red social bloqueada, la pantalla de bloqueo ofrece "Usar un pase (te quedan 2)". Se abre solo esa app.
- **El pase se mide en uso real**, no en reloj. Si abres Instagram 2 minutos y lo cierras, puedes volver a entrar a Instagram durante los 3 minutos que quedan de ese pase.
- **Los pases no existen en las sesiones de enfoque**, que siguen sin poder negociarse, **ni después de llegar al límite diario** de esa app.
- **El límite de 15 minutos** se acumula en todo el día, también durante los pases.
- **Lo que no se puede hacer no aparece**, como en escritorio: durante un bloqueo no hay botón para desactivarlo.

### Cuándo empieza "la mañana"

| | Android | iPhone |
|---|---|---|
| Cómo lo sabe | El primer desbloqueo después de que termina la noche | iOS no avisa a las apps cuando se enciende o se desbloquea el celular |
| Solución | Automática | Una automatización de la app Atajos, "Al despertar" o "Al detener la alarma", que inicia el bloqueo de 45 minutos. Si no hay automatización, empieza al terminar la noche (por ejemplo, de 6:00 a 6:45) |

En Android también se detecta el encendido del celular, pero lo que importa es el primer uso del día, porque casi nadie apaga el celular por la noche.

Si usas el celular antes de que termine la noche, por ejemplo a las 5:30, sigue valiendo la noche. La mañana empieza con el primer uso después de las 6:00. Así la noche y la mañana no se superponen y no queda un hueco entre ellas.

## iPhone (iOS 16 o superior)

### Cómo funciona

Apple ofrece la **API de Tiempo de uso** (Screen Time), que usan las apps de bloqueo serias. Tiene tres partes:

| Parte | Para qué |
|---|---|
| `FamilyControls` | Pide permiso a la persona para controlar su propio Tiempo de uso (autorización `.individual`) y muestra el selector de apps |
| `ManagedSettings` | Pone el "escudo": la pantalla que cubre una app bloqueada. También bloquea dominios en Safari y en los navegadores que usan WebKit |
| `DeviceActivity` | Avisa a la app cuando empieza o termina un horario y cuando el uso de unas apps pasa de un límite |

Cómo se arma cada regla:

| Regla | Implementación |
|---|---|
| Mañana | Un *App Intent* "Empezar la mañana" que la automatización de Atajos ejecuta al despertar. Activa el escudo y un horario de 45 minutos que lo quita al terminar. Si no hay automatización, un horario fijo diario |
| Noche | Un horario diario de `DeviceActivity` con hora fija de inicio y de fin, por ejemplo de 22:00 a 6:00, que pone y quita el escudo |
| Pases de 5 minutos | El escudo tiene un botón "Usar un pase". La extensión `ShieldAction` recibe la ficha de la app que se intentó abrir, le quita el escudo solo a ella y vigila un evento de 5 minutos de uso de esa app. Al llegar, la extensión `DeviceActivityMonitor` vuelve a ponerlo. Los pases que quedan hoy se guardan en el grupo compartido de la app, al que acceden la app y sus extensiones |
| Límite diario | Un horario de 0:00 a 23:59 con un evento de 15 minutos por app. Al llegar, se bloquea solo esa app hasta medianoche |
| Sesión de enfoque | Escudo sobre lo elegido y un horario hasta la hora de fin. Extender mueve la hora de fin |

La cuenta regresiva de una sesión se puede mostrar en la pantalla bloqueada con una *Live Activity*.

### Privacidad y batería

Esta es la mejor parte de iOS:

- **La app nunca sabe qué apps elegiste.** El selector de Apple devuelve fichas opacas, no nombres. La app puede bloquear "esta ficha", pero no leer que es Instagram.
- **El tiempo de uso lo mide iOS**, no la app. La app solo recibe "se llegó al límite".
- **Las extensiones no pueden enviar datos.** Las de `DeviceActivity` y del escudo se ejecutan aisladas, sin red.
- **Casi no gasta batería:** no hay ningún proceso de la app vivo en segundo plano. iOS despierta una extensión pequeña solo cuando pasa algo.
- En la App Store, la ficha de privacidad sería **"Datos no recopilados"**.

### Limitaciones

- **La persona puede quitar el permiso** desde Ajustes > Tiempo de uso. Desde iOS 26.4, según reportes de otros desarrolladores, ese permiso se puede proteger con el código de Tiempo de uso, y conviene explicarlo en la app. Mismo principio que en escritorio: frena el impulso, no a alguien decidido.
- **iOS no avisa del desbloqueo.** Por eso la mañana depende de Atajos o de un horario fijo.
- **Los avisos de límite no son exactos.** Hay reportes de eventos que llegan antes o después de tiempo, también en iOS 26. Hay que comprobar el tiempo real antes de bloquear y probar en celulares reales.
- **Los horarios de `DeviceActivity` duran mínimo unos 15 minutos**, según reportes de desarrolladores. Por eso cada pase de 5 minutos usa un evento de uso dentro de un horario más largo, y no un horario de 5 minutos.

### Distribución

| Opción | Sirve para | Requisito |
|---|---|---|
| **App Store** | Que cualquiera la instale | Apple Developer Program (99 USD al año) y el permiso Family Controls de distribución |
| **TestFlight** | Pruebas con hasta 10 000 personas, cada versión dura 90 días | Lo mismo |
| Instalar desde Xcode | Probar en tu propio iPhone | Una Mac con Xcode. No sirve para repartirla |

No hay forma práctica de repartir una app de iPhone sin pasar por Apple. Las tiendas alternativas solo existen en la Unión Europea.

**El permiso Family Controls de distribución se pide con un formulario de Apple**, aparte de la cuenta de desarrollador. En 2026 hay desarrolladores que esperaron días y otros más de un mes. Hay que pedirlo para la app y para cada extensión, y revisar que el perfil de distribución lo incluya antes de subir la app.

## Android (Android 8 o superior)

### Cómo funciona

Android no tiene una API pública para que una app bloquee otras. El Bienestar digital de Google lo hace porque es parte del sistema. Hay dos caminos:

| | Servicio de accesibilidad (recomendado) | Estadísticas de uso con sondeo |
|---|---|---|
| Cómo detecta la app abierta | Android avisa al instante cuando se abre una de las apps elegidas | La app pregunta cada segundo qué app está abierta |
| Batería | Muy baja: solo despierta al abrir una red social | Más alta: necesita un servicio en primer plano siempre activo |
| Permisos | Accesibilidad y acceso a uso | Acceso a uso y mostrar sobre otras apps |
| Play Store | Requiere declaración y aviso destacado, con riesgo de rechazo | Más fácil de aprobar |

El servicio de accesibilidad se configura de forma que **no pueda leer la pantalla**:

- `canRetrieveWindowContent="false"`: no ve textos, mensajes ni contraseñas.
- Solo escucha `TYPE_WINDOW_STATE_CHANGED`: se entera de qué app pasa a primer plano, nada más.
- `packageNames` limitado a las apps elegidas: Android ni siquiera le avisa cuando abres otras apps.

Cómo se arma cada regla:

| Regla | Implementación |
|---|---|
| Mañana | El servicio escucha el desbloqueo. El primero después de que termina la noche inicia 45 minutos de bloqueo |
| Noche | Se calcula con las horas fijas cada vez que se abre una red social. No hacen falta alarmas |
| Pases de 5 minutos | La pantalla de bloqueo tiene el botón "Usar un pase" para esa app. El uso se mide con `UsageStatsManager`. Se guarda cuántos pases quedan hoy |
| Límite diario | Al abrir una red social se consulta su uso de hoy con `UsageStatsManager`, que guarda el propio Android. Si ya pasó de 15 minutos, se bloquea. Si no, se programa una revisión para el momento en que llegue |
| Sesión de enfoque | Una notificación con la cuenta regresiva y bloqueo de lo elegido hasta la hora de fin |

Bloquear significa volver a la pantalla de inicio y mostrar la pantalla de Enfócate pe causa con el tiempo que falta.

### Privacidad y batería

- **Sin permiso de internet.** Si el manifiesto no declara `INTERNET`, Android no deja que la app se conecte a nada. Cualquiera puede comprobarlo en Ajustes > Apps > Permisos o en el código.
- **Permisos mínimos:** accesibilidad (limitada como se explica arriba), acceso a uso, notificaciones e inicio al encender. Nada de ubicación, contactos, cámara, micrófono, SMS ni "ver todas las apps": la lista de apps instaladas se obtiene solo de las que tienen icono en el inicio.
- **Nada sale del celular:** las reglas y el estado se guardan en el almacenamiento privado de la app. El uso por app ya lo guarda Android, así que la app no necesita guardar un historial propio.
- **Batería:** sin servicio en primer plano, sin alarmas repetidas y sin sondeo. El servicio solo despierta cuando abres una de las apps elegidas.

### Limitaciones

- **La persona puede desactivar el servicio** desde Ajustes > Accesibilidad. La app avisa cuando eso pasa. Mismo principio que en escritorio.
- **Navegadores:** el bloqueo es por app. Bloquear instagram.com dentro de Chrome exigiría una VPN local o leer la barra de direcciones, y las dos cosas van contra la privacidad y la batería. En la primera versión no se bloquean sitios web en Android.
- **Android 17 con Protección avanzada:** si la persona activa ese modo, Android quita la accesibilidad a las apps que no son de asistencia, y la app no podría bloquear. La app puede detectarlo y explicarlo.
- **Fabricantes:** algunas capas de Android, como las de Xiaomi, Huawei u Oppo, cierran servicios para ahorrar batería. Hay que incluir una guía por marca.

### Distribución

| Opción | Ventajas | Requisitos y riesgos |
|---|---|---|
| **GitHub Releases** (APK) | Inmediato, sin revisión | En Android 13 y superior, al instalar desde el navegador, hay que activar "Permitir ajustes restringidos" en la información de la app para poder darle accesibilidad. Android 15 lo hace más estricto |
| **F-Droid** | Tienda de apps libres, encaja con la privacidad del proyecto. Su instalador normalmente evita el paso de ajustes restringidos, pero hay que comprobarlo en Android 15 y superior | Código abierto y compilable por F-Droid. Sus revisiones tardan |
| **Play Store** | Llega a más gente y se actualiza sola | 25 USD una vez. Declaración de accesibilidad y aviso destacado, con riesgo de rechazo. Con una cuenta personal nueva: 12 testers durante 14 días antes de publicar. Una cuenta de organización se salta ese paso |

**Verificación de desarrolladores de Google:** desde el 30 de septiembre de 2026, en Brasil, Indonesia, Singapur y Tailandia, las apps instaladas desde algunas tiendas tienen que ser de desarrolladores verificados. En 2027 se extiende a todo el mundo, y Google dice que habrá una vía avanzada para instalar apps no registradas. Conviene registrarse como desarrollador verificado aunque no se publique en Play Store, para que en 2027 la instalación siga siendo simple.

## Recomendación

1. **Android primero.** No depende de la aprobación de nadie, se puede probar en días y valida las reglas de mañana, noche, pase y límite con gente real.
2. **Pedir los permisos de Apple el primer día**, en paralelo. La espera de Family Controls es lo que más puede retrasar iOS.
3. **iPhone después**, por TestFlight con un grupo pequeño y luego en la App Store.
4. **Play Store al final**, cuando haya usuarios y se sepa si la declaración de accesibilidad se aprueba. Hasta entonces, GitHub y F-Droid.

## Fases

| Fase | Qué | Tiempo estimado |
|---|---|---|
| 0 | Apple Developer Program, formulario de Family Controls para la app y sus extensiones, registro de desarrollador de Android | 1 día, más la espera de Apple |
| 1 | Android: reglas, servicio de accesibilidad, pantalla de bloqueo, elegir apps, sesiones de enfoque | 3 a 4 semanas |
| 2 | Android: pruebas de una semana en 3 o 4 celulares de marcas distintas, midiendo batería con el historial de batería de Android | 1 a 2 semanas |
| 3 | Android: publicar en GitHub Releases y enviar a F-Droid | 1 semana, más la revisión de F-Droid |
| 4 | iPhone: app, extensiones de `DeviceActivityMonitor`, `ShieldConfiguration` y `ShieldAction`, App Intent para Atajos | 4 a 5 semanas |
| 5 | iPhone: pruebas en iPhones reales, sobre todo la exactitud de los límites, y TestFlight | 2 semanas |
| 6 | App Store y, si se decide, Play Store con los 12 testers | 2 a 4 semanas |

Tiempos para una persona a tiempo parcial que ya conoce Swift. Kotlin suma la curva de aprendizaje.

## Estructura en el repositorio

```
ios/        app de iPhone (Swift, SwiftUI) y sus extensiones
android/    app de Android (Kotlin, Jetpack Compose)
docs/       reglas comunes y este plan
```

No se recomienda Flutter ni React Native: el núcleo son APIs nativas de cada sistema, y una capa extra suma tamaño, dependencias y superficie de ataque sin ahorrar trabajo.

## Decisiones tomadas

- **La noche termina a una hora fija**, que eliges tú.
- **Hay 2 pases al día** de 5 minutos cada uno, para la app que elijas, durante los bloqueos de la mañana y de la noche.

## Preguntas abiertas

- ¿Debe haber pase también en las sesiones de enfoque o después del límite diario? La propuesta es que no, para que la sesión siga sin poder negociarse y el límite de 15 minutos sea un límite real.
- ¿Nombre y diseño de la pantalla de bloqueo? Debería seguir el [diseño](diseno.md): calma, sin colores de alerta, solo el tiempo que falta y el botón del pase.

## Fuentes

- Apple: [Family Controls](https://developer.apple.com/documentation/familycontrols), [Configurar Family Controls](https://developer.apple.com/documentation/xcode/configuring-family-controls), [DeviceActivitySchedule](https://developer.apple.com/documentation/deviceactivity/deviceactivityschedule), [DeviceActivityEvent](https://developer.apple.com/documentation/deviceactivity/deviceactivityevent/init(applications:categories:webdomains:threshold:includespastactivity:))
- Esperas del permiso de distribución, reportes de desarrolladores: [1](https://developer.apple.com/forums/thread/826427), [2](https://developer.apple.com/forums/thread/818452), [3](https://developer.apple.com/forums/thread/823934)
- Avisos de límite que llegan antes de tiempo en iOS 26: [foro de Apple](https://developer.apple.com/forums/thread/840907); duración mínima de los horarios: [zenn.dev](https://zenn.dev/yosshi4486/articles/55120847cdb926)
- Proteger el permiso con el código de Tiempo de uso desde iOS 26.4: [AppBlock](https://appblock.app/how-to-block-screen-time-on-ios-26-4-and-newer/), [Freedom](https://support.freedom.to/en/articles/15949415-how-to-prevent-disabling-freedom-s-screen-time-permissions-on-ios); antes de 26.4: [foro de Apple](https://developer.apple.com/forums/thread/758333)
- Automatizaciones de Atajos que se ejecutan solas: [Matthew Cassinelli](https://matthewcassinelli.com/automations-run-immediately-shortcuts-notifications)
- Google Play, uso de la API de accesibilidad: [política](https://support.google.com/googleplay/android-developer/answer/10964491); experiencia de un desarrollador: [dev.to](https://dev.to/lui61140/why-i-removed-accessibilityservice-from-my-android-app-and-finally-got-into-play-store-4i52); bloqueo sin accesibilidad: [dev.to](https://dev.to/rexa/how-to-block-apps-on-android-without-an-accessibilityservice-5gog)
- Android 17 y Protección avanzada: [Security Affairs](https://securityaffairs.com/189497/security/advanced-protection-mode-in-android-17-prevents-apps-from-misusing-accessibility-services.html)
- Ajustes restringidos en apps instaladas fuera de tiendas: [Esper](https://esper.io/blog/android-13-sideloading-restriction-harder-malware-abuse-accessibility-apis), [Android Authority](https://androidauthority.com/android-15-enhanced-confirmation-mode-3436697)
- Verificación de desarrolladores de Android: [Android Developers](https://developer.android.com/developer-verification), [blog de Android](https://android-developers.googleblog.com/2026/06/android-developer-verification.html), [Android Authority](https://www.androidauthority.com/android-sideloading-developer-verification-first-wave-rollout-3717921/)
- Requisito de 12 testers en Play Store: [ayuda de Play Console](https://support.google.com/googleplay/android-developer/answer/14151465), [resumen](https://extendsclass.com/blog/google-plays-closed-testing-requirement-what-developers-need-to-know-in-2026)
