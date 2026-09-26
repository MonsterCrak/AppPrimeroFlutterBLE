/// Abstraction over `flutter_beacon` for unit tests.
///
/// In production, [FlutterBeaconApi] wraps the singleton. In tests, a mock
/// can be injected to avoid platform channels.
library;

import 'dart:async';

import 'package:dchs_flutter_beacon/dchs_flutter_beacon.dart' as fb;

abstract class BeaconScannerApi {
  /// Init the library + check all required permissions.
  /// Returns true if scanning is allowed.
  Future<bool> initializeAndCheckScanning();

  /// Open a stream of ranging results for the given regions.
  Stream<fb.RangingResult> ranging(List<fb.Region> regions);
}

class FlutterBeaconApi implements BeaconScannerApi {
  @override
  Future<bool> initializeAndCheckScanning() {
    return fb.flutterBeacon.initializeAndCheckScanning;
  }

  @override
  Stream<fb.RangingResult> ranging(List<fb.Region> regions) {
    return fb.flutterBeacon.ranging(regions);
  }
}