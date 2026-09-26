# Arquitectura

> Documento vivo. Se actualiza cuando cambian las decisiones arquitectónicas.
> Plan maestro: ver `E:\Obsidian\Tesis\Emulador BLE Indoor\Plan.md`.

## Resumen en 30 segundos

App Flutter standalone (sin backend) que emula posicionamiento BLE en interiores.
Dos modos intercambiables:

- **Simulación** (default): recorrido predefinido + RSSI calculado matemáticamente.
- **Real BLE**: escaneo real de balizas Feasycom FSC-BP104D con `flutter_blue_plus`.

La UI solo consume un `ChangeNotifier` que expone el estado de la simulación.
La fuente de RSSI es inyectable (interfaz `RssiSource`).

## Capas

| Capa | Carpeta | Responsabilidad |
|------|---------|-----------------|
| Modelos | `lib/models/` | Estructuras de datos inmutables (`Beacon`, `HouseMap`, `RssiSample`, `BeaconMode`). |
| Util | `lib/util/` | Funciones puras, sin estado. Acá vive `rssi_model.dart` con la fórmula log-distance. |
| Fuentes | `lib/sources/` | Implementaciones de `RssiSource`: `SimulatedRssiSource` y `BleRssiSource`. |
| Estado | `lib/state/` | `SimulationNotifier` (ChangeNotifier) orquesta timer + posición + RSSI. |
| Vista | `lib/view/` | Widgets. `HomeScreen` + sub-widgets (`map_canvas`, `telemetry_panel`, `control_bar`, `mode_selector`). |
| Render | `lib/view/widgets/house_painter.dart` | `CustomPainter` que dibuja el plano. Recibe estado, no calcula. |

## Reglas de dependencia (estrictas)

```
view  ──►  state  ──►  sources  ──►  util
                          │
                          └────────►  models
   ▲                              ▲
   └────────────  models  ◄───────┘
```

- **view** puede importar `state` y `models`. No puede importar `sources` ni `util` directamente.
- **state** puede importar `sources`, `models`, `util`.
- **sources** puede importar `models` y `util`. No puede importar `state` ni `view`.
- **models** no importa nada del proyecto.
- **util** no importa nada del proyecto (funciones puras).

> [!warning] Estas reglas las valida el code review.
> No usamos `import_lint` por ahora para no agregar fricción, pero cualquier PR que las rompa se rechaza.

## Flujo de datos

1. Usuario toca "Iniciar" en `ControlBar`.
2. `ControlBar` llama a `SimulationNotifier.start()`.
3. El notifier arma un `Timer.periodic` (100 ms).
4. Cada tick:
   - Avanza la posición del usuario interpolando entre waypoints.
   - Llama a `RssiSource.currentSamples(userPosition)` → `Map<BeaconId, RssiSample>`.
   - `notifyListeners()`.
5. `HomeScreen` escucha al notifier (`Consumer<SimulationNotifier>`).
6. El nuevo estado baja a `MapCanvasView` → `HousePainter.shouldRepaint` → repinta.

## ¿Por qué este diseño?

- **MVVM ligero (sin librerías de DI):** el notifier recibe el `RssiSource` por constructor. En `main.dart` se inyecta la implementación real. Testeable.
- **Interfaz `RssiSource`:** permite alternar simulación/real sin tocar la UI. Es la pieza que justifica el modo dual.
- **`CustomPainter` puro:** recibe estado por parámetro, no conoce al notifier. Esto permite golden tests aislados.
- **Sin singletons ni globals:** todo se inyecta. El estado se crea en `main.dart` y se provee vía `ChangeNotifierProvider`.

## Estructura de archivos (post-WU-0)

Ver `docs/ARQUITECTURA.md` (este doc) y `Plan.md` en Obsidian para la estructura objetivo.

```
lib/
├── main.dart                    # entrypoint + bootstrap del estado
├── models/                      # [vacío hasta WU-1]
├── sources/                     # [vacío hasta WU-5/WU-12]
├── state/                      # [vacío hasta WU-6]
├── util/                       # [vacío hasta WU-4]
└── view/
    ├── home_screen.dart        # [placeholder, llega en WU-7]
    └── widgets/                # [vacío hasta WU-3+]
```

## Cómo correr

```bash
# Análisis estático (debe pasar sin errores)
flutter analyze

# Correr todos los tests
flutter test

# Correr la app en Windows (requiere Developer Mode)
flutter run -d windows

# Correr en Chrome (útil para iterar rápido sin permisos BLE)
flutter run -d chrome
```

> [!note] Developer Mode
> El `pub get` mostró un warning pidiendo Developer Mode. Es necesario para que los plugins nativos (incluido `flutter_blue_plus`) funcionen en Windows. Ver § "Habilitar Developer Mode" más abajo.

## Habilitar Developer Mode (Windows)

1. `Win + R` → `ms-settings:developers` → Enter.
2. Activar **Developer Mode**.
3. Reiniciar la terminal.
4. `flutter doctor` debería mostrar ✓ en Windows.

## Próximos pasos arquitectónicos

- WU-1: introducir `models/` con inmutabilidad.
- WU-4: introducir `util/rssi_model.dart` (función pura testeable).
- WU-5/12: introducir `sources/` con la interfaz `RssiSource`.
- WU-6: introducir `state/simulation_notifier.dart`.
- WU-7+: poblar `view/`.