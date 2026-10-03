/// Widget wrapper around the [HousePainter].
///
/// Owns two animations that bring the canvas to life:
///   * [_beaconPulseController] — a 1.5 s repeating controller that drives the
///     subtle 1.0× → 1.15× radius pulse on every beacon.
///   * A [TweenAnimationBuilder] around the user dot that glides between
///     successive [userPosition] values (e.g. RSSI samples or drift ticks)
///     instead of snapping from one to the next.
///
/// Optional [userPosition] and [route] add the user dot and planned route.
library;

import 'package:flutter/material.dart';

import 'package:app_primero_flutter_ble/models/house_map.dart';
import 'package:app_primero_flutter_ble/view/widgets/house_painter.dart';

class MapCanvas extends StatefulWidget {
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
  State<MapCanvas> createState() => _MapCanvasState();
}

class _MapCanvasState extends State<MapCanvas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _beaconPulseController;

  @override
  void initState() {
    super.initState();
    _beaconPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _beaconPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black26),
          color: Colors.white,
        ),
        // AnimatedBuilder drives the per-frame repaint while the pulse
        // controller ticks. We also tween the user position so the dot
        // glides instead of snapping between samples.
        child: AnimatedBuilder(
          animation: _beaconPulseController,
          builder: (context, _) {
            return TweenAnimationBuilder<Offset?>(
              // 350 ms glide between successive user positions. When the
              // user position is null we use Offset.zero as the anchor;
              // HousePainter already short-circuits on a null user, so
              // the anchor value never reaches the painter.
              tween: Tween<Offset>(
                end: widget.userPosition ?? Offset.zero,
              ),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              builder: (context, tweenedUser, _) {
                return CustomPaint(
                  painter: HousePainter(
                    houseMap: widget.houseMap,
                    userPosition: widget.userPosition == null
                        ? null
                        : tweenedUser,
                    route: widget.route,
                    beaconPulseValue: _beaconPulseController.value,
                  ),
                  size: Size.infinite,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
