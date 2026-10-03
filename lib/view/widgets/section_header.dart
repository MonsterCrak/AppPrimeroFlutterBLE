/// Section header with optional icon and uppercase label.
library;

import 'package:flutter/material.dart';

import 'package:app_primero_flutter_ble/view/theme/app_theme.dart';

class SectionHeader extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.primary;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: tint),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: AppTypography.sectionHeaderSize,
              fontWeight: FontWeight.w600,
              color: tint,
              letterSpacing: 0.8,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
