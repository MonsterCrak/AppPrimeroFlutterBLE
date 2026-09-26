/// Hardware configuration of the 3 FSC-BP104D beacons.
///
/// Confirmed via Feasycom official app. Beacons are now in pure iBeacon mode
/// (Eddystone tramas disabled).
///
/// > **Note on iOS compatibility:** the iBeacon format is an Apple-proprietary
/// > protocol, but the BLE advertisement structure is a standard that any
/// > modern device (Android with the right API, iOS with CoreLocation) knows
/// > how to decode. The hardware setup here is platform-agnostic — **no
/// > physical changes needed to work on iOS**. The only thing that changes
/// > between platforms is software: iOS forces the app to use CoreLocation
/// > (a plugin like `flutter_beacon`) and to request location permissions
/// > in `Info.plist`. See `docs/DEPLOY_BEACONS.md` for details.
library;

import 'dart:ui' show Offset;

import 'package:app_primero_flutter_ble/models/beacon.dart';

class BeaconConfig {
  /// iBeacon Proximity UUID. Standard 128-bit Apple identifier for the
  /// "deployment". All 3 beacons share the same UUID.
  static const String proximityUuid = 'fda50693-a4e2-4fb1-afcf-c6eb07647825';

  /// Major common to all 3 beacons.
  static const int major = 10065;

  /// Calibrated RSSI at 1 meter for all 3 beacons (set in Feasycom app).
  static const int txPowerDbm = -59;

  /// Apple manufacturer ID used in BLE advertisements.
  static const int appleManufacturerId = 0x004C;

  /// iBeacon advertisement opcode byte.
  static const int iBeaconOpcode = 0x02;

  /// Mapping from Minor → logical beacon id used by the app (B1, B2, B3).
  ///
  /// Minor values assigned by the user via the Feasycom app:
  ///   Minor 1 → B1 "Sala"
  ///   Minor 2 → B2 "Mi cuarto"
  ///   Minor 3 → B3 "Hermano"
  static const Map<int, String> minorToBeaconId = {
    1: 'B1',
    2: 'B2',
    3: 'B3',
  };

  /// Suggested names to assign in the FeasyBeacon app for human
  /// identification of each physical beacon. These names are stored in
  /// the beacon's local memory ONLY — they do NOT travel in BLE
  /// advertisements, so the app cannot see them. They help the user
  /// tell the 3 physically identical beacons apart when configuring or
  /// replacing batteries.
  ///
  /// Keep them short (≤15 chars) and ASCII — FeasyBeacon firmware
  /// enforces these limits.
  static const Map<String, String> feasyBeaconNames = {
    'B1': 'FB104-Sala',
    'B2': 'FB104-MiCuarto',
    'B3': 'FB104-Hermano',
  };

/// Default physical position of each beacon in normalized [0, 1] coords.
///
/// Distribution chosen by the user to maximize trianglulation coverage:
///   - B1 "Sala":      SVG (220, 280)  → norm (0.489, 0.329) — near west
///                      wall of Sala (by the door to the pasadizo).
///   - B2 "Mi cuarto": SVG (380, 460)  → norm (0.844, 0.541) — east wall of
///                      Mi cuarto.
///   - B3 "Hermano":   SVG (40, 720)   → norm (0.089, 0.847) — west wall of
///                      Cuarto Hermano.
///
/// The 3 positions form a roughly equilateral triangle (~0.41-0.82
/// normalized side lengths), which gives the trilateration algorithm
/// the best numeric conditioning.
  static const Map<String, Offset> defaultPositions = {
    'B1': Offset(0.489, 0.329),
    'B2': Offset(0.844, 0.541),
    'B3': Offset(0.089, 0.847),
  };

  /// Builds the list of configured beacons (used by SimulatedRssiSource and
  /// as defaults for BleRssiSource).
  static List<Beacon> buildBeacons() {
    return [
      for (final entry in defaultPositions.entries)
        Beacon(
          id: entry.key,
          label: _labelFor(entry.key),
          position: entry.value,
          txPower: txPowerDbm.toDouble(),
        ),
    ];
  }

  static String _labelFor(String id) {
    switch (id) {
      case 'B1':
        return 'Sala';
      case 'B2':
        return 'Pasadizo';
      case 'B3':
        return 'Padres';
      default:
        return id;
    }
  }

  /// Resolves a beacon id from an iBeacon Major+Minor pair.
  ///
  /// Returns null if the Minor is not in the configured set.
  static String? beaconIdForIBeacon(int majorValue, int minorValue) {
    if (majorValue != major) return null;
    return minorToBeaconId[minorValue];
  }
}