/// RSSI source backed by the log-distance path-loss model.
///
/// Pure-math, no permissions, no hardware. Pass a seeded [Random] for
/// deterministic demos/tests.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:app_primero_flutter_ble/models/beacon.dart';
import 'package:app_primero_flutter_ble/models/rssi_sample.dart';
import 'package:app_primero_flutter_ble/sources/rssi_source.dart';
import 'package:app_primero_flutter_ble/util/rssi_model.dart';

class SimulatedRssiSource implements RssiSource {
  final List<Beacon> beacons;
  final double pathLossExponent;
  final double noiseStdDev;
  final math.Random _rng;

  Offset _userPosition = const Offset(0.5, 0.5);
  Map<String, RssiSample> _snapshot = const <String, RssiSample>{};
  final StreamController<void> _controller = StreamController<void>.broadcast();

  SimulatedRssiSource({
    required this.beacons,
    this.pathLossExponent = 2.0,
    this.noiseStdDev = 2.5,
    math.Random? random,
  }) : _rng = random ?? math.Random() {
    _recomputeAndEmit();
  }

  @override
  Map<String, RssiSample> current() => _snapshot;

  @override
  Stream<void> get changes => _controller.stream;

  @override
  void updateUserPosition(Offset position) {
    _userPosition = position;
    _recomputeAndEmit();
  }

  void _recomputeAndEmit() {
    _snapshot = _compute();
    if (!_controller.isClosed) {
      _controller.add(null);
    }
  }

  Map<String, RssiSample> _compute() {
    final out = <String, RssiSample>{};
    for (final beacon in beacons) {
      final distance = distanceBetween(_userPosition, beacon.position);
      final dbm = rssiFromDistance(
        distance: distance,
        txPower: beacon.txPower,
        pathLossExponent: pathLossExponent,
        noiseStdDev: noiseStdDev,
        random: _rng,
      );
      out[beacon.id] = RssiSample(
        beaconId: beacon.id,
        dbm: dbm,
        distance: distance,
      );
    }
    return out;
  }

  @override
  Future<void> dispose() async {
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}