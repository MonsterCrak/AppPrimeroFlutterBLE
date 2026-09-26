/// Widget tests for [ControlBar].
library;

import 'dart:async';

import 'package:app_primero_flutter_ble/models/house_map.dart';
import 'package:app_primero_flutter_ble/models/rssi_sample.dart';
import 'package:app_primero_flutter_ble/sources/rssi_source.dart';
import 'package:app_primero_flutter_ble/state/simulation_notifier.dart';
import 'package:app_primero_flutter_ble/view/widgets/control_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRssiSource extends Mock implements RssiSource {}

void main() {
  late HouseMap houseMap;
  late _MockRssiSource mockSource;
  late SimulationNotifier notifier;

  setUpAll(() {
    registerFallbackValue(const Offset(0, 0));
  });

  setUp(() {
    houseMap = HouseMap.casaDemo();
    mockSource = _MockRssiSource();
    when(() => mockSource.current()).thenReturn({
      for (final b in houseMap.beacons)
        b.id: RssiSample(beaconId: b.id, dbm: -70, distance: 1),
    });
    when(() => mockSource.changes)
        .thenAnswer((_) => StreamController<void>.broadcast().stream);
    when(() => mockSource.updateUserPosition(any())).thenReturn(null);
    when(() => mockSource.dispose()).thenAnswer((_) async {});
    notifier = SimulationNotifier(
      rssiSource: mockSource,
      houseMap: houseMap,
    );
  });

  tearDown(() {
    if (notifier.isRunning) notifier.stop();
    notifier.dispose();
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ControlBar(notifier: notifier)),
        ),
      );

  testWidgets('label inicial es "Iniciar"', (tester) async {
    await pump(tester);
    expect(find.text('Iniciar'), findsOneWidget);
    expect(find.text('Detener'), findsNothing);
  });

  testWidgets('tap en "Iniciar" cambia label a "Detener" y arranca timer',
      (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('start-stop-button')));
    await tester.pump();
    expect(find.text('Detener'), findsOneWidget);
    expect(notifier.isRunning, isTrue);
    notifier.stop();
  });

  testWidgets('tap en "Detener" cambia label a "Iniciar" y para timer',
      (tester) async {
    await pump(tester);
    // Start
    await tester.tap(find.byKey(const ValueKey('start-stop-button')));
    await tester.pump();
    // Stop
    await tester.tap(find.byKey(const ValueKey('start-stop-button')));
    await tester.pump();
    expect(find.text('Iniciar'), findsOneWidget);
    expect(notifier.isRunning, isFalse);
  });

  testWidgets('muestra boton Reset cuando se pasa onReset', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ControlBar(notifier: notifier, onReset: () {}),
        ),
      ),
    );
    expect(find.text('Reset'), findsOneWidget);
  });

  testWidgets('tap en Reset llama al callback', (tester) async {
    var resetCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ControlBar(
            notifier: notifier,
            onReset: () => resetCalls++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(resetCalls, 1);
  });
}