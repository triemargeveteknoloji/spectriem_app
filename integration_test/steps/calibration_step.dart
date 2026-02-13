import '../config/test_config.dart';
import '../core/step_executor.dart';
import '../core/test_context.dart';
import '../observability/integration_logger.dart';

/// Fetches calibration data from the device.
///
/// This step must run BEFORE [executePerformScanStep] because
/// [performScan()] requires calibration data to be cached.
///
/// The calibration data (spectrum coefficients, reference coefficients,
/// and reference matrix) is fetched via BLE and cached in the service
/// for subsequent scan operations.
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
      logger.ble(
          'Requesting calibration data (spectrum coeff + ref coeff + matrix)...');

      final calData = await context.service.getCalibrationData();
      context.calibrationData = calData;

      final totalBytes = calData.spectrumCoefficients.length +
          calData.coefficients.length +
          calData.matrix.length;

      logger.cal(
          '[CAL-STEP] Spectrum calibration coefficients: '
          '${calData.spectrumCoefficients.length} bytes '
          '(expected: 48 bytes for 6x float64 polynomial)');

      if (calData.spectrumCoefficients.isNotEmpty) {
        final hexPreview = calData.spectrumCoefficients
            .take(16)
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(' ');
        logger.cal(
            '[CAL-STEP] Spectrum coeff hex preview: $hexPreview...');
      } else {
        logger.cal(
            '[CAL-STEP] WARNING: Spectrum coefficients are EMPTY (0 bytes)');
      }

      logger.cal(
          '[CAL-STEP] Reference coefficients: '
          '${calData.coefficients.length}B, '
          'Reference matrix: ${calData.matrix.length}B');

      logger.pass('Calibration complete (${totalBytes}B total: '
          'specCoeff=${calData.spectrumCoefficients.length}B, '
          'refCoeff=${calData.coefficients.length}B, '
          'refMatrix=${calData.matrix.length}B)');
    },
    timeout: TestConfig.calibrationTimeout,
  );
}
