/// Horizontal bar visualizing signal strength (RSSI dBm).
///
/// The bar fills from left to right with a color that depends on the dBm
/// value: green for strong, orange for medium, red for weak. A 1-px
/// border gives the bar a subtle frame against light backgrounds.
library;

import 'package:flutter/material.dart';

import 'package:app_primero_flutter_ble/view/theme/app_theme.dart';

class SignalStrengthBar extends StatelessWidget {
  /// RSSI value in dBm (clamped internally).
  final double dbm;

  /// Bar height in logical pixels.
  final double height;

  const SignalStrengthBar({
    super.key,
    required this.dbm,
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    final color = signalColorForDbm(dbm);
    final fraction = signalFractionForDbm(dbm);
    return Semantics(
      label: 'Signal strength',
      value: '${(fraction * 100).round()} percent',
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.divider,
          borderRadius: BorderRadius.circular(height / 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: fraction,
            heightFactor: 1,
            child: Container(color: color),
          ),
        ),
      ),
    );
  }
}
