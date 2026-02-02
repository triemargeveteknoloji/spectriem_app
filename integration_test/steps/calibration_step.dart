import '../config/test_config.dart';
import '../core/step_executor.dart';
import '../core/test_context.dart';
import '../observability/integration_logger.dart';

/// Verifies that calibration data was fetched successfully.
///
/// The [BleNirScanService] caches calibration data internally during
/// [performScan()]. The calibration fetch methods are private, so we verify
/// calibration success implicitly by checking that a scan completed.
///
/// This step requires [executePerformScanStep] to have run first.
///
/// Throws [StateError] if scan data is missing (calibration cannot be verified).
Future<void> executeCalibrationStep(
  TestContext context,
  StepExecutor executor,
  IntegrationLogger logger,
) async {
  await executor.execute(
    'CALIBRATION: Verifying calibration data was fetched',
    () async {
      if (context.scanData == null) {
        throw StateError(
          'Scan data missing - calibration cannot be verified. '
          'Run perform_scan step first.',
        );
      }

      logger.ble('Calibration data was fetched successfully during scan');
      logger.data('Verification', 'Scan completed with ${context.scanData!.rawData.length} bytes');

      logger.pass('Calibration verified (implicit via successful scan)');
    },
    timeout: TestConfig.calibrationTimeout,
  );
}
