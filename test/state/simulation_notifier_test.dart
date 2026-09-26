/// Tests for [SimulationNotifier].
///
/// Uses `fake_async` to control the periodic timer deterministically.
library;

import 'dart:async';

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
}