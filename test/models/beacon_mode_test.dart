import 'package:app_primero_flutter_ble/models/beacon_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BeaconMode', () {
    test('tiene exactamente 2 valores', () {
      expect(BeaconMode.values.length, 2);
    });

    test('contiene simulated y realBle', () {
      expect(BeaconMode.values, containsAll(<BeaconMode>[
        BeaconMode.simulated,
        BeaconMode.realBle,
      ]));
    });

    test('byName recupera cada valor', () {
      expect(BeaconMode.values.byName('simulated'), BeaconMode.simulated);
      expect(BeaconMode.values.byName('realBle'), BeaconMode.realBle);
    });
  });
}