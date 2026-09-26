import 'package:app_primero_flutter_ble/models/beacon.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Beacon', () {
    Beacon makeBeacon({
      String id = 'B1',
      String label = 'Sala-A',
      Offset position = const Offset(0.15, 0.20),
      double txPower = -59,
    }) =>
        Beacon(
          id: id,
          label: label,
          position: position,
          txPower: txPower,
        );

    test('dos beacons con mismos datos son iguales', () {
      final a = makeBeacon();
      final b = makeBeacon();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('distinto id rompe la igualdad', () {
      expect(makeBeacon(id: 'B1'), isNot(equals(makeBeacon(id: 'B2'))));
    });

    test('distinto label rompe la igualdad', () {
      expect(
        makeBeacon(label: 'Sala-A'),
        isNot(equals(makeBeacon(label: 'Sala-B'))),
      );
    });

    test('distinta position rompe la igualdad', () {
      expect(
        makeBeacon(position: const Offset(0.1, 0.1)),
        isNot(equals(makeBeacon(position: const Offset(0.2, 0.2)))),
      );
    });

    test('distinto txPower rompe la igualdad', () {
      expect(
        makeBeacon(txPower: -59),
        isNot(equals(makeBeacon(txPower: -60))),
      );
    });

    test('toString contiene id y label', () {
      final s = makeBeacon(id: 'B3', label: 'Pasillo').toString();
      expect(s, contains('B3'));
      expect(s, contains('Pasillo'));
    });

    test('constructor es const-friendly (mismos datos == misma instancia?)',
        () {
      // No se puede probar runtime la inmutabilidad de `final`, pero podemos
      // confirmar que dos `const` con mismos datos colapsan en una sola
      // instancia gracias a canonicalization.
      const a = Beacon(
        id: 'B1',
        label: 'Sala-A',
        position: Offset(0.15, 0.20),
        txPower: -59,
      );
      const b = Beacon(
        id: 'B1',
        label: 'Sala-A',
        position: Offset(0.15, 0.20),
        txPower: -59,
      );
      expect(identical(a, b), isTrue);
    });
  });
}