/// Tests for the single-beacon position estimator.
///
/// Covers the WU-17 / Etapa 1 case: one beacon, room bounds with real
/// dimensions, animate the user position based on BLE-derived distance.
library;

import 'dart:ui';

import 'package:app_primero_flutter_ble/util/position_estimator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Standard Etapa 1 setup: `Cuarto 1`, 3 m × 2.6 m, beacon at upper-right.
const _beacon = Offset(0.95, 0.05);
final _bounds = const Rect.fromLTWH(0, 0, 1, 2.6 / 3); // longest side = 1.0
const _roomScale = 1.0 / 3.0; // 1 / max(width=3, height=2.6)

void main() {
  group('estimatePositionFromSingleBeacon', () {
    test('caso basico: distancia 1m, last known opuesto → usuario en el circulo',
        () {
      // Last known at the lower-left corner, beacon at upper-right.
      const lastKnown = Offset(0.05, 0.05);

      final pos = estimatePositionFromSingleBeacon(
        beaconPositionNormalized: _beacon,
        distanceMeters: 1.0,
        roomScale: _roomScale,
        lastKnownPositionNormalized: lastKnown,
        roomBoundsNormalized: _bounds,
      );

      // Direction from beacon → last known is purely horizontal (-1, 0).
      // Distance 1m in normalized = 1/3. So newPos = (0.95 - 1/3, 0.05).
      expect(pos.dx, closeTo(0.95 - 1.0 / 3.0, 1e-9));
      expect(pos.dy, closeTo(0.05, 1e-9));
      // Stay inside the room.
      expect(_bounds.contains(pos), isTrue);
    });

    test('last known == beacon → usa direccion por defecto (0, 1)', () {
      // When lastKnown coincides with the beacon we can't infer a direction.
      // The estimator must still produce a deterministic, in-bounds position.
      final pos = estimatePositionFromSingleBeacon(
        beaconPositionNormalized: _beacon,
        distanceMeters: 1.0,
        roomScale: _roomScale,
        lastKnownPositionNormalized: _beacon,
        roomBoundsNormalized: _bounds,
      );

      // Default direction = (0, 1). 1m * 1/3 = 0.333 normalized below beacon.
      expect(pos.dx, closeTo(0.95, 1e-9));
      expect(pos.dy, closeTo(0.05 + 1.0 / 3.0, 1e-9));
      expect(_bounds.contains(pos), isTrue);
    });

    test('last known casi-en-beacon (delta < 1e-6) → direccion por defecto',
        () {
      // Tiny nudge off the beacon: delta length below 1e-6 must trigger
      // the default-direction fallback.
      final nudged = _beacon + const Offset(0.5e-7, 0);
      final pos = estimatePositionFromSingleBeacon(
        beaconPositionNormalized: _beacon,
        distanceMeters: 1.0,
        roomScale: _roomScale,
        lastKnownPositionNormalized: nudged,
        roomBoundsNormalized: _bounds,
      );

      // Same as the explicit-snap test: default direction (0, 1).
      expect(pos.dx, closeTo(0.95, 1e-9));
      expect(pos.dy, closeTo(0.05 + 1.0 / 3.0, 1e-9));
    });

    test('clamping: circulo excede bounds → posicion clampeada dentro', () {
      // 10m radius — way bigger than the 3m room. Direction toward lower-left
      // would put newPos far outside the room; clamp must keep us in bounds.
      final pos = estimatePositionFromSingleBeacon(
        beaconPositionNormalized: _beacon,
        distanceMeters: 10.0,
        roomScale: _roomScale,
        lastKnownPositionNormalized: const Offset(0.05, 0.05),
        roomBoundsNormalized: _bounds,
      );

      expect(pos.dx, _bounds.left); // clamped to left wall
      expect(pos.dy, closeTo(0.05, 1e-9)); // dy unchanged
      expect(_bounds.contains(pos), isTrue);
    });

    test('distancia cero no lanza, devuelve la posicion del beacon', () {
      // distance=0 with lastKnown far from beacon: newPos = beacon exactly.
      final pos = estimatePositionFromSingleBeacon(
        beaconPositionNormalized: _beacon,
        distanceMeters: 0.0,
        roomScale: _roomScale,
        lastKnownPositionNormalized: const Offset(0.05, 0.05),
        roomBoundsNormalized: _bounds,
      );

      expect(pos.dx, closeTo(0.95, 1e-9));
      expect(pos.dy, closeTo(0.05, 1e-9));
    });

    test('distancia cero con lastKnown == beacon → tambien el beacon', () {
      // distance=0 + degenerate direction (lastKnown == beacon) → 0*Offset =
      // Offset.zero, so newPos == beacon.
      final pos = estimatePositionFromSingleBeacon(
        beaconPositionNormalized: _beacon,
        distanceMeters: 0.0,
        roomScale: _roomScale,
        lastKnownPositionNormalized: _beacon,
        roomBoundsNormalized: _bounds,
      );

      expect(pos, _beacon);
    });

    test('funcion pura: mismos inputs → mismos outputs', () {
      const lastKnown = Offset(0.5, 0.5);
      Offset call() => estimatePositionFromSingleBeacon(
            beaconPositionNormalized: _beacon,
            distanceMeters: 1.5,
            roomScale: _roomScale,
            lastKnownPositionNormalized: lastKnown,
            roomBoundsNormalized: _bounds,
          );
      final a = call();
      final b = call();
      expect(a, equals(b));
    });

    test('distancia muy chica con lastKnown en el beacon → cerca del beacon',
        () {
      // The "snap" described in the spec: distance ≈ 0 cm, lastKnown at the
      // beacon. We default to (0, 1) so the result is the beacon plus a tiny
      // nudge — still inside the room and effectively on top of the beacon.
      final pos = estimatePositionFromSingleBeacon(
        beaconPositionNormalized: _beacon,
        distanceMeters: 0.005, // 5 mm
        roomScale: _roomScale,
        lastKnownPositionNormalized: _beacon,
        roomBoundsNormalized: _bounds,
      );

      // 5 mm * 1/3 ≈ 0.00167 normalized units below the beacon.
      expect(pos.dx, closeTo(0.95, 1e-9));
      expect(pos.dy, closeTo(0.05 + 0.005 / 3.0, 1e-9));
      expect(_bounds.contains(pos), isTrue);
    });

    test('direccion arbitraria (last known hacia el sur)', () {
      // Last known directly below the beacon. Direction from beacon = (0, +1).
      // Since the beacon is tucked into the upper-right corner, going south
      // is the only direction that has room to spare — we use that to
      // exercise the non-horizontal branch without bumping into a wall.
      final pos = estimatePositionFromSingleBeacon(
        beaconPositionNormalized: _beacon,
        distanceMeters: 0.3,
        roomScale: _roomScale,
        lastKnownPositionNormalized: const Offset(0.95, 0.5),
        roomBoundsNormalized: _bounds,
      );

      expect(pos.dx, closeTo(0.95, 1e-9));
      expect(pos.dy, closeTo(0.05 + 0.3 / 3.0, 1e-9));
      expect(_bounds.contains(pos), isTrue);
    });
  });
}
