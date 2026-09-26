/// Widget wrapper around the [HousePainter].
///
/// Optional [userPosition] and [route] add the user dot and planned route.
library;

import 'package:flutter/material.dart';

import 'package:app_primero_flutter_ble/models/house_map.dart';
import 'package:app_primero_flutter_ble/view/widgets/house_painter.dart';

class MapCanvas extends StatelessWidget {
  final HouseMap houseMap;
  final Offset? userPosition;
  final List<Offset> route;

  const MapCanvas({
    super.key,
    required this.houseMap,
    this.userPosition,
    this.route = const [],
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black26),
          color: Colors.white,
        ),
        child: CustomPaint(
          painter: HousePainter(
            houseMap: houseMap,
            userPosition: userPosition,
            route: route,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}