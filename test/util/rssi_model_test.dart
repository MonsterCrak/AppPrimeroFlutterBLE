/// Tests for the log-distance path-loss model with Gaussian noise.
library;

import 'dart:math' as math;

import 'package:app_primero_flutter_ble/models/rssi_sample.dart';
import 'package:app_primero_flutter_ble/util/rssi_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('rssiFromDistance', () {
    test('con d=1m y ruido=0, dbm == txPower', () {
      final r = rssiFromDistance(
        distance: 1.0,
        txPower: -59,
        noiseStdDev: 0,
      );
      expect(r, closeTo(-59, 0.0001));
    });

    test('con d=1m y ruido gaussiano, promedio se acerca a txPower', () {
      const n = 2000;
      final rng = math.Random(42);
      double sum = 0;
      for (var i = 0; i < n; i++) {
        sum += rssiFromDistance(
          distance: 1.0,
          txPower: -59,
          noiseStdDev: 2.5,
          random: rng,
        );
      }
      final mean = sum / n;
      // Mean of N(0, 2.5) over 2000 samples is well within ±0.5 of 0.
      expect(mean, closeTo(-59, 0.5));
    });

    test('a mayor distancia, promedio de dbm es menor', () {
      const n = 500;
      double avg(double distance) {
        final rng = math.Random(123);
        double s = 0;
        for (var i = 0; i < n; i++) {
          s += rssiFromDistance(
            distance: distance,
            txPower: -59,
            noiseStdDev: 0.5,
            random: rng,
          );
        }
        return s / n;
      }

      expect(avg(1.0), greaterThan(avg(5.0)));
      expect(avg(5.0), greaterThan(avg(15.0)));
    });

    test('dbm siempre clamped a [minDbm, maxDbm]', () {
      final rng = math.Random(7);
      // Muy cerca
      expect(
        rssiFromDistance(
            distance: 0.001, txPower: -59, noiseStdDev: 100, random: rng),
        lessThanOrEqualTo(RssiSample.maxDbm),
      );
      // Muy lejos
      expect(
        rssiFromDistance(
            distance: 1e6, txPower: -59, noiseStdDev: 100, random: rng),
        greaterThanOrEqualTo(RssiSample.minDbm),
      );
    });

    test('distance=0 no rompe log(0)', () {
      final r = rssiFromDistance(
        distance: 0,
        txPower: -59,
        noiseStdDev: 0,
      );
      expect(r.isFinite, isTrue);
      expect(r, lessThanOrEqualTo(RssiSample.maxDbm));
    });

    test('path loss exponent mayor -> dbm cae mas rapido', () {
      final n2 = rssiFromDistance(
        distance: 10.0,
        txPower: -59,
        pathLossExponent: 2.0,
        noiseStdDev: 0,
      );
      final n3 = rssiFromDistance(
        distance: 10.0,
        txPower: -59,
        pathLossExponent: 3.0,
        noiseStdDev: 0,
      );
      expect(n3, lessThan(n2));
    });

    test('noiseStdDev=0 elimina ruido (resultado determinista)', () {
      final a = rssiFromDistance(
          distance: 3.0, txPower: -59, noiseStdDev: 0);
      final b = rssiFromDistance(
          distance: 3.0, txPower: -59, noiseStdDev: 0);
      expect(a, equals(b));
    });

    test('misma seed produce misma secuencia (determinismo)', () {
      final a1 = rssiFromDistance(
          distance: 2.0, txPower: -59, random: math.Random(99));
      final b1 = rssiFromDistance(
          distance: 2.0, txPower: -59, random: math.Random(99));
      expect(a1, equals(b1));

      // Diferente seed => casi seguro distinto resultado.
      final c1 = rssiFromDistance(
          distance: 2.0, txPower: -59, random: math.Random(100));
      expect(c1, isNot(equals(a1)));
    });

    test('varianza del ruido crece con noiseStdDev', () {
      double variance(double std) {
        const n = 5000;
        final rng = math.Random(2025);
        final samples = <double>[];
        for (var i = 0; i < n; i++) {
          samples.add(rssiFromDistance(
            distance: 1.0,
            txPower: -59,
            noiseStdDev: std,
            random: rng,
          ));
        }
        final mean = samples.reduce((a, b) => a + b) / n;
        final v = samples
                .map((s) => (s - mean) * (s - mean))
                .reduce((a, b) => a + b) /
            n;
        return v;
      }

      final vLow = variance(1.0);
      final vHigh = variance(5.0);
      expect(vHigh, greaterThan(vLow * 5)); // ~25x theoretical
    });
  });

  group('distanceBetween', () {
    test('distancia entre mismo punto es 0', () {
      const p = Offset(0.5, 0.5);
      expect(distanceBetween(p, p), 0);
    });

    test('distancia horizontal pura', () {
      expect(
        distanceBetween(const Offset(0, 0), const Offset(3, 0)),
        closeTo(3, 0.0001),
      );
    });

    test('distancia diagonal (3-4-5)', () {
      expect(
        distanceBetween(const Offset(0, 0), const Offset(3, 4)),
        closeTo(5, 0.0001),
      );
    });

    test('es conmutativa', () {
      const a = Offset(0.1, 0.2);
      const b = Offset(0.7, 0.9);
      expect(distanceBetween(a, b), closeTo(distanceBetween(b, a), 0.0001));
    });
  });
}