# Publicar en Android

Tres caminos, de más rápido a más lento. Los marcados **(tú)** necesitan tu cuenta, tu identidad o tus claves.

## Firma (necesaria para los tres)

Android solo instala apps firmadas, y cada actualización tiene que venir con la misma firma. Si pierdes la clave, no podrás actualizar la app: guárdala con copia de seguridad.

1. **(tú)** Crea la clave en tu computadora. Necesitas Java instalado:

   ```bash
   keytool -genkeypair -v -keystore enfocate.jks -alias enfocate -keyalg RSA -keysize 4096 -validity 10000
   ```

2. **(tú)** Conviértela a base64:

   ```bash
   base64 -i enfocate.jks
   ```

3. **(tú)** En GitHub, en **Settings > Secrets and variables > Actions**, agrega:

   | Secreto | Valor |
   |---|---|
   | `ANDROID_KEYSTORE_BASE64` | El texto en base64 del paso 2 |
   | `ANDROID_KEYSTORE_PASSWORD` | La contraseña del almacén |
   | `ANDROID_KEY_ALIAS` | `enfocate` |
   | `ANDROID_KEY_PASSWORD` | La contraseña de la clave |

## 1. GitHub Releases: descarga directa

Con los secretos guardados, crea una etiqueta que empiece con `android-v`:

```bash
git tag android-v0.1.0 && git push origin android-v0.1.0
```

La compilación **Publicar Android** prueba, firma, comprueba que no haya permiso de internet y publica `enfocate-pe-causa.apk` en **Releases** como versión de prueba. Desde el celular se abre ese enlace, se descarga y se instala.

## 2. F-Droid

F-Droid es una tienda de apps libres, sin rastreo. Compila la app desde el código, así que la firma la pone F-Droid.

- La ficha ya está en `fastlane/metadata/android/`. F-Droid la lee de ahí.
- **(tú)** Pide la inclusión abriendo una solicitud en [fdroiddata](https://gitlab.com/fdroid/fdroiddata), con el enlace al repositorio. El código tiene que estar en la rama principal o en una etiqueta.
- F-Droid marca las apps que usan accesibilidad. Es normal: lo explica la descripción de la ficha.

## 3. Google Play

1. **(tú)** Crea una cuenta en [Play Console](https://play.google.com/console) (25 USD, una vez) y verifica tu identidad.
2. **(tú)** Crea la app con el paquete `work.michaelnet.enfocate`. Activa **Play App Signing** y sube la clave de subida, la del paso de firma.
3. Sube `app-release.aab`. Está en los artefactos de la compilación **Publicar Android**.
4. **(tú)** Con una cuenta personal creada después de noviembre de 2023, primero hay que hacer una **prueba cerrada con 12 personas durante 14 días**. Luego se puede pedir la producción.

### Formularios de Play Console

**Declaración de accesibilidad** (Policy > App content > Accessibility API):

> Enfócate pe causa is a self-control app chosen by the user to limit their own social media use. It uses the AccessibilityService API only to receive `TYPE_WINDOW_STATE_CHANGED` events for the apps the user selected (the service sets `packageNames` to that list), so it knows when one of them comes to the foreground and can return to the home screen during a block the user configured (night, morning, daily limit or focus session). It does not retrieve window content (`canRetrieveWindowContent="false"`), does not read text or input, does not perform actions on other apps besides going home, and stores nothing about the apps opened. The app has no INTERNET permission, so no data can leave the device. A prominent disclosure explains this and asks for consent before opening the Accessibility settings.

En el mismo formulario: **no** es una herramienta de accesibilidad (no se usa `isAccessibilityTool`). Google pide además un video corto que muestre el aviso destacado y el permiso.

**Seguridad de los datos** (Data safety):

| Pregunta | Respuesta |
|---|---|
| ¿Recopila o comparte datos? | No |
| ¿Los datos se cifran en tránsito? | No aplica: la app no transmite datos |
| ¿Se pueden borrar los datos? | Sí, desinstalando la app |

**Otros datos de la ficha:**

| Campo | Valor |
|---|---|
| Política de privacidad | https://github.com/michael-net/enfocate-pe-causa/blob/main/docs/privacidad.md |
| Categoría | Productividad |
| Público objetivo | Mayores de 13 años. No está dirigida a niños |
| Clasificación de contenido | Cuestionario IARC: sin contenido sensible |
| Anuncios | No |

**Acceso a uso** (`PACKAGE_USAGE_STATS`) no necesita declaración aparte, pero conviene explicarlo en la descripción, como ya hace la ficha.

## Lo que ya está resuelto en el código

- Apunta a Android 16 (API 36), lo que exige Google Play desde el 31 de agosto de 2026.
- No tiene permiso de internet. Las compilaciones fallan si alguien lo agrega.
- Muestra un aviso destacado, con consentimiento, antes de abrir los ajustes de accesibilidad.
- El servicio de accesibilidad no puede leer la pantalla y solo escucha las apps elegidas.
- `allowBackup="false"`: tus listas no se copian a la nube de Google.
- La versión release se minimiza con R8 y se firma con la clave de los secretos.

## Pendiente antes de publicar

- [ ] Probar una semana en 3 o 4 celulares de marcas distintas, sobre todo Samsung, Xiaomi y Motorola.
- [ ] Medir la batería con el historial de batería de Android.
- [ ] Avisar cuando el servicio de accesibilidad se desactiva o lo cierra el fabricante.
- [ ] Capturas de pantalla para la ficha.
