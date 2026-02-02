import '../config/test_config.dart';
import '../core/step_executor.dart';
import '../core/test_context.dart';
import '../observability/integration_logger.dart';
import '../assertions/sensor_assertions.dart';

/// Executes a spectral scan and validates the returned data.
///
/// This is the most time-consuming step in the integration test suite,
/// taking up to 60 seconds to complete a full spectral scan.
///
/// The step:
/// 1. Initiates a spectral scan (without saving to SD card)
/// 2. Stores the scan data in [TestContext.scanData]
/// 3. Logs scan metadata for debugging
/// 4. Validates the scan data structure
///
/// Throws [AssertionError] if the scan data is invalid.
Future<void> executePerformScanStep(
  TestContext context,
  StepExecutor executor,
  IntegrationLogger logger,
) async {
  await executor.execute(
    'PERFORM_SCAN: Executing spectral scan',
    () async {
      logger.ble('Starting spectral scan (this may take up to 60s)...');

      final scanData = await context.service.performScan(saveToSd: false);

      context.scanData = scanData;

      logger.data('Scan Name', scanData.name);
      logger.data('Scan Type', '0x${scanData.type}');
      logger.data('Scan Date', scanData.date);
      logger.data('Packet Format', scanData.packetFormatVersion);
      logger.data('Raw Data Size', '${scanData.rawData.length} bytes');

      if (scanData.rawData.length >= 20) {
        logger.data('First 20 bytes', scanData.rawData.sublist(0, 20));
        logger.data(
          'Last 20 bytes',
          scanData.rawData.sublist(scanData.rawData.length - 20),
        );
      }

      assertValidScanData(scanData);

      logger.pass('Spectral scan complete: ${scanData.rawData.length} bytes');
    },
    timeout: TestConfig.performScanTimeout,
  );
}
