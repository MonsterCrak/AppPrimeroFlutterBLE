/// Tests for the house rendering pipeline.
///
/// - `shouldRepaint_cambiaConDatos`: verifies the painter invalidates when the
///   underlying map changes.
/// - `noLanzaConDatosValidos`: verifies the painter can render without throwing.
/// - `golden_matcheaReferencia`: ensures the rendered map stays visually stable.
library;

import 'dart:ui' as ui;

import 'package:app_primero_flutter_ble/models/beacon.dart';
import 'package:app_primero_flutter_ble/models/house_map.dart';
import 'package:app_primero_flutter_ble/view/widgets/house_painter.dart';
import 'package:app_primero_flutter_ble/view/widgets/map_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HousePainter', () {
    test('no lanza con datos validos y size > 0', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 400, 400));
      final painter = HousePainter(houseMap: HouseMap.casaDemo());
      expect(
        () => painter.paint(canvas, const Size(400, 400)),
        returnsNormally,
      );
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
      picture.dispose();
    });

    test('no lanza con size cero (early return)', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 0, 0));
      final painter = HousePainter(houseMap: HouseMap.casaDemo());
      expect(
        () => painter.paint(canvas, const Size(0, 0)),
        returnsNormally,
      );
      recorder.endRecording().dispose();
    });

    test('shouldRepaint es false si houseMap es el mismo', () {
      final map = HouseMap.casaDemo();
      final p1 = HousePainter(houseMap: map);
      final p2 = HousePainter(houseMap: map);
      expect(p1.shouldRepaint(p2), isFalse);
    });

    test('shouldRepaint es true si houseMap cambia', () {
      final map = HouseMap.casaDemo();
      final modified = HouseMap(
        name: map.name,
        bounds: map.bounds,
        rooms: map.rooms,
        beacons: map.beacons.take(2).toList(),
      );
      final p1 = HousePainter(houseMap: map);
      final p2 = HousePainter(houseMap: modified);
      expect(p1.shouldRepaint(p2), isTrue);
    });
  });

  group('MapCanvas (widget)', () {
    testWidgets('renderiza sin lanzar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapCanvas(houseMap: HouseMap.casaDemo()),
          ),
        ),
      );
      expect(find.byType(MapCanvas), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('matchea golden file (snapshot del render)', (tester) async {
      // Forzar tamaño fijo del viewport para que el golden sea determinista.
      tester.view.physicalSize = const Size(400, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: SizedBox(
                width: 400,
                height: 400,
                child: MapCanvas(houseMap: HouseMap.casaDemo()),
              ),
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(MapCanvas),
        matchesGoldenFile('goldens/map_canvas_casaDemo.png'),
      );
    });

    testWidgets(
        'matchea golden file con usuario + ruta', (tester) async {
      tester.view.physicalSize = const Size(400, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const route = [
        Offset(0.15, 0.85),
        Offset(0.15, 0.20),
        Offset(0.50, 0.55),
        Offset(0.80, 0.85),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: SizedBox(
                width: 400,
                height: 400,
                child: MapCanvas(
                  houseMap: HouseMap.casaDemo(),
                  userPosition: const Offset(0.50, 0.55),
                  route: route,
                ),
              ),
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(MapCanvas),
        matchesGoldenFile('goldens/map_canvas_with_user.png'),
      );
    });

    testWidgets('matchea golden file de miCasa (casa real del usuario)',
        (tester) async {
      tester.view.physicalSize = const Size(400, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Casa real del usuario + 3 beacons con posiciones reales.
      final micasa = HouseMap.miCasa().copyWith(
        beacons: const [
          Beacon(id: 'B1', label: 'Sala', position: Offset(0.622, 0.082), txPower: -59),
          Beacon(id: 'B2', label: 'Pasadizo', position: Offset(0.311, 0.471), txPower: -59),
          Beacon(id: 'B3', label: 'Padres', position: Offset(0.600, 0.812), txPower: -59),
        ],
      );

      const route = [
        Offset(0.622, 0.206),
        Offset(0.622, 0.082),
        Offset(0.444, 0.294),
        Offset(0.311, 0.471),
        Offset(0.311, 0.706),
        Offset(0.444, 0.812),
        Offset(0.600, 0.812),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: SizedBox(
                width: 400,
                height: 400,
                child: MapCanvas(
                  houseMap: micasa,
                  userPosition: const Offset(0.444, 0.294),
                  route: route,
                ),
              ),
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(MapCanvas),
        matchesGoldenFile('goldens/map_canvas_miCasa.png'),
      );
    });
  });

  group('HousePainter con userPosition', () {
    test('no lanza con userPosition = null', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 400, 400));
      final painter = HousePainter(
        houseMap: HouseMap.casaDemo(),
        userPosition: null,
      );
      expect(() => painter.paint(canvas, const Size(400, 400)),
          returnsNormally);
      recorder.endRecording().dispose();
    });

    test('no lanza con userPosition valida y ruta con 2 puntos', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 400, 400));
      final painter = HousePainter(
        houseMap: HouseMap.casaDemo(),
        userPosition: const Offset(0.5, 0.5),
        route: const [Offset(0.1, 0.1), Offset(0.9, 0.9)],
      );
      expect(() => painter.paint(canvas, const Size(400, 400)),
          returnsNormally);
      recorder.endRecording().dispose();
    });

    test('shouldRepaint es true si userPosition cambia', () {
      final p1 = HousePainter(
        houseMap: HouseMap.casaDemo(),
        userPosition: const Offset(0.1, 0.1),
      );
      final p2 = HousePainter(
        houseMap: HouseMap.casaDemo(),
        userPosition: const Offset(0.9, 0.9),
      );
      expect(p1.shouldRepaint(p2), isTrue);
    });

    test('shouldRepaint es true si beaconPulseValue cambia', () {
      final p1 = HousePainter(
        houseMap: HouseMap.casaDemo(),
        beaconPulseValue: 0.0,
      );
      final p2 = HousePainter(
        houseMap: HouseMap.casaDemo(),
        beaconPulseValue: 0.5,
      );
      expect(p1.shouldRepaint(p2), isTrue);
    });

    test('shouldRepaint es false si beaconPulseValue es el mismo', () {
      final p1 = HousePainter(
        houseMap: HouseMap.casaDemo(),
        beaconPulseValue: 0.25,
      );
      final p2 = HousePainter(
        houseMap: HouseMap.casaDemo(),
        beaconPulseValue: 0.25,
      );
      expect(p1.shouldRepaint(p2), isFalse);
    });
  });
}