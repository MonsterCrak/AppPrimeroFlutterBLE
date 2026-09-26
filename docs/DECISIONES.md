# Decisiones arquitectónicas (ADRs)

> Log de decisiones. Formato: número + título + contexto + decisión + consecuencias.

---

## ADR-001 · Usar Provider en vez de Riverpod

**Fecha:** 2026-05-30
**WU:** WU-0

### Contexto
El proyecto necesita un gestor de estado reactivo para separar la lógica de simulación del render. Las opciones evaluadas fueron:
- `provider` ^6.1.2
- `flutter_riverpod` ^2.x
- `bloc`/`flutter_bloc` ^8.x

### Decisión
Usar **`provider` ^6.1.2**.

### Razones
1. **Simplicidad para defensa de tesis.** Provider tiene la curva de aprendizaje más corta y la documentación más extendida en español.
2. **Suficiente para el alcance.** `ChangeNotifier` + `Consumer` cubre todo lo que necesitamos (timer, modo dual, telemetría reactiva).
3. **Migración posible.** Si en el futuro hace falta scopes múltiples o testabilidad avanzada, migrar a Riverpod es directo (mismo patrón de notifier).

### Consecuencias
- ✅ Menos código boilerplate.
- ✅ Más familiar para evaluadores de tesis nuevos en Flutter.
- ⚠️ Si el proyecto crece a 20+ widgets, Riverpod sería mejor.
- ⚠️ Provider no tiene un sistema de DI tan explícito como Riverpod — dependemos del code review para evitar singletons.

### Alternativas descartadas
- **Riverpod:** más potente pero overkill. Decidido posponerlo.
- **BLoC:** patrón excelente pero exige ceremonias (Event/State) que no aportan valor en un demo pequeño.

---

## ADR-002 · Modo dual Simulación / Real BLE

**Fecha:** 2026-05-30
**WU:** WU-7 (arquitectura propuesta)

### Contexto
El proyecto es un emulador para validar lógica espacial. Inicialmente se pensaba solo en simulación matemática. Pero las balizas Feasycom FSC-BP104D existen físicamente y eventualmente se usarán.

### Decisión
La app tendrá **dos modos intercambiables** mediante una interfaz `RssiSource`:

```dart
abstract class RssiSource {
  Stream<Map<BeaconId, RssiSample>> start({required Offset userPosition});
  Future<void> stop();
}
```

Implementaciones:
- `SimulatedRssiSource` (default, sin permisos).
- `BleRssiSource` (opt-in, con permisos, usa `flutter_blue_plus`).

### Razones
1. **Defender la tesis sin hardware.** El modo simulación es suficiente para la demo.
2. **Demostrar readiness.** Cuando lleguen las balizas, el modo real se enchufa sin reescribir UI ni lógica.
3. **Testeable.** `RssiSource` es mockeable con `mocktail`.

### Consecuencias
- ✅ La UI nunca sabe de qué fuente lee. Una sola UI para dos modos.
- ✅ Los tests no necesitan permisos ni hardware real.
- ⚠️ Pequeño overhead de abstracción (1 interfaz + 2 implementaciones).

---

## ADR-003 · Pinneado de versión exacta de `flutter_blue_plus`

**Fecha:** 2026-05-30
**WU:** WU-0

### Contexto
`flutter_blue_plus` evoluciona rápido. Cambios menores rompen APIs frecuentemente.

### Decisión
Pinear versión exacta en `pubspec.yaml`:
```yaml
flutter_blue_plus: 2.3.13
```
(sin el `^`).

### Razones
1. Estabilidad. No queremos que un `pub get` nos rompa el código.
2. Para vibecoding, esto significa que la documentación que consulte el LLM corresponde a la versión instalada.

### Consecuencias
- ✅ Build reproducible.
- ⚠️ Hay que actualizar manualmente para bugfixes.
- ⚠️ Si Flutter SDK actualiza incompatibilidades, hay que intervenir.

---

## ADR-004 · Sin backend (decisión de alcance)

**Fecha:** 2026-05-30

### Contexto
El prompt maestro original mencionaba "cliente ligero" sin ser explícito sobre backend.

### Decisión
**No existirá backend.** Todo el procesamiento ocurre en la app.

### Razones
1. El objetivo es validar la lógica espacial localmente.
2. Elimina complejidad operacional (auth, hosting, base de datos).
3. La tesis se enfoca en el sub-módulo de posicionamiento BLE del MVP original, no en infraestructura.

### Consecuencias
- ✅ Arquitectura simple, deploy trivial (instalar APK).
- ⚠️ No hay forma de compartir datos entre dispositivos (no es un requisito).
- ⚠️ Si en el futuro la tesis necesita backend, hay que refactorizar las fuentes de RSSI para que sean "remote".

---

## Próximos ADRs

- ADR-005: Estrategia de golden tests del `CustomPainter`.
- ADR-006: Manejo de errores BLE (estados del adapter, permisos denegados).
- ADR-007: Mapeo baliza detectada → coordenadas (manual vs. automático).