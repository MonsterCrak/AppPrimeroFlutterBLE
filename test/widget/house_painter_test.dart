/// Tests for the house rendering pipeline.
///
/// - `shouldRepaint_cambiaConDatos`: verifies the painter invalidates when the
///   underlying map changes.
/// - `noLanzaConDatosValidos`: verifies the painter can render without throwing.
/// - `golden_matcheaReferencia`: ensures the rendered map stays visually stable.
library;

import 'dart:ui' as ui;

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
  });
}