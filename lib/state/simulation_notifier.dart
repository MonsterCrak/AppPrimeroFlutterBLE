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
import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

import 'package:app_primero_flutter_ble/models/beacon.dart';
import 'package:app_primero_flutter_ble/models/beacon_mode.dart';
import 'package:app_primero_flutter_ble/models/house_map.dart';
import 'package:app_primero_flutter_ble/models/rssi_sample.dart';
import 'package:app_primero_flutter_ble/sources/rssi_source.dart';
import 'package:app_primero_flutter_ble/util/position_estimator.dart';

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

  /// Ambient drift timer used when the user is NOT driving the route manually
  /// and NOT in Real BLE mode. It animates the user around a small circle so
  /// the visualization feels alive even in the Etapa 1 single-static-waypoint
  /// scenario. Always disabled when [_waypoints.length] > 1 — multi-waypoint
  /// routes get their motion from [_timer] / [start].
  Timer? _driftTimer;
  int _driftStartMs = 0;
  bool _driftDisabled = false;

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
      // In Real BLE mode, BLE readings drive position; in Simulated mode,
      // ticks do. The `_rssiSource.current()` call above already refreshed
      // the snapshot for Simulated use; we only need the BLE branch here.
      if (_mode == BeaconMode.realBle) {
        _updatePositionFromBle();
      }
    });
    // Kick the ambient drift if the app booted straight into simulated
    // mode with a static waypoint (Etapa 1 default).
    _maybeStartDrift();
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
    _stopDrift();
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
    // Drift phase must restart from the waypoint so the next drift tick
    // begins at the room center, not at the previous drift phase.
    _driftStartMs = DateTime.now().millisecondsSinceEpoch;
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
      // In Real BLE mode, BLE readings drive position; in Simulated mode,
      // ticks do. The `_rssiSource.current()` call above already refreshed
      // the snapshot for Simulated use; we only need the BLE branch here.
      if (_mode == BeaconMode.realBle) {
        _updatePositionFromBle();
      }
    });
    notifyListeners();
    // Dispose the previous source last, so any errors don't break state.
    await old.dispose();
  }

  /// Updates the operating mode (Simulated vs Real BLE).
  ///
  /// When switching to Real BLE we stop the simulation timer (the user
  /// moves physically, not via timer) and immediately seed the user
  /// position from the current BLE snapshot so the map doesn't show a
  /// stale position from the simulated route.
  ///
  /// Switching back to Simulated does NOT auto-start the timer — the user
  /// must press "Iniciar" in the [ControlBar]. However, it DOES start the
  /// ambient drift (see [_driftTimer]) when the configured waypoint list is
  /// static (length 1), which is the Etapa 1 default.
  void setMode(BeaconMode newMode) {
    if (_mode == newMode) return;
    _mode = newMode;
    if (_mode == BeaconMode.realBle) {
      _timer?.cancel();
      _timer = null;
      _isRunning = false;
      _stopDrift();
      _updatePositionFromBle(); // seed from current BLE snapshot
    } else {
      _maybeStartDrift();
    }
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

  /// Stops the ambient drift loop so deterministic tests can pin the user
  /// to a fixed waypoint. Has no effect on multi-waypoint routes because
  /// those never start drift to begin with.
  @visibleForTesting
  void disableDrift() {
    _driftDisabled = true;
    _stopDrift();
  }

  // ---- Internals --------------------------------------------------------

  /// Back the user position out of the current BLE snapshot.
  ///
  /// Uses the strongest beacon (smallest reported distance) as the anchor
  /// and asks [estimatePositionFromSingleBeacon] for a position consistent
  /// with both that distance and the user's previous known location. No-op
  /// when the snapshot is empty or the strongest beacon is unknown to the
  /// configured [HouseMap].
  void _updatePositionFromBle() {
    _rssiSnapshot = _rssiSource.current();
    if (_rssiSnapshot.isEmpty) return;

    // Find the strongest beacon (smallest distance)
    final samples = _rssiSnapshot.values.toList()
      ..sort((a, b) => a.distance.compareTo(b.distance));
    final strongest = samples.first;
    final beacon = _houseMap.beaconById(strongest.beaconId);
    if (beacon == null) return;

    _userPosition = estimatePositionFromSingleBeacon(
      beaconPositionNormalized: beacon.position,
      distanceMeters: strongest.distance,
      roomScale: _houseMap.roomScale,
      lastKnownPositionNormalized: _userPosition,
      roomBoundsNormalized: _houseMap.bounds,
    );
    notifyListeners();
  }

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

  // ---- Drift ------------------------------------------------------------

  /// Whether the ambient drift loop should run right now.
  bool get _shouldDrift =>
      _mode == BeaconMode.simulated &&
      !_isRunning &&
      !_driftDisabled &&
      _waypoints.length <= 1;

  /// Starts the ambient drift loop when [_shouldDrift] holds. Idempotent —
  /// re-entering simulated mode while already drifting is a no-op.
  void _maybeStartDrift() {
    if (!_shouldDrift) return;
    if (_driftTimer != null) return;
    _driftStartMs = DateTime.now().millisecondsSinceEpoch;
    _driftTimer = Timer.periodic(
      const Duration(milliseconds: 33), // ~30 FPS
      (_) => _onDriftTick(),
    );
  }

  void _stopDrift() {
    _driftTimer?.cancel();
    _driftTimer = null;
  }

  /// Drift step: a slow circular motion around the configured room center
  /// (7 % of normalized space — small enough to stay inside any room).
  /// Full revolution every 6 seconds — deliberately slow.
  void _onDriftTick() {
    final center = Offset(0.5, _houseMap.bounds.height / 2);
    const radius = 0.07;
    final t = (DateTime.now().millisecondsSinceEpoch - _driftStartMs) / 6000.0;
    final newPos = Offset(
      center.dx + math.cos(t * 2 * math.pi) * radius,
      center.dy + math.sin(t * 2 * math.pi) * radius,
    );
    // Skip the notify if we're already there (e.g. first frame after a
    // reset with no clock advance) so we don't spam listeners.
    if ((newPos - _userPosition).distance < 1e-6) return;
    _userPosition = newPos;
    _rssiSource.updateUserPosition(_userPosition);
    _rssiSnapshot = _rssiSource.current();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopDrift();
    _sourceSub?.cancel();
    _rssiSource.dispose();
    super.dispose();
  }
}