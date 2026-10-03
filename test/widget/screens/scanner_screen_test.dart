/// Widget tests for [ScannerScreen].
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
import 'package:app_primero_flutter_ble/view/screens/scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class _MockBleRssiSource extends Mock implements BleRssiSource {}

class _MockSimulatedRssiSource extends Mock implements SimulatedRssiSource {}

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
    when(() => bleSource.start()).thenAnswer((_) async => true);

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
          // Disable repeating tickers (scanning pulse dot, etc.) so
          // pumpAndSettle can settle.
          enabled: false,
          child: ChangeNotifierProvider<SimulationNotifier>.value(
            value: notifier,
            child: child ??
                ScannerScreen(
                  notifier: notifier,
                  modeController: modeController,
                  permissionService: permissionService,
                ),
          ),
        ),
      );

  testWidgets('Scanner renderiza con lista de beacons vacía', (tester) async {
    when(() => simSource.current()).thenReturn(const {});

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.pump(Duration.zero);

    // Status card title visible (uppercased by SectionHeader).
    expect(find.text('ESTADO BLE'), findsOneWidget);
    // Section header visible (uppercased).
    expect(find.text('BALIZAS DETECTADAS'), findsOneWidget);
    // Empty state copy visible.
    expect(find.text('Sin beacons detectados en rango'), findsOneWidget);
  });

  testWidgets('Scanner muestra beacons cuando el snapshot tiene datos',
      (tester) async {
    when(() => simSource.current()).thenReturn({
      'B1': RssiSample(beaconId: 'B1', dbm: -55, distance: 2.0),
      'B2': RssiSample(beaconId: 'B2', dbm: -85, distance: 5.0),
    });

    await tester.pumpWidget(app());
    await tester.pump();

    // Both beacons render their ID badge.
    expect(find.text('B1'), findsOneWidget);
    expect(find.text('B2'), findsOneWidget);

    // RSSI shown.
    expect(find.text('-55 dBm'), findsOneWidget);
    expect(find.text('-85 dBm'), findsOneWidget);

    // Distance shown (meters, 1 decimal).
    expect(find.text('2.0 m'), findsOneWidget);
    expect(find.text('5.0 m'), findsOneWidget);

    // Empty state should NOT be shown.
    expect(find.text('Sin beacons detectados en rango'), findsNothing);
  });

  testWidgets(
      'Scanner muestra la sección de último error con acción de Settings',
      (tester) async {
    // Use a much taller viewport so all three sections (status card +
    // beacons list + last-error card) fit on screen at once.
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.pump(Duration.zero);

    // Initially no error section.
    expect(find.text('ÚLTIMO ERROR'), findsNothing);

    // Inject a permanent-permission error through the controller stream.
    modeController.errors.add(BleError.permissionDenied(permanent: true));
    // Drain the stream: the subscription is microtask-delayed.
    await tester.pump();
    await tester.pump(Duration.zero);

    expect(find.text('ÚLTIMO ERROR'), findsOneWidget);
    // The Settings CTA is a TextButton.icon — the icon factory returns
    // an internal wrapper, so we search for both the text label and the
    // settings icon to confirm the CTA is mounted.
    expect(find.text('Settings'), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });

  testWidgets('Scanner refleja los permisos chequeados en el status card',
      (tester) async {
    when(() => permissionService.check()).thenAnswer(
      (_) async => const PermissionStatusReport(
        bluetoothScanGranted: false,
          bluetoothConnectGranted: false,
        locationGranted: true,
      ),
    );

    await tester.pumpWidget(app());
    // Wait for the async check() to complete.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();

    // Permission label shows "Pendientes" when not granted.
    expect(find.text('Pendientes'), findsOneWidget);
  });
}
