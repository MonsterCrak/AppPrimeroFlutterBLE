/// Tests for [SimulatedRssiSource].
library;

import 'dart:math' as math;

import 'package:app_primero_flutter_ble/models/beacon.dart';
import 'package:app_primero_flutter_ble/models/house_map.dart';
import 'package:app_primero_flutter_ble/sources/simulated_rssi_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SimulatedRssiSource', () {
    final map = HouseMap.casaDemo();

    SimulatedRssiSource make({math.Random? random}) =>
        SimulatedRssiSource(beacons: map.beacons, random: random);

    test('current() devuelve un snapshot no vacio tras construccion', () {
      final src = make();
      expect(src.current(), isNotEmpty);
      expect(src.current().length, map.beacons.length);
      src.dispose();
    });

    test('cada beacon aparece con su id en el snapshot', () {
      final src = make();
      for (final b in map.beacons) {
        expect(src.current().containsKey(b.id), isTrue);
      }
      src.dispose();
    });

    test('changes emite al hacer updateUserPosition', () async {
      final src = make();
      final emissions = <int>[];
      final sub = src.changes.listen((_) => emissions.add(emissions.length));
      // El constructor ya emitio 1 vez; el listener no recibe eventos
      // pasados, asi que esperamos nuevos.
      await Future<void>.delayed(Duration.zero);
      final initial = emissions.length;
      src.updateUserPosition(const Offset(0.1, 0.1));
      await Future<void>.delayed(Duration.zero);
      expect(emissions.length, initial + 1);
      await sub.cancel();
      await src.dispose();
    });

    test('misma seed + misma posicion = mismo snapshot', () {
      final a = SimulatedRssiSource(
        beacons: map.beacons,
        random: math.Random(7),
      );
      final b = SimulatedRssiSource(
        beacons: map.beacons,
        random: math.Random(7),
      );
      const pos = Offset(0.5, 0.5);
      a.updateUserPosition(pos);
      b.updateUserPosition(pos);
      final snapA = a.current();
      final snapB = b.current();
      for (final id in snapA.keys) {
        expect(snapA[id]!.dbm, equals(snapB[id]!.dbm));
      }
      a.dispose();
      b.dispose();
    });

    test('dispose cierra el stream de changes', () async {
      final src = make();
      var done = false;
      // ignore: unawaited_futures
      src.changes.listen(
        (_) {},
        onDone: () => done = true,
      );
      await src.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(done, isTrue);
    });

    test('mover al usuario cerca de B3 aumenta su dBm', () {
      final src = make(random: math.Random(0));
      final initial = src.current();
      src.updateUserPosition(const Offset(0.80, 0.85));
      final close = src.current();
      expect(close['B3']!.dbm, greaterThan(initial['B3']!.dbm));
      src.dispose();
    });

    test('alejarse de B3 disminuye su dBm', () {
      final src = make(random: math.Random(0));
      final initial = src.current();
      src.updateUserPosition(const Offset(0.05, 0.05));
      final moved = src.current();
      expect(moved['B3']!.dbm, lessThan(initial['B3']!.dbm));
      src.dispose();
    });
  });

  group('SimulatedRssiSource con beacons vacios', () {
    test('current() devuelve map vacio', () {
      final src = SimulatedRssiSource(
        beacons: const <Beacon>[],
        random: math.Random(1),
      );
      expect(src.current(), isEmpty);
      src.dispose();
    });
  });
}