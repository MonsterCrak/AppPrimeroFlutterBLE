/// Central state of the simulation.
///
/// Owns the user position (interpolated along waypoints via a periodic
/// timer), pulls RSSI snapshots from an injected [RssiSource], and exposes
/// derived data (top-N nearest beacons) to the UI.
///
/// The [RssiSource] is mutable via [setRssiSource] so the UI can swap
/// between simulated and real-BLE sources without rebuilding the notifier.
library;

import 'dart:async';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

import 'package:app_primero_flutter_ble/models/beacon.dart';
import 'package:app_primero_flutter_ble/models/beacon_mode.dart';
import 'package:app_primero_flutter_ble/models/house_map.dart';
import 'package:app_primero_flutter_ble/models/rssi_sample.dart';
import 'package:app_primero_flutter_ble/sources/rssi_source.dart';

class SimulationNotifier extends ChangeNotifier {
  RssiSource _rssiSource;
  final HouseMap _houseMap;
  final Duration _tickInterval;

  /// Loop of waypoints the user traverses in order. Last segment wraps to
  /// the first (cyclical).
  final List<Offset> _waypoints;

  Timer? _timer;
  StreamSubscription<void>? _sourceSub;
  int _segmentIndex = 0;
  double _segmentProgress = 0.0;
  Offset _userPosition = const Offset(0.5, 0.5);
  Map<String, RssiSample> _rssiSnapshot = const <String, RssiSample>{};
  bool _isRunning = false;
  BeaconMode _mode = BeaconMode.simulated;

  /// Default route traverses the real house (see `E:\Obsidian\Tesis\
  /// Emulador BLE Indoor\Distribución casa.md`), visiting the 3
  /// beacons in order B1 (Sala) → B2 (Pasadizo) → B3 (Padres).
  ///
  /// Coordinates are normalized [0, 1]. The route:
  ///   1. Starts near B1 in the Sala (north).
  ///   2. Descends to the pasadizo entrance.
  ///   3. Crosses the pasadizo to Mi cuarto's door.
  ///   4. Goes east to B2 (east wall of Mi cuarto).
  ///   5. Returns to the pasadizo.
  ///   6. Continues south to the bottom of the pasadizo.
  ///   7. Enters Cuarto Hermano.
  ///   8. Goes west to B3 (west wall of Cuarto Hermano).
  ///   9. Loops back to start.
  static const List<Offset> _defaultWaypoints = [
    Offset(0.622, 0.206), // start: bajar un poco desde B1 dentro de la Sala
    Offset(0.622, 0.082), // B1 Sala (pared norte)
    Offset(0.444, 0.294), // bajar al pasadizo (sur de Sala)
    Offset(0.311, 0.471), // B2 Pasadizo (centro)
    Offset(0.311, 0.706), // seguir bajando por pasadizo
    Offset(0.444, 0.812), // entrar al Cuarto Padres
    Offset(0.600, 0.812), // B3 Padres (pared norte del cuarto)
  ];

  SimulationNotifier({
    required RssiSource rssiSource,
    required HouseMap houseMap,
    Duration tickInterval = const Duration(milliseconds: 100),
    List<Offset>? waypoints,
  })  : _rssiSource = rssiSource,
        _houseMap = houseMap,
        _tickInterval = tickInterval,
        _waypoints = waypoints ?? _defaultWaypoints {
    _userPosition = _waypoints.first;
    _rssiSnapshot = _rssiSource.current();
    _rssiSource.updateUserPosition(_userPosition);
    _rssiSnapshot = _rssiSource.current();
    _sourceSub = _rssiSource.changes.listen((_) {
      _rssiSnapshot = _rssiSource.current();
      // Do not notify here: ticks drive notifications for simplicity.
    });
  }

  // ---- Read-only state --------------------------------------------------

  bool get isRunning => _isRunning;
  Offset get userPosition => _userPosition;
  HouseMap get houseMap => _houseMap;
  RssiSource get rssiSource => _rssiSource;
  List<Offset> get waypoints => List.unmodifiable(_waypoints);
  BeaconMode get mode => _mode;

  /// Top-N beacons sorted by distance to the user.
  List<RssiSample> nearestBeacons({int n = 3}) {
    final all = _rssiSnapshot.values.toList()
      ..sort((a, b) => a.distance.compareTo(b.distance));
    return all.take(n).toList();
  }

  /// Current RSSI sample for a given beacon id (or null if unknown).
  RssiSample? rssiFor(String beaconId) => _rssiSnapshot[beaconId];

  /// Whether the given beacon id exists in the configured map.
  bool hasBeacon(String id) => _houseMap.beaconById(id) != null;

  Beacon? beaconById(String id) => _houseMap.beaconById(id);

  // ---- Commands ---------------------------------------------------------

  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _timer = Timer.periodic(_tickInterval, _onTick);
    notifyListeners();
  }

  void stop() {
    if (!_isRunning) return;
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  /// Resets position to the first waypoint without changing running state.
  void reset() {
    _segmentIndex = 0;
    _segmentProgress = 0.0;
    _userPosition = _waypoints.first;
    _rssiSource.updateUserPosition(_userPosition);
    _rssiSnapshot = _rssiSource.current();
    notifyListeners();
  }

  /// Swaps the RSSI source. The previous source is disposed; the new one
  /// is wired up and primed with the current user position.
  ///
  /// Use [setMode] to also update the UI badge.
  Future<void> setRssiSource(RssiSource newSource) async {
    if (identical(_rssiSource, newSource)) return;
    await _sourceSub?.cancel();
    _sourceSub = null;
    final old = _rssiSource;
    _rssiSource = newSource;
    _rssiSource.updateUserPosition(_userPosition);
    _rssiSnapshot = _rssiSource.current();
    _sourceSub = _rssiSource.changes.listen((_) {
      _rssiSnapshot = _rssiSource.current();
      // Do not notify here: ticks drive notifications for simplicity.
    });
    notifyListeners();
    // Dispose the previous source last, so any errors don't break state.
    await old.dispose();
  }

  /// Updates the operating mode (Simulated vs Real BLE).
  /// In Real BLE, the [ControlBar] should hide the Start button because
  /// the user moves physically, not via timer.
  void setMode(BeaconMode newMode) {
    if (_mode == newMode) return;
    _mode = newMode;
    notifyListeners();
  }

  // ---- For tests --------------------------------------------------------

  @visibleForTesting
  void setUserPosition(Offset pos) {
    _userPosition = pos;
    _rssiSource.updateUserPosition(_userPosition);
    _rssiSnapshot = _rssiSource.current();
    notifyListeners();
  }

  // ---- Internals --------------------------------------------------------

  void _onTick(Timer _) {
    // How long each segment should take. With 6 waypoints and a 100ms tick,
    // full loop = 6 * 2s = 12s. Tunable via tickInterval.
    const segmentDurationMs = 2000;
    final tickMs = _tickInterval.inMilliseconds;
    _segmentProgress += tickMs / segmentDurationMs;
    if (_segmentProgress >= 1.0) {
      _segmentProgress = 0.0;
      _segmentIndex = (_segmentIndex + 1) % _waypoints.length;
    }
    final from = _waypoints[_segmentIndex];
    final to = _waypoints[(_segmentIndex + 1) % _waypoints.length];
    _userPosition = Offset.lerp(from, to, _segmentProgress) ?? from;
    _rssiSource.updateUserPosition(_userPosition);
    _rssiSnapshot = _rssiSource.current();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sourceSub?.cancel();
    _rssiSource.dispose();
    super.dispose();
  }
}