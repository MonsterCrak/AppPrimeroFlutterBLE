/// Abstraction over a source of RSSI readings.
///
/// Implementations:
/// - [SimulatedRssiSource]: pure-math, no permissions, no hardware.
/// - (Fase B) `BleRssiSource`: real BLE scan via `flutter_blue_plus`.
///
/// Consumers pull the latest snapshot via [current] and subscribe to
/// [changes] to know when to refresh.
library;

import 'dart:async';
import 'dart:ui' show Offset;

import 'package:app_primero_flutter_ble/models/rssi_sample.dart';

abstract class RssiSource {
  /// Latest snapshot of all known beacons. Always non-null after
  /// construction. May be empty if no beacons are configured.
  Map<String, RssiSample> current();

  /// Emits whenever a new snapshot is available. Broadcast stream.
  Stream<void> get changes;

  /// Notifies the source of the current user position. Implementations
  /// should recompute and push a new snapshot via [changes].
  void updateUserPosition(Offset position);

  /// Stops emitting and releases resources.
  Future<void> dispose();
}