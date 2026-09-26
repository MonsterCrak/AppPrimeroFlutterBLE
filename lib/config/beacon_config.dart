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
  ///   Minor 1 → B1 "Sala-A"
  ///   Minor 2 → B2 "Pasillo"
  ///   Minor 3 → B3 "Habitacion"
  static const Map<int, String> minorToBeaconId = {
    1: 'B1',
    2: 'B2',
    3: 'B3',
  };

  /// Default physical position of each beacon in normalized [0, 1] coords.
  ///
  /// Coordinates derived from the user's SVG floorplan (viewBox 450 x 850):
  ///   - B1 "Sala":     SVG (280, 70)   → norm (0.622, 0.082)
  ///   - B2 "Pasadizo": SVG (140, 400)  → norm (0.311, 0.471)
  ///   - B3 "Padres":   SVG (270, 690)  → norm (0.600, 0.812)
  ///
  /// Used by the simulated source; real BLE scanner will use whatever the
  /// scanner reports (or manual mapping assigned later).
  static const Map<String, Offset> defaultPositions = {
    'B1': Offset(0.622, 0.082),
    'B2': Offset(0.311, 0.471),
    'B3': Offset(0.600, 0.812),
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