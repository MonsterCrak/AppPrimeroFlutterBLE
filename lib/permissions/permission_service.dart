/// Permission helper for BLE + location.
///
/// Defines an abstract [PermissionService] interface (testable with mocktail)
/// and a default [SystemPermissionService] that wraps `permission_handler`.
///
/// Android requires Bluetooth + fine-location. iOS requires Bluetooth +
/// location (because iBeacons go through CoreLocation).
library;

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Status of each individual permission we care about.
@immutable
class PermissionStatusReport {
  final bool bluetoothGranted;
  final bool locationGranted;

  const PermissionStatusReport({
    required this.bluetoothGranted,
    required this.locationGranted,
  });

  /// Whether the app has everything it needs to start a BLE scan.
  bool get allGranted => bluetoothGranted && locationGranted;

  /// Human-readable description of what's missing, or null if all granted.
  String? get missingDescription {
    final missing = <String>[];
    if (!bluetoothGranted) missing.add('Bluetooth');
    if (!locationGranted) missing.add('Ubicación');
    if (missing.isEmpty) return null;
    return 'Falta permiso de: ${missing.join(", ")}';
  }

  @override
  String toString() =>
      'PermissionStatusReport(bluetoothGranted: $bluetoothGranted, '
      'locationGranted: $locationGranted)';
}

/// Aggregate result of a permission request flow.
@immutable
class PermissionRequestResult {
  final PermissionStatusReport finalStatus;
  final bool somePermanentlyDenied;

  const PermissionRequestResult({
    required this.finalStatus,
    required this.somePermanentlyDenied,
  });

  bool get allGranted => finalStatus.allGranted;
}

abstract class PermissionService {
  /// Inspect current permission state without prompting.
  Future<PermissionStatusReport> check();

  /// Prompt for any missing permissions in the correct order.
  ///
  /// Returns the final status + a flag for whether any was permanently denied
  /// (Android: "Don't ask again", iOS: first-time denial).
  Future<PermissionRequestResult> request();
}

/// Default implementation backed by `permission_handler`.
class SystemPermissionService implements PermissionService {
  @override
  Future<PermissionStatusReport> check() async {
    final bt = await _bluetoothStatus();
    final loc = await ph.Permission.locationWhenInUse.status;
    return PermissionStatusReport(
      bluetoothGranted: bt.isGranted,
      locationGranted: loc.isGranted,
    );
  }

  @override
  Future<PermissionRequestResult> request() async {
    // Order matters: ask location first on iOS (Apple shows this prompt
    // earlier and more often), then Bluetooth. On Android the order is
    // irrelevant since each prompt is independent.
    final locationStatus = await ph.Permission.locationWhenInUse.request();
    final bluetoothStatus = await _bluetoothRequest();

    final result = PermissionStatusReport(
      bluetoothGranted: bluetoothStatus.isGranted,
      locationGranted: locationStatus.isGranted,
    );

    final anyPermanentlyDenied = locationStatus.isPermanentlyDenied ||
        bluetoothStatus.isPermanentlyDenied ||
        locationStatus.isRestricted ||
        bluetoothStatus.isRestricted;

    return PermissionRequestResult(
      finalStatus: result,
      somePermanentlyDenied: anyPermanentlyDenied,
    );
  }

  /// On Android: `BLUETOOTH_CONNECT` (granted automatically at install on older
  /// versions, runtime on Android 12+). On iOS: `NSBluetoothAlwaysUsageDescription`.
  Future<ph.PermissionStatus> _bluetoothStatus() async {
    // permission_handler doesn't expose BLUETOOTH_CONNECT directly; on Android
    // it's checked implicitly when starting a scan. We approximate with
    // `Permission.bluetooth` (which maps to BLUETOOTH_CONNECT on Android 12+).
    return ph.Permission.bluetooth.status;
  }

  Future<ph.PermissionStatus> _bluetoothRequest() async {
    return ph.Permission.bluetooth.request();
  }
}