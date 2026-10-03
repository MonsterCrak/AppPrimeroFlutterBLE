/// Widget tests for [HomeScreen] tab structure + tab-specific smoke tests.
///
/// The legacy tests used to drive the mode selector / start-stop button
/// inside a single column view. After WU-19 the simulation view is
/// hidden and the home screen exposes two tabs (Scanner / Cuarto). These
/// tests cover the new structure: tabs are present, default tab is the
/// Scanner, switching to Cuarto swaps the body, and the Scanner tab
/// shows the BLE status card.
library;

import 'dart:async';

import 'package:app_primero_flutter_ble/models/house_map.dart';
import 'package:app_primero_flutter_ble/models/rssi_sample.dart';
import 'package:app_primero_flutter_ble/permissions/permission_service.dart';
import 'package:app_primero_flutter_ble/sources/beacon_scanner_api.dart';
import 'package:app_primero_flutter_ble/sources/ble_error.dart';
import 'package:app_primero_flutter_ble/sources/ble_rssi_source.dart';
import 'package:app_primero_flutter_ble/sources/simulated_rssi_source.dart';
import 'package:app_primero_flutter_ble/state/mode_controller.dart';
import 'package:app_primero_flutter_ble/state/simulation_notifier.dart';
import 'package:app_primero_flutter_ble/view/home_screen.dart';
import 'package:dchs_flutter_beacon/dchs_flutter_beacon.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class _MockSimulatedRssiSource extends Mock implements SimulatedRssiSource {}

class _MockBleRssiSource extends Mock implements BleRssiSource {}

class _MockPermissionService extends Mock implements PermissionService {}

class _MockBeaconScannerApi extends Mock implements BeaconScannerApi {}

void main() {
  late HouseMap houseMap;
  late _MockSimulatedRssiSource simSource;
  late _MockBleRssiSource bleSource;
  late _MockPermissionService permissionService;
  late _MockBeaconScannerApi bleApi;
  late SimulationNotifier notifier;
  late ModeController modeController;

  setUpAll(() {
    registerFallbackValue(const Offset(0, 0));
    registerFallbackValue(<fb.Region>[]);
    registerFallbackValue(StreamController<void>.broadcast().stream);
  });

  setUp(() {
    houseMap = HouseMap.cuartoPracticaUno();
    simSource = _MockSimulatedRssiSource();
    bleSource = _MockBleRssiSource();
    permissionService = _MockPermissionService();
    bleApi = _MockBeaconScannerApi();

    when(() => simSource.current()).thenReturn({
      'B1': RssiSample(beaconId: 'B1', dbm: -55, distance: 2.0),
    });
    when(() => simSource.changes)
        .thenAnswer((_) => StreamController<void>.broadcast().stream);
    when(() => simSource.updateUserPosition(any())).thenReturn(null);
    when(() => simSource.dispose()).thenAnswer((_) async {});

    when(() => bleSource.current()).thenReturn({
      'B1': RssiSample(beaconId: 'B1', dbm: -55, distance: 2.0),
    });
    when(() => bleSource.errors)
        .thenAnswer((_) => StreamController<BleError>.broadcast().stream);
    when(() => bleSource.changes)
        .thenAnswer((_) => StreamController<void>.broadcast().stream);
    when(() => bleSource.updateUserPosition(any())).thenReturn(null);
    when(() => bleSource.dispose()).thenAnswer((_) async {});
    when(() => bleSource.start()).thenAnswer((_) async => true);

    when(() => bleApi.bluetoothState())
        .thenAnswer((_) async => fb.BluetoothState.stateOn);
    when(() => bleApi.initializeAndCheckScanning())
        .thenAnswer((_) async => true);
    when(() => bleApi.ranging(any()))
        .thenAnswer((_) => StreamController<fb.RangingResult>.broadcast().stream);

    // Permission check returns granted by default (used by Scanner screen
    // on initState).
    when(() => permissionService.check()).thenAnswer(
      (_) async => const PermissionStatusReport(
        bluetoothScanGranted: true,
          bluetoothConnectGranted: true,
        locationGranted: true,
      ),
    );
    when(() => permissionService.request()).thenAnswer(
      (_) async => PermissionRequestResult.granted(
        const PermissionStatusReport(
          bluetoothScanGranted: true,
          bluetoothConnectGranted: true,
          locationGranted: true,
        ),
      ),
    );

    notifier = SimulationNotifier(
      rssiSource: simSource,
      houseMap: houseMap,
    );
    modeController = ModeController(
      notifier: notifier,
      permissionService: permissionService,
      createSimulated: (_) => simSource,
      createBle: () => bleSource,
    );
  });

  tearDown(() {
    if (notifier.isRunning) notifier.stop();
    notifier.dispose();
    modeController.dispose();
  });

  Widget app() => MaterialApp(
        home: TickerMode(
          // Disable repeating tickers (beacon pulse, scanning pulse dot)
          // so pumpAndSettle can settle.
          enabled: false,
          child: ChangeNotifierProvider<SimulationNotifier>.value(
            value: notifier,
            child: HomeScreen(
              notifier: notifier,
              modeController: modeController,
              permissionService: permissionService,
            ),
          ),
        ),
      );

  /// Drains pending Timers and any leaked 0-duration FakeTimers from
  /// flutter_animate (which fires a `Future.delayed(Duration.zero, _play)`
  /// on every `.animate()` mount).
  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump(Duration.zero);
    await tester.pump(Duration.zero);
  }

  testWidgets('HomeScreen arranca en la pestaña Scanner', (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);

    // Bottom nav has both tabs.
    expect(find.text('Scanner'), findsOneWidget);
    expect(find.text('Cuarto'), findsOneWidget);

    // Scanner content is visible: status card section header.
    expect(find.text('ESTADO BLE'), findsOneWidget);
    expect(find.text('BALIZAS DETECTADAS'), findsOneWidget);

    // Cuarto content is NOT visible (IndexedStack hides it).
    expect(find.text('B1 sin señal'), findsNothing);
  });

  testWidgets('Tap en Cuarto cambia la pestaña activa', (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);

    // Initially on Scanner.
    expect(find.text('ESTADO BLE'), findsOneWidget);
    expect(find.text('B1 sin señal'), findsNothing);

    await tester.tap(find.text('Cuarto'));
    await tester.pumpAndSettle();

    // Now Cuarto is visible: room title.
    expect(find.text('Cuarto 1'), findsOneWidget);
    expect(find.text('3.0 × 2.6 m'), findsOneWidget);
  });

  testWidgets('No hay controles de simulación en la UI', (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);

    // No mode selector, no Iniciar button, no legend.
    expect(find.text('Iniciar'), findsNothing);
    expect(find.text('Detener'), findsNothing);
    expect(find.text('Reset'), findsNothing);
    expect(find.text('Simulación'), findsNothing);
    expect(find.text('MODO SIMULACIÓN'), findsNothing);
  });

  testWidgets('HomeScreen.initState arranca el modo Real BLE', (tester) async {
    await tester.pumpWidget(app());
    // The post-frame callback fires after the first frame.
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await settle(tester);

    verify(() => permissionService.request()).called(1);
    expect(notifier.mode.name, 'realBle');
    // The badge in the AppBar shows REAL BLE.
    expect(find.text('REAL BLE'), findsWidgets);
  });
}
