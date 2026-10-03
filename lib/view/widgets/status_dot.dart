/// Small colored dot + label, used for BLE status rows and badges.
library;

import 'package:flutter/material.dart';

import 'package:app_primero_flutter_ble/view/theme/app_theme.dart';

class StatusDot extends StatelessWidget {
  /// Color of the dot.
  final Color color;

  /// Optional icon rendered inside the dot (replaces the dot fill when set).
  final IconData? icon;

  /// Label text shown to the right of the dot.
  final String label;

  /// Optional emphasis for the label.
  final FontWeight labelWeight;

  /// Icon size if [icon] is set; otherwise the dot diameter.
  final double size;

  const StatusDot({
    super.key,
    required this.color,
    required this.label,
    this.icon,
    this.labelWeight = FontWeight.w500,
    this.size = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null)
          Container(
            width: size * 2.2,
            height: size * 2.2,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: size * 1.4, color: color),
          )
        else
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppTypography.bodySize,
              fontWeight: labelWeight,
              color: AppColors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
