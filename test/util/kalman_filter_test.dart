/// Tests for [KalmanFilter1D] — focused on convergence and noise rejection.
///
/// The Kalman filter is a deterministic algorithm given fixed inputs, so
/// these tests use exact expected values within numerical tolerance.
library;

import 'package:app_primero_flutter_ble/util/kalman_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KalmanFilter1D — initialization', () {
    test('first measurement initializes filter to that value', () {
      final f = KalmanFilter1D();
      expect(f.isInitialized, isFalse);
      expect(f.update(-60), -60);
      expect(f.isInitialized, isTrue);
      expect(f.value, -60);
    });

    test('reset clears state', () {
      final f = KalmanFilter1D();
      f.update(-60);
      f.update(-61);
      f.reset();
      expect(f.isInitialized, isFalse);
      // Next update re-initializes.
      expect(f.update(-50), -50);
    });

    test('value getter returns 0 before initialization (documented behavior)',
        () {
      final f = KalmanFilter1D();
      expect(f.value, 0);
    });
  });

  group('KalmanFilter1D — convergence', () {
    test('converges to constant value with consistent measurements', () {
      final f = KalmanFilter1D();
      double last = 0;
      for (var i = 0; i < 30; i++) {
        last = f.update(-70);
      }
      // After enough identical measurements, the output equals the input.
      expect(last, closeTo(-70, 1e-6));
    });

    test('tracks step changes after enough samples', () {
      final f = KalmanFilter1D(q: 2.0, r: 16.0);
      // Stabilize at -60.
      for (var i = 0; i < 30; i++) {
        f.update(-60);
      }
      // Step to -80 and feed many samples.
      double last = 0;
      for (var i = 0; i < 50; i++) {
        last = f.update(-80);
      }
      // Filter should converge to -80 within numerical tolerance.
      expect(last, closeTo(-80, 0.5));
    });

    test('smooths noisy measurements toward true value', () {
      final f = KalmanFilter1D(q: 2.0, r: 16.0);
      // True value: -60. Noisy samples with one extreme outlier (-90).
      final noisy = <double>[-58, -65, -55, -90, -62, -58, -64, -60, -59, -61];
      double lastSmoothed = 0;
      for (final z in noisy) {
        lastSmoothed = f.update(z);
      }
      // The outlier should be down-weighted — the filter output should
      // be much closer to the cluster around -60 than to -90.
      // (Filter output is pulled slightly toward the noisy mean, not the outlier.)
      expect(lastSmoothed, greaterThan(-70));
      expect(lastSmoothed, lessThan(-55));
    });
  });

  group('KalmanFilter1D — parameter sensitivity', () {
    test('high r produces more smoothing (slower response)', () {
      final highR = KalmanFilter1D(q: 2.0, r: 100.0);
      final lowR = KalmanFilter1D(q: 2.0, r: 1.0);

      // Initialize both at -60.
      highR.update(-60);
      lowR.update(-60);

      // Single big step to -80.
      final highROut = highR.update(-80);
      final lowROut = lowR.update(-80);

      // Low r trusts the outlier more, so it should be closer to -80.
      expect(lowROut, lessThan(highROut));
      // High r smooths more, so it should be closer to -60.
      expect(highROut, greaterThan(lowROut));
    });

    test('high q produces less smoothing (faster response)', () {
      final highQ = KalmanFilter1D(q: 20.0, r: 16.0);
      final lowQ = KalmanFilter1D(q: 0.5, r: 16.0);

      // Stabilize to -60.
      for (var i = 0; i < 30; i++) {
        highQ.update(-60);
        lowQ.update(-60);
      }

      // Single big step to -80.
      final highQStep = highQ.update(-80);
      final lowQStep = lowQ.update(-80);

      // High q trusts measurements more, so it should be closer to -80.
      expect(highQStep, lessThan(lowQStep));
    });
  });

  group('KalmanFilter1D — use case: RSSI smoothing', () {
    test('realistic scenario: noisy RSSI from a stationary beacon', () {
      // RSSI from a stationary beacon typically fluctuates ±3-5 dBm.
      // Simulate 30 samples around true value -65 dBm.
      final noisyRssi = <double>[
        -67, -63, -65, -68, -62, -66, -64, -65, -67, -63,
        -66, -64, -68, -62, -65, -64, -66, -63, -67, -65,
        -64, -66, -63, -67, -65, -64, -66, -63, -65, -67,
      ];
      final filter = KalmanFilter1D(q: 1.0, r: 16.0);

      // Skip warmup (first 10 samples), measure stability after.
      for (var i = 0; i < 10; i++) {
        filter.update(noisyRssi[i]);
      }
      final stabilized = <double>[];
      for (var i = 10; i < noisyRssi.length; i++) {
        stabilized.add(filter.update(noisyRssi[i]));
      }

      // After stabilization, output should be near -65 and have lower
      // variance than raw input.
      final rawAfterWarmup = noisyRssi.sublist(10);
      final rawMean = rawAfterWarmup.reduce((a, b) => a + b) / rawAfterWarmup.length;
      final stabilizedMean = stabilized.reduce((a, b) => a + b) / stabilized.length;

      // Means should be similar (we don't bias the estimate).
      expect((stabilizedMean - rawMean).abs(), lessThan(1.5));

      // Variance: smoothed should have lower variance than raw.
      double variance(List<double> xs, double mean) {
        return xs.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) /
            xs.length;
      }
      final rawVar = variance(rawAfterWarmup, rawMean);
      final smoothedVar = variance(stabilized, stabilizedMean);
      expect(smoothedVar, lessThan(rawVar));
    });
  });
}