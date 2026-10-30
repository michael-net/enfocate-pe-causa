# Enfócate pe causa para iPhone

Base de la app para iOS 16 o superior. Las reglas están en el [plan para celular](../docs/plan-movil.md).

> En desarrollo. Para instalarla en un iPhone hace falta el permiso Family Controls de Apple.

## Qué hace

Las mismas reglas que en Android: noche, mañana, 2 pases de 5 minutos al día, límite de 15 minutos por app y sesiones de enfoque. Usa la API de Tiempo de uso de Apple:

| Carpeta | Qué hace |
|---|---|
| `App` | Pantalla principal y el atajo "Empezar la mañana sin redes" |
| `Compartido` | Las reglas (`Reglas.swift`) y cómo se aplican (`Motor.swift`) |
| `Monitor` | Extensión que iOS despierta al empezar o terminar un horario, o al llegar a un límite |
| `Escudo` | La pantalla que cubre una app bloqueada |
| `AccionEscudo` | Los botones de esa pantalla: volver o usar un pase |

La app nunca sabe qué apps elegiste: iOS le da fichas opacas. No tiene código de red.

## Compilar

Necesitas una Mac con Xcode y [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen
```

```bash
cd ios && xcodegen && open Enfocate.xcodeproj
```

Para el simulador no hace falta firmar. Para un iPhone real:

1. En `project.yml`, pon tu Team ID en `DEVELOPMENT_TEAM` y vuelve a ejecutar `xcodegen`.
2. Para probar en tu iPhone basta el permiso Family Controls de desarrollo, que Xcode agrega solo.
3. Para TestFlight y la App Store hay que pedir a Apple el permiso de distribución, para la app y para cada extensión.

## Publicar

Para TestFlight y la App Store, sigue [PUBLICAR.md](PUBLICAR.md): tiene el texto para pedir Family Controls y la compilación que sube la app.

## Limitaciones conocidas

- iOS no avisa del desbloqueo: la mañana empieza al terminar la noche, o con una automatización de Atajos.
- El límite diario solo aplica a las apps elegidas una por una, no a categorías enteras.
- Un pase dura hasta 5 minutos de uso o 1 hora de reloj, lo que pase primero.
- Hay reportes de que iOS 26 avisa de los límites antes de tiempo. Hay que probarlo en iPhones reales.
