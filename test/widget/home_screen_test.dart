// Smoke test para WU-0: verifica que la app arranca sin lanzar excepciones.
// Este test será reemplazado por tests reales en WU-1..WU-15.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_primero_flutter_ble/main.dart';

void main() {
  group('Bootstrap', () {
    testWidgets('app arranca y muestra AppBar', (tester) async {
      await tester.pumpWidget(const AppPrimeroFlutterBleApp());
      await tester.pumpAndSettle();

      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.text('Emulador BLE Indoor'), findsOneWidget);
    });

    testWidgets('muestra el mensaje de bootstrap', (tester) async {
      await tester.pumpWidget(const AppPrimeroFlutterBleApp());
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Bootstrap OK'),
        findsOneWidget,
      );
    });
  });
}