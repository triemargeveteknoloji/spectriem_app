import '../config/test_config.dart';
import '../core/step_executor.dart';
import '../core/test_context.dart';
import '../observability/integration_logger.dart';

/// Fetches calibration data from the device.
///
/// This step must run BEFORE [executePerformScanStep] because
/// [performScan()] requires calibration data to be cached.
///
/// The calibration data (coefficients and matrix) is fetched via BLE
/// and cached in the service for subsequent scan operations.
///
/// Throws [CalibrationRequiredException] if calibration is not available.
Future<void> executeCalibrationStep(
  TestContext context,
  StepExecutor executor,
  IntegrationLogger logger,
) async {
  await executor.execute(
    'CALIBRATION: Fetching calibration data',
    () async {
      logger.ble('Requesting calibration data (coefficients + matrix)...');

      final calData = await context.service.getCalibrationData();
      context.calibrationData = calData;

      logger.ble(
          'Calibration fetched: ${calData.coefficients.length}B coefficients, ${calData.matrix.length}B matrix');
      logger.pass(
          'Calibration complete (${calData.coefficients.length + calData.matrix.length}B total)');
    },
    timeout: TestConfig.calibrationTimeout,
  );
}
