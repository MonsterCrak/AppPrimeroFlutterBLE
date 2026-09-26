/// Renders a [HouseMap] (rooms + beacons + architectural layout) plus an
/// optional user position and planned route to a Canvas in normalized
/// coordinates.
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
  final Color wallColor;
  final Color doorColor;
  final Color labelColor;
  final Color excludedFill;
  final Color excludedStroke;
  final double roomStrokeWidth;
  final double beaconStrokeWidth;
  final double userStrokeWidth;
  final double routeStrokeWidth;
  final double beaconRadiusFraction; // of smaller canvas side
  final double userRadiusFraction;
  final double wallThicknessFraction;

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
    this.wallColor = const Color(0xFF1E293B),
    this.doorColor = const Color(0xFF1E293B),
    this.labelColor = const Color(0xFF475569),
    this.excludedFill = const Color(0x22EF4444),
    this.excludedStroke = const Color(0xFFEF4444),
    this.roomStrokeWidth = 1.0,
    this.beaconStrokeWidth = 2.0,
    this.userStrokeWidth = 2.0,
    this.routeStrokeWidth = 1.2,
    this.beaconRadiusFraction = 0.025,
    this.userRadiusFraction = 0.04,
    this.wallThicknessFraction = 0.005,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    _paintRooms(canvas, w, h);
    _paintExcludedZones(canvas, w, h);
    _paintRoute(canvas, w, h);
    _paintWalls(canvas, w, h);
    _paintDoors(canvas, w, h);
    _paintBeacons(canvas, w, h);
    _paintLabels(canvas, w, h);
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

  void _paintExcludedZones(Canvas canvas, double w, double h) {
    if (houseMap.layout.excludedZones.isEmpty) return;
    final fill = Paint()..color = excludedFill;
    final stroke = Paint()
      ..color = excludedStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final zone in houseMap.layout.excludedZones) {
      final rect = Rect.fromLTWH(
        zone.rect.left * w,
        zone.rect.top * h,
        zone.rect.width * w,
        zone.rect.height * h,
      );
      canvas.drawRect(rect, fill);
      canvas.drawRect(rect, stroke);
      if (zone.label != null) {
        _drawText(
          canvas,
          zone.label!,
          Offset(rect.center.dx, rect.center.dy),
          fontSize: h * 0.014,
          color: excludedStroke,
          bold: false,
        );
      }
    }
  }

  void _paintWalls(Canvas canvas, double w, double h) {
    if (houseMap.layout.walls.isEmpty) return;
    final thickness = wallThicknessFraction * (w < h ? w : h);
    final paint = Paint()
      ..color = wallColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.square;
    for (final wall in houseMap.layout.walls) {
      canvas.drawLine(
        Offset(wall.from.dx * w, wall.from.dy * h),
        Offset(wall.to.dx * w, wall.to.dy * h),
        paint,
      );
    }
  }

  void _paintDoors(Canvas canvas, double w, double h) {
    if (houseMap.layout.doors.isEmpty) return;
    final radius = 0.012 * (w < h ? w : h);
    final stroke = Paint()
      ..color = doorColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (final door in houseMap.layout.doors) {
      final center = Offset(door.center.dx * w, door.center.dy * h);
      // Erase a small gap on the wall by painting the background.
      canvas.drawCircle(center, radius * 1.2, Paint()..color = Colors.white);
      // Draw a 90° arc to suggest the swing.
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(rect, 0, 1.57, false, stroke);
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

    final dashLen = w * 0.02;
    final gapLen = w * 0.015;
    final points = route
        .map((p) => Offset(p.dx * w, p.dy * h))
        .toList(growable: false);
    for (var i = 0; i < points.length - 1; i++) {
      _drawDashedSegment(canvas, points[i], points[i + 1], dashLen, gapLen, paint);
    }
    if (points.length >= 3) {
      _drawDashedSegment(canvas, points.last, points.first, dashLen, gapLen, paint);
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

  void _paintLabels(Canvas canvas, double w, double h) {
    if (houseMap.layout.labels.isEmpty) return;
    for (final label in houseMap.layout.labels) {
      // Detect beacon labels (B1/B2/B3) and color them green, others gray.
      final isBeacon = RegExp(r'^B[123]$').hasMatch(label.text);
      _drawText(
        canvas,
        label.text,
        Offset(label.position.dx * w, label.position.dy * h),
        fontSize: h * label.fontFraction,
        color: isBeacon ? const Color(0xFF065F46) : labelColor,
        bold: true,
      );
    }
  }

  void _drawText(Canvas canvas, String text, Offset center,
      {required double fontSize, required Color color, required bool bold}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
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
      old.routeStroke != routeStroke ||
      old.wallColor != wallColor ||
      old.labelColor != labelColor;
}

bool _listEq(List<Offset> a, List<Offset> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}