/// Permission helper for BLE + location.
///
/// Defines an abstract [PermissionService] interface (testable with
/// mocktail) and a default [SystemPermissionService] that wraps
/// `permission_handler`.
///
/// Required permissions by platform:
/// - **Android 12+ (API 31+)**: `ACCESS_FINE_LOCATION`, `BLUETOOTH_SCAN`,
///   `BLUETOOTH_CONNECT`. We ask for `bluetoothScan` because that's the one
///   required for ranging iBeacons; `bluetoothConnect` is auto-granted on
///   install for our use case.
/// - **Android <12**: `ACCESS_FINE_LOCATION`; `BLUETOOTH` legacy is
///   granted at install time.
/// - **iOS**: `NSBluetoothAlwaysUsageDescription` (any use of Bluetooth)
///   and `NSLocationWhenInUseUsageDescription` (iBeacons via CoreLocation).
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// What the UI should do with a [PermissionRequestResult].
enum PermissionAction {
  /// All permissions are granted — proceed with BLE initialization.
  granted,

  /// At least one permission is permanently denied. The UI should offer
  /// an "Open Settings" action via [PermissionService.openSettings].
  openSettings,

  /// Permissions were denied (but not permanently). The UI can ask the
  /// user to retry; in practice this means the OS will show the popup
  /// again next time [PermissionService.request] is called.
  retry,
}

/// Status of each individual permission we care about.
@immutable
class PermissionStatusReport {
  final bool bluetoothGranted;
  final bool locationGranted;

  const PermissionStatusReport({
    required this.bluetoothGranted,
    required this.locationGranted,
  });

  bool get allGranted => bluetoothGranted && locationGranted;

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

/// Result of a permission request flow.
@immutable
class PermissionRequestResult {
  final PermissionStatusReport finalStatus;
  final PermissionAction action;

  const PermissionRequestResult({
    required this.finalStatus,
    required this.action,
  });

  bool get allGranted => action == PermissionAction.granted;
  bool get requiresOpenSettings =>
      action == PermissionAction.openSettings;

  /// Convenience factory.
  factory PermissionRequestResult.granted(PermissionStatusReport status) =>
      PermissionRequestResult(
        finalStatus: status,
        action: PermissionAction.granted,
      );
}

abstract class PermissionService {
  /// Inspect current permission state without prompting.
  Future<PermissionStatusReport> check();

  /// Prompt for any missing permissions.
  ///
  /// Returns a [PermissionRequestResult] with an [PermissionAction]:
  /// - [PermissionAction.granted] if everything is OK.
  /// - [PermissionAction.openSettings] if at least one is permanently
  ///   denied (UI must call [openSettings]).
  /// - [PermissionAction.retry] if denied (non-permanent) — the OS may
  ///   show the popup again next time.
  Future<PermissionRequestResult> request();

  /// Open the system app-settings page for this app.
  Future<void> openSettings();
}

class SystemPermissionService implements PermissionService {
  /// On Android 12+ the relevant Bluetooth permission is `BLUETOOTH_SCAN`.
  /// On older Android + iOS we use the generic `Permission.bluetooth`.
  ph.Permission get _bluetoothPermission =>
      Platform.isAndroid ? ph.Permission.bluetoothScan : ph.Permission.bluetooth;

  @override
  Future<PermissionStatusReport> check() async {
    final bt = await _bluetoothPermission.status;
    final loc = await ph.Permission.locationWhenInUse.status;
    return PermissionStatusReport(
      bluetoothGranted: _isGranted(bt),
      locationGranted: _isGranted(loc),
    );
  }

  @override
  Future<PermissionRequestResult> request() async {
    // 1. Check current state. If anything is permanently denied, we cannot
    // recover with a popup — must go through Settings.
    final initial = await check();
    final initialBt = await _bluetoothPermission.status;
    final initialLoc = await ph.Permission.locationWhenInUse.status;
    if (_isPermanentlyDenied(initialBt, initialLoc)) {
      return PermissionRequestResult(
        finalStatus: initial,
        action: PermissionAction.openSettings,
      );
    }
    if (initial.allGranted) {
      return PermissionRequestResult.granted(initial);
    }

    // 2. Request the missing ones in parallel.
    final results = await Future.wait([
      ph.Permission.locationWhenInUse.request(),
      _bluetoothPermission.request(),
    ]);
    final newLoc = results[0];
    final newBt = results[1];

    final finalStatus = PermissionStatusReport(
      bluetoothGranted: _isGranted(newBt),
      locationGranted: _isGranted(newLoc),
    );

    if (finalStatus.allGranted) {
      return PermissionRequestResult.granted(finalStatus);
    }
    if (_isPermanentlyDenied(newBt, newLoc)) {
      return PermissionRequestResult(
        finalStatus: finalStatus,
        action: PermissionAction.openSettings,
      );
    }
    return PermissionRequestResult(
      finalStatus: finalStatus,
      action: PermissionAction.retry,
    );
  }

  @override
  Future<void> openSettings() async {
    await ph.openAppSettings();
  }

  bool _isGranted(ph.PermissionStatus s) => s.isGranted || s.isLimited;

  bool _isPermanentlyDenied(ph.PermissionStatus bt, ph.PermissionStatus loc) =>
      bt.isPermanentlyDenied ||
      loc.isPermanentlyDenied ||
      bt.isRestricted ||
      loc.isRestricted;
}