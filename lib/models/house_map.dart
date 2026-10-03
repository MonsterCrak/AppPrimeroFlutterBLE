/// A simple house layout with rooms and a fixed set of beacons.
///
/// All rooms and beacons are described in normalized coordinates [0,1] so
/// the painter can map them to any canvas size.
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'beacon.dart';
import 'house_layout.dart';

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

  /// Architectural details (walls, doors, labels, excluded zones).
  /// Defaults to empty for legacy callers; `miCasa()` populates it.
  final HouseLayout layout;

  /// Real-world dimensions of the map in meters.
  ///
  /// When set, [roomScale] exposes the conversion factor from meters to
  /// normalized units (so 1 m of real space maps to `roomScale` normalized
  /// units). When null, the map is treated as dimensionless (legacy maps
  /// used by the simulated source only).
  final Size? realDimensions;

  const HouseMap({
    required this.name,
    required this.bounds,
    required this.rooms,
    required this.beacons,
    this.layout = const HouseLayout(),
    this.realDimensions,
  });

  /// Conversion factor from meters to normalized units for this map.
  ///
  /// Defined as `1.0 / max(width, height)` so the longest side of the real
  /// room always maps to 1.0 in normalized space, keeping aspect ratio.
  /// Returns 1.0 for maps without [realDimensions] (legacy / simulated only).
  double get roomScale => realDimensions == null
      ? 1.0
      : 1.0 / math.max(realDimensions!.width, realDimensions!.height);

  /// Returns a copy of this map with the given fields replaced.
  HouseMap copyWith({
    String? name,
    Rect? bounds,
    List<Rect>? rooms,
    List<Beacon>? beacons,
    HouseLayout? layout,
    Size? realDimensions,
  }) {
    return HouseMap(
      name: name ?? this.name,
      bounds: bounds ?? this.bounds,
      rooms: rooms ?? this.rooms,
      beacons: beacons ?? this.beacons,
      layout: layout ?? this.layout,
      realDimensions: realDimensions ?? this.realDimensions,
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
      layout: HouseLayout.miCasaFromSvg(),
    );
  }

  /// Etapa 1 room for the physical practice beacon.
  ///
  /// Single rectangular room (`Cuarto 1`) measuring **3 m × 2.6 m × 2.6 m**
  /// (height is unused for 2D positioning). One beacon is placed in the
  /// upper-right corner, slightly inset so it remains visible inside the
  /// bounds.
  ///
  /// Bounds use normalized [0, 1] coordinates with the longest side mapped
  /// to 1.0 (so `width=1.0`, `height=2.6/3 ≈ 0.8667`). This preserves the
  /// real aspect ratio of the room. See [roomScale] for the meters →
  /// normalized conversion.
  factory HouseMap.cuartoPracticaUno() {
    return const HouseMap(
      name: 'CuartoPractica1',
      bounds: Rect.fromLTWH(0, 0, 1, 2.6 / 3),
      rooms: [
        Rect.fromLTWH(0, 0, 1, 2.6 / 3),
      ],
      beacons: [
        Beacon(
          id: 'B1',
          label: 'Cuarto1',
          position: Offset(0.95, 0.05),
          txPower: -59,
        ),
      ],
      // Labels clarifican el diagrama: el nombre del cuarto y el id de
      // la baliza. No hay paredes/puertas/zonas excluidas porque Cuarto 1
      // es un cuarto único y simple.
      layout: HouseLayout(
        labels: [
          RoomLabel(
            text: 'Cuarto 1',
            position: Offset(0.5, 0.3),
            fontFraction: 0.04,
          ),
          RoomLabel(
            text: 'B1',
            position: Offset(0.92, 0.13),
            fontFraction: 0.025,
          ),
        ],
      ),
      realDimensions: Size(3.0, 2.6),
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
          listEquals(beacons, other.beacons) &&
          realDimensions == other.realDimensions;

  @override
  int get hashCode => Object.hash(
        name,
        bounds,
        Object.hashAll(rooms),
        Object.hashAll(beacons),
        realDimensions,
      );

  @override
  String toString() =>
      'HouseMap(name: $name, rooms: ${rooms.length}, beacons: ${beacons.length})';
}