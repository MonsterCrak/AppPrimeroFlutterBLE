/// A simple house layout with rooms and a fixed set of beacons.
///
/// All rooms and beacons are described in normalized coordinates [0,1] so
/// the painter can map them to any canvas size.
library;

import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'beacon.dart';

@immutable
class HouseMap {
  /// Friendly name (e.g. "CasaDemo").
  final String name;

  /// Bounding rectangle of the whole house in normalized coords. Always
  /// Rect.fromLTWH(0, 0, 1, 1) for the demo, kept explicit for future maps.
  final Rect bounds;

  /// Rooms drawn as filled rectangles (background) before beacons are drawn.
  final List<Rect> rooms;

  /// Static beacons placed in this house.
  final List<Beacon> beacons;

  const HouseMap({
    required this.name,
    required this.bounds,
    required this.rooms,
    required this.beacons,
  });

  /// Demo house: 3 rooms (sala, pasillo, habitacion) with 4 beacons at the
  /// corners/walls. Coordinates are normalized to [0, 1].
  factory HouseMap.casaDemo() {
    return const HouseMap(
      name: 'CasaDemo',
      bounds: Rect.fromLTWH(0, 0, 1, 1),
      rooms: [
        // Sala (large, top-left)
        Rect.fromLTWH(0.05, 0.05, 0.50, 0.40),
        // Pasillo (horizontal corridor, middle)
        Rect.fromLTWH(0.05, 0.50, 0.90, 0.20),
        // Habitacion (bottom-right)
        Rect.fromLTWH(0.55, 0.75, 0.40, 0.20),
      ],
      beacons: [
        Beacon(
          id: 'B1',
          label: 'Sala-A',
          position: Offset(0.15, 0.20),
          txPower: -59,
        ),
        Beacon(
          id: 'B2',
          label: 'Sala-B',
          position: Offset(0.85, 0.20),
          txPower: -59,
        ),
        Beacon(
          id: 'B3',
          label: 'Pasillo',
          position: Offset(0.50, 0.55),
          txPower: -59,
        ),
        Beacon(
          id: 'B4',
          label: 'Habitacion',
          position: Offset(0.80, 0.85),
          txPower: -59,
        ),
      ],
    );
  }

  /// Looks up a beacon by its ID. Returns null if not found.
  Beacon? beaconById(String id) {
    for (final b in beacons) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// Whether the given point is inside the house bounds.
  bool containsPoint(Offset point) => bounds.contains(point);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HouseMap &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          bounds == other.bounds &&
          listEquals(rooms, other.rooms) &&
          listEquals(beacons, other.beacons);

  @override
  int get hashCode => Object.hash(
        name,
        bounds,
        Object.hashAll(rooms),
        Object.hashAll(beacons),
      );

  @override
  String toString() =>
      'HouseMap(name: $name, rooms: ${rooms.length}, beacons: ${beacons.length})';
}