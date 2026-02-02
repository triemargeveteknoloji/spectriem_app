import 'dart:async';

import 'package:spectriem_app/services/ble/nir_scan_service.dart';

import '../config/test_config.dart';
import '../core/step_executor.dart';
import '../core/test_context.dart';
import '../observability/integration_logger.dart';

/// Executes the device scan step for NIR sensor integration tests.
///
/// Scans for NIRScan devices via BLE, logs discovered devices, and selects
/// one for subsequent test steps. Device selection prioritizes:
/// 1. Device matching [TestConfig.preferredDeviceName] if configured
/// 2. Device with strongest RSSI signal otherwise
///
/// Throws [StateError] if no NIRScan devices are found.
Future<void> executeScanStep(
  TestContext context,
  StepExecutor executor,
  TestConfig config,
  IntegrationLogger logger,
) async {
  await executor.execute(
    'Scanning for NIRScan devices',
    () async {
      context.discoveredDevices.clear();

      final completer = Completer<void>();
      final foundDevices = <String, NirScanDevice>{};

      // Subscribe to discovered devices
      final subscription = context.service.discoveredDevices.listen((device) {
        logger.ble('Found: ${device.name} (${device.id}) RSSI: ${device.rssi}');
        foundDevices[device.id] = device;

        // If we found preferred device, complete early
        if (config.preferredDeviceName != null &&
            device.name.contains(config.preferredDeviceName!)) {
          logger.ble('Preferred device found, stopping scan early');
          if (!completer.isCompleted) {
            completer.complete();
          }
        }
      });

      try {
        // Start scan without waiting for it to complete
        logger.ble('Starting BLE scan (timeout: ${TestConfig.scanTimeout.inSeconds}s)...');

        // Don't await - let it run in background
        context.service.startDeviceScan(timeout: TestConfig.scanTimeout).catchError((e) {
          logger.ble('Scan error: $e');
        });

        // Wait for either: preferred device found, or timeout
        await Future.any([
          completer.future,
          Future.delayed(TestConfig.scanTimeout),
        ]);

        // Stop scan if still running
        await context.service.stopDeviceScan().catchError((_) {});

      } finally {
        await subscription.cancel();
      }

      // Collect discovered devices
      context.discoveredDevices.addAll(foundDevices.values);

      logger.ble('Scan complete. Found ${context.discoveredDevices.length} device(s)');

      if (context.discoveredDevices.isEmpty) {
        throw StateError('No NIRScan devices found. Is the sensor powered on and nearby?');
      }

      // Select device
      if (config.preferredDeviceName != null) {
        context.selectedDevice = context.discoveredDevices.firstWhere(
          (d) => d.name.contains(config.preferredDeviceName!),
          orElse: () {
            logger.ble('Preferred device "${config.preferredDeviceName}" not found, using first');
            return context.discoveredDevices.first;
          },
        );
      } else {
        // Select strongest signal
        context.discoveredDevices.sort((a, b) => b.rssi.compareTo(a.rssi));
        context.selectedDevice = context.discoveredDevices.first;
      }

      logger.data('Selected', '${context.selectedDevice!.name} (${context.selectedDevice!.id})');
    },
    // No step-level timeout - we handle it internally
  );
}
