import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spectriem_app/providers/ble_providers.dart';
import 'package:spectriem_app/providers/log_provider.dart';
import 'package:spectriem_app/services/ble/nir_scan_service.dart';
import 'package:spectriem_app/services/ble/ble_nir_scan_service.dart';
import 'package:spectriem_app/services/ble/mock_nir_scan_service.dart';

void main() {
  group('nirScanServiceProvider', () {
    test('provides a NirScanService instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final nirScanService = container.read(nirScanServiceProvider);

      expect(nirScanService, isA<NirScanService>());
    });

    test('returns the same instance on multiple reads', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final service1 = container.read(nirScanServiceProvider);
      final service2 = container.read(nirScanServiceProvider);

      expect(identical(service1, service2), isTrue);
    });

    test('provides MockNirScanService on non-mobile platforms', () {
      // This test assumes running on non-mobile platform (e.g., macOS/Linux/Windows)
      if (!Platform.isAndroid && !Platform.isIOS) {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final service = container.read(nirScanServiceProvider);

        expect(service, isA<MockNirScanService>());
      }
    });

    test('depends on logServiceProvider', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Read nirScanService which should trigger logService creation
      final nirScanService = container.read(nirScanServiceProvider);
      final logService = container.read(logServiceProvider);

      expect(nirScanService, isNotNull);
      expect(logService, isNotNull);
    });

    test('can override with custom NirScanService in tests', () {
      final mockService = MockNirScanService();
      final container = ProviderContainer(
        overrides: [
          nirScanServiceProvider.overrideWithValue(mockService),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(mockService.dispose);

      final service = container.read(nirScanServiceProvider);

      expect(identical(service, mockService), isTrue);
    });

    test('disposes NirScanService when container is disposed', () async {
      final container = ProviderContainer();
      final service = container.read(nirScanServiceProvider);

      // Verify service is active
      expect(service, isNotNull);

      // Dispose container should call service.dispose()
      container.dispose();

      // Service should be disposed (no way to directly test internal state)
      // This test mainly verifies no exceptions are thrown during disposal
    });

    test('service has working connectionState stream', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final service = container.read(nirScanServiceProvider);
      final states = <NirConnectionState>[];

      final subscription = service.connectionState.listen((state) {
        states.add(state);
      });
      addTearDown(subscription.cancel);

      // Trigger a state change to verify stream works
      if (service is MockNirScanService) {
        final device =
            NirScanDevice(id: '00:11:22:33:44:55', name: 'Test', rssi: -50);
        await service.connect(device.id);
        await Future.delayed(Duration(milliseconds: 50));

        // Should have received connecting and connected states
        expect(states, isNotEmpty);
        expect(states, contains(NirConnectionState.connecting));
      }
    });

    test('service has working discoveredDevices stream', () async {
      // Use a mock with zero delays for faster tests
      final mockService = MockNirScanService(
        operationDelay: Duration.zero,
        deviceEmitInterval: Duration.zero,
      );
      final container = ProviderContainer(
        overrides: [
          nirScanServiceProvider.overrideWithValue(mockService),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(mockService.dispose);

      final service = container.read(nirScanServiceProvider);

      // Verify stream exists and is a broadcast stream
      expect(service.discoveredDevices, isA<Stream<NirScanDevice>>());
      expect(service.discoveredDevices.isBroadcast, isTrue);

      final devices = <NirScanDevice>[];
      final subscription = service.discoveredDevices.listen((device) {
        devices.add(device);
      });
      addTearDown(subscription.cancel);

      await service.startDeviceScan();
      await Future.delayed(Duration(milliseconds: 10));

      expect(devices, isNotEmpty);
    });

    test('service connectedDevice is initially null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final service = container.read(nirScanServiceProvider);

      expect(service.connectedDevice, isNull);
    });
  });

  group('connectionStateProvider', () {
    test('provides a StreamProvider wrapping service connectionState', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final connectionStateAsync = container.read(connectionStateProvider);

      // Should return an AsyncValue (loading initially since stream hasn't emitted)
      expect(connectionStateAsync, isA<AsyncValue<NirConnectionState>>());
    });

    test('exposes the connectionState stream from nirScanService', () {
      final mockService = MockNirScanService();
      final container = ProviderContainer(
        overrides: [
          nirScanServiceProvider.overrideWithValue(mockService),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(mockService.dispose);

      // Verify the provider is created without error
      final stateAsync = container.read(connectionStateProvider);
      expect(stateAsync, isA<AsyncValue<NirConnectionState>>());
    });

    test('can be overridden with a custom stream in tests', () {
      final container = ProviderContainer(
        overrides: [
          connectionStateProvider.overrideWith((ref) {
            return Stream.value(NirConnectionState.connected);
          }),
        ],
      );
      addTearDown(container.dispose);

      // Verify override works
      expect(container.read(connectionStateProvider),
          isA<AsyncValue<NirConnectionState>>());
    });
  });

  group('discoveredDevicesProvider', () {
    test('provides a StreamProvider wrapping service discoveredDevices', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final devicesAsync = container.read(discoveredDevicesProvider);

      expect(devicesAsync, isA<AsyncValue<NirScanDevice>>());
    });

    test('exposes the discoveredDevices stream from nirScanService', () {
      final mockService = MockNirScanService();
      final container = ProviderContainer(
        overrides: [
          nirScanServiceProvider.overrideWithValue(mockService),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(mockService.dispose);

      final devicesAsync = container.read(discoveredDevicesProvider);
      expect(devicesAsync, isA<AsyncValue<NirScanDevice>>());
    });

    test('can be overridden with a custom stream in tests', () {
      final testDevice =
          NirScanDevice(id: 'test-id', name: 'Test Device', rssi: -50);
      final container = ProviderContainer(
        overrides: [
          discoveredDevicesProvider.overrideWith((ref) {
            return Stream.value(testDevice);
          }),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(discoveredDevicesProvider),
          isA<AsyncValue<NirScanDevice>>());
    });
  });

  group('connectedDeviceProvider', () {
    test('provides the currently connected device', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final device = container.read(connectedDeviceProvider);

      expect(device, isNull);
    });

    test('returns null when no device is connected', () {
      final mockService = MockNirScanService();
      final container = ProviderContainer(
        overrides: [
          nirScanServiceProvider.overrideWithValue(mockService),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(mockService.dispose);

      final device = container.read(connectedDeviceProvider);
      expect(device, isNull);
    });

    test('can be overridden in tests', () {
      final testDevice =
          NirScanDevice(id: 'test-id', name: 'Test Device', rssi: -50);
      final container = ProviderContainer(
        overrides: [
          connectedDeviceProvider.overrideWithValue(testDevice),
        ],
      );
      addTearDown(container.dispose);

      final device = container.read(connectedDeviceProvider);
      expect(device, testDevice);
    });
  });
}
