import 'dart:ui';

import 'package:app_primero_flutter_ble/models/beacon.dart';
import 'package:app_primero_flutter_ble/models/house_map.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HouseMap.casaDemo', () {
    final map = HouseMap.casaDemo();

    test('tiene 3 habitaciones (sala, pasillo, habitacion)', () {
      expect(map.rooms.length, 3);
    });

    test('bounds son [0, 1] x [0, 1]', () {
      expect(map.bounds, const Rect.fromLTWH(0, 0, 1, 1));
    });

    test('tiene 4 beacons en esquinas/walls', () {
      expect(map.beacons.length, 4);
    });

    test('todos los beacons están dentro de [0, 1] x [0, 1]', () {
      for (final b in map.beacons) {
        expect(b.position.dx, inInclusiveRange(0, 1),
            reason: '${b.id}.position.dx fuera de rango');
        expect(b.position.dy, inInclusiveRange(0, 1),
            reason: '${b.id}.position.dy fuera de rango');
      }
    });

    test('beaconById retorna el beacon correcto', () {
      expect(map.beaconById('B1')?.label, 'Sala-A');
      expect(map.beaconById('B2')?.label, 'Sala-B');
      expect(map.beaconById('B3')?.label, 'Pasillo');
      expect(map.beaconById('B4')?.label, 'Habitacion');
    });

    test('beaconById retorna null para id inexistente', () {
      expect(map.beaconById('B999'), isNull);
      expect(map.beaconById(''), isNull);
    });

    test('containsPoint detecta puntos dentro/fuera', () {
      expect(map.containsPoint(const Offset(0.5, 0.5)), isTrue);
      expect(map.containsPoint(const Offset(0, 0)), isTrue);
      expect(map.containsPoint(const Offset(-0.1, 0.5)), isFalse);
      expect(map.containsPoint(const Offset(1.1, 0.5)), isFalse);
    });

    test('dos llamadas a casaDemo producen mapas iguales', () {
      final a = HouseMap.casaDemo();
      final b = HouseMap.casaDemo();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('txPower típico del DA14531 está alrededor de -59 dBm', () {
      for (final b in map.beacons) {
        expect(b.txPower, lessThanOrEqualTo(-55));
        expect(b.txPower, greaterThanOrEqualTo(-65));
      }
    });
  });

  group('HouseMap equality', () {
    test('mapas con mismos datos son iguales', () {
      const a = HouseMap(
        name: 'X',
        bounds: Rect.fromLTWH(0, 0, 1, 1),
        rooms: [Rect.fromLTWH(0, 0, 1, 1)],
        beacons: [
          Beacon(id: 'B1', label: 'L', position: Offset(0.1, 0.1), txPower: -59),
        ],
      );
      const b = HouseMap(
        name: 'X',
        bounds: Rect.fromLTWH(0, 0, 1, 1),
        rooms: [Rect.fromLTWH(0, 0, 1, 1)],
        beacons: [
          Beacon(id: 'B1', label: 'L', position: Offset(0.1, 0.1), txPower: -59),
        ],
      );
      expect(a, equals(b));
    });

    test('mapas con distinto número de beacons NO son iguales', () {
      final demo = HouseMap.casaDemo();
      final modified = HouseMap(
        name: demo.name,
        bounds: demo.bounds,
        rooms: demo.rooms,
        beacons: demo.beacons.take(2).toList(),
      );
      expect(demo, isNot(equals(modified)));
    });
  });
}