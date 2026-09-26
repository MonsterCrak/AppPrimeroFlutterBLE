# AppPrimeroFlutterBLE

> Emulador de posicionamiento BLE en interiores con Flutter.
> Proyecto de validación para tesis UPC: *"Sistema de recomendación y optimización de compras con IA Generativa, XGBoost, NSGA-II y BLE"* — sub-módulo de navegación indoor con balizas Feasycom FSC-BP104D (BLE 5.1, chip Dialog DA14531).

## ¿Qué hace esta app?

Visualiza el rastreo de un usuario en un plano 2D de una casa, mostrando en tiempo real su posición, las balizas estáticas y los valores RSSI derivados de la distancia.

**Dos modos intercambiables:**

| Modo | Requiere hardware | Requiere permisos |
|------|-------------------|-------------------|
| **Simulación** (default) | ❌ | ❌ |
| **Real BLE** (Fase B) | ✅ FSC-BP104D | ✅ Bluetooth + ubicación |

## Estado del proyecto

🚧 **En desarrollo.** Tracker de avance en `E:\Obsidian\Tesis\Emulador BLE Indoor\Plan.md` (Work Units WU-0..WU-15).

**Actual:** WU-0 (bootstrap) completada. App arranca con smoke test verde.

## Quickstart

```bash
# 1. Instalar dependencias
flutter pub get

# 2. Correr análisis estático (debe pasar limpio)
flutter analyze

# 3. Correr tests
flutter test

# 4. Correr la app (modo simulación, sin permisos)
#    Android (emulador o dispositivo físico):
flutter run -d android
#    iOS (solo macOS con Xcode):
flutter run -d ios
```

> [!note] Plataformas soportadas
> Esta app es **mobile-only**: Android e iOS. No incluye Windows, macOS, Linux ni Web. Si necesitás otra plataforma, regenerala con `flutter create --platforms=...`.

## Arquitectura

Documento completo: [`docs/ARQUITECTURA.md`](docs/ARQUITECTURA.md).
Decisiones: [`docs/DECISIONES.md`](docs/DECISIONES.md).

```
view  ──►  state  ──►  sources  ──►  util
                          │
                          └────────►  models
```

- **MVVM ligero** con `provider`.
- **`RssiSource`** inyectable: `SimulatedRssiSource` o `BleRssiSource`.
- **`CustomPainter`** puro: recibe estado, no calcula.

## Estructura

```
lib/
├── main.dart
├── models/           # Beacon, HouseMap, RssiSample, BeaconMode
├── state/            # SimulationNotifier (ChangeNotifier)
├── sources/          # RssiSource + 2 implementaciones
├── view/             # HomeScreen + widgets
│   └── widgets/      # HousePainter, TelemetryPanel, ControlBar, ModeSelector
└── util/             # Funciones puras (rssi_model)

test/                 # mirror de lib/

pubspec.yaml          # dependencias pinneadas
```

## Testing

Documento completo: [`docs/TESTING.md`](docs/TESTING.md).

```bash
flutter test                            # todos
flutter test test/util/                 # una carpeta
flutter test --update-goldens           # regenerar golden files
flutter test --coverage                 # coverage
```

**Convención:** una WU no se considera terminada hasta que su test específico pasa y `flutter analyze` está limpio.

## Stack

| Capa | Tecnología | Versión |
|------|-----------|---------|
| Framework | Flutter | 3.29.0 |
| Lenguaje | Dart | 3.7.0 |
| Estado | `provider` | ^6.1.2 |
| BLE | `flutter_blue_plus` | **2.3.13** (pinned) |
| Permisos | `permission_handler` | ^11.3.1 |
| Tests | `mocktail` (dev) | ^1.0.4 |

## Documentación externa

- Plan maestro (Obsidian): `E:\Obsidian\Tesis\Emulador BLE Indoor\Plan.md`
- Tesis completa (Obsidian): `E:\Obsidian\Tesis\TF-261-2093-12-LN-...md`
- Conceptos BLE para principiantes: Plan.md §13

## Licencia

Proyecto académico — Universidad Peruana de Ciencias Aplicadas (UPC), 2026.