/// Operating mode for RSSI acquisition.
///
/// The app can run in two interchangeable modes:
/// - [simulated]: RSSI is computed from a mathematical model. No hardware,
///   no permissions. Default mode.
/// - [realBle]: RSSI comes from real BLE scan via flutter_blue_plus. Requires
///   Bluetooth + location permissions and physical Feasycom FSC-BP104D beacons.
library;

enum BeaconMode {
  simulated,
  realBle,
}