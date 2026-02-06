import '../core/test_context.dart';
import '../core/step_executor.dart';
import '../config/test_config.dart';
import '../observability/integration_logger.dart';

/// Executes the scan configuration step.
///
/// This step fetches available scan configurations from the device
/// and retrieves the currently active configuration.
Future<void> executeConfigStep(
  TestContext context,
  StepExecutor executor,
  IntegrationLogger logger,
) async {
  await executor.execute(
    'CONFIG: Fetching scan configurations',
    () async {
      // Step 1: Get all available configurations
      logger.data('Action', 'Fetching scan configurations...');
      final configs = await context.service.getScanConfigurations();
      context.scanConfigurations = configs;

      logger.data('Config count', '${configs.length}');
      for (final config in configs) {
        logger.data(
          '  Config ${config.index}',
          '"${config.name}" (${config.startWavelength.toInt()}-${config.endWavelength.toInt()} nm)',
        );
      }

      if (configs.isEmpty) {
        logger.warning('No scan configurations found on device');
        return;
      }

      // Step 2: Get active configuration
      logger.data('Action', 'Getting active configuration...');
      final activeConfig = await context.service.getActiveScanConfiguration();
      context.activeScanConfiguration = activeConfig;

      logger.data('Active config', '"${activeConfig.name}" (index: ${activeConfig.index})');
      logger.data('  Wavelength range', '${activeConfig.startWavelength.toInt()}-${activeConfig.endWavelength.toInt()} nm');
      logger.data('  Patterns', '${activeConfig.numPatterns}');
      logger.data('  Resolution', '${activeConfig.resolution.toStringAsFixed(2)} nm');

      // Verify active config is in the list
      final activeInList = configs.any((c) => c.index == activeConfig.index);
      if (!activeInList) {
        logger.warning('Active config index ${activeConfig.index} not in config list');
      }

      logger.pass('Scan configurations fetched successfully');
    },
    timeout: TestConfig.configTimeout,
  );
}
