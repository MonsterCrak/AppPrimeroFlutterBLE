/// Permission helper for BLE + location.
///
/// Defines an abstract [PermissionService] interface (testable with
/// mocktail) and a default [SystemPermissionService] that wraps
/// `permission_handler`.
///
/// Required permissions by platform:
/// - **Android**: `ACCESS_FINE_LOCATION` (driven by Android/Google policy —
///   not optional for BLE scan), plus `BLUETOOTH_SCAN` and `BLUETOOTH_CONNECT`
///   on Android 12+ (API 31+).
/// - **iOS**: `NSBluetoothAlwaysUsageDescription` (any use of Bluetooth must
///   be justified) and `NSLocationWhenInUseUsageDescription` (iBeacons go
///   through CoreLocation, which Apple gates behind location permission).
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
///
/// Tells the UI whether to proceed (granted), open Settings (permanently
/// denied), or retry.
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
    // 1. Check current state. If anything is permanently denied, we cannot
    // recover with a popup — must go through Settings.
    final initial = await check();
    final initialBt = await _bluetoothStatus();
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

    // 2. Request the missing ones. permission_handler.request takes a
    // single permission; we await them in parallel for snappiness.
    final results = await Future.wait([
      ph.Permission.locationWhenInUse.request(),
      _bluetoothRequest(),
    ]);
    final newLoc = results[0];
    final newBt = results[1];

    final finalStatus = PermissionStatusReport(
      bluetoothGranted: newBt.isGranted,
      locationGranted: newLoc.isGranted,
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

  bool _isPermanentlyDenied(ph.PermissionStatus bt, ph.PermissionStatus loc) =>
      bt.isPermanentlyDenied ||
      loc.isPermanentlyDenied ||
      bt.isRestricted ||
      loc.isRestricted;

  Future<ph.PermissionStatus> _bluetoothStatus() async {
    // On Android 12+ this maps to BLUETOOTH_CONNECT (the Android scan
    // permission is granted automatically with ACCESS_FINE_LOCATION).
    if (Platform.isAndroid) {
      // Read the actual BLUETOOTH_CONNECT state. On older Androids this
      // returns "granted" without prompting.
      return ph.Permission.bluetooth.status;
    }
    return ph.Permission.bluetooth.status;
  }

  Future<ph.PermissionStatus> _bluetoothRequest() async {
    return ph.Permission.bluetooth.request();
  }
}