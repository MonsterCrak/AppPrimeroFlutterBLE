/// RSSI source backed by real BLE iBeacon scan via `flutter_beacon`.
///
/// Platform support:
/// - Android: uses Android-Beacon-Library under the hood. Detects all
///   iBeacon-format advertisements (Eddystone is ignored).
/// - iOS: uses CoreLocation (mandatory for iBeacons by Apple's policy).
///
/// The source emits a fresh [Map<beaconId, RssiSample>] every time the
/// scanner reports new ranging data. Beacons are mapped to logical IDs
/// (B1/B2/B3) via [BeaconConfig.minorToBeaconId] using their iBeacon Minor.
library;

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show Offset;

import 'package:dchs_flutter_beacon/dchs_flutter_beacon.dart' as fb;

import 'package:app_primero_flutter_ble/config/beacon_config.dart';
import 'package:app_primero_flutter_ble/models/rssi_sample.dart';
import 'package:app_primero_flutter_ble/sources/beacon_scanner_api.dart';
import 'package:app_primero_flutter_ble/sources/rssi_source.dart';

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
  final Map<String, RssiSample> _snapshot = <String, RssiSample>{};
  StreamSubscription<fb.RangingResult>? _sub;
  bool _initialized = false;

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

  @override
  void updateUserPosition(Offset position) {
    _userPosition = position;
    // No emit: position alone doesn't change RSSI. The scanner decides.
  }

  /// Initializes the underlying scanner and starts ranging.
  ///
  /// Returns true if initialization succeeded and ranging started.
  /// Returns false if permissions were denied or Bluetooth is off.
  Future<bool> start() async {
    if (_initialized) return true;
    final ok = await _api.initializeAndCheckScanning();
    if (!ok) return false;
    _sub = _api.ranging(_regions).listen(_onRangingResult);
    _initialized = true;
    return true;
  }

  void _onRangingResult(fb.RangingResult result) {
    final next = mapRangingResult(result);
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

  @override
  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _initialized = false;
    if (!_changes.isClosed) {
      await _changes.close();
    }
  }
}