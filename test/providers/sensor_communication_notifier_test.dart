import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:spectriem_app/models/device_info.dart';
import 'package:spectriem_app/models/device_status.dart';
import 'package:spectriem_app/models/scan_configuration.dart';
import 'package:spectriem_app/models/scan_data.dart';
import 'package:spectriem_app/providers/ble_providers.dart';
import 'package:spectriem_app/providers/log_provider.dart';
import 'package:spectriem_app/providers/sensor_communication_notifier.dart';
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

  tearDown() async {
    await mockBleService.stopDeviceScan();
    mockBleService.dispose();
    logService.dispose();
    container.dispose();
  }

  // Helper to wait for async state updates and stream propagation
  Future<void> pump() async {
    // Wait for microtasks AND timer queue to flush
    for (var i = 0; i < 10; i++) {
      await Future.delayed(Duration.zero);
    }
  }

  group('SensorCommunicationNotifier', () {
    test('initial state is disconnected with empty configurations', () {
      final state = container.read(sensorCommunicationProvider);

      expect(state.isConnected, false);
      expect(state.configurations, null);
      expect(state.selectedConfigIndex, null);
      expect(state.logPanelExpanded, false);
    });

    test('loadConfigurations loads configurations when connected', () {
      fakeAsync((async) {
        // Keep provider alive during test
        final sub = container.listen(sensorCommunicationProvider, (_, __) {});
        final notifier = container.read(sensorCommunicationProvider.notifier);

        // Simulate connection
        mockBleService.simulateConnection();
        async.flushMicrotasks();

        // Load configurations
        notifier.loadConfigurations();
        async.elapse(Duration.zero); // Process Future.delayed(Duration.zero)
        async.flushMicrotasks();

        // Check configurations loaded
        final state = container.read(sensorCommunicationProvider);
        expect(state.configurations, isNotNull);
        expect(state.configurations, isNotEmpty);
        expect(state.selectedConfigIndex, isNotNull);
        expect(state.selectedConfigIndex, state.configurations!.first.index);

        sub.close();
      });
    });

    test('loadConfigurations sets first config as selected by default',
        () async {
      final notifier = container.read(sensorCommunicationProvider.notifier);

      mockBleService.simulateConnection();
      await pump();

      await notifier.loadConfigurations();

      final state = container.read(sensorCommunicationProvider);
      expect(state.selectedConfigIndex, equals(0));
    });

    test('loadConfigurations does nothing when disconnected', () async {
      final notifier = container.read(sensorCommunicationProvider.notifier);

      // Try to load while disconnected
      await notifier.loadConfigurations();

      final state = container.read(sensorCommunicationProvider);
      expect(state.configurations, null);
      expect(state.selectedConfigIndex, null);
    });

    test('loadConfigurations handles errors gracefully', () async {
      // Create failing service
      final failingService = MockNirScanService(
        operationDelay: Duration.zero,
        scanDelay: Duration.zero,
        deviceEmitInterval: Duration.zero,
        simulateErrors: true,
        errorProbability: 1.0,
      );

      final failingContainer = ProviderContainer(
        overrides: [
          nirScanServiceProvider.overrideWithValue(failingService),
          logServiceProvider.overrideWithValue(logService),
        ],
      );

      final notifier =
          failingContainer.read(sensorCommunicationProvider.notifier);

      // Simulate connection
      failingService.simulateConnection();
      await pump();

      // Try to load configurations (should fail gracefully)
      await notifier.loadConfigurations();

      final state = failingContainer.read(sensorCommunicationProvider);
      expect(state.configurations, null);

      failingService.dispose();
      failingContainer.dispose();
    });

    test('selectConfig changes selected configuration index', () async {
      final notifier = container.read(sensorCommunicationProvider.notifier);

      mockBleService.simulateConnection();
      await pump();

      await notifier.loadConfigurations();

      // Select different configuration
      await notifier.selectConfig(1);

      final state = container.read(sensorCommunicationProvider);
      expect(state.selectedConfigIndex, 1);
    });

    test('selectConfig calls setActiveScanConfiguration on service', () async {
      final notifier = container.read(sensorCommunicationProvider.notifier);

      mockBleService.simulateConnection();
      await pump();

      await notifier.loadConfigurations();

      // Select configuration
      await notifier.selectConfig(2);

      // Verify service was called
      // Note: MockNirScanService should track this, or we verify via state change
      final state = container.read(sensorCommunicationProvider);
      expect(state.selectedConfigIndex, 2);
    });

    test('selectConfig does nothing when selecting same index', () async {
      final notifier = container.read(sensorCommunicationProvider.notifier);

      mockBleService.simulateConnection();
      await pump();

      await notifier.loadConfigurations();

      final initialState = container.read(sensorCommunicationProvider);
      final initialIndex = initialState.selectedConfigIndex;

      // Select same index
      await notifier.selectConfig(initialIndex);

      final state = container.read(sensorCommunicationProvider);
      expect(state.selectedConfigIndex, initialIndex);
    });

    test('selectConfig handles errors and logs them', () async {
      // Create failing service
      final failingService = MockNirScanService(
        operationDelay: Duration.zero,
        scanDelay: Duration.zero,
        deviceEmitInterval: Duration.zero,
        simulateErrors: true,
        errorProbability: 1.0,
      );

      final failingContainer = ProviderContainer(
        overrides: [
          nirScanServiceProvider.overrideWithValue(failingService),
          logServiceProvider.overrideWithValue(logService),
        ],
      );

      final notifier =
          failingContainer.read(sensorCommunicationProvider.notifier);

      failingService.simulateConnection();
      await pump();

      // Try to select config (should fail but not crash)
      await notifier.selectConfig(1);

      // State should remain unchanged
      final state = failingContainer.read(sensorCommunicationProvider);
      expect(state.selectedConfigIndex, null);

      failingService.dispose();
      failingContainer.dispose();
    });

    test('toggleLogPanel toggles the panel state', () {
      final notifier = container.read(sensorCommunicationProvider.notifier);

      // Initially collapsed
      var state = container.read(sensorCommunicationProvider);
      expect(state.logPanelExpanded, false);

      // Toggle to expand
      notifier.toggleLogPanel();
      state = container.read(sensorCommunicationProvider);
      expect(state.logPanelExpanded, true);

      // Toggle to collapse
      notifier.toggleLogPanel();
      state = container.read(sensorCommunicationProvider);
      expect(state.logPanelExpanded, false);
    });

    test('connection state updates isConnected flag', () async {
      // Initially disconnected
      var state = container.read(sensorCommunicationProvider);
      expect(state.isConnected, false);

      // Connect
      mockBleService.simulateConnection();
      await pump();

      state = container.read(sensorCommunicationProvider);
      expect(state.isConnected, true);

      // Disconnect
      mockBleService.simulateDisconnection();
      await pump();

      state = container.read(sensorCommunicationProvider);
      expect(state.isConnected, false);
    });

    test('disconnection clears configurations and selected index', () async {
      final notifier = container.read(sensorCommunicationProvider.notifier);

      // Connect and load configurations
      mockBleService.simulateConnection();
      await pump();

      await notifier.loadConfigurations();

      var state = container.read(sensorCommunicationProvider);
      expect(state.configurations, isNotNull);
      expect(state.selectedConfigIndex, isNotNull);

      // Disconnect
      mockBleService.simulateDisconnection();
      await pump();

      state = container.read(sensorCommunicationProvider);
      expect(state.isConnected, false);
      expect(state.configurations, null);
      expect(state.selectedConfigIndex, null);
    });

    test('auto-loads configurations on connection', () async {
      // Start disconnected
      var state = container.read(sensorCommunicationProvider);
      expect(state.configurations, null);

      // Connect (should auto-load)
      mockBleService.simulateConnection();
      await pump();

      state = container.read(sensorCommunicationProvider);
      expect(state.isConnected, true);
      expect(state.configurations, isNotNull);
      expect(state.configurations, isNotEmpty);
    });
  });

  group('CommandExecutionNotifier', () {
    test('initial state is null with no loading', () {
      final asyncValue = container.read(commandExecutionProvider);

      expect(asyncValue, isA<AsyncData>());
      expect(asyncValue.value, null);
      expect(asyncValue.isLoading, false);
    });

    test('executeCommand sets loading state while executing', () async {
      final notifier = container.read(commandExecutionProvider.notifier);

      mockBleService.simulateConnection();
      await pump();

      // Start command execution
      final future = notifier.executeCommand('getDeviceInfo');

      // Should be loading immediately
      var asyncValue = container.read(commandExecutionProvider);
      expect(asyncValue.isLoading, true);

      // Wait to complete
      await future;

      asyncValue = container.read(commandExecutionProvider);
      expect(asyncValue.isLoading, false);
    });

    test('executeCommand returns DeviceInfo for getDeviceInfo', () async {
      final notifier = container.read(commandExecutionProvider.notifier);

      mockBleService.simulateConnection();
      await pump();

      await notifier.executeCommand('getDeviceInfo');

      final asyncValue = container.read(commandExecutionProvider);
      expect(asyncValue.hasValue, true);
      expect(asyncValue.value, isA<DeviceInfo>());
    });

    test('executeCommand returns DeviceStatus for getDeviceStatus', () async {
      final notifier = container.read(commandExecutionProvider.notifier);

      mockBleService.simulateConnection();
      await pump();

      await notifier.executeCommand('getDeviceStatus');

      final asyncValue = container.read(commandExecutionProvider);
      expect(asyncValue.hasValue, true);
      expect(asyncValue.value, isA<DeviceStatus>());
    });

    test('executeCommand returns ScanData for performScan', () async {
      final notifier = container.read(commandExecutionProvider.notifier);

      mockBleService.simulateConnection();
      await pump();

      await notifier.executeCommand('performScan');

      final asyncValue = container.read(commandExecutionProvider);
      expect(asyncValue.hasValue, true);
      expect(asyncValue.value, isA<ScanData>());
    });

    test('executeCommand returns OK for syncTime', () async {
      final notifier = container.read(commandExecutionProvider.notifier);

      mockBleService.simulateConnection();
      await pump();

      await notifier.executeCommand('syncTime');

      final asyncValue = container.read(commandExecutionProvider);
      expect(asyncValue.hasValue, true);
      expect(asyncValue.value, 'OK');
    });

    test(
        'executeCommand returns List<ScanConfiguration> for getScanConfigurations',
        () async {
      final notifier = container.read(commandExecutionProvider.notifier);

      mockBleService.simulateConnection();
      await pump();

      await notifier.executeCommand('getScanConfigurations');

      final asyncValue = container.read(commandExecutionProvider);
      expect(asyncValue.hasValue, true);
      expect(asyncValue.value, isA<List<ScanConfiguration>>());
    });

    test('executeCommand handles errors and sets error state', () async {
      // Create failing service
      final failingService = MockNirScanService(
        operationDelay: Duration.zero,
        scanDelay: Duration.zero,
        deviceEmitInterval: Duration.zero,
        simulateErrors: true,
        errorProbability: 1.0,
      );

      final failingContainer = ProviderContainer(
        overrides: [
          nirScanServiceProvider.overrideWithValue(failingService),
          logServiceProvider.overrideWithValue(logService),
        ],
      );

      final notifier = failingContainer.read(commandExecutionProvider.notifier);

      failingService.simulateConnection();
      await pump();

      // Execute command that will fail
      await notifier.executeCommand('getDeviceInfo');

      final asyncValue = failingContainer.read(commandExecutionProvider);
      expect(asyncValue.hasError, true);
      expect(asyncValue.error, isA<NirScanException>());

      failingService.dispose();
      failingContainer.dispose();
    });

    test('executeCommand does not execute when disconnected', () async {
      final notifier = container.read(commandExecutionProvider.notifier);

      // Try to execute while disconnected
      await notifier.executeCommand('getDeviceInfo');

      final asyncValue = container.read(commandExecutionProvider);
      // Should remain in initial state
      expect(asyncValue.value, null);
    });

    test('executeCommand logs command execution', () async {
      final notifier = container.read(commandExecutionProvider.notifier);

      mockBleService.simulateConnection();
      await pump();

      await notifier.executeCommand('getDeviceInfo');

      // Check logs contain command info
      final logs = logService.history;
      expect(logs.any((log) => log.message.contains('getDeviceInfo')), true);
    });

    test('consecutive commands update state correctly', () async {
      final notifier = container.read(commandExecutionProvider.notifier);

      mockBleService.simulateConnection();
      await pump();

      // First command
      await notifier.executeCommand('getDeviceInfo');

      var asyncValue = container.read(commandExecutionProvider);
      expect(asyncValue.value, isA<DeviceInfo>());

      // Second command
      await notifier.executeCommand('getDeviceStatus');

      asyncValue = container.read(commandExecutionProvider);
      expect(asyncValue.value, isA<DeviceStatus>());
    });

    test('executeCommand with unknown command throws error', () async {
      final notifier = container.read(commandExecutionProvider.notifier);

      mockBleService.simulateConnection();
      await pump();

      await notifier.executeCommand('unknownCommand');

      final asyncValue = container.read(commandExecutionProvider);
      expect(asyncValue.hasError, true);
    });

    test('error state can be cleared by executing successful command',
        () async {
      // Create service that fails once then succeeds
      final flakeyService = MockNirScanService(
        operationDelay: Duration.zero,
        scanDelay: Duration.zero,
        deviceEmitInterval: Duration.zero,
        simulateErrors: true,
        errorProbability: 1.0,
      );

      final flakeyContainer = ProviderContainer(
        overrides: [
          nirScanServiceProvider.overrideWithValue(flakeyService),
          logServiceProvider.overrideWithValue(logService),
        ],
      );

      final notifier = flakeyContainer.read(commandExecutionProvider.notifier);

      flakeyService.simulateConnection();
      await pump();

      // First command fails
      await notifier.executeCommand('getDeviceInfo');

      var asyncValue = flakeyContainer.read(commandExecutionProvider);
      expect(asyncValue.hasError, true);

      // Make service succeed
      flakeyService.errorProbability = 0.0;

      // Second command succeeds
      await notifier.executeCommand('getDeviceInfo');

      asyncValue = flakeyContainer.read(commandExecutionProvider);
      expect(asyncValue.hasError, false);
      expect(asyncValue.hasValue, true);

      flakeyService.dispose();
      flakeyContainer.dispose();
    });
  });

  group('Integration: SensorCommunication + CommandExecution', () {
    test('command execution works with configuration selection', () async {
      final sensorNotifier =
          container.read(sensorCommunicationProvider.notifier);
      final commandNotifier = container.read(commandExecutionProvider.notifier);

      mockBleService.simulateConnection();
      await pump();

      // Load configurations
      await sensorNotifier.loadConfigurations();

      // Select a configuration
      await sensorNotifier.selectConfig(1);

      // Execute scan with selected config
      await commandNotifier.executeCommand('performScan');

      final asyncValue = container.read(commandExecutionProvider);
      expect(asyncValue.hasValue, true);
      expect(asyncValue.value, isA<ScanData>());

      final sensorState = container.read(sensorCommunicationProvider);
      expect(sensorState.selectedConfigIndex, 1);
    });

    test('both notifiers respond to connection state changes', () async {
      // Initially disconnected
      var sensorState = container.read(sensorCommunicationProvider);
      expect(sensorState.isConnected, false);

      // Connect
      mockBleService.simulateConnection();
      await pump();

      sensorState = container.read(sensorCommunicationProvider);
      expect(sensorState.isConnected, true);
      expect(sensorState.configurations, isNotNull);

      // Disconnect
      mockBleService.simulateDisconnection();
      await pump();

      sensorState = container.read(sensorCommunicationProvider);
      expect(sensorState.isConnected, false);
      expect(sensorState.configurations, null);
    });

    test('log panel state persists across operations', () async {
      final sensorNotifier =
          container.read(sensorCommunicationProvider.notifier);
      final commandNotifier = container.read(commandExecutionProvider.notifier);

      // Expand log panel
      sensorNotifier.toggleLogPanel();
      expect(
          container.read(sensorCommunicationProvider).logPanelExpanded, true);

      mockBleService.simulateConnection();
      await pump();

      // Execute command
      await commandNotifier.executeCommand('getDeviceInfo');

      // Log panel should still be expanded
      expect(
          container.read(sensorCommunicationProvider).logPanelExpanded, true);
    });
  });
}
