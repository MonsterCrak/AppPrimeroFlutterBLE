/// Permission helper for BLE + location + notifications.
///
/// Defines an abstract [PermissionService] interface (testable with
/// mocktail) and a default [SystemPermissionService] that wraps
/// `permission_handler`.
///
/// Required permissions by platform:
/// - **Android 12+ (API 31+)**: `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`,
///   `ACCESS_FINE_LOCATION`. iBeacon ranging requires all three to be
///   runtime-granted; ABL silently refuses to range if any is missing.
///   On Android 13+ (API 33+), `POST_NOTIFICATIONS` is also requested
///   but treated as optional (ranging works without it).
/// - **Android <12**: `ACCESS_FINE_LOCATION`; `BLUETOOTH` legacy is
///   granted at install time.
/// - **iOS**: `NSBluetoothAlwaysUsageDescription` (any use of Bluetooth)
///   and `NSLocationWhenInUseUsageDescription` (iBeacons via CoreLocation).
///
/// Request order rationale:
///   1. Location first — iBeacon protocol requires location on Android.
///      If denied, no point asking for Bluetooth.
///   2. Bluetooth Scan — required to actually scan advertisements.
///   3. Bluetooth Connect — required to operate on discovered devices.
///   4. Notifications — Android 13+ runtime. Optional for ranging.
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// What the UI should do with a [PermissionRequestResult].
enum PermissionAction {
  /// All required permissions are granted — proceed with BLE initialization.
  granted,

  /// At least one permission is permanently denied. The UI should offer
  /// an "Open Settings" action via [PermissionService.openSettings].
  openSettings,

  /// Permissions were denied (but not permanently). The UI can ask the
  /// user to retry; in practice this means the OS will show the popup
  /// again next time [PermissionService.request] is called.
  retry,
}

/// Granular status of each individual permission we care about.
///
/// Notifications are tracked separately but excluded from [allGranted]
/// because they are optional for foreground iBeacon ranging.
@immutable
class PermissionStatusReport {
  /// `ACCESS_FINE_LOCATION` (Android) / `WhenInUse` (iOS).
  final bool locationGranted;

  /// Android 12+: `BLUETOOTH_SCAN`. Legacy: `BLUETOOTH`.
  final bool bluetoothScanGranted;

  /// Android 12+: `BLUETOOTH_CONNECT`. Auto-granted on older Android.
  final bool bluetoothConnectGranted;

  /// Android 13+: `POST_NOTIFICATIONS`. Optional for ranging.
  /// Defaults to `true` on platforms that don't have this concept (iOS,
  /// pre-Android 13) so tests/mocks don't need to specify it.
  final bool notificationGranted;

  const PermissionStatusReport({
    required this.locationGranted,
    required this.bluetoothScanGranted,
    required this.bluetoothConnectGranted,
    this.notificationGranted = true,
  });

  /// Convenience getter: Bluetooth (scan + connect) all granted.
  bool get bluetoothGranted => bluetoothScanGranted && bluetoothConnectGranted;

  /// True when all REQUIRED permissions for iBeacon ranging are granted.
  /// Notifications are NOT required for foreground ranging.
  bool get allGranted =>
      locationGranted && bluetoothScanGranted && bluetoothConnectGranted;

  String? get missingDescription {
    final missing = <String>[];
    if (!bluetoothGranted) missing.add('Bluetooth');
    if (!locationGranted) missing.add('Ubicación');
    if (missing.isEmpty) return null;
    return 'Falta permiso de: ${missing.join(", ")}';
  }

  @override
  String toString() =>
      'PermissionStatusReport(location: $locationGranted, '
      'btScan: $bluetoothScanGranted, btConnect: $bluetoothConnectGranted, '
      'notification: $notificationGranted)';
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
  bool get requiresOpenSettings => action == PermissionAction.openSettings;

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
  /// Requests are issued SEQUENTIALLY in the order documented at the top
  /// of this file. Returns a [PermissionRequestResult] with an
  /// [PermissionAction]:
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
  ph.Permission get _bluetoothScanPermission =>
      Platform.isAndroid ? ph.Permission.bluetoothScan : ph.Permission.bluetooth;

  /// Android 12+ only. On older Android, BLUETOOTH is install-granted.
  /// On iOS, BT permission is implicitly granted via `Permission.bluetooth`.
  ph.Permission get _bluetoothConnectPermission => Platform.isAndroid
      ? ph.Permission.bluetoothConnect
      : ph.Permission.bluetooth;

  /// Android 13+ only. Optional for foreground ranging.
  ph.Permission get _notificationPermission => Platform.isAndroid
      ? ph.Permission.notification
      : ph.Permission.bluetooth; // placeholder for iOS

  @override
  Future<PermissionStatusReport> check() async {
    final results = await Future.wait([
      ph.Permission.locationWhenInUse.status,
      _bluetoothScanPermission.status,
      if (Platform.isAndroid) _bluetoothConnectPermission.status,
      if (Platform.isAndroid) _notificationPermission.status,
    ]);
    final locIdx = 0;
    final scanIdx = 1;
    final connectIdx = Platform.isAndroid ? 2 : -1;
    final notifIdx = Platform.isAndroid ? 3 : -1;
    return PermissionStatusReport(
      locationGranted: _isGranted(results[locIdx]),
      bluetoothScanGranted: _isGranted(results[scanIdx]),
      bluetoothConnectGranted:
          connectIdx >= 0 ? _isGranted(results[connectIdx]) : true,
      notificationGranted:
          notifIdx >= 0 ? _isGranted(results[notifIdx]) : true,
    );
  }

  @override
  Future<PermissionRequestResult> request() async {
    // 1. Snapshot current state. If all already granted, return early.
    final initial = await check();
    if (initial.allGranted) {
      return PermissionRequestResult.granted(initial);
    }

    // 2. If any required permission is permanently denied up-front, we
    //    cannot recover via a popup — must go through Settings.
    if (await _hasAnyPermanentlyDenied()) {
      return PermissionRequestResult(
        finalStatus: await check(),
        action: PermissionAction.openSettings,
      );
    }

    // 3. Request SEQUENTIALLY in documented order. Each `await` blocks
    //    until the user responds to the previous dialog. This avoids the
    //    OS showing overlapping dialogs when two `request()` calls race.
    //
    //    Location first — iBeacon requires location on Android. If the
    //    user denies it, there's no point asking for Bluetooth.
    if (!initial.locationGranted) {
      final locResult = await ph.Permission.locationWhenInUse.request();
      if (!_isGranted(locResult)) {
        return _failureResultFor('Ubicación', locResult);
      }
    }

    // Re-check after location; user might have toggled.
    var afterLoc = await check();
    if (!afterLoc.bluetoothScanGranted) {
      final btScanResult = await _bluetoothScanPermission.request();
      if (!_isGranted(btScanResult)) {
        return _failureResultFor('Bluetooth (scan)', btScanResult);
      }
    }

    afterLoc = await check();
    if (Platform.isAndroid && !afterLoc.bluetoothConnectGranted) {
      final btConnectResult = await _bluetoothConnectPermission.request();
      if (!_isGranted(btConnectResult)) {
        return _failureResultFor('Bluetooth (connect)', btConnectResult);
      }
    }

    // Notifications are non-blocking for ranging — request but never fail.
    if (Platform.isAndroid) {
      final afterConnect = await check();
      if (!afterConnect.notificationGranted) {
        await _notificationPermission.request();
      }
    }

    // 4. Final verification.
    final finalReport = await check();
    if (finalReport.allGranted) {
      return PermissionRequestResult.granted(finalReport);
    }

    // 5. Some still missing after sequential flow — likely the user
    //    permanently denied something mid-flow.
    if (await _hasAnyPermanentlyDenied()) {
      return PermissionRequestResult(
        finalStatus: finalReport,
        action: PermissionAction.openSettings,
      );
    }
    return PermissionRequestResult(
      finalStatus: finalReport,
      action: PermissionAction.retry,
    );
  }

  @override
  Future<void> openSettings() async {
    await ph.openAppSettings();
  }

  bool _isGranted(ph.PermissionStatus s) => s.isGranted || s.isLimited;

  bool _isPermanentlyDeniedStatus(ph.PermissionStatus s) =>
      s.isPermanentlyDenied || s.isRestricted;

  Future<bool> _hasAnyPermanentlyDenied() async {
    final results = await Future.wait([
      ph.Permission.locationWhenInUse.status,
      _bluetoothScanPermission.status,
      if (Platform.isAndroid) _bluetoothConnectPermission.status,
    ]);
    return results.any(_isPermanentlyDeniedStatus);
  }

  PermissionRequestResult _failureResultFor(
    String deniedName,
    ph.PermissionStatus denied,
  ) {
    final isPermanent = _isPermanentlyDeniedStatus(denied);
    // The request flow stops at the first denial. Mark that specific
    // permission as not granted and assume earlier ones were granted
    // (we got past them in the sequential flow).
    final locDenied = deniedName == 'Ubicación';
    final scanDenied = deniedName == 'Bluetooth (scan)';
    final connectDenied = deniedName == 'Bluetooth (connect)';
    final report = PermissionStatusReport(
      locationGranted: !locDenied,
      bluetoothScanGranted: !scanDenied,
      bluetoothConnectGranted: !connectDenied,
    );
    return PermissionRequestResult(
      finalStatus: report,
      action: isPermanent
          ? PermissionAction.openSettings
          : PermissionAction.retry,
    );
  }
}