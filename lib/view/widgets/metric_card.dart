/// Card displaying a metric: a small label and a value, optional icon.
library;

import 'package:flutter/material.dart';

import 'package:app_primero_flutter_ble/view/theme/app_theme.dart';

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? accentColor;
  final TextStyle? valueStyle;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.accentColor,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppCardDecoration.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: color),
                const SizedBox(width: AppSpacing.xs),
              ],
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: AppTypography.captionSize,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                    letterSpacing: 0.4,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: valueStyle ??
                const TextStyle(
                  fontSize: AppTypography.titleSize,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  height: 1.1,
                ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
