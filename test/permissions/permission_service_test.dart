/// Tests for [PermissionStatusReport] and the [PermissionService] contract.
///
/// The [SystemPermissionService] depends on platform channels, so we test
/// only the pure-Dart logic here. Integration of the system plugin is
/// covered by the in-repo AndroidManifest / Info.plist and by manual
/// end-to-end testing on a real device.
library;

import 'package:app_primero_flutter_ble/permissions/permission_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPermissionService extends Mock implements PermissionService {}

void main() {
  group('PermissionStatusReport', () {
    test('allGranted es true solo si ambos true', () {
      expect(
        const PermissionStatusReport(
          bluetoothGranted: true,
          locationGranted: true,
        ).allGranted,
        isTrue,
      );
      expect(
        const PermissionStatusReport(
          bluetoothGranted: false,
          locationGranted: true,
        ).allGranted,
        isFalse,
      );
      expect(
        const PermissionStatusReport(
          bluetoothGranted: true,
          locationGranted: false,
        ).allGranted,
        isFalse,
      );
    });

    test('missingDescription lista solo los faltantes', () {
      expect(
        const PermissionStatusReport(
          bluetoothGranted: true,
          locationGranted: true,
        ).missingDescription,
        isNull,
      );
      expect(
        const PermissionStatusReport(
          bluetoothGranted: false,
          locationGranted: true,
        ).missingDescription,
        'Falta permiso de: Bluetooth',
      );
      expect(
        const PermissionStatusReport(
          bluetoothGranted: false,
          locationGranted: false,
        ).missingDescription,
        'Falta permiso de: Bluetooth, Ubicación',
      );
    });

    test('toString incluye ambos flags', () {
      final s = const PermissionStatusReport(
        bluetoothGranted: true,
        locationGranted: false,
      ).toString();
      expect(s, contains('bluetoothGranted'));
      expect(s, contains('locationGranted'));
    });
  });

  group('PermissionRequestResult', () {
    test('allGranted delega en finalStatus.allGranted', () {
      const r1 = PermissionRequestResult(
        finalStatus: PermissionStatusReport(
          bluetoothGranted: true,
          locationGranted: true,
        ),
        somePermanentlyDenied: false,
      );
      expect(r1.allGranted, isTrue);

      const r2 = PermissionRequestResult(
        finalStatus: PermissionStatusReport(
          bluetoothGranted: false,
          locationGranted: true,
        ),
        somePermanentlyDenied: true,
      );
      expect(r2.allGranted, isFalse);
    });
  });

  group('PermissionService (mocked contract)', () {
    test('check y request delegan al implementation', () async {
      final mock = _MockPermissionService();
      when(() => mock.check()).thenAnswer(
        (_) async => const PermissionStatusReport(
          bluetoothGranted: true,
          locationGranted: true,
        ),
      );
      when(() => mock.request()).thenAnswer(
        (_) async => const PermissionRequestResult(
          finalStatus: PermissionStatusReport(
            bluetoothGranted: true,
            locationGranted: true,
          ),
          somePermanentlyDenied: false,
        ),
      );

      expect((await mock.check()).allGranted, isTrue);
      expect((await mock.request()).allGranted, isTrue);
    });
  });
}