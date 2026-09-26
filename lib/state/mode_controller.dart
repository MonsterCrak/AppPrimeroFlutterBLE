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
library;

import 'package:app_primero_flutter_ble/models/beacon.dart';
import 'package:app_primero_flutter_ble/models/beacon_mode.dart';
import 'package:app_primero_flutter_ble/permissions/permission_service.dart';
import 'package:app_primero_flutter_ble/sources/ble_rssi_source.dart';
import 'package:app_primero_flutter_ble/sources/rssi_source.dart';
import 'package:app_primero_flutter_ble/sources/simulated_rssi_source.dart';
import 'package:app_primero_flutter_ble/state/simulation_notifier.dart';

/// Factory for a fresh simulated source. Takes the current beacons list
/// from the notifier.
typedef CreateSimulatedRssi = SimulatedRssiSource Function(List<Beacon> beacons);

/// Factory for a fresh BLE source. In production this is just `BleRssiSource()`;
/// in tests it can return a mock that pretends initialization succeeded.
typedef CreateBleRssi = BleRssiSource Function();

class ModeController {
  final SimulationNotifier notifier;
  final PermissionService permissionService;
  final CreateSimulatedRssi createSimulated;
  final CreateBleRssi createBle;

  BleRssiSource? _activeBleSource;

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
  ///
  /// Switching to [BeaconMode.realBle] requires permissions; if they
  /// are not granted, the switch is aborted and the notifier stays in
  /// its current mode.
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
      if (!permResult.allGranted) {
        lastResult = ModeSwitchResult.permissionDenied(
          permResult.somePermanentlyDenied,
          permResult.finalStatus.missingDescription ?? 'Permisos denegados',
        );
        return lastResult!;
      }

      final ble = createBle();
      final started = await ble.start();
      if (!started) {
        await ble.dispose();
        lastResult = ModeSwitchResult.bleInitFailed(
          'No se pudo iniciar el escaneo BLE',
        );
        return lastResult!;
      }

      await notifier.setRssiSource(ble);
      notifier.setMode(BeaconMode.realBle);
      notifier.stop(); // El usuario se mueve caminando, no por timer.
      _activeBleSource = ble;
      lastResult = ModeSwitchResult.success(target);
    }

    return lastResult!;
  }

  Future<void> _switchToSimulated() async {
    final simulated = createSimulated(notifier.houseMap.beacons);
    await notifier.setRssiSource(simulated);
    notifier.setMode(BeaconMode.simulated);
    final oldBle = _activeBleSource;
    _activeBleSource = null;
    await oldBle?.dispose();
  }

  Future<void> dispose() async {
    await _activeBleSource?.dispose();
    _activeBleSource = null;
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

  final String? errorMessage;

  const ModeSwitchResult._({
    required this.ok,
    this.permissionPermanentlyDenied = false,
    this.bleInitFailed = false,
    this.mode,
    this.errorMessage,
  });

  factory ModeSwitchResult.success(BeaconMode mode) =>
      ModeSwitchResult._(ok: true, mode: mode);

  factory ModeSwitchResult.permissionDenied(
    bool permanentlyDenied,
    String message,
  ) =>
      ModeSwitchResult._(
        ok: false,
        permissionPermanentlyDenied: permanentlyDenied,
        errorMessage: message,
      );

  factory ModeSwitchResult.bleInitFailed(String message) =>
      ModeSwitchResult._(
        ok: false,
        bleInitFailed: true,
        errorMessage: message,
      );
}