/// Tests for [SimulationNotifier].
///
/// Uses `fake_async` to control the periodic timer deterministically.
library;

import 'dart:async';

import 'package:app_primero_flutter_ble/models/beacon_mode.dart';
import 'package:app_primero_flutter_ble/models/house_map.dart';
import 'package:app_primero_flutter_ble/models/rssi_sample.dart';
import 'package:app_primero_flutter_ble/sources/rssi_source.dart';
import 'package:app_primero_flutter_ble/state/simulation_notifier.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRssiSource extends Mock implements RssiSource {}

/// First default waypoint of the SimulationNotifier route (real house).
const Offset _firstWaypoint = Offset(0.622, 0.206);

void main() {
  late HouseMap houseMap;
  late _MockRssiSource mockSource;

  setUpAll(() {
    registerFallbackValue(const Offset(0, 0));
  });

  setUp(() {
    houseMap = HouseMap.casaDemo();
    mockSource = _MockRssiSource();
    when(() => mockSource.current()).thenReturn({
      for (final b in houseMap.beacons)
        b.id: RssiSample(beaconId: b.id, dbm: -70, distance: 1),
    });
    when(() => mockSource.changes)
        .thenAnswer((_) => StreamController<void>.broadcast().stream);
    when(() => mockSource.updateUserPosition(any())).thenReturn(null);
    when(() => mockSource.dispose()).thenAnswer((_) async {});
  });

  group('estado inicial', () {
    test('isRunning == false y userPosition == primer waypoint', () {
      final notifier = SimulationNotifier(
        rssiSource: mockSource,
        houseMap: houseMap,
      );
      expect(notifier.isRunning, isFalse);
      expect(notifier.userPosition, notifier.waypoints.first);
      expect(notifier.userPosition, _firstWaypoint);
    });

    test('expone los waypoints (al menos 3)', () {
      final notifier = SimulationNotifier(
        rssiSource: mockSource,
        houseMap: houseMap,
      );
      expect(notifier.waypoints.length, greaterThanOrEqualTo(3));
    });

    test('nearestBeacons devuelve hasta N elementos ordenados por distancia',
        () {
      when(() => mockSource.current()).thenReturn({
        'B1': RssiSample(beaconId: 'B1', dbm: -60, distance: 5),
        'B2': RssiSample(beaconId: 'B2', dbm: -70, distance: 1),
        'B3': RssiSample(beaconId: 'B3', dbm: -80, distance: 3),
      });
      final notifier = SimulationNotifier(
        rssiSource: mockSource,
        houseMap: houseMap,
      );
      final nearest = notifier.nearestBeacons(n: 3);
      expect(nearest.length, 3);
      expect(nearest[0].beaconId, 'B2');
      expect(nearest[1].beaconId, 'B3');
      expect(nearest[2].beaconId, 'B1');
    });
  });

  group('start/stop/reset', () {
    test('start cambia isRunning y los ticks avanzan la posicion', () {
      fakeAsync((async) {
        final notifier = SimulationNotifier(
          rssiSource: mockSource,
          houseMap: houseMap,
          tickInterval: const Duration(milliseconds: 100),
        );
        final initial = notifier.userPosition;
        notifier.start();
        expect(notifier.isRunning, isTrue);

        async.elapse(const Duration(milliseconds: 2500));
        expect(notifier.userPosition, isNot(equals(initial)));
        verify(() => mockSource.updateUserPosition(any())).called(
          greaterThan(5),
        );
        notifier.stop();
      });
    });

    test('stop detiene el timer y la posicion queda congelada', () {
      fakeAsync((async) {
        final notifier = SimulationNotifier(
          rssiSource: mockSource,
          houseMap: houseMap,
          tickInterval: const Duration(milliseconds: 100),
        );
        notifier.start();
        async.elapse(const Duration(milliseconds: 500));
        final pos1 = notifier.userPosition;
        notifier.stop();
        async.elapse(const Duration(seconds: 5));
        expect(notifier.userPosition, equals(pos1));
        expect(notifier.isRunning, isFalse);
      });
    });

    test('reset vuelve al primer waypoint', () {
      fakeAsync((async) {
        final notifier = SimulationNotifier(
          rssiSource: mockSource,
          houseMap: houseMap,
        );
        notifier.start();
        async.elapse(const Duration(seconds: 3));
        notifier.reset();
        expect(notifier.userPosition, notifier.waypoints.first);
        notifier.stop();
      });
    });

    test('doble start es idempotente', () {
      fakeAsync((async) {
        final notifier = SimulationNotifier(
          rssiSource: mockSource,
          houseMap: houseMap,
        );
        notifier.start();
        notifier.start();
        expect(notifier.isRunning, isTrue);
        notifier.stop();
      });
    });
  });

  group('integracion con RssiSource', () {
    test('constructor llama updateUserPosition con el primer waypoint', () {
      SimulationNotifier(rssiSource: mockSource, houseMap: houseMap);
      final captured =
          verify(() => mockSource.updateUserPosition(captureAny())).captured;
      expect(captured, isNotEmpty);
      expect(captured.first, _firstWaypoint);
    });

    test('cada tick llama updateUserPosition exactamente una vez', () {
      fakeAsync((async) {
        final notifier = SimulationNotifier(
          rssiSource: mockSource,
          houseMap: houseMap,
          tickInterval: const Duration(milliseconds: 100),
        );
        clearInteractions(mockSource);
        notifier.start();
        async.elapse(const Duration(milliseconds: 500));
        notifier.stop();
        // 5 ticks @ 100ms cada uno.
        verify(() => mockSource.updateUserPosition(any())).called(5);
      });
    });

    test('dispose libera el source', () {
      fakeAsync((async) {
        final notifier = SimulationNotifier(
          rssiSource: mockSource,
          houseMap: houseMap,
        );
        notifier.start();
        notifier.dispose();
        async.elapse(const Duration(seconds: 1));
        verify(() => mockSource.dispose()).called(1);
      });
    });
  });

  group('drift en simulated mode (WU-18)', () {
    test(
        'drift mueve la posicion del usuario alrededor del centro del cuarto '
        '(Etapa 1, single waypoint)', () {
      fakeAsync((async) {
        final map = HouseMap.cuartoPracticaUno();
        // Static single-waypoint setup — mirrors `main.dart` for Etapa 1.
        const staticWaypoint = Offset(0.5, 2.6 / 6);
        final notifier = SimulationNotifier(
          rssiSource: mockSource,
          houseMap: map,
          waypoints: const [staticWaypoint],
        );
        expect(notifier.userPosition, equals(staticWaypoint));

        // Advance ~500ms in fake time. The drift Timer ticks every 33ms
        // so we should observe at least one position change.
        async.elapse(const Duration(milliseconds: 500));

        // Position must have moved off the static waypoint.
        expect(notifier.userPosition, isNot(equals(staticWaypoint)));

        // Sanity: the new position is still inside the room bounds.
        expect(map.bounds.contains(notifier.userPosition), isTrue);

        notifier.dispose();
      });
    });

    test('disableDrift() mantiene la posicion en el waypoint estatico', () {
      fakeAsync((async) {
        const staticWaypoint = Offset(0.5, 2.6 / 6);
        final notifier = SimulationNotifier(
          rssiSource: mockSource,
          houseMap: HouseMap.cuartoPracticaUno(),
          waypoints: const [staticWaypoint],
        );
        notifier.disableDrift();

        async.elapse(const Duration(milliseconds: 500));
        // Drift is disabled → position must stay pinned to the waypoint.
        expect(notifier.userPosition, equals(staticWaypoint));

        notifier.dispose();
      });
    });

    test(
        'realBle: el drift timer NO corre (la posicion viene de RSSI/BLE)',
        () {
      fakeAsync((async) {
        const staticWaypoint = Offset(0.5, 2.6 / 6);
        final notifier = SimulationNotifier(
          rssiSource: mockSource,
          houseMap: HouseMap.cuartoPracticaUno(),
          waypoints: const [staticWaypoint],
        );
        // Snapshot so setMode(realBle) has something to seed position from.
        when(() => mockSource.current()).thenReturn({
          'B1': RssiSample(beaconId: 'B1', dbm: -65, distance: 1.5),
        });
        notifier.setMode(BeaconMode.realBle);
        final seeded = notifier.userPosition;

        async.elapse(const Duration(milliseconds: 500));
        // Real BLE: drift must NOT move the position on its own.
        expect(notifier.userPosition, equals(seeded));

        notifier.dispose();
      });
    });

    test('reset() restablece la fase de drift (vuelve al waypoint inicial)',
        () {
      fakeAsync((async) {
        const staticWaypoint = Offset(0.5, 2.6 / 6);
        final notifier = SimulationNotifier(
          rssiSource: mockSource,
          houseMap: HouseMap.cuartoPracticaUno(),
          waypoints: const [staticWaypoint],
        );

        async.elapse(const Duration(milliseconds: 250));
        // Drift has moved the user off the waypoint by now.
        expect(notifier.userPosition, isNot(equals(staticWaypoint)));

        notifier.reset();
        // After reset, the next drift tick must start at the waypoint, not
        // at whatever random phase the previous drift had reached.
        expect(notifier.userPosition, equals(staticWaypoint));

        notifier.dispose();
      });
    });
  });

  group('modo Real BLE (WU-17)', () {
    /// Builds a notifier wired to a stable [StreamController] so we can fire
    /// BLE events on demand. The [snapshotHolder] lets us mutate the
    /// snapshot that `mockSource.current()` returns between events.
    _MockRssiSource makeBleSource({
      required StreamController<void> controller,
      required Map<String, RssiSample> Function() snapshotHolder,
    }) {
      final m = _MockRssiSource();
      when(() => m.current()).thenAnswer((_) => snapshotHolder());
      when(() => m.changes).thenAnswer((_) => controller.stream);
      when(() => m.updateUserPosition(any())).thenReturn(null);
      when(() => m.dispose()).thenAnswer((_) async {});
      return m;
    }

    test(
        'setMode(realBle) detiene el timer y siembra posicion desde snapshot BLE',
        () {
      fakeAsync((async) {
        final map = HouseMap.cuartoPracticaUno();
        final controller = StreamController<void>.broadcast();
        var snapshot = <String, RssiSample>{
          'B1': RssiSample(beaconId: 'B1', dbm: -65, distance: 1.5),
        };
        final bleSource =
            makeBleSource(controller: controller, snapshotHolder: () => snapshot);

        final notifier = SimulationNotifier(
          rssiSource: bleSource,
          houseMap: map,
        );
        // Position starts at the first waypoint.
        expect(notifier.userPosition, equals(notifier.waypoints.first));

        // Start the timer (simulated mode active), then switch to realBle.
        notifier.start();
        expect(notifier.isRunning, isTrue);
        notifier.setMode(BeaconMode.realBle);

        // Timer must be cancelled, mode must be realBle.
        expect(notifier.isRunning, isFalse);
        expect(notifier.mode, BeaconMode.realBle);

        // Position must have been reseeded from the BLE snapshot. With B1
        // at (0.95, 0.05) and 1.5 m distance, the seeded position cannot
        // coincide with the first waypoint of the miCasa route.
        expect(notifier.userPosition, isNot(equals(notifier.waypoints.first)));

        async.flushMicrotasks();
        controller.close();
      });
    });

    test(
        'realBle: un evento del stream BLE actualiza _userPosition (WU-15b fix)',
        () async {
      final map = HouseMap.cuartoPracticaUno();
      final controller = StreamController<void>.broadcast();
      Map<String, RssiSample> snapshot = {
        'B1': RssiSample(beaconId: 'B1', dbm: -65, distance: 1.0),
      };
      final bleSource =
          makeBleSource(controller: controller, snapshotHolder: () => snapshot);

      final notifier = SimulationNotifier(
        rssiSource: bleSource,
        houseMap: map,
      );

      // Switch to realBle to enable BLE-driven position updates. The
      // initial seed uses the current snapshot (1 m from B1).
      notifier.setMode(BeaconMode.realBle);
      final posAfterSeed = notifier.userPosition;
      expect(posAfterSeed, isNot(equals(notifier.waypoints.first)));

      // Move the user further from the beacon and fire a BLE event.
      snapshot = {
        'B1': RssiSample(beaconId: 'B1', dbm: -75, distance: 2.5),
      };
      controller.add(null);
      // Allow the stream listener (microtask) to run.
      await Future<void>.delayed(Duration.zero);

      // Position must have moved further from the beacon.
      expect(notifier.userPosition, isNot(equals(posAfterSeed)));
      // And it must still be inside the room.
      expect(map.bounds.contains(notifier.userPosition), isTrue);

      await controller.close();
      notifier.dispose();
    });

    test(
        'realBle: snapshot BLE vacio es no-op (no rompe, mantiene posicion)',
        () async {
      final map = HouseMap.cuartoPracticaUno();
      final controller = StreamController<void>.broadcast();
      // Start with one sample, then empty the snapshot mid-test.
      var snapshot = <String, RssiSample>{
        'B1': RssiSample(beaconId: 'B1', dbm: -65, distance: 1.0),
      };
      final bleSource =
          makeBleSource(controller: controller, snapshotHolder: () => snapshot);

      final notifier = SimulationNotifier(
        rssiSource: bleSource,
        houseMap: map,
      );
      notifier.setMode(BeaconMode.realBle);
      final posBefore = notifier.userPosition;

      // Drop the snapshot and fire an event.
      snapshot = const <String, RssiSample>{};
      controller.add(null);
      await Future<void>.delayed(Duration.zero);

      // No-op: position must be unchanged.
      expect(notifier.userPosition, equals(posBefore));

      await controller.close();
      notifier.dispose();
    });

    test('realBle: beacon desconocido al snapshot es no-op', () async {
      final map = HouseMap.cuartoPracticaUno(); // only knows B1
      final controller = StreamController<void>.broadcast();
      var snapshot = <String, RssiSample>{
        // B99 is not in the configured HouseMap — must be ignored.
        'B99': RssiSample(beaconId: 'B99', dbm: -65, distance: 1.0),
      };
      final bleSource =
          makeBleSource(controller: controller, snapshotHolder: () => snapshot);

      final notifier = SimulationNotifier(
        rssiSource: bleSource,
        houseMap: map,
      );
      notifier.setMode(BeaconMode.realBle);
      // The "seed" above finds no beacon in the map -> position stays
      // at the first waypoint (no error).
      expect(notifier.userPosition, equals(notifier.waypoints.first));

      await controller.close();
      notifier.dispose();
    });
  });
}
