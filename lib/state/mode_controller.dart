/// Coordinates the transition between Simulated and Real BLE modes.
///
/// Owns the lifecycle of the active [RssiSource] (simulated vs BLE) and
/// the permission flow required to enable BLE scanning.
///
/// Design notes:
/// - [RssiSource] instances are created via injectable factories so unit
///   tests can mock them without touching platform channels.
/// - [PermissionService] is also injected (the system one wraps
///   `permission_handler`; the mock one returns whatever the test wants).
/// - When [BleRssiSource] emits errors after start, they are forwarded
///   via the [errors] stream so the UI can react.
library;

import 'dart:async';

import 'package:app_primero_flutter_ble/models/beacon.dart';
import 'package:app_primero_flutter_ble/models/beacon_mode.dart';
import 'package:app_primero_flutter_ble/permissions/permission_service.dart';
import 'package:app_primero_flutter_ble/sources/ble_error.dart';
import 'package:app_primero_flutter_ble/sources/ble_rssi_source.dart';
import 'package:app_primero_flutter_ble/sources/rssi_source.dart';
import 'package:app_primero_flutter_ble/sources/simulated_rssi_source.dart';
import 'package:app_primero_flutter_ble/state/simulation_notifier.dart';

typedef CreateSimulatedRssi = SimulatedRssiSource Function(List<Beacon> beacons);
typedef CreateBleRssi = BleRssiSource Function();

class ModeController {
  final SimulationNotifier notifier;
  final PermissionService permissionService;
  final CreateSimulatedRssi createSimulated;
  final CreateBleRssi createBle;

  BleRssiSource? _activeBleSource;
  StreamSubscription<BleError>? _bleErrorsSub;

  /// Forwarded BLE errors while in Real BLE mode. UI listens to show
  /// snackbars. Emits `null` when switching away from Real BLE to allow
  /// the UI to dismiss any open snackbar.
  final StreamController<BleError?> errors =
      StreamController<BleError?>.broadcast();

  /// Result of the most recent switch attempt. UI uses this to show
  /// error snackbars when permission is denied.
  ModeSwitchResult? lastResult;

  ModeController({
    required this.notifier,
    required this.permissionService,
    CreateSimulatedRssi? createSimulated,
    CreateBleRssi? createBle,
  })  : createSimulated = createSimulated ?? _defaultSimulated,
        createBle = createBle ?? _defaultBle;

  static SimulatedRssiSource _defaultSimulated(List<Beacon> beacons) =>
      SimulatedRssiSource(beacons: beacons);

  static BleRssiSource _defaultBle() => BleRssiSource();

  /// Requests a mode change. Returns whether the switch succeeded.
  Future<ModeSwitchResult> switchTo(BeaconMode target) async {
    if (notifier.mode == target) {
      lastResult = ModeSwitchResult.success(target);
      return lastResult!;
    }

    if (target == BeaconMode.simulated) {
      await _switchToSimulated();
      lastResult = ModeSwitchResult.success(target);
    } else {
      final permResult = await permissionService.request();
      if (permResult.action == PermissionAction.openSettings) {
        lastResult = ModeSwitchResult.permissionDenied(
          permanentlyDenied: true,
          message:
              'Permisos denegados permanentemente. Tocá "Settings" para '
              'habilitarlos manualmente.',
        );
        return lastResult!;
      }
      if (!permResult.allGranted) {
        lastResult = ModeSwitchResult.permissionDenied(
          permanentlyDenied: false,
          message: permResult.finalStatus.missingDescription ??
              'Permisos denegados.',
        );
        return lastResult!;
      }

      final ble = createBle();
      final started = await ble.start();
      if (!started) {
        final captured = await _captureNextBleError(ble, const Duration(seconds: 1));
        await ble.dispose();
        lastResult = ModeSwitchResult.bleError(
          captured ?? BleError.unknown('No se pudo iniciar el escaneo BLE'),
        );
        return lastResult!;
      }

      // Forward ongoing BLE errors to the UI.
      _bleErrorsSub?.cancel();
      _bleErrorsSub = ble.errors.listen((err) {
        if (!errors.isClosed) errors.add(err);
      });

      await notifier.setRssiSource(ble);
      notifier.setMode(BeaconMode.realBle);
      notifier.stop(); // El usuario se mueve caminando, no por timer.
      _activeBleSource = ble;
      lastResult = ModeSwitchResult.success(target);
    }

    return lastResult!;
  }

  Future<BleError?> _captureNextBleError(
    BleRssiSource source,
    Duration timeout,
) async {
  // Use Future.any: race the first error vs a delayed null.
  final firstError = source.errors.first
      .then<BleError?>((e) => e)
      .catchError((_) => null);
  final timer = Future<BleError?>.delayed(timeout, () => null);
  return Future.any([firstError, timer]);
}

  Future<void> _switchToSimulated() async {
    final simulated = createSimulated(notifier.houseMap.beacons);
    await notifier.setRssiSource(simulated);
    notifier.setMode(BeaconMode.simulated);
    await _bleErrorsSub?.cancel();
    _bleErrorsSub = null;
    if (!errors.isClosed) errors.add(null);
    final oldBle = _activeBleSource;
    _activeBleSource = null;
    await oldBle?.dispose();
  }

  Future<void> dispose() async {
    await _bleErrorsSub?.cancel();
    await _activeBleSource?.dispose();
    _activeBleSource = null;
    await errors.close();
  }
}

/// Outcome of [ModeController.switchTo].
class ModeSwitchResult {
  final bool ok;
  final BeaconMode? mode;

  /// True when the only reason for failure was the user denying
  /// permissions. The UI should show "Open Settings" CTA if true.
  final bool permissionPermanentlyDenied;

  /// True when BLE initialization failed for a non-permission reason
  /// (Bluetooth off, hardware error, etc.).
  final bool bleInitFailed;

  /// Structured [BleError] when the failure was BLE-side.
  final BleError? bleError;

  final String? errorMessage;

  const ModeSwitchResult._({
    required this.ok,
    this.permissionPermanentlyDenied = false,
    this.bleInitFailed = false,
    this.bleError,
    this.mode,
    this.errorMessage,
  });

  factory ModeSwitchResult.success(BeaconMode mode) =>
      ModeSwitchResult._(ok: true, mode: mode);

  factory ModeSwitchResult.permissionDenied({
    required bool permanentlyDenied,
    required String message,
  }) =>
      ModeSwitchResult._(
        ok: false,
        permissionPermanentlyDenied: permanentlyDenied,
        errorMessage: message,
      );

  factory ModeSwitchResult.bleError(BleError err) =>
      ModeSwitchResult._(
        ok: false,
        bleInitFailed: true,
        bleError: err,
        errorMessage: err.message,
      );

  bool get requiresOpenSettings =>
      permissionPermanentlyDenied ||
      (bleError?.requiresOpenSettings ?? false);
}