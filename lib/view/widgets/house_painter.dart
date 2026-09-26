/// Renders a [HouseMap] (rooms + beacons) to a Canvas in normalized coordinates.
///
/// The painter is **pure**: it only draws, never computes state. It receives
/// everything it needs through the constructor, so it can be reused as a
/// `CustomPainter` without depending on any notifier or provider.
///
/// All coordinates are normalized to [0, 1] and are scaled to the actual
/// canvas size at paint time.
library;

import 'package:flutter/material.dart';

import 'package:app_primero_flutter_ble/models/house_map.dart';

class HousePainter extends CustomPainter {
  final HouseMap houseMap;

  // Visual constants. Kept as fields (not const class) so future theming
  // can pass them in via constructor without breaking the API.
  final Color roomFill;
  final Color roomStroke;
  final Color beaconFill;
  final Color beaconStroke;
  final double roomStrokeWidth;
  final double beaconStrokeWidth;
  final double beaconRadiusFraction; // of the smaller canvas side

  HousePainter({
    required this.houseMap,
    this.roomFill = const Color(0xFFEEEEEE),
    this.roomStroke = const Color(0xFF555555),
    this.beaconFill = const Color(0xFF66BB6A),
    this.beaconStroke = const Color(0xFF1B5E20),
    this.roomStrokeWidth = 1.5,
    this.beaconStrokeWidth = 2.0,
    this.beaconRadiusFraction = 0.025,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    _paintRooms(canvas, w, h);
    _paintBeacons(canvas, w, h);
  }

  void _paintRooms(Canvas canvas, double w, double h) {
    final fill = Paint()..color = roomFill;
    final stroke = Paint()
      ..color = roomStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = roomStrokeWidth;

    for (final room in houseMap.rooms) {
      final rect = Rect.fromLTWH(
        room.left * w,
        room.top * h,
        room.width * w,
        room.height * h,
      );
      canvas.drawRect(rect, fill);
      canvas.drawRect(rect, stroke);
    }
  }

  void _paintBeacons(Canvas canvas, double w, double h) {
    final fill = Paint()..color = beaconFill;
    final stroke = Paint()
      ..color = beaconStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = beaconStrokeWidth;

    final radius = beaconRadiusFraction * (w < h ? w : h);

    for (final beacon in houseMap.beacons) {
      final center = Offset(beacon.position.dx * w, beacon.position.dy * h);
      canvas.drawCircle(center, radius, fill);
      canvas.drawCircle(center, radius, stroke);
    }
  }

  @override
  bool shouldRepaint(HousePainter old) =>
      old.houseMap != houseMap ||
      old.roomFill != roomFill ||
      old.roomStroke != roomStroke ||
      old.beaconFill != beaconFill ||
      old.beaconStroke != beaconStroke;
}