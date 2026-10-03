/// Design tokens for the app's polished look.
///
/// Centralizes the color palette, typography, and common decoration
/// patterns used across the Scanner and Cuarto screens so they stay
/// visually consistent.
library;

import 'package:flutter/material.dart';

/// App color palette.
///
/// Inspired by a clean, professional indoor-positioning tool: deep indigo
/// as the primary accent (associated with Bluetooth/wireless), a soft
/// neutral background, and traffic-light semantic colors for status.
class AppColors {
  AppColors._();

  // Backgrounds
  static const Color background = Color(0xFFF5F7FA);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE5E7EB);

  // Accent
  static const Color primary = Color(0xFF1A237E); // deep indigo
  static const Color primaryLight = Color(0xFFE8EAF6);

  // Semantic
  static const Color success = Color(0xFF00C853);
  static const Color warning = Color(0xFFFF6F00);
  static const Color error = Color(0xFFD32F2F);

  // Text
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color textInverse = Color(0xFFFFFFFF);

  // Beacon/UI accents
  static const Color beaconGreen = Color(0xFF66BB6A);
  static const Color beaconGreenDark = Color(0xFF1B5E20);
  static const Color userBlue = Color(0xFF2196F3);
  static const Color userBlueDark = Color(0xFF0D47A1);
}

/// Spacing scale — keep widgets in the same rhythm.
class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
}

/// Typography presets. We don't redefine the whole Material 3 type scale;
/// just expose the sizes we actually use so they stay consistent.
class AppTypography {
  AppTypography._();
  static const double titleSize = 22;
  static const double sectionHeaderSize = 16;
  static const double bodySize = 14;
  static const double captionSize = 12;
  static const double metricSize = 13;
}

/// Decoration for the standard card look (16 px radius + soft shadow).
class AppCardDecoration {
  AppCardDecoration._();

  static BoxDecoration card({Color? color}) => BoxDecoration(
        color: color ?? AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      );
}

/// Maps an RSSI dBm value to a colored bucket for the signal-strength bar.
///
/// - Green:  > -70 dBm  (close, strong)
/// - Orange: -85 to -70 dBm (mid range)
/// - Red:    < -85 dBm  (far, weak)
Color signalColorForDbm(double dbm) {
  if (dbm > -70) return AppColors.success;
  if (dbm >= -85) return AppColors.warning;
  return AppColors.error;
}

/// Normalizes an RSSI dBm value to a [0, 1] strength fraction for the bar.
///
/// Maps the realistic range [-100, -40] dBm to [0, 1].
double signalFractionForDbm(double dbm) {
  const minDbm = -100.0;
  const maxDbm = -40.0;
  final clamped = dbm.clamp(minDbm, maxDbm);
  return (clamped - minDbm) / (maxDbm - minDbm);
}
