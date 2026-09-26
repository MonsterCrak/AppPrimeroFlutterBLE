/// Static BLE beacon with fixed position and transmission power.
///
/// All fields are final; instances are immutable. Two beacons with the same
/// field values are considered equal.
///
/// Coordinates are in normalized space [0, 1] x [0, 1] so they map cleanly to
/// any canvas size at paint time. txPower is the calibrated RSSI at 1m in dBm
/// (typical value for the Dialog DA14531 / Feasycom FSC-BP104D is -59 dBm).
library;

import 'dart:ui';

class Beacon {
  /// Stable identifier (e.g. "B1"). Used as key in maps and stream payloads.
  final String id;

  /// Human-friendly label (e.g. "Sala-A"). For UI only.
  final String label;

  /// Position in normalized space [0, 1] x [0, 1].
  final Offset position;

  /// Calibrated RSSI at 1m in dBm.
  final double txPower;

  const Beacon({
    required this.id,
    required this.label,
    required this.position,
    required this.txPower,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Beacon &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          label == other.label &&
          position == other.position &&
          txPower == other.txPower;

  @override
  int get hashCode => Object.hash(id, label, position, txPower);

  @override
  String toString() =>
      'Beacon(id: $id, label: $label, position: $position, txPower: $txPower)';
}