# Testing

> Documento vivo. Las convenciones de testing de este proyecto.
> Origen: `E:\Obsidian\Tesis\Emulador BLE Indoor\Plan.md` §7.0.

## Filosofía

**Test-after-inmediato para vibecoding.** Cada WU escribe su código **y sus tests en la misma sesión**, antes del commit. Los tests son la red de seguridad que evita que código generado por LLM "que compila pero hace cualquier cosa" se cuele al repo.

**Cobertura por capa, no por porcentaje.** No nos obsesionamos con un número; cada capa del MVVM tiene tests específicos.

**Tests rápidos.** `flutter test` corre en segundos. Si un test tarda más de 100 ms, repensar.

## Stack

- `flutter_test` (incluido en Flutter SDK).
- `mocktail` ^1.0.4 — mocks con sintaxis moderna, mejor para vibecoding que `mockito`.
- Golden tests via `flutter test --update-goldens` para el render visual.
- **Sin** `integration_test` por ahora (overhead innecesario para un demo).

## Estructura

Mirror de `lib/`:

```
lib/models/          →  test/models/
lib/util/            →  test/util/
lib/sources/         →  test/sources/
lib/state/           →  test/state/
lib/view/            →  test/widget/
```

Cada archivo en `lib/` tiene su espejo en `test/` con el mismo nombre + `_test.dart`.

## Convenciones de código

### Nombre de archivo
`<nombre>_test.dart`. Ej: `beacon.dart` → `beacon_test.dart`.

### Nombre de grupo
`group('ClassName', () { ... })`. Agrupar por clase o feature.

### Nombre de test
Descriptivo, sin "should":
- ✅ `test('rssi decreases as distance increases', ...)`
- ❌ `test('should decrease rssi', ...)`

### Aislamiento
Cada test corre en aislamiento. Sin dependencias de orden. `setUp()` / `tearDown()` para estado compartido.

### AAA pattern
- **Arrange** (preparar datos).
- **Act** (ejecutar).
- **Assert** (verificar).

## Tests por capa

| Capa | Qué testear | Cómo |
|------|-------------|------|
| Modelo | Inmutabilidad, equality, factory methods | Tests puros. |
| Util | Fórmula matemática, casos borde, propiedades | Tests con valores conocidos. |
| Source (sim) | Stream emite, RSSI depende de distancia, clamping | Tests asíncronos con `expectLater` + `Stream`. |
| Source (BLE) | Llamadas a API, traducción de `ScanResult` → `RssiSample` | `mocktail` sobre `FlutterBluePlus`. |
| Estado | `start`/`stop`/`reset`, interpolación de waypoints | `fakeAsync` para controlar el tiempo. |
| Widget | Render, interacción, banners | `WidgetTester` + `pumpWidget`. |
| Render | Regresiones visuales | Golden tests. |

## Comandos

```bash
# Todos los tests
flutter test

# Un archivo
flutter test test/util/rssi_model_test.dart

# Por nombre
flutter test --plain-name "rssi decreases"

# Con coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html

# Actualizar golden files (solo cuando el cambio de render es intencional)
flutter test --update-goldens

# Análisis estático (corre antes de los tests en CI)
flutter analyze
```

## Definition of Done (DoD) por WU

Una WU está terminada solo si:

1. ✅ `flutter analyze` = 0 errores, 0 warnings.
2. ✅ `flutter test` verde.
3. ✅ El test específico de la WU pasa (`flutter test test/<ruta>/<arch>_test.dart`).
4. ✅ Hay un commit atómico con mensaje convencional.

## Anti-patrones evitados

- ❌ Tests que no fallan nunca (tests placebo).
- ❌ Tests que dependen de tiempo real (`sleep`, `Future.delayed` real). Usar `fakeAsync`.
- ❌ Tests que comparten estado mutable entre sí.
- ❌ Tests que prueban implementación en vez de comportamiento.
- ❌ Tests con setup gigante que oscurece la intención. Preferir `setUpAll` solo para mocks costosos.

## Recursos

- [Flutter testing docs](https://docs.flutter.dev/testing)
- [mocktail docs](https://pub.dev/packages/mocktail)
- [fakeAsync package](https://pub.dev/packages/fake_async)