/// Tests for [BleRssiSource] — focusing on the pure parsing logic.
///
/// `flutter_beacon` doesn't expose a public constructor for [RangingResult];
/// the only way to build one is via `RangingResult.from(json)`. So we
/// exercise the pure function [BleRssiSource.mapRangingResult] directly
/// with RangingResults built from valid JSON.
library;

import 'dart:convert';

import 'package:app_primero_flutter_ble/config/beacon_config.dart';
import 'package:app_primero_flutter_ble/models/rssi_sample.dart';
import 'package:app_primero_flutter_ble/sources/ble_rssi_source.dart';
import 'package:dchs_flutter_beacon/dchs_flutter_beacon.dart' as fb;
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Builds a JSON representation of a RangingResult containing the given
  // raw beacons, suitable for `RangingResult.from(json)`.
  Map<String, dynamic> rangingJson(List<Map<String, dynamic>> beaconsJson) {
    return {
      'region': {
        'identifier': 'test',
        'proximityUUID': BeaconConfig.proximityUuid,
      },
      'beacons': beaconsJson,
    };
  }

  Map<String, dynamic> beaconJson({
    int major = BeaconConfig.major,
    int minor = 1,
    String? uuid,
    int rssi = -60,
    double accuracy = 1.5,
    String proximity = 'near',
  }) {
    return {
      'proximityUUID': uuid ?? BeaconConfig.proximityUuid,
      'major': major,
      'minor': minor,
      'rssi': rssi,
      'txPower': -59,
      'accuracy': accuracy,
      'proximity': proximity,
    };
  }

  fb.RangingResult ranging(List<Map<String, dynamic>> beacons) {
    return fb.RangingResult.from(jsonDecode(jsonEncode(rangingJson(beacons))));
  }

  group('BleRssiSource.mapRangingResult — mapeo iBeacon → B1/B2/B3', () {
    test('Minor=1 → B1', () {
      final r = ranging([beaconJson(minor: 1, rssi: -60)]);
      final out = BleRssiSource.mapRangingResult(r);
      expect(out.containsKey('B1'), isTrue);
      expect(out['B1']!.dbm, closeTo(-60, 0.0001));
      expect(out['B1']!.distance, 1.5);
    });

    test('Minor=2 → B2, Minor=3 → B3', () {
      final r = ranging([
        beaconJson(minor: 2, rssi: -70, accuracy: 3.0),
        beaconJson(minor: 3, rssi: -80, accuracy: 4.5),
      ]);
      final out = BleRssiSource.mapRangingResult(r);
      expect(out.keys, containsAll(['B2', 'B3']));
      expect(out['B2']!.dbm, closeTo(-70, 0.0001));
      expect(out['B3']!.dbm, closeTo(-80, 0.0001));
      expect(out['B2']!.distance, 3.0);
      expect(out['B3']!.distance, 4.5);
    });

    test('Minor fuera del set configurado se ignora', () {
      final r = ranging([beaconJson(minor: 99, rssi: -50)]);
      expect(BleRssiSource.mapRangingResult(r), isEmpty);
    });

    test('Major incorrecto se ignora (otro deployment)', () {
      final r = ranging([beaconJson(minor: 1, major: 99999)]);
      expect(BleRssiSource.mapRangingResult(r), isEmpty);
    });

    test('Proximity UUID incorrecto se ignora', () {
      final r = ranging([
        beaconJson(minor: 1, uuid: '00000000-0000-0000-0000-000000000000'),
      ]);
      expect(BleRssiSource.mapRangingResult(r), isEmpty);
    });

    test('Mezcla de beacons válidos e inválidos: solo válidos pasan', () {
      final r = ranging([
        beaconJson(minor: 1, rssi: -60),
        beaconJson(minor: 99, rssi: -40),
        beaconJson(minor: 2, rssi: -70),
        beaconJson(minor: 1, major: 9999, rssi: -30),
      ]);
      final out = BleRssiSource.mapRangingResult(r);
      expect(out.keys, {'B1', 'B2'});
      expect(out['B1']!.dbm, -60);
      expect(out['B2']!.dbm, -70);
    });
  });

  group('BleRssiSource.mapRangingResult — clamping de RSSI', () {
    test('RSSI > 0 se clampa a maxDbm (-30)', () {
      final r = ranging([beaconJson(minor: 1, rssi: 100)]);
      final out = BleRssiSource.mapRangingResult(r);
      expect(out['B1']!.dbm, RssiSample.maxDbm);
    });

    test('RSSI muy bajo se clampa a minDbm (-100)', () {
      final r = ranging([beaconJson(minor: 1, rssi: -200)]);
      final out = BleRssiSource.mapRangingResult(r);
      expect(out['B1']!.dbm, RssiSample.minDbm);
    });
  });

  group('BleRssiSource — instance behavior (start/stop/dispose)', () {
    test('instance se puede construir sin errores', () {
      // Production constructor: uses Platform.isIOS check.
      // We can't call start() because that requires a real device, but
      // construction itself should not throw.
      final src = BleRssiSource();
      expect(src.current(), isEmpty);
      src.dispose();
    });

    test('current() devuelve snapshot inmutable vacío por default', () {
      final src = BleRssiSource();
      expect(src.current(), isEmpty);
      src.dispose();
    });

    test('updateUserPosition no rompe aunque el scanner ignore la posición',
        () {
      final src = BleRssiSource();
      // Should not throw even though BLE RSSI is independent of position.
      src.updateUserPosition(const Offset(0.7, 0.3));
      src.dispose();
    });

    test('dispose cierra el stream de changes', () async {
      final src = BleRssiSource();
      var done = false;
      // ignore: unawaited_futures
      src.changes.listen((_) {}, onDone: () => done = true);
      await src.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(done, isTrue);
    });
  });
}