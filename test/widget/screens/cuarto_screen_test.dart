/// Widget tests for [CuartoScreen].
library;

import 'dart:async';

import 'package:app_primero_flutter_ble/models/house_map.dart';
import 'package:app_primero_flutter_ble/models/rssi_sample.dart';
import 'package:app_primero_flutter_ble/permissions/permission_service.dart';
import 'package:app_primero_flutter_ble/sources/ble_error.dart';
import 'package:app_primero_flutter_ble/sources/ble_rssi_source.dart';
import 'package:app_primero_flutter_ble/sources/simulated_rssi_source.dart';
import 'package:app_primero_flutter_ble/state/mode_controller.dart';
import 'package:app_primero_flutter_ble/state/simulation_notifier.dart';
import 'package:app_primero_flutter_ble/view/screens/cuarto_screen.dart';
import 'package:app_primero_flutter_ble/view/widgets/map_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

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
    houseMap = HouseMap.cuartoPracticaUno();
    simSource = _MockSimulatedRssiSource();
    bleSource = _MockBleRssiSource();
    permissionService = _MockPermissionService();

    when(() => simSource.current()).thenReturn(const {});
    when(() => simSource.changes)
        .thenAnswer((_) => StreamController<void>.broadcast().stream);
    when(() => simSource.updateUserPosition(any())).thenReturn(null);
    when(() => simSource.dispose()).thenAnswer((_) async {});

    when(() => bleSource.current()).thenReturn(const {});
    when(() => bleSource.errors)
        .thenAnswer((_) => StreamController<BleError>.broadcast().stream);
    when(() => bleSource.changes)
        .thenAnswer((_) => StreamController<void>.broadcast().stream);
    when(() => bleSource.updateUserPosition(any())).thenReturn(null);
    when(() => bleSource.dispose()).thenAnswer((_) async {});

    when(() => permissionService.check()).thenAnswer(
      (_) async => const PermissionStatusReport(
        bluetoothScanGranted: true,
          bluetoothConnectGranted: true,
        locationGranted: true,
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

  Widget app({Widget? child}) => MaterialApp(
        home: TickerMode(
          // MapCanvas pulses the beacon — disable for deterministic tests.
          enabled: false,
          child: ChangeNotifierProvider<SimulationNotifier>.value(
            value: notifier,
            child: child ?? CuartoScreen(notifier: notifier),
          ),
        ),
      );

  testWidgets('Cuarto renderiza con map canvas + título + dimensiones',
      (tester) async {
    when(() => simSource.current()).thenReturn(const {});

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // Header.
    expect(find.text('Cuarto 1'), findsOneWidget);
    expect(find.text('3.0 × 2.6 m'), findsOneWidget);

    // Map canvas present.
    expect(find.byType(MapCanvas), findsOneWidget);
  });

  testWidgets('Cuarto muestra "B1 sin señal" cuando no hay beacons',
      (tester) async {
    when(() => simSource.current()).thenReturn(const {});

    // Use a tall viewport so the distance strip below the canvas is
    // visible without scrolling.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Cuarto 1'), findsOneWidget);
    expect(find.text('B1 sin señal'), findsOneWidget);
  });

  testWidgets('Cuarto muestra la distancia al beacon más cercano',
      (tester) async {
    when(() => simSource.current()).thenReturn({
      'B1': RssiSample(beaconId: 'B1', dbm: -60, distance: 3.4),
    });

    // Use a tall viewport so the distance strip below the canvas is
    // visible without scrolling.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.textContaining('B1 detectado a'), findsOneWidget);
    // "3.4 m" is part of the "B1 detectado a 3.4 m" Text widget.
    expect(find.textContaining('3.4 m'), findsOneWidget);
    expect(find.text('-60 dBm'), findsOneWidget);
  });

  testWidgets('Cuarto no muestra controles de simulación', (tester) async {
    when(() => simSource.current()).thenReturn(const {});

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Iniciar'), findsNothing);
    expect(find.text('Detener'), findsNothing);
    expect(find.text('Reset'), findsNothing);
    expect(find.text('Simulación'), findsNothing);
  });
}
