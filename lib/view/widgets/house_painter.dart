/// Renders a [HouseMap] (rooms + beacons) plus optional user position and
/// planned route to a Canvas in normalized coordinates.
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

  // User and route are optional; both default to "not drawn".
  final Offset? userPosition;
  final List<Offset> route;

  // Colors and sizes — overridable for theming / tests.
  final Color roomFill;
  final Color roomStroke;
  final Color beaconFill;
  final Color beaconStroke;
  final Color userFill;
  final Color userStroke;
  final Color routeStroke;
  final double roomStrokeWidth;
  final double beaconStrokeWidth;
  final double userStrokeWidth;
  final double routeStrokeWidth;
  final double beaconRadiusFraction; // of smaller canvas side
  final double userRadiusFraction;

  HousePainter({
    required this.houseMap,
    this.userPosition,
    this.route = const [],
    this.roomFill = const Color(0xFFEEEEEE),
    this.roomStroke = const Color(0xFF555555),
    this.beaconFill = const Color(0xFF66BB6A),
    this.beaconStroke = const Color(0xFF1B5E20),
    this.userFill = const Color(0xFF2196F3),
    this.userStroke = const Color(0xFF0D47A1),
    this.routeStroke = const Color(0xFF9E9E9E),
    this.roomStrokeWidth = 1.5,
    this.beaconStrokeWidth = 2.0,
    this.userStrokeWidth = 2.0,
    this.routeStrokeWidth = 1.2,
    this.beaconRadiusFraction = 0.025,
    this.userRadiusFraction = 0.04,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    _paintRoute(canvas, w, h);
    _paintRooms(canvas, w, h);
    _paintBeacons(canvas, w, h);
    _paintUser(canvas, w, h);
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

  void _paintRoute(Canvas canvas, double w, double h) {
    if (route.length < 2) return;
    final paint = Paint()
      ..color = routeStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = routeStrokeWidth
      ..strokeCap = StrokeCap.round;

    // Dashed path: build by drawing short segments separated by gaps.
    final dashLen = w * 0.02;
    final gapLen = w * 0.015;
    final points = route
        .map((p) => Offset(p.dx * w, p.dy * h))
        .toList(growable: false);
    for (var i = 0; i < points.length - 1; i++) {
      _drawDashedSegment(canvas, points[i], points[i + 1], dashLen, gapLen,
          paint);
    }
    // Close the loop if there are >=3 waypoints.
    if (points.length >= 3) {
      _drawDashedSegment(canvas, points.last, points.first, dashLen, gapLen,
          paint);
    }
  }

  void _drawDashedSegment(Canvas canvas, Offset from, Offset to,
      double dashLen, double gapLen, Paint paint) {
    final total = (to - from).distance;
    if (total == 0) return;
    final dir = (to - from) / total;
    double traveled = 0;
    while (traveled < total) {
      final segEnd = (traveled + dashLen).clamp(0, total).toDouble();
      canvas.drawLine(
        from + dir * traveled,
        from + dir * segEnd,
        paint,
      );
      traveled = segEnd + gapLen;
    }
  }

  void _paintUser(Canvas canvas, double w, double h) {
    final pos = userPosition;
    if (pos == null) return;
    final fill = Paint()..color = userFill;
    final stroke = Paint()
      ..color = userStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = userStrokeWidth;
    final radius = userRadiusFraction * (w < h ? w : h);
    final center = Offset(pos.dx * w, pos.dy * h);
    canvas.drawCircle(center, radius, fill);
    canvas.drawCircle(center, radius, stroke);
  }

  @override
  bool shouldRepaint(HousePainter old) =>
      old.houseMap != houseMap ||
      old.userPosition != userPosition ||
      !_listEq(old.route, route) ||
      old.roomFill != roomFill ||
      old.userFill != userFill ||
      old.routeStroke != routeStroke;
}

// Helper: structural equality for List<Offset> without depending on collectionEquals.
bool _listEq(List<Offset> a, List<Offset> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}