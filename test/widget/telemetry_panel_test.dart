/// Widget tests for [TelemetryPanel].
library;

import 'dart:async';

import 'package:app_primero_flutter_ble/models/house_map.dart';
import 'package:app_primero_flutter_ble/models/rssi_sample.dart';
import 'package:app_primero_flutter_ble/sources/rssi_source.dart';
import 'package:app_primero_flutter_ble/state/simulation_notifier.dart';
import 'package:app_primero_flutter_ble/view/widgets/telemetry_panel.dart';
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
      'B1': RssiSample(beaconId: 'B1', dbm: -60, distance: 5),
      'B2': RssiSample(beaconId: 'B2', dbm: -70, distance: 1),
      'B3': RssiSample(beaconId: 'B3', dbm: -80, distance: 3),
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

  tearDown(() => notifier.dispose());

  Future<void> pumpPanel(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TelemetryPanel(notifier: notifier),
        ),
      ),
    );
  }

  testWidgets('muestra la posicion del usuario', (tester) async {
    await pumpPanel(tester);
    expect(find.textContaining('Pos:'), findsOneWidget);
  });

  testWidgets('muestra el titulo Telemetria', (tester) async {
    await pumpPanel(tester);
    expect(find.text('Telemetría'), findsOneWidget);
  });

  testWidgets('muestra 3 beacons (top-N default)', (tester) async {
    await pumpPanel(tester);
    expect(find.textContaining('Sala-A'), findsOneWidget);
    expect(find.textContaining('Pasillo'), findsOneWidget);
    expect(find.textContaining('Habitacion'), findsOneWidget);
  });

  testWidgets('los beacons se muestran ordenados por distancia (B2 primero)',
      (tester) async {
    await pumpPanel(tester);
    final pasilloY = tester.getTopLeft(find.textContaining('Pasillo')).dy;
    final salaAY = tester.getTopLeft(find.textContaining('Sala-A')).dy;
    // Pasillo (dist=1) debe estar arriba de Sala-A (dist=5).
    expect(pasilloY, lessThan(salaAY));
  });

  testWidgets('cada fila incluye dBm con formato -XX', (tester) async {
    await pumpPanel(tester);
    expect(find.textContaining('-60 dBm'), findsOneWidget);
    expect(find.textContaining('-70 dBm'), findsOneWidget);
    expect(find.textContaining('-80 dBm'), findsOneWidget);
  });

  testWidgets('si topN=2 muestra solo los 2 mas cercanos', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TelemetryPanel(notifier: notifier, topN: 2),
        ),
      ),
    );
    // Pasillo (dist=1) y Habitacion (dist=3) son los 2 mas cercanos.
    expect(find.textContaining('Pasillo'), findsOneWidget);
    expect(find.textContaining('Habitacion'), findsOneWidget);
    expect(find.textContaining('Sala-A'), findsNothing);
  });

  testWidgets('si no hay beacons muestra mensaje vacio', (tester) async {
    when(() => mockSource.current()).thenReturn(const <String, RssiSample>{});
    // Forzar refresco del notifier
    notifier.setUserPosition(const Offset(0.5, 0.5));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TelemetryPanel(notifier: notifier),
        ),
      ),
    );
    expect(find.text('— sin beacons detectados —'), findsOneWidget);
  });
}