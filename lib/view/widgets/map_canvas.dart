/// Widget wrapper around the [HousePainter].
///
/// The canvas is square by default (aspect ratio 1.0). It fills the available
/// width and centers vertically.
library;

import 'package:flutter/material.dart';

import 'package:app_primero_flutter_ble/models/house_map.dart';
import 'package:app_primero_flutter_ble/view/widgets/house_painter.dart';

class MapCanvas extends StatelessWidget {
  final HouseMap houseMap;

  const MapCanvas({super.key, required this.houseMap});

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
          painter: HousePainter(houseMap: houseMap),
          size: Size.infinite,
        ),
      ),
    );
  }
}