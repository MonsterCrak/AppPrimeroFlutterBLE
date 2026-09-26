/// Single RSSI reading for a beacon at a given moment.
///
/// `dbm` is always clamped to [-100, -30] dBm to reflect physical reality.
/// `distance` is the Euclidean distance from the user to the beacon, in
/// meters, in the same normalized coordinate space as [Beacon.position]
/// (i.e. it is NOT in meters of real space — it is the raw distance in
/// the normalized plane, which the caller scales to real units if needed).
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

@immutable
class RssiSample {
  /// ID of the beacon this sample belongs to.
  final String beaconId;

  /// Received signal strength in dBm. Always clamped to [-100, -30].
  final double dbm;

  /// Distance from the user position to the beacon (in normalized units).
  final double distance;

  /// Minimum and maximum allowed dBm.
  static const double minDbm = -100.0;
  static const double maxDbm = -30.0;

  const RssiSample({
    required this.beaconId,
    required this.dbm,
    required this.distance,
  })  : assert(dbm >= minDbm && dbm <= maxDbm,
            'dbm must be clamped to [$minDbm, $maxDbm]'),
        assert(distance >= 0, 'distance must be >= 0');

  /// Builds a deterministic sample from a Euclidean distance.
  ///
  /// Uses the log-distance path loss model WITHOUT noise:
  ///   rssi(d) = txPower - 10 * n * log10(d)
  ///
  /// Noise injection lives in `lib/util/rssi_model.dart` (added in WU-4),
  /// which the simulated source will use instead of this factory.
  ///
  /// `distance` is floored at 0.01 m to avoid log(0).
  factory RssiSample.fromDistance({
    required String beaconId,
    required double distance,
    required double txPower,
    double pathLossExponent = 2.0,
  }) {
    final d = math.max(distance, 0.01);
    final raw = txPower - 10 * pathLossExponent * math.log(d) / math.ln10;
    final clamped = raw.clamp(minDbm, maxDbm);
    return RssiSample(
      beaconId: beaconId,
      dbm: clamped,
      distance: distance,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RssiSample &&
          runtimeType == other.runtimeType &&
          beaconId == other.beaconId &&
          dbm == other.dbm &&
          distance == other.distance;

  @override
  int get hashCode => Object.hash(beaconId, dbm, distance);

  @override
  String toString() =>
      'RssiSample(beaconId: $beaconId, dbm: ${dbm.toStringAsFixed(1)}, '
      'distance: ${distance.toStringAsFixed(3)})';
}