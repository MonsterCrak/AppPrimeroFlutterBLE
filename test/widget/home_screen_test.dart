/// Widget tests for [HomeScreen].
///
/// Validates the integration of map + telemetry + control bar + mode badge.
library;

import 'dart:async';

import 'package:app_primero_flutter_ble/models/house_map.dart';
import 'package:app_primero_flutter_ble/models/rssi_sample.dart';
import 'package:app_primero_flutter_ble/sources/rssi_source.dart';
import 'package:app_primero_flutter_ble/state/simulation_notifier.dart';
import 'package:app_primero_flutter_ble/view/home_screen.dart';
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

  Widget app() => MaterialApp(
        home: HomeScreen(notifier: notifier),
      );

  testWidgets('HomeScreen renderiza AppBar y titulo', (tester) async {
    await tester.pumpWidget(app());
    expect(find.text('Emulador BLE Indoor'), findsOneWidget);
  });

  testWidgets('muestra el badge de modo SIMULACIÓN', (tester) async {
    await tester.pumpWidget(app());
    expect(find.text('MODO SIMULACIÓN'), findsOneWidget);
  });

  testWidgets('muestra la leyenda con Baliza, Usuario y Ruta', (tester) async {
    await tester.pumpWidget(app());
    expect(find.text('Baliza'), findsOneWidget);
    expect(find.text('Usuario'), findsOneWidget);
    expect(find.text('Ruta'), findsOneWidget);
  });

  testWidgets('muestra el panel de telemetria con sus beacons', (tester) async {
    await tester.pumpWidget(app());
    expect(find.text('Telemetría'), findsOneWidget);
    expect(find.textContaining('Sala-A'), findsOneWidget);
    expect(find.textContaining('Pasillo'), findsOneWidget);
    expect(find.textContaining('Habitacion'), findsOneWidget);
  });

  testWidgets('muestra el boton Iniciar inicialmente', (tester) async {
    await tester.pumpWidget(app());
    expect(find.text('Iniciar'), findsOneWidget);
  });

  testWidgets('tap en Iniciar cambia a Detener y arranca timer', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('Iniciar'));
    await tester.pump();
    expect(find.text('Detener'), findsOneWidget);
    expect(notifier.isRunning, isTrue);
    notifier.stop();
  });

  testWidgets('muestra el boton Reset', (tester) async {
    await tester.pumpWidget(app());
    expect(find.text('Reset'), findsOneWidget);
  });
}