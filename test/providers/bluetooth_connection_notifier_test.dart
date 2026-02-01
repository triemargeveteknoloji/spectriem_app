import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:spectriem_app/models/device_info.dart';
import 'package:spectriem_app/models/device_status.dart';
import 'package:spectriem_app/providers/ble_providers.dart';
import 'package:spectriem_app/providers/bluetooth_connection_notifier.dart';
import 'package:spectriem_app/providers/log_provider.dart';
import 'package:spectriem_app/services/ble/mock_nir_scan_service.dart';
import 'package:spectriem_app/services/ble/nir_scan_service.dart';
import 'package:spectriem_app/services/logging/log_service.dart';

void main() {
  late ProviderContainer container;
  late MockNirScanService mockBleService;
  late LogService logService;

  setUp(() {
    mockBleService = MockNirScanService(
      operationDelay: Duration.zero,
      scanDelay: Duration.zero,
      deviceEmitInterval: Duration.zero,
    );
    logService = LogService();

    container = ProviderContainer(
      overrides: [
        nirScanServiceProvider.overrideWithValue(mockBleService),
        logServiceProvider.overrideWithValue(logService),
      ],
    );
  });

  tearDown(() async {
    await mockBleService.stopDeviceScan();
    mockBleService.dispose();
    logService.dispose();
    container.dispose();
  });

  group('BluetoothConnectionNotifier', () {
    test('initial state is idle with empty devices', () {
      final notifier = container.read(bluetoothConnectionProvider.notifier);
      final state = container.read(bluetoothConnectionProvider);

      expect(state.screenState, ScreenState.idle);
      expect(state.discoveredDevices, isEmpty);
      expect(state.deviceInfo, isNull);
      expect(state.deviceStatus, isNull);
      expect(state.errorMessage, isNull);
      expect(state.logPanelExpanded, false);
    });

    test('startScanning changes state to scanning', () async {
      final notifier = container.read(bluetoothConnectionProvider.notifier);

      // Start scanning
      final scanFuture = notifier.startScanning();

      // Check state changed to scanning
      var state = container.read(bluetoothConnectionProvider);
      expect(state.screenState, ScreenState.scanning);
      expect(state.discoveredDevices, isEmpty);

      // Wait for scan to complete
      await scanFuture;

      // State should return to idle after scan completes
      state = container.read(bluetoothConnectionProvider);
      expect(state.screenState, ScreenState.idle);
    });

    test('startScanning discovers devices from stream', () {
      fakeAsync((async) {
        final notifier = container.read(bluetoothConnectionProvider.notifier);

        // Start scanning
        notifier.startScanning();

        // Flush microtasks to process stream events
        async.flushMicrotasks();

        // Check devices were added
        var state = container.read(bluetoothConnectionProvider);
        expect(state.discoveredDevices, isNotEmpty);
        expect(state.discoveredDevices.first.name, contains('NIRScan Nano'));
      });
    });

    test('startScanning does not add duplicate devices', () {
      fakeAsync((async) {
        final notifier = container.read(bluetoothConnectionProvider.notifier);

        // Start scanning
        notifier.startScanning();

        // Flush microtasks to process stream events
        async.flushMicrotasks();

        // Get device count
        final state = container.read(bluetoothConnectionProvider);
        final deviceIds = state.discoveredDevices.map((d) => d.id).toSet();

        // Check no duplicates (all IDs are unique)
        expect(deviceIds.length, state.discoveredDevices.length);
      });
    });

    test('stopScanning cancels scan and returns to idle', () async {
      final notifier = container.read(bluetoothConnectionProvider.notifier);

      // Start scanning
      notifier.startScanning();

      // Wait a bit
      await Future.delayed(const Duration(milliseconds: 50));

      // Stop scanning
      await notifier.stopScanning();

      // Check state is idle
      final state = container.read(bluetoothConnectionProvider);
      expect(state.screenState, ScreenState.idle);
    });

    test('connectToDevice changes state to connecting then connected', () {
      fakeAsync((async) {
        final notifier = container.read(bluetoothConnectionProvider.notifier);

        // Discover devices first
        notifier.startScanning();
        async.flushMicrotasks();
        final device =
            container.read(bluetoothConnectionProvider).discoveredDevices.first;

        // Connect to device
        notifier.connectToDevice(device);

        // State should be connecting
        var state = container.read(bluetoothConnectionProvider);
        expect(state.screenState, ScreenState.connecting);

        // Flush microtasks to process connection state change
        async.flushMicrotasks();

        // State should be connected
        state = container.read(bluetoothConnectionProvider);
        expect(state.screenState, ScreenState.connected);
      });
    });

    test('connectToDevice loads device info and status', () {
      fakeAsync((async) {
        final notifier = container.read(bluetoothConnectionProvider.notifier);

        // Discover and connect
        notifier.startScanning();
        async.flushMicrotasks();
        final device =
            container.read(bluetoothConnectionProvider).discoveredDevices.first;
        notifier.connectToDevice(device);

        // Flush microtasks to process connection and device info load
        async.flushMicrotasks();

        // Check device info and status loaded
        final state = container.read(bluetoothConnectionProvider);
        expect(state.deviceInfo, isNotNull);
        expect(state.deviceInfo?.manufacturerName, 'Texas Instruments');
        expect(state.deviceStatus, isNotNull);
        expect(state.deviceStatus?.batteryLevel, greaterThan(0));
      });
    });

    test('connectToDevice handles error and updates state', () async {
      // Create a service that simulates errors
      final failingService = MockNirScanService(
        operationDelay: Duration.zero,
        scanDelay: Duration.zero,
        deviceEmitInterval: Duration.zero,
        simulateErrors: true,
        errorProbability: 1.0, // Always fail
      );

      final failingContainer = ProviderContainer(
        overrides: [
          nirScanServiceProvider.overrideWithValue(failingService),
          logServiceProvider.overrideWithValue(logService),
        ],
      );

      final notifier =
          failingContainer.read(bluetoothConnectionProvider.notifier);

      // Create a fake device (don't scan since that might also fail)
      const device =
          NirScanDevice(id: 'test-device', name: 'Test Device', rssi: -60);

      // Try to connect (should fail)
      await notifier.connectToDevice(device);

      // State should be error
      final state = failingContainer.read(bluetoothConnectionProvider);
      expect(state.screenState, ScreenState.error);
      expect(state.errorMessage, isNotNull);

      failingService.dispose();
      failingContainer.dispose();
    });

    test('disconnect changes state to idle and clears device info', () {
      fakeAsync((async) {
        final notifier = container.read(bluetoothConnectionProvider.notifier);

        // Connect first
        notifier.startScanning();
        async.flushMicrotasks();
        final device =
            container.read(bluetoothConnectionProvider).discoveredDevices.first;
        notifier.connectToDevice(device);
        async.flushMicrotasks();

        // Disconnect
        notifier.disconnect();

        // Flush microtasks to process disconnection
        async.flushMicrotasks();

        // State should be idle with cleared info
        final state = container.read(bluetoothConnectionProvider);
        expect(state.screenState, ScreenState.idle);
        expect(state.deviceInfo, isNull);
        expect(state.deviceStatus, isNull);
      });
    });

    test('toggleLogPanel toggles the panel state', () {
      final notifier = container.read(bluetoothConnectionProvider.notifier);

      // Initially collapsed
      var state = container.read(bluetoothConnectionProvider);
      expect(state.logPanelExpanded, false);

      // Toggle to expand
      notifier.toggleLogPanel();
      state = container.read(bluetoothConnectionProvider);
      expect(state.logPanelExpanded, true);

      // Toggle to collapse
      notifier.toggleLogPanel();
      state = container.read(bluetoothConnectionProvider);
      expect(state.logPanelExpanded, false);
    });

    test('connection state listener updates screen state', () {
      fakeAsync((async) {
        final notifier = container.read(bluetoothConnectionProvider.notifier);

        // Start scanning and connect
        notifier.startScanning();
        async.flushMicrotasks();
        final device =
            container.read(bluetoothConnectionProvider).discoveredDevices.first;
        notifier.connectToDevice(device);

        // Flush microtasks to process connection
        async.flushMicrotasks();

        // Should be connected
        var state = container.read(bluetoothConnectionProvider);
        expect(state.screenState, ScreenState.connected);

        // Disconnect
        notifier.disconnect();
        async.flushMicrotasks();

        // Should be idle
        state = container.read(bluetoothConnectionProvider);
        expect(state.screenState, ScreenState.idle);
      });
    });

    test('state maintains discovered devices across scan cycles', () async {
      final notifier = container.read(bluetoothConnectionProvider.notifier);

      // First scan
      await notifier.startScanning();
      final firstScanDevices =
          container.read(bluetoothConnectionProvider).discoveredDevices;
      expect(firstScanDevices, isNotEmpty);

      // Second scan should clear and rediscover
      await notifier.startScanning();
      final secondScanDevices =
          container.read(bluetoothConnectionProvider).discoveredDevices;
      expect(secondScanDevices, isNotEmpty);
    });
  });
}
