/// Pure functions implementing the log-distance path-loss model with
/// Gaussian noise.
///
/// This module is intentionally side-effect free: it only depends on
/// `dart:math` and `dart:ui`. It can be used by any RSSI source (simulated,
/// real, or custom) to compute a noisy RSSI reading from a Euclidean
/// distance.
library;

import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:app_primero_flutter_ble/models/rssi_sample.dart';

/// Computes a noisy RSSI reading using the log-distance path-loss model.
///
///   rssi(d) = txPower - 10 * n * log10(d/d0) + X_sigma
///
/// where `X_sigma` is Gaussian noise with mean 0 and stddev [noiseStdDev].
/// `d0` is fixed at 1 m (reference distance).
///
/// Pass a seeded [Random] for deterministic results (useful for tests and
/// reproducible demos). If [random] is null, a fresh `Random()` is created.
///
/// The returned value is clamped to `[RssiSample.minDbm, RssiSample.maxDbm]`.
///
/// [distance] is floored at 0.01 m to avoid log(0).
double rssiFromDistance({
  required double distance,
  required double txPower,
  double pathLossExponent = 2.0,
  double noiseStdDev = 2.5,
  math.Random? random,
}) {
  final rng = random ?? math.Random();
  final d = math.max(distance, 0.01);
  final clean = txPower - 10 * pathLossExponent * math.log(d) / math.ln10;
  final noise = noiseStdDev <= 0 ? 0.0 : _gaussian(rng) * noiseStdDev;
  final raw = clean + noise;
  return raw.clamp(RssiSample.minDbm, RssiSample.maxDbm);
}

/// Box–Muller transform: returns a standard normal sample (mean 0, stddev 1).
double _gaussian(math.Random rng) {
  // Avoid u1 == 0 (log(0) blow-up).
  double u1;
  do {
    u1 = rng.nextDouble();
  } while (u1 < 1e-12);
  final u2 = rng.nextDouble();
  return math.sqrt(-2.0 * math.log(u1)) * math.cos(2.0 * math.pi * u2);
}

/// Euclidean distance between two normalized points.
double distanceBetween(Offset a, Offset b) {
  final dx = a.dx - b.dx;
  final dy = a.dy - b.dy;
  return math.sqrt(dx * dx + dy * dy);
}