# Enfócate pe causa para Android

Base de la app para Android 8 o superior. Las reglas están en el [plan para celular](../docs/plan-movil.md).

> En desarrollo. Todavía no está lista para usar a diario.

## Qué hace

- **Noche:** bloquea las redes sociales de 22:00 a 6:00. Las horas se cambian en la app.
- **Mañana:** bloquea las redes 45 minutos desde el primer desbloqueo después de la noche.
- **Pases:** 2 al día, de 5 minutos de uso, para la app que elijas, durante la noche o la mañana.
- **Límite diario:** 15 minutos por red social.
- **Sesiones de enfoque:** 1 h, 1 h 30 min, 2 h o 3 h. No se cancelan; se pueden extender 30 min.

## Cómo está hecha

| Archivo | Qué hace |
|---|---|
| `Reglas.kt` | Las reglas, sin Android, con pruebas en `ReglasTest.kt` |
| `Guardian.kt` | Servicio de accesibilidad. Android lo despierta solo al abrir una de las apps elegidas. No puede leer la pantalla |
| `Uso.kt` | Lee los minutos de uso que ya guarda Android |
| `BloqueoActivity.kt` | La pantalla de bloqueo, con el botón del pase |
| `MainActivity.kt` | Permisos, sesión de enfoque, horas de la noche y lista de apps |
| `Almacen.kt` | Guarda la configuración en el almacenamiento privado de la app |

La app **no tiene permiso de internet**. La compilación automática falla si alguien lo agrega.

## Compilar

Con Android Studio, abre la carpeta `android`. Desde la terminal:

```bash
cd android
./gradlew testDebugUnitTest assembleDebug
```

El APK queda en `app/build/outputs/apk/debug/app-debug.apk`. Cada cambio en GitHub lo compila y lo deja para descargar en la pestaña **Actions**, en la ejecución **Celular**.

## Probar en tu celular

1. Instala el APK.
2. En la app, activa el **acceso a uso** y el servicio en **Accesibilidad**.
3. Si Accesibilidad dice que no está disponible: Ajustes > Apps > Enfócate pe causa > menú ⋮ > **Permitir ajustes restringidos**.

## Pendiente

- Probar en celulares de varias marcas y medir la batería.
- Guía para las marcas que cierran servicios en segundo plano.
- Avisar cuando el servicio de accesibilidad se desactiva.
- Detectar la Protección avanzada de Android 17.
