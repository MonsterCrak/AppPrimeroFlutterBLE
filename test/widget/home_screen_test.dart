/// Widget tests for [HomeScreen] + [ModeSelector] + [ModeController].
///
/// Uses mocked [PermissionService], [SimulatedRssiSource], and
/// [BleRssiSource] so the transition between Simulated and Real BLE
/// can be exercised in isolation (no platform channels).
library;

import 'dart:async';

import 'package:app_primero_flutter_ble/models/house_map.dart';
import 'package:app_primero_flutter_ble/models/rssi_sample.dart';
import 'package:app_primero_flutter_ble/permissions/permission_service.dart';
import 'package:app_primero_flutter_ble/sources/ble_rssi_source.dart';
import 'package:app_primero_flutter_ble/sources/simulated_rssi_source.dart';
import 'package:app_primero_flutter_ble/state/mode_controller.dart';
import 'package:app_primero_flutter_ble/state/simulation_notifier.dart';
import 'package:app_primero_flutter_ble/view/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSimulatedRssiSource extends Mock implements SimulatedRssiSource {}

class _MockBleRssiSource extends Mock implements BleRssiSource {}

class _MockPermissionService extends Mock implements PermissionService {}

void main() {
  late HouseMap houseMap;
  late _MockSimulatedRssiSource simSource;
  late _MockBleRssiSource bleSource;
  late _MockPermissionService permissionService;
  late SimulationNotifier notifier;
  late ModeController modeController;

  setUpAll(() {
    registerFallbackValue(const Offset(0, 0));
  });

  setUp(() {
    houseMap = HouseMap.casaDemo();
    simSource = _MockSimulatedRssiSource();
    bleSource = _MockBleRssiSource();
    permissionService = _MockPermissionService();

    when(() => simSource.current()).thenReturn({
      for (final b in houseMap.beacons)
        b.id: RssiSample(beaconId: b.id, dbm: -70, distance: 1),
    });
    when(() => simSource.changes)
        .thenAnswer((_) => StreamController<void>.broadcast().stream);
    when(() => simSource.updateUserPosition(any())).thenReturn(null);
    when(() => simSource.dispose()).thenAnswer((_) async {});

    when(() => bleSource.current()).thenReturn({
      'B1': RssiSample(beaconId: 'B1', dbm: -55, distance: 2.0),
      'B2': RssiSample(beaconId: 'B2', dbm: -65, distance: 1.5),
      'B3': RssiSample(beaconId: 'B3', dbm: -75, distance: 3.0),
    });
    when(() => bleSource.changes)
        .thenAnswer((_) => StreamController<void>.broadcast().stream);
    when(() => bleSource.updateUserPosition(any())).thenReturn(null);
    when(() => bleSource.dispose()).thenAnswer((_) async {});
    when(() => bleSource.start()).thenAnswer((_) async => true);

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

  Widget app({ValueChanged<String>? onError}) => MaterialApp(
        home: HomeScreen(
          notifier: notifier,
          modeController: modeController,
          onError: onError,
        ),
      );

  Future<void> grantPermissions() async {
    when(() => permissionService.request()).thenAnswer(
      (_) async => const PermissionRequestResult(
        finalStatus: PermissionStatusReport(
          bluetoothGranted: true,
          locationGranted: true,
        ),
        somePermanentlyDenied: false,
      ),
    );
  }

  Future<void> denyPermissions({bool permanent = false}) async {
    when(() => permissionService.request()).thenAnswer(
      (_) async => PermissionRequestResult(
        finalStatus: PermissionStatusReport(
          bluetoothGranted: false,
          locationGranted: false,
        ),
        somePermanentlyDenied: permanent,
      ),
    );
  }

  testWidgets('HomeScreen arranca con MODO SIMULACIÓN y muestra el selector',
      (tester) async {
    await tester.pumpWidget(app());
    expect(find.text('MODO SIMULACIÓN'), findsOneWidget);
    expect(find.text('Simulación'), findsOneWidget);
    expect(find.text('Real BLE'), findsOneWidget);
    expect(find.text('Iniciar'), findsOneWidget);
  });

  testWidgets('Tap en Real BLE pide permisos y cambia el modo + el banner',
      (tester) async {
    await grantPermissions();
    await tester.pumpWidget(app());
    expect(find.text('MODO SIMULACIÓN'), findsOneWidget);

    await tester.tap(find.text('Real BLE'));
    // switchTo es async; usar runAsync para esperar el Future real.
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();

    verify(() => permissionService.request()).called(1);
    expect(notifier.mode.name, 'realBle');
    expect(find.text('MODO REAL BLE'), findsOneWidget);
  });

  testWidgets('Tap en Real BLE sin permisos vuelve a Simulated',
      (tester) async {
    await denyPermissions();
    await tester.pumpWidget(app());
    await tester.tap(find.text('Real BLE'));
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();

    expect(notifier.mode.name, 'simulated');
    expect(find.text('MODO SIMULACIÓN'), findsOneWidget);
  });

  testWidgets('Tap en Real BLE con permisos denegados dispara onError',
      (tester) async {
    await denyPermissions(permanent: true);
    String? captured;
    await tester.pumpWidget(app(onError: (msg) => captured = msg));

    await tester.tap(find.text('Real BLE'));
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured, contains('Bluetooth'));
  });

  testWidgets(
      'En modo Real BLE el botón Iniciar está oculto (usuario camina)',
      (tester) async {
    await grantPermissions();
    await tester.pumpWidget(app());

    await tester.tap(find.text('Real BLE'));
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();

    expect(find.text('Iniciar'), findsNothing);
    expect(find.text('Detener'), findsNothing);
  });

  testWidgets('Volver a Simulación restaura el botón Iniciar',
      (tester) async {
    await grantPermissions();
    await tester.pumpWidget(app());

    await tester.tap(find.text('Real BLE'));
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
    expect(find.text('Iniciar'), findsNothing);

    await tester.tap(find.text('Simulación'));
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
    expect(notifier.mode.name, 'simulated');
    expect(find.text('Iniciar'), findsOneWidget);
    expect(find.text('MODO SIMULACIÓN'), findsOneWidget);
  });

  testWidgets('El source real (BLE) reemplaza al simulado en el notifier',
      (tester) async {
    await grantPermissions();
    await tester.pumpWidget(app());

    expect(notifier.rssiSource, same(simSource));
    await tester.tap(find.text('Real BLE'));
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
    expect(notifier.rssiSource, same(bleSource));
    verify(() => simSource.dispose()).called(1);
  });

  testWidgets('Cambiar al mismo modo no pide permisos (no-op)',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('Simulación'));
    await tester.pumpAndSettle();
    verifyNever(() => permissionService.request());
    expect(notifier.mode.name, 'simulated');
  });
}