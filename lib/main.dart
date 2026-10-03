/// Entrypoint: builds the [SimulationNotifier] backed by [BleRssiSource]
/// (Real BLE mode is the default for this app) and mounts the [HomeScreen]
/// along with a [ModeController] for swapping RSSI sources.
///
/// Etapa 2 (WU-19): the simulation view is hidden from the UI but its
/// code is kept for tests; the app boots directly into Real BLE.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app_primero_flutter_ble/models/house_map.dart';
import 'package:app_primero_flutter_ble/permissions/permission_service.dart';
import 'package:app_primero_flutter_ble/sources/ble_rssi_source.dart';
import 'package:app_primero_flutter_ble/state/mode_controller.dart';
import 'package:app_primero_flutter_ble/state/simulation_notifier.dart';
import 'package:app_primero_flutter_ble/view/home_screen.dart';
import 'package:app_primero_flutter_ble/view/theme/app_theme.dart';

void main() {
  runApp(const AppPrimeroFlutterBleApp());
}

class AppPrimeroFlutterBleApp extends StatelessWidget {
  const AppPrimeroFlutterBleApp({super.key});

  @override
  Widget build(BuildContext context) {
    // State is constructed once (singleton-style for this app).
    //
    // Etapa 2 (WU-19): the app starts in Real BLE. We still wire up a
    // real [BleRssiSource] through the notifier so the simulator type
    // matches the public API; the [ModeController] is also constructed
    // here so HomeScreen can swap if ever needed.
    final houseMap = HouseMap.cuartoPracticaUno();
    final rssiSource = BleRssiSource();
    final notifier = SimulationNotifier(
      rssiSource: rssiSource,
      houseMap: houseMap,
    );
    final permissionService = SystemPermissionService();
    final modeController = ModeController(
      notifier: notifier,
      permissionService: permissionService,
    );

    return ChangeNotifierProvider<SimulationNotifier>.value(
      value: notifier,
      child: MaterialApp(
        title: 'Emulador BLE Indoor',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            primary: AppColors.primary,
            surface: AppColors.background,
          ),
          scaffoldBackgroundColor: AppColors.background,
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
          ),
          textTheme: const TextTheme(
            bodyMedium: TextStyle(color: AppColors.textPrimary),
            bodySmall: TextStyle(color: AppColors.textMuted),
            titleLarge: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        home: HomeScreen(
          notifier: notifier,
          modeController: modeController,
          permissionService: permissionService,
        ),
      ),
    );
  }
}
