/// Entrypoint: builds the [SimulationNotifier] with a [SimulatedRssiSource]
/// and mounts the [HomeScreen] along with a [ModeController] for swapping
/// between simulated and real BLE sources.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app_primero_flutter_ble/config/beacon_config.dart';
import 'package:app_primero_flutter_ble/models/house_map.dart';
import 'package:app_primero_flutter_ble/permissions/permission_service.dart';
import 'package:app_primero_flutter_ble/sources/simulated_rssi_source.dart';
import 'package:app_primero_flutter_ble/state/mode_controller.dart';
import 'package:app_primero_flutter_ble/state/simulation_notifier.dart';
import 'package:app_primero_flutter_ble/view/home_screen.dart';

void main() {
  runApp(const AppPrimeroFlutterBleApp());
}

class AppPrimeroFlutterBleApp extends StatelessWidget {
  const AppPrimeroFlutterBleApp({super.key});

  @override
  Widget build(BuildContext context) {
    // State is constructed once (singleton-style for this app).
    final houseMap = HouseMap.miCasa().copyWith(
      beacons: BeaconConfig.buildBeacons(),
    );
    final rssiSource = SimulatedRssiSource(beacons: houseMap.beacons);
    final notifier = SimulationNotifier(
      rssiSource: rssiSource,
      houseMap: houseMap,
    );
    final modeController = ModeController(
      notifier: notifier,
      permissionService: SystemPermissionService(),
    );

    return ChangeNotifierProvider<SimulationNotifier>.value(
      value: notifier,
      child: MaterialApp(
        title: 'Emulador BLE Indoor',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
        ),
        home: HomeScreen(
          notifier: notifier,
          modeController: modeController,
        ),
      ),
    );
  }
}