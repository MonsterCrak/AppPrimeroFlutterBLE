/// RSSI source backed by real BLE iBeacon scan via `dchs_flutter_beacon`.
///
/// Platform support:
/// - Android: uses Android-Beacon-Library under the hood. Detects all
///   iBeacon-format advertisements (Eddystone is ignored).
/// - iOS: uses CoreLocation (mandatory for iBeacons by Apple's policy).
///
/// The source emits a fresh [Map<beaconId, RssiSample>] every time the
/// scanner reports new ranging data. Beacons are mapped to logical IDs
/// (B1/B2/B3) via [BeaconConfig.minorToBeaconId] using their iBeacon Minor.
///
/// Error handling (WU-15):
/// - Validates Bluetooth state before [start]. Emits [BleError.bluetoothOff]
///   if the adapter is off and returns false.
/// - Emits [BleError.permissionDenied] / [BleError.permissionPermanentlyDenied]
///   if the underlying scanner refuses to initialize due to missing permissions.
/// - On ranging stream errors, emits [BleError.rangingFailed] and
///   automatically re-subscribes after a backoff.
library;

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show Offset;

import 'package:dchs_flutter_beacon/dchs_flutter_beacon.dart' as fb;

import 'package:app_primero_flutter_ble/config/beacon_config.dart';
import 'package:app_primero_flutter_ble/models/rssi_sample.dart';
import 'package:app_primero_flutter_ble/sources/beacon_scanner_api.dart';
import 'package:app_primero_flutter_ble/sources/ble_error.dart';
import 'package:app_primero_flutter_ble/sources/rssi_source.dart';
import 'package:app_primero_flutter_ble/util/kalman_filter.dart';

class BleRssiSource implements RssiSource {
  final BeaconScannerApi _api;
  final List<fb.Region> _regions;

  /// Current known user position. The scanner doesn't actually use it (the
  /// BLE driver decides RSSI on its own), but we keep it as part of the
  /// [RssiSource] contract so callers don't have to special-case this impl.
  // ignore: unused_field
  Offset _userPosition = const Offset(0.5, 0.5);

  final StreamController<Map<String, RssiSample>> _changes =
      StreamController<Map<String, RssiSample>>.broadcast();
  final StreamController<BleError> _errors =
      StreamController<BleError>.broadcast();
  final Map<String, RssiSample> _snapshot = <String, RssiSample>{};
  StreamSubscription<fb.RangingResult>? _sub;
  Timer? _retryTimer;
  bool _initialized = false;
  bool _disposed = false;

  /// Per-beacon Kalman filter for smoothing RSSI readings. Each beacon
  /// gets its own filter so they don't share state. Defaults: q=2.0,
  /// r=16.0 (reasonable for indoor BLE, ~1 Hz samples).
  final Map<String, KalmanFilter1D> _rssiFilters = <String, KalmanFilter1D>{};

  /// Constructor for production.
  ///
  /// On Android, the scanner detects all iBeacons (no UUID filter required).
  /// On iOS, we MUST specify the proximityUUID because Apple requires it.
  BleRssiSource({BeaconScannerApi? api})
      : _api = api ?? FlutterBeaconApi(),
        _regions = _buildRegions();

  /// Constructor for tests: lets you inject a fake scanner + regions.
  BleRssiSource.withScanner({
    required BeaconScannerApi api,
    required List<fb.Region> regions,
  })  : _api = api,
        _regions = regions;

  static List<fb.Region> _buildRegions() {
    final uuid = BeaconConfig.proximityUuid;
    return [
      if (Platform.isIOS)
        fb.Region(
          identifier: 'FSC-BP104D',
          proximityUUID: uuid,
        )
      else
        // Android: any identifier works; plugin scans all iBeacons.
        fb.Region(identifier: 'AllFSC-BP104D'),
    ];
  }

  @override
  Map<String, RssiSample> current() => Map.unmodifiable(_snapshot);

  @override
  Stream<void> get changes => _changes.stream.map((_) {});

  /// Surfaces [BleError] events (bluetooth off, permission denied, ranging
  /// stream failures). UI listens to show snackbars.
  Stream<BleError> get errors => _errors.stream;

  @override
  void updateUserPosition(Offset position) {
    _userPosition = position;
    // No emit: position alone doesn't change RSSI. The scanner decides.
  }

  /// Initializes the underlying scanner and starts ranging.
  ///
  /// Returns `true` if initialization + ranging started. Returns `false`
  /// if [BleErrorKind.bluetoothOff] or [BleErrorKind.permissionDenied].
  /// The detailed reason is emitted via [errors].
  Future<bool> start() async {
    if (_disposed) return false;
    if (_initialized) return true;

    // 1. Verify Bluetooth adapter state.
    final btState = await _api.bluetoothState();
    if (btState != fb.BluetoothState.stateOn) {
      _emitError(BleError.bluetoothOff());
      return false;
    }

    // 2. Try to initialize (this is where flutter_beacon checks permissions).
    final ok = await _api.initializeAndCheckScanning();
    if (!ok) {
      // We don't know here if it's permanently denied; the API doesn't
      // expose that. We mark as "permission denied, possibly permanent"
      // and let the UI offer the "open Settings" path.
      _emitError(BleError.permissionDenied(permanent: true));
      return false;
    }

    // 3. Subscribe to ranging, with error handling.
    _sub = _api.ranging(_regions).listen(
      _onRangingResult,
      onError: _onRangingError,
    );
    _initialized = true;
    return true;
  }

  void _onRangingError(Object error) {
    if (_disposed) return;
    _emitError(BleError.rangingFailed(error));
    _scheduleRetry();
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 3), () {
      if (_disposed) return;
      _restartRanging();
    });
  }

  Future<void> _restartRanging() async {
    await _sub?.cancel();
    if (_disposed) return;
    _sub = _api.ranging(_regions).listen(
      _onRangingResult,
      onError: _onRangingError,
    );
  }

  void _onRangingResult(fb.RangingResult result) {
    final raw = mapRangingResult(result);
    final next = <String, RssiSample>{};
    for (final entry in raw.entries) {
      final id = entry.key;
      final sample = entry.value;
      final filter = _rssiFilters.putIfAbsent(
        id,
        () => KalmanFilter1D(q: 2.0, r: 16.0),
      );
      final smoothedDbm = filter.update(sample.dbm);
      next[id] = RssiSample(
        beaconId: id,
        dbm: smoothedDbm,
        distance: sample.distance,
      );
    }
    _snapshot
      ..clear()
      ..addAll(next);
    if (!_changes.isClosed) {
      _changes.add(Map.unmodifiable(next));
    }
  }

  /// Maps a [RangingResult] to the subset of beacons we care about.
  ///
  /// Filters out:
  /// - Beacons from a different Proximity UUID (other deployments).
  /// - Beacons with a different Major.
  /// - Beacons whose Minor is not in our configured set.
  ///
  /// Pure function — exposed as static so tests can exercise it directly
  /// without needing to construct a [RangingResult] (which has no public
  /// constructor in `flutter_beacon`; only `RangingResult.from(json)`).
  static Map<String, RssiSample> mapRangingResult(fb.RangingResult result) {
    final out = <String, RssiSample>{};
    for (final raw in result.beacons) {
      if (!_matchesDeployment(raw)) continue;
      final id = BeaconConfig.beaconIdForIBeacon(raw.major, raw.minor);
      if (id == null) continue;
      out[id] = RssiSample(
        beaconId: id,
        dbm: raw.rssi.toDouble().clamp(RssiSample.minDbm, RssiSample.maxDbm),
        distance: raw.accuracy,
      );
    }
    return out;
  }

  static bool _matchesDeployment(fb.Beacon raw) {
    final expectedUuid = BeaconConfig.proximityUuid.toLowerCase();
    final actualUuid = raw.proximityUUID.toLowerCase();
    if (actualUuid != expectedUuid) return false;
    if (raw.major != BeaconConfig.major) return false;
    return true;
  }

  void _emitError(BleError err) {
    if (!_errors.isClosed) {
      _errors.add(err);
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _retryTimer?.cancel();
    await _sub?.cancel();
    _sub = null;
    _initialized = false;
    await _changes.close();
    await _errors.close();
  }
}