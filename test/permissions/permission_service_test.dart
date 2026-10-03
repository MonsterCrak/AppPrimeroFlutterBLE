/// Tests for [PermissionStatusReport], [PermissionRequestResult], and the
/// [PermissionService] contract.
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
          bluetoothScanGranted: true,
          bluetoothConnectGranted: true,
          locationGranted: true,
        ).allGranted,
        isTrue,
      );
      expect(
        const PermissionStatusReport(
          bluetoothScanGranted: false,
          bluetoothConnectGranted: false,
          locationGranted: true,
        ).allGranted,
        isFalse,
      );
      expect(
        const PermissionStatusReport(
          bluetoothScanGranted: true,
          bluetoothConnectGranted: true,
          locationGranted: false,
        ).allGranted,
        isFalse,
      );
    });

    test('missingDescription lista solo los faltantes', () {
      expect(
        const PermissionStatusReport(
          bluetoothScanGranted: true,
          bluetoothConnectGranted: true,
          locationGranted: true,
        ).missingDescription,
        isNull,
      );
      expect(
        const PermissionStatusReport(
          bluetoothScanGranted: false,
          bluetoothConnectGranted: false,
          locationGranted: true,
        ).missingDescription,
        'Falta permiso de: Bluetooth',
      );
      expect(
        const PermissionStatusReport(
          bluetoothScanGranted: false,
          bluetoothConnectGranted: false,
          locationGranted: false,
        ).missingDescription,
        'Falta permiso de: Bluetooth, Ubicación',
      );
    });
  });

  group('PermissionRequestResult', () {
    test('allGranted y requiresOpenSettings delegan en action', () {
      const granted = PermissionRequestResult(
        finalStatus: PermissionStatusReport(
          bluetoothScanGranted: true,
          bluetoothConnectGranted: true,
          locationGranted: true,
        ),
        action: PermissionAction.granted,
      );
      expect(granted.allGranted, isTrue);
      expect(granted.requiresOpenSettings, isFalse);

      const settings = PermissionRequestResult(
        finalStatus: PermissionStatusReport(
          bluetoothScanGranted: false,
          bluetoothConnectGranted: false,
          locationGranted: true,
        ),
        action: PermissionAction.openSettings,
      );
      expect(settings.allGranted, isFalse);
      expect(settings.requiresOpenSettings, isTrue);

      const retry = PermissionRequestResult(
        finalStatus: PermissionStatusReport(
          bluetoothScanGranted: false,
          bluetoothConnectGranted: false,
          locationGranted: false,
        ),
        action: PermissionAction.retry,
      );
      expect(retry.allGranted, isFalse);
      expect(retry.requiresOpenSettings, isFalse);
    });
  });

  group('PermissionService (mocked contract)', () {
    test('check, request, openSettings delegan al implementation', () async {
      final mock = _MockPermissionService();
      when(() => mock.check()).thenAnswer(
        (_) async => const PermissionStatusReport(
          bluetoothScanGranted: true,
          bluetoothConnectGranted: true,
          locationGranted: true,
        ),
      );
      when(() => mock.request()).thenAnswer(
        (_) async => PermissionRequestResult.granted(
          const PermissionStatusReport(
            bluetoothScanGranted: true,
          bluetoothConnectGranted: true,
            locationGranted: true,
          ),
        ),
      );
      when(() => mock.openSettings()).thenAnswer((_) async {});

      expect((await mock.check()).allGranted, isTrue);
      expect((await mock.request()).allGranted, isTrue);
      await mock.openSettings();
      verify(() => mock.openSettings()).called(1);
    });
  });
}