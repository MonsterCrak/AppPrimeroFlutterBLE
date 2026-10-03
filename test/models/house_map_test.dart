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

    test('tiene 3 beacons (uno por zona)', () {
      expect(map.beacons.length, 3);
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
      expect(map.beaconById('B2')?.label, 'Pasillo');
      expect(map.beaconById('B3')?.label, 'Habitacion');
    });

    test('IDs son únicos', () {
      final ids = map.beacons.map((b) => b.id).toList();
      expect(ids.toSet().length, ids.length);
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

  group('HouseMap.miCasa (real house)', () {
    test('tiene 8 habitaciones (incluye zona excluida)', () {
      final micasa = HouseMap.miCasa();
      expect(micasa.rooms.length, 8);
    });

    test('bounds son [0, 1] x [0, 1]', () {
      final micasa = HouseMap.miCasa();
      expect(micasa.bounds, const Rect.fromLTWH(0, 0, 1, 1));
    });

    test('miCasa viene sin beacons (se inyectan desde BeaconConfig)', () {
      final micasa = HouseMap.miCasa();
      expect(micasa.beacons, isEmpty);
    });

    test('copyWith reemplaza solo el campo pasado', () {
      final micasa = HouseMap.miCasa();
      const b1 = Beacon(
        id: 'B1',
        label: 'Sala',
        position: Offset(0.622, 0.082),
        txPower: -59,
      );
      final conB1 = micasa.copyWith(beacons: [b1]);
      expect(conB1.beacons.length, 1);
      expect(conB1.beacons.first.id, 'B1');
      // Resto igual.
      expect(conB1.rooms, micasa.rooms);
      expect(conB1.bounds, micasa.bounds);
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

  group('HouseMap.cuartoPracticaUno', () {
    final map = HouseMap.cuartoPracticaUno();

    test('tiene 1 sola habitación (un solo room = los bounds)', () {
      expect(map.rooms.length, 1);
      expect(map.rooms.first, map.bounds);
    });

    test('bounds preservan aspect ratio del cuarto 3 × 2.6 m', () {
      // 1 m = 1/3 normalized (longest side); altura = 2.6/3 ≈ 0.8667
      expect(map.bounds, const Rect.fromLTWH(0, 0, 1, 2.6 / 3));
    });

    test('tiene 1 beacon (B1) en la esquina superior derecha', () {
      expect(map.beacons.length, 1);
      expect(map.beacons.first.id, 'B1');
      expect(map.beacons.first.position, const Offset(0.95, 0.05));
      expect(map.beacons.first.txPower, -59);
    });

    test('realDimensions documenta el tamaño real del cuarto', () {
      expect(map.realDimensions, const Size(3.0, 2.6));
      expect(map.roomScale, closeTo(1.0 / 3.0, 1e-9));
    });

    test('layout incluye labels "Cuarto 1" y "B1" para clarificar el diagrama', () {
      expect(map.layout.labels.length, 2);
      final texts = map.layout.labels.map((l) => l.text).toList();
      expect(texts, containsAll(['Cuarto 1', 'B1']));
    });

    test('layout NO incluye paredes, puertas ni zonas excluidas', () {
      expect(map.layout.walls, isEmpty);
      expect(map.layout.doors, isEmpty);
      expect(map.layout.excludedZones, isEmpty);
    });
  });
}