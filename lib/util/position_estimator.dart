/// Pure functions to estimate the user's position from RSSI readings.
///
/// Side-effect free: depends only on `dart:math` and `dart:ui`. Used by
/// [SimulationNotifier] when the active [RssiSource] is a real BLE source —
/// the BLE driver decides RSSI, and we back out the position geometrically.
library;

import 'dart:ui' show Offset, Rect;

/// Estimates the user's position from a single beacon's distance reading.
///
/// With only 1 beacon we know the distance to it but not the direction.
/// The function places the user on the circle of radius [distanceMeters]
/// around [beaconPositionNormalized], picking the point that is closest
/// to [lastKnownPositionNormalized] so the visualization animates smoothly
/// as the user moves around the room.
///
/// If [lastKnownPositionNormalized] is effectively on top of the beacon
/// (distance < 1e-6 normalized units), the default direction is `Offset(0, 1)`
/// (toward the bottom of the map) so we still produce a deterministic point.
///
/// [roomScale] is normalized units per meter (see [HouseMap.roomScale]).
/// All positions are in normalized [0, 1] coordinates.
///
/// The result is clamped to [roomBoundsNormalized] so the dot never
/// escapes the room visually.
Offset estimatePositionFromSingleBeacon({
  required Offset beaconPositionNormalized,
  required double distanceMeters,
  required double roomScale,
  required Offset lastKnownPositionNormalized,
  required Rect roomBoundsNormalized,
}) {
  final distanceNormalized = distanceMeters * roomScale;

  // Direction from beacon toward last known position. If we have no usable
  // last position (e.g. first reading right on top of the beacon), default
  // to "down" so the dot starts somewhere visible inside the room.
  final delta = lastKnownPositionNormalized - beaconPositionNormalized;
  final direction = delta.distance > 1e-6
      ? delta / delta.distance
      : const Offset(0, 1);

  final newPos = beaconPositionNormalized + direction * distanceNormalized;

  // Clamp to room bounds so the dot doesn't escape the walls.
  return Offset(
    newPos.dx.clamp(roomBoundsNormalized.left, roomBoundsNormalized.right),
    newPos.dy.clamp(roomBoundsNormalized.top, roomBoundsNormalized.bottom),
  );
}
