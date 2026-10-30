# Publicar en iPhone

Pasos para pasar de este código a TestFlight y a la App Store. Los marcados **(tú)** necesitan tu cuenta o tu identidad.

## 1. Cuenta y permisos

1. **(tú)** Inscríbete en el [Apple Developer Program](https://developer.apple.com/programs/) (99 USD al año). Anota tu **Team ID**, que está en Membership.
2. **(tú)** En [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list), crea:
   - El App Group `group.work.michaelnet.enfocate`.
   - Cuatro identificadores (App IDs), cada uno con las capacidades **Family Controls** y **App Groups**, y con ese grupo asignado:

     | Identificador | Qué es |
     |---|---|
     | `work.michaelnet.enfocate` | La app |
     | `work.michaelnet.enfocate.monitor` | Extensión que lleva los horarios y los límites |
     | `work.michaelnet.enfocate.escudo` | Extensión que dibuja la pantalla de bloqueo |
     | `work.michaelnet.enfocate.accion-escudo` | Extensión de los botones de esa pantalla |

   Si cambias `work.michaelnet` por otro prefijo, cámbialo también en `project.yml` y en `Compartido/Motor.swift` (`Motor.grupo`).
3. **(tú)** Pide el permiso de distribución en el [formulario de Family Controls](https://developer.apple.com/contact/request/family-controls-distribution), **una vez por cada uno de los cuatro identificadores**. Abajo está el texto para pegar.

Mientras Apple responde, ya puedes probar en tu iPhone con Xcode: el permiso de desarrollo no necesita aprobación.

### Texto para el formulario de Family Controls

El formulario está en inglés. Este texto describe lo que hace la app de verdad:

> **App name:** Enfócate pe causa
>
> **How does your app use the Family Controls framework?**
> Enfócate pe causa is a self-control app that helps people break the habit of opening social media first thing in the morning and late at night. The user authorizes it for their own device with `AuthorizationCenter.requestAuthorization(for: .individual)` and picks the apps to limit with `FamilyActivityPicker`.
>
> We use ManagedSettings to shield the selected apps during a night window chosen by the user and for 45 minutes in the morning, during focus sessions started by the user, and once an app reaches a 15-minute daily limit. We use DeviceActivity schedules and events to start and end those shields and to measure the daily limit. A ShieldConfiguration extension shows a calm blocking screen, and a ShieldAction extension lets the user spend one of two daily 5-minute passes.
>
> **Data:** The app only stores the opaque tokens returned by FamilyActivityPicker and the user's settings, in an App Group on the device. It has no networking code, no accounts and no analytics. No usage data leaves the device. The source code is public: https://github.com/michael-net/enfocate-pe-causa
>
> **This bundle ID:** (write which of the four it is: the main app, the DeviceActivityMonitor extension, the ShieldConfiguration extension or the ShieldAction extension)

## 2. Clave de App Store Connect

1. **(tú)** En [App Store Connect](https://appstoreconnect.apple.com), crea la app con el identificador `work.michaelnet.enfocate`, nombre **Enfócate pe causa** e idioma principal español.
2. **(tú)** En Users and Access > Integrations > App Store Connect API, crea una clave con rol **Admin**. Ese rol hace falta para que GitHub cree los certificados de firma. Descarga el archivo `.p8`: solo se puede descargar una vez.
3. **(tú)** En GitHub, en **Settings > Secrets and variables > Actions** del repositorio, agrega estos secretos. No los compartas por chat ni los subas al código.

   | Secreto | Valor |
   |---|---|
   | `APPLE_TEAM_ID` | Tu Team ID |
   | `ASC_KEY_ID` | El Key ID de la clave |
   | `ASC_ISSUER_ID` | El Issuer ID, arriba de la lista de claves |
   | `ASC_KEY_P8` | Todo el contenido del archivo `.p8` |

## 3. Subir a TestFlight

Cuando Apple apruebe Family Controls para los cuatro identificadores:

1. Crea una etiqueta que empiece con `ios-v` en la rama `movil`:

   ```bash
   git tag ios-v0.1.0 && git push origin ios-v0.1.0
   ```

   Cuando esta rama esté unida a `main`, también se puede lanzar desde **Actions > TestFlight > Run workflow**.
2. La compilación **TestFlight** firma la app y la sube. App Store Connect la procesa en unos minutos.
3. **(tú)** En App Store Connect > TestFlight, agrégate como probador. Instala **TestFlight** en tu iPhone y acepta la invitación.

Para probar con más personas, crea un grupo externo en TestFlight. La primera versión para probadores externos pasa una revisión corta de Apple.

## 4. App Store

Datos para la ficha en App Store Connect:

| Campo | Valor |
|---|---|
| Categoría | Productividad |
| Subtítulo | Menos redes, más enfoque |
| URL de privacidad | https://github.com/michael-net/enfocate-pe-causa/blob/main/docs/privacidad.md |
| URL de soporte | https://github.com/michael-net/enfocate-pe-causa/issues |
| Privacidad de la app | **Datos no recopilados** |
| Clasificación por edad | 4+ |

**Notas para la revisión de Apple** (App Review Information > Notes):

> This app uses Family Controls with individual authorization, for the user's own device. To test: open the app, tap "Dar permiso de Tiempo de uso" and approve, tap "Elegir redes sociales" and pick any app (for example Safari), then start a 1-hour focus session ("Sesión de enfoque > 1 hora"). Opening the chosen app shows the shield. Focus sessions cannot be cancelled by design; they end on their own. The night window (22:00–06:00 by default) can be changed in the app when no block is active. The app has no networking code and collects no data.

## Antes de pedir la revisión

- [ ] Probar en un iPhone real cada regla: noche, mañana, los dos pases, el límite de 15 minutos y una sesión de enfoque.
- [ ] Comprobar que los horarios que cruzan la medianoche se activan y terminan a la hora correcta.
- [ ] Revisar que el pase vuelve a bloquear la app a los 5 minutos de uso.
- [ ] Capturas de pantalla para la App Store.
