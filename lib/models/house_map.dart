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

  /// Returns a copy of this map with the given fields replaced.
  HouseMap copyWith({
    String? name,
    Rect? bounds,
    List<Rect>? rooms,
    List<Beacon>? beacons,
  }) {
    return HouseMap(
      name: name ?? this.name,
      bounds: bounds ?? this.bounds,
      rooms: rooms ?? this.rooms,
      beacons: beacons ?? this.beacons,
    );
  }

  /// Demo house: 3 rooms (sala, pasillo, habitacion) with 3 beacons — one
  /// per zone. Coordinates are normalized to [0, 1].
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
          label: 'Pasillo',
          position: Offset(0.50, 0.55),
          txPower: -59,
        ),
        Beacon(
          id: 'B3',
          label: 'Habitacion',
          position: Offset(0.80, 0.85),
          txPower: -59,
        ),
      ],
    );
  }

  /// Real house layout, derived from the user's SVG floorplan
  /// (viewBox 450 x 850, see `E:\Obsidian\Tesis\Emulador BLE Indoor\
  /// Distribución casa.md`).
  ///
  /// Coords normalized from SVG: (x_svg / 450, y_svg / 850).
  factory HouseMap.miCasa() {
    return HouseMap(
      name: 'MiCasa',
      bounds: Rect.fromLTWH(0, 0, 1, 1),
      rooms: const [
        // Pasadizo (eje vertical central): SVG x=100..180, y=50..650
        Rect.fromLTWH(0.222, 0.059, 0.178, 0.706),
        // Sala (norte, derecha): SVG x=180..400, y=50..300
        Rect.fromLTWH(0.400, 0.059, 0.489, 0.294),
        // Cocina: SVG x=180..400, y=300..420
        Rect.fromLTWH(0.400, 0.353, 0.489, 0.141),
        // Mi cuarto: SVG x=180..400, y=420..500
        Rect.fromLTWH(0.400, 0.494, 0.489, 0.094),
        // Baño (mitad izquierda del bloque inferior): SVG x=180..290, y=500..650
        Rect.fromLTWH(0.400, 0.588, 0.244, 0.176),
        // Lavandería (mitad derecha del bloque inferior): SVG x=290..400, y=500..650
        // Marcada como zona excluida (no se transita).
        Rect.fromLTWH(0.644, 0.588, 0.244, 0.176),
        // Cuarto hermano (esquina inferior izquierda): SVG x=20..100, y=650..780
        Rect.fromLTWH(0.044, 0.765, 0.178, 0.153),
        // Cuarto Padres (esquina inferior derecha): SVG x=140..400, y=680..780
        Rect.fromLTWH(0.311, 0.800, 0.578, 0.118),
      ],
      beacons: const [],
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