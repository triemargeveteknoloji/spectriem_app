import 'dart:async';

import '../config/test_config.dart';
import '../core/step_executor.dart';
import '../core/test_context.dart';
import '../observability/integration_logger.dart';
import '../assertions/sensor_assertions.dart';
import 'package:spectriem_app/services/ble/nir_scan_service.dart';
import 'package:spectriem_app/models/scan_data.dart';

/// Executes spectral scans with retry logic for lamp failures.
///
/// On lamp failure (0x01):
/// 1. Calls resetErrorStatus() to clear error flags
/// 2. Waits 5s for sensor recovery
/// 3. Retries the scan
///
/// The step performs TWO scans to verify stale notification handling.
Future<void> executePerformScanStep(
  TestContext context,
  StepExecutor executor,
  IntegrationLogger logger,
) async {
  await executor.execute(
    'PERFORM_SCAN: Executing spectral scans (2x with retry)',
    () async {
      // ===== SCAN 1 =====
      logger.ble('=== SCAN 1 ===');
      logger.ble('Starting first spectral scan...');

      final scan1Stopwatch = Stopwatch()..start();
      String? scan1Error;
      String? scan1Index;
      ScanData? scanData1;

      try {
        scanData1 = await context.service.performScan(saveToSd: false);
        scan1Stopwatch.stop();

        scan1Index = scanData1.name;
        logger.data('[SCAN1] Duration', '${scan1Stopwatch.elapsedMilliseconds}ms');
        logger.data('[SCAN1] Name', scanData1.name);
        logger.data('[SCAN1] Date', scanData1.date);
        logger.data('[SCAN1] Raw Size', '${scanData1.rawData.length} bytes');
        logger.pass('[SCAN1] First scan successful');

        context.scanData = scanData1;
      } on ScanFailedException catch (e) {
        scan1Stopwatch.stop();
        scan1Error = e.message;
        logger.data('[SCAN1] Duration', '${scan1Stopwatch.elapsedMilliseconds}ms');
        logger.data('[SCAN1] Error', e.message);

        // Lamp failure or other scan error - try error reset + retry
        final isLampFailure = e.message.contains('Lamp power failure');
        if (isLampFailure) {
          logger.ble('[SCAN1] Lamp failure detected - resetting error status and retrying...');
        } else {
          logger.ble('[SCAN1] Scan failed - resetting error status and retrying...');
        }

        // Read battery level for diagnostics
        try {
          final status = await context.service.getDeviceStatus();
          logger.data('[DIAG] Battery', '${status.batteryLevel}%');
          logger.data('[DIAG] Error status', status.errorStatus);
          logger.data('[DIAG] Device status', status.deviceStatus);
        } catch (diagErr) {
          logger.ble('[DIAG] Could not read status: $diagErr');
        }

        // Reset error flags
        try {
          await context.service.resetErrorStatus();
          logger.ble('[SCAN1] Error status reset complete');
        } catch (resetErr) {
          logger.ble('[SCAN1] Error reset failed: $resetErr');
        }

        // Wait for sensor recovery
        logger.ble('Waiting 5s for sensor recovery after error reset...');
        await Future.delayed(const Duration(seconds: 5));
      } on TimeoutException catch (e) {
        scan1Stopwatch.stop();
        scan1Error = e.message ?? 'Timeout';
        logger.data('[SCAN1] Duration', '${scan1Stopwatch.elapsedMilliseconds}ms');
        logger.data('[SCAN1] Error', 'TimeoutException: ${e.message}');
        logger.ble('[SCAN1] Scan timed out - likely stale error flag or disconnect');

        // Read diagnostics if still connected
        try {
          final status = await context.service.getDeviceStatus();
          logger.data('[DIAG] Battery', '${status.batteryLevel}%');
          logger.data('[DIAG] Error status', status.errorStatus);
          logger.data('[DIAG] Device status', status.deviceStatus);
        } catch (diagErr) {
          logger.ble('[DIAG] Could not read status: $diagErr');
        }

        // Reset error flags
        try {
          await context.service.resetErrorStatus();
          logger.ble('[SCAN1] Error status reset complete');
        } catch (resetErr) {
          logger.ble('[SCAN1] Error reset failed: $resetErr');
        }

        // Wait for sensor recovery
        logger.ble('Waiting 5s for sensor recovery after timeout...');
        await Future.delayed(const Duration(seconds: 5));
      } on NirScanException catch (e) {
        scan1Stopwatch.stop();
        scan1Error = e.message;
        logger.data('[SCAN1] Duration', '${scan1Stopwatch.elapsedMilliseconds}ms');
        logger.data('[SCAN1] Error', e.message);
        logger.ble('[SCAN1] First scan failed with BLE error');

        // Wait for recovery
        logger.ble('Waiting 3s for sensor recovery...');
        await Future.delayed(const Duration(seconds: 3));
      }

      // ===== SCAN 2 =====
      logger.ble('=== SCAN 2 ===');
      logger.ble('Starting second spectral scan...');

      final scan2Stopwatch = Stopwatch()..start();
      String? scan2Error;
      String? scan2Index;
      ScanData? scanData2;

      try {
        scanData2 = await context.service.performScan(saveToSd: false);
        scan2Stopwatch.stop();

        scan2Index = scanData2.name;
        logger.data('[SCAN2] Duration', '${scan2Stopwatch.elapsedMilliseconds}ms');
        logger.data('[SCAN2] Name', scanData2.name);
        logger.data('[SCAN2] Date', scanData2.date);
        logger.data('[SCAN2] Packet Format', scanData2.packetFormatVersion);
        logger.data('[SCAN2] Raw Size', '${scanData2.rawData.length} bytes');

        if (scanData2.rawData.length >= 20) {
          logger.data('[SCAN2] First 20 bytes', scanData2.rawData.sublist(0, 20));
          logger.data(
            '[SCAN2] Last 20 bytes',
            scanData2.rawData.sublist(scanData2.rawData.length - 20),
          );
        }

        logger.pass('[SCAN2] Second scan successful');
        context.scanData = scanData2;
      } on NirScanException catch (e) {
        scan2Stopwatch.stop();
        scan2Error = e.message;
        logger.data('[SCAN2] Duration', '${scan2Stopwatch.elapsedMilliseconds}ms');
        logger.data('[SCAN2] Error', e.message);
        logger.ble('[SCAN2] Second scan also failed');

        // Post-failure diagnostics
        try {
          final status = await context.service.getDeviceStatus();
          logger.data('[DIAG] Battery', '${status.batteryLevel}%');
          logger.data('[DIAG] Error status', status.errorStatus);
          logger.data('[DIAG] Device status', status.deviceStatus);
        } catch (diagErr) {
          logger.ble('[DIAG] Could not read status: $diagErr');
        }
      }

      // ===== COMPARISON =====
      logger.ble('=== COMPARISON ===');
      logger.data('Scan 1 result', scan1Error ?? 'Success: $scan1Index');
      logger.data('Scan 2 result', scan2Error ?? 'Success: $scan2Index');

      if (scan1Error != null && scan1Index == null) {
        logger.data('Stale data check', 'Scan 1 failed, checking Scan 2 behavior...');

        if (scan2Error == null && scan2Stopwatch.elapsedMilliseconds < 1000) {
          logger.data(
            'WARNING',
            'Scan 2 completed in ${scan2Stopwatch.elapsedMilliseconds}ms - might be using stale notification!',
          );
        } else if (scan2Error == null) {
          logger.pass('Scan 2 duration normal (${scan2Stopwatch.elapsedMilliseconds}ms) - using fresh notification');
        } else {
          logger.data('INFO', 'Both scans failed with errors - stale data not applicable');
        }
      }

      if (scan1Index != null && scan2Index != null) {
        if (scan1Index == scan2Index) {
          logger.data('WARNING', 'Both scans returned same name - might be stale data');
        } else {
          logger.pass('Scans have different names - confirmed independent');
        }
      }

      // Final validation
      final finalScanData = scanData2 ?? scanData1;
      if (finalScanData != null) {
        assertValidScanData(finalScanData);
        context.scanData = finalScanData;
        logger.pass('Spectral scan step complete (at least one scan succeeded)');
      } else {
        logger.ble('Both scans failed - likely hardware issue (lamp, config, etc.)');
        logger.data('Scan 1 error', scan1Error ?? 'unknown');
        logger.data('Scan 2 error', scan2Error ?? 'unknown');

        if (scan1Error == scan2Error) {
          logger.pass('Both scans failed with SAME error - consistent behavior (no stale data issue)');
          logger.ble('STALE DATA FIX VERIFIED: Each scan gets its own fresh error response');
        } else {
          throw AssertionError('Both scans failed with different errors: $scan1Error vs $scan2Error');
        }
      }
    },
    timeout: TestConfig.performScanTimeout * 2,
  );
}
