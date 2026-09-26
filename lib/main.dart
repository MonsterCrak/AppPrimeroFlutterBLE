/// Entrypoint: builds the [SimulationNotifier] with a [SimulatedRssiSource]
/// and mounts the [HomeScreen].
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app_primero_flutter_ble/models/house_map.dart';
import 'package:app_primero_flutter_ble/sources/simulated_rssi_source.dart';
import 'package:app_primero_flutter_ble/state/simulation_notifier.dart';
import 'package:app_primero_flutter_ble/view/home_screen.dart';

void main() {
  runApp(const AppPrimeroFlutterBleApp());
}

class AppPrimeroFlutterBleApp extends StatelessWidget {
  const AppPrimeroFlutterBleApp({super.key});

  @override
  Widget build(BuildContext context) {
    // El estado se construye una sola vez (es Singleton para esta app).
    // Cambiar la fuente aqui cambia el modo por defecto.
    final houseMap = HouseMap.casaDemo();
    final rssiSource = SimulatedRssiSource(beacons: houseMap.beacons);
    final notifier = SimulationNotifier(
      rssiSource: rssiSource,
      houseMap: houseMap,
    );

    return ChangeNotifierProvider<SimulationNotifier>.value(
      value: notifier,
      child: MaterialApp(
        title: 'Emulador BLE Indoor',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
        ),
        home: HomeScreen(notifier: notifier),
      ),
    );
  }
}