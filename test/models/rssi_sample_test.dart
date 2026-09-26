import 'package:app_primero_flutter_ble/models/rssi_sample.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RssiSample', () {
    group('constructor', () {
      test('dbm fuera de [-100, -30] lanza assert', () {
        expect(
          () => RssiSample(
            beaconId: 'B1',
            dbm: -200,
            distance: 1.0,
          ),
          throwsA(isA<AssertionError>()),
        );
        expect(
          () => RssiSample(
            beaconId: 'B1',
            dbm: 0,
            distance: 1.0,
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('distance negativo lanza assert', () {
        expect(
          () => RssiSample(
            beaconId: 'B1',
            dbm: -60,
            distance: -0.5,
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('equality + hashCode consistentes', () {
        const a = RssiSample(beaconId: 'B1', dbm: -60, distance: 2.0);
        const b = RssiSample(beaconId: 'B1', dbm: -60, distance: 2.0);
        const c = RssiSample(beaconId: 'B1', dbm: -61, distance: 2.0);
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
        expect(a, isNot(equals(c)));
      });
    });

    group('fromDistance', () {
      test('con d=1m, sin ruido, dbm == txPower', () {
        final s = RssiSample.fromDistance(
          beaconId: 'B1',
          distance: 1.0,
          txPower: -59,
        );
        expect(s.dbm, closeTo(-59, 0.0001));
        expect(s.distance, 1.0);
        expect(s.beaconId, 'B1');
      });

      test('a mayor distancia, dbm es menor (log-distance)', () {
        final near =
            RssiSample.fromDistance(beaconId: 'B1', distance: 1.0, txPower: -59);
        final mid = RssiSample.fromDistance(
            beaconId: 'B1', distance: 5.0, txPower: -59);
        final far =
            RssiSample.fromDistance(beaconId: 'B1', distance: 10.0, txPower: -59);
        expect(near.dbm, greaterThan(mid.dbm));
        expect(mid.dbm, greaterThan(far.dbm));
      });

      test('dbm siempre clamped a [-100, -30]', () {
        final s1 = RssiSample.fromDistance(
            beaconId: 'B1', distance: 0.001, txPower: -59); // muy cerca
        final s2 = RssiSample.fromDistance(
            beaconId: 'B1', distance: 1e6, txPower: -59); // muy lejos
        expect(s1.dbm, lessThanOrEqualTo(RssiSample.maxDbm));
        expect(s1.dbm, greaterThanOrEqualTo(RssiSample.minDbm));
        expect(s2.dbm, greaterThanOrEqualTo(RssiSample.minDbm));
        expect(s2.dbm, lessThanOrEqualTo(RssiSample.maxDbm));
      });

      test('distance=0 no rompe log() (floor a 0.01)', () {
        final s = RssiSample.fromDistance(
          beaconId: 'B1',
          distance: 0,
          txPower: -59,
        );
        expect(s.dbm.isFinite, isTrue);
        expect(s.distance, 0);
      });

      test('path loss exponent mayor -> caída más rápida con distancia', () {
        final n2 = RssiSample.fromDistance(
          beaconId: 'B1',
          distance: 10.0,
          txPower: -59,
          pathLossExponent: 2.0,
        );
        final n3 = RssiSample.fromDistance(
          beaconId: 'B1',
          distance: 10.0,
          txPower: -59,
          pathLossExponent: 3.0,
        );
        expect(n3.dbm, lessThan(n2.dbm));
      });
    });
  });
}