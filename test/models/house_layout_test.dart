/// Tests for [HouseLayout] and its SVG-derived factory.
library;

import 'dart:ui' show Rect;

import 'package:app_primero_flutter_ble/models/house_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HouseLayout', () {
    test('default constructor returns empty layout', () {
      const layout = HouseLayout();
      expect(layout.walls, isEmpty);
      expect(layout.doors, isEmpty);
      expect(layout.labels, isEmpty);
      expect(layout.excludedZones, isEmpty);
      expect(layout.isEmpty, isTrue);
    });

    test('isEmpty is false when there are walls', () {
      const layout = HouseLayout(
        walls: [WallSegment(from: Offset(0, 0), to: Offset(0.5, 0.5))],
      );
      expect(layout.isEmpty, isFalse);
    });
  });

  group('HouseLayout.miCasaFromSvg', () {
    final layout = HouseLayout.miCasaFromSvg();

    test('has all SVG walls (perímetro + interiores + divisiones)', () {
      // Expected counts: 5 perímetro + 1 pasadizo izq + 3 muro interno pasadizo
      // + 4 divisiones horizontales + 2 divisiones cuartos inferiores = 15.
      expect(layout.walls.length, greaterThanOrEqualTo(15));
    });

    test('all wall coordinates are normalized [0, 1]', () {
      for (final wall in layout.walls) {
        expect(wall.from.dx, inInclusiveRange(0, 1));
        expect(wall.from.dy, inInclusiveRange(0, 1));
        expect(wall.to.dx, inInclusiveRange(0, 1));
        expect(wall.to.dy, inInclusiveRange(0, 1));
      }
    });

    test('has 3 doors (principal + Cocina/Mi cuarto + Mi cuarto/Baño)', () {
      expect(layout.doors.length, 3);
    });

    test('room labels include Sala, Cocina, Mi cuarto, Baño, Pasadizo, '
        'Hermano, Padres', () {
      final texts = layout.labels.map((l) => l.text).toSet();
      expect(texts, containsAll(['Sala', 'Cocina', 'Mi cuarto', 'Baño',
        'Pasadizo', 'Hermano', 'Padres']));
    });

    test('beacon labels B1, B2, B3 are present', () {
      final texts = layout.labels.map((l) => l.text).toSet();
      expect(texts, containsAll(['B1', 'B2', 'B3']));
    });

    test('has the Lavandería excluded zone', () {
      expect(layout.excludedZones.length, 1);
      final zone = layout.excludedZones.first;
      expect(zone.label, 'Lavandería');
      expect(zone.rect, isA<Rect>());
    });
  });
}