/// Structured error from [BleRssiSource].
///
/// Surfaced through the `errors` stream so the UI can show a snackbar with
/// an actionable message. Designed to be human-readable in Spanish.
library;

import 'package:flutter/foundation.dart';

enum BleErrorKind {
  /// Bluetooth is off or unavailable (airplane mode, hardware off).
  bluetoothOff,

  /// Permissions were denied by the user.
  permissionDenied,

  /// Permissions were denied permanently ("Don't ask again" / iOS first-time).
  permissionPermanentlyDenied,

  /// Underlying ranging stream errored (typically BLE stack reset).
  rangingFailed,

  /// Initialization failed for an unknown reason.
  unknown,
}

@immutable
class BleError {
  final BleErrorKind kind;
  final String message;

  /// True when the only fix is for the user to open system Settings.
  final bool requiresOpenSettings;

  const BleError({
    required this.kind,
    required this.message,
    this.requiresOpenSettings = false,
  });

  factory BleError.bluetoothOff() => const BleError(
        kind: BleErrorKind.bluetoothOff,
        message:
            'Bluetooth está apagado. Activalo para usar el modo Real BLE.',
      );

  factory BleError.permissionDenied({required bool permanent}) => BleError(
        kind: permanent
            ? BleErrorKind.permissionPermanentlyDenied
            : BleErrorKind.permissionDenied,
        message: permanent
            ? 'Permisos denegados permanentemente. Abrí Settings y '
                'habilitá Bluetooth + Ubicación para esta app.'
            : 'Se necesitan permisos de Bluetooth y Ubicación para '
                'escanear iBeacons.',
        requiresOpenSettings: permanent,
      );

  factory BleError.rangingFailed(Object cause) => BleError(
        kind: BleErrorKind.rangingFailed,
        message: 'Error de escaneo BLE: $cause. Reintentando…',
      );

  factory BleError.unknown(String detail) => BleError(
        kind: BleErrorKind.unknown,
        message: 'No se pudo iniciar el escaneo BLE: $detail',
      );

  @override
  String toString() => 'BleError(${kind.name}: $message)';
}