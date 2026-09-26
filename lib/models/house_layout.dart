/// Architectural details of a house: walls, doors, room labels and
/// excluded zones. Drawn on top of [HouseMap.rooms] by [HousePainter] to
/// make the canvas look like the original SVG floorplan.
///
/// All coordinates are normalized [0, 1] (same space as [Beacon.position]).
library;

import 'dart:ui' show Offset, Rect;

import 'package:flutter/foundation.dart';

/// A straight wall segment. Rendered as a line with given width.
@immutable
class WallSegment {
  /// Start point in normalized coords.
  final Offset from;

  /// End point in normalized coords.
  final Offset to;

  /// Visual thickness as a fraction of the canvas side (e.g. 0.005 ≈ 5px in
  /// a 1000px canvas). Defaults to a sensible value.
  final double thickness;

  const WallSegment({
    required this.from,
    required this.to,
    this.thickness = 0.005,
  });
}

/// A door: a gap in a wall plus the swing arc. The gap is computed as a
/// rectangle subtracted from the wall; we render a small arc to suggest
/// the door swing direction.
@immutable
class DoorSegment {
  /// Center of the door on the wall (normalized).
  final Offset center;

  /// Width of the gap in normalized coords.
  final double width;

  /// Whether the door swings inward to the room on the positive side of
  /// the wall (true) or the negative side (false). Currently visual-only.
  final bool swingsPositive;

  const DoorSegment({
    required this.center,
    this.width = 0.04,
    this.swingsPositive = true,
  });
}

/// A text label drawn at a position inside (or above) a room.
@immutable
class RoomLabel {
  final String text;
  final Offset position;
  final double fontFraction; // of canvas height (e.g. 0.018 ≈ 18px in 1000)

  const RoomLabel({
    required this.text,
    required this.position,
    this.fontFraction = 0.018,
  });
}

/// A non-walkable zone (e.g. stairs, a void, machinery). Rendered as a
/// hatched pattern that crosses the rect diagonally.
@immutable
class ExcludedZone {
  final Rect rect;
  final String? label;

  const ExcludedZone({required this.rect, this.label});
}

/// All architectural overlays for a house. Empty by default.
@immutable
class HouseLayout {
  final List<WallSegment> walls;
  final List<DoorSegment> doors;
  final List<RoomLabel> labels;
  final List<ExcludedZone> excludedZones;

  const HouseLayout({
    this.walls = const [],
    this.doors = const [],
    this.labels = const [],
    this.excludedZones = const [],
  });

  /// Returns true if there's nothing to draw.
  bool get isEmpty =>
      walls.isEmpty && doors.isEmpty && labels.isEmpty && excludedZones.isEmpty;

  /// Layout that mirrors `E:\Obsidian\Tesis\Emulador BLE Indoor\
  /// Distribución casa.md` (the user's SVG floorplan, viewBox 450×850).
  ///
  /// Coordinates converted to normalized [0, 1] (x/450, y/850).
  factory HouseLayout.miCasaFromSvg() {
    const w = 450.0;
    const h = 850.0;
    Offset n(double x, double y) => Offset(x / w, y / h);

    return HouseLayout(
      walls: [
        // Pasadizo exterior (muro izquierdo del pasadizo).
        WallSegment(from: n(100, 50), to: n(100, 650)),

        // Perímetro exterior.
        const WallSegment(from: Offset(160 / w, 50 / h), to: Offset(400 / w, 50 / h)), // top
        const WallSegment(from: Offset(400 / w, 50 / h), to: Offset(400 / w, 780 / h)), // right
        const WallSegment(from: Offset(20 / w, 780 / h), to: Offset(400 / w, 780 / h)), // bottom

        // Cuarto hermano (esquina inferior izquierda).
        const WallSegment(from: Offset(20 / w, 780 / h), to: Offset(20 / w, 650 / h)), // left
        const WallSegment(from: Offset(20 / w, 650 / h), to: Offset(100 / w, 650 / h)), // top

        // Muro interno derecho del pasadizo (con huecos para puertas).
        const WallSegment(from: Offset(180 / w, 50 / h), to: Offset(180 / w, 300 / h)),
        const WallSegment(from: Offset(180 / w, 340 / h), to: Offset(180 / w, 420 / h)),
        const WallSegment(from: Offset(180 / w, 460 / h), to: Offset(180 / w, 650 / h)),

        // Divisiones horizontales.
        const WallSegment(from: Offset(180 / w, 300 / h), to: Offset(400 / w, 300 / h)), // Sala - Cocina
        const WallSegment(from: Offset(180 / w, 420 / h), to: Offset(400 / w, 420 / h)), // Cocina - Mi cuarto
        const WallSegment(from: Offset(180 / w, 500 / h), to: Offset(400 / w, 500 / h)), // Mi cuarto - Baño
        const WallSegment(from: Offset(180 / w, 650 / h), to: Offset(400 / w, 650 / h)), // Baño/Lav - Padres

        // Divisiones de cuartos inferiores.
        const WallSegment(from: Offset(140 / w, 780 / h), to: Offset(140 / w, 680 / h)),
        const WallSegment(from: Offset(110 / w, 680 / h), to: Offset(170 / w, 680 / h)),
      ],
      doors: [
        // Puerta principal (entrada al pasadizo, esquina superior izq).
        const DoorSegment(center: Offset(120 / w, 65 / h), width: 0.07),
        // Puerta entre Cocina y Mi cuarto.
        const DoorSegment(center: Offset(195 / w, 320 / h), width: 0.06),
        // Puerta entre Mi cuarto y Baño.
        const DoorSegment(center: Offset(195 / w, 440 / h), width: 0.06),
      ],
      labels: [
        const RoomLabel(text: 'Sala', position: Offset(290 / w, 140 / h)),
        const RoomLabel(text: 'Cocina', position: Offset(290 / w, 240 / h)),
        const RoomLabel(text: 'Mi cuarto', position: Offset(290 / w, 365 / h)),
        const RoomLabel(text: 'Baño', position: Offset(240 / w, 465 / h)),
        const RoomLabel(text: 'Pasadizo', position: Offset(140 / w, 350 / h)),
        const RoomLabel(text: 'Hermano', position: Offset(80 / w, 740 / h)),
        const RoomLabel(text: 'Padres', position: Offset(270 / w, 740 / h)),
        // Etiquetas de baliza (verde).
        const RoomLabel(text: 'B1', position: Offset(280 / w, 60 / h), fontFraction: 0.022),
        const RoomLabel(text: 'B2', position: Offset(140 / w, 380 / h), fontFraction: 0.022),
        const RoomLabel(text: 'B3', position: Offset(270 / w, 680 / h), fontFraction: 0.022),
      ],
      excludedZones: [
        // Lavandería (lateral derecho entre y=500 y y=650).
        const ExcludedZone(
          rect: Rect.fromLTWH(290 / w, 500 / h, 110 / w, 150 / h),
          label: 'Lavandería',
        ),
      ],
    );
  }
}