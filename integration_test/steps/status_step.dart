import '../core/test_context.dart';
import '../core/step_executor.dart';
import '../config/test_config.dart';
import '../observability/integration_logger.dart';
import '../assertions/sensor_assertions.dart';

/// Executes the device status step for NIR sensor integration tests.
///
/// Reads device status (battery, temperature, humidity, errors) from the
/// connected NIRScan device and validates the values are within expected ranges.
///
/// Logs warnings for low battery conditions and fails if error flags are set.
Future<void> executeStatusStep(
  TestContext context,
  StepExecutor executor,
  IntegrationLogger logger,
) async {
  await executor.execute(
    'STATUS: Reading device status',
    () async {
      final status = await context.service.getDeviceStatus();

      context.deviceStatus = status;

      logger.data('Battery', '${status.batteryLevel}%');
      logger.data('Temperature', '${status.temperature.toStringAsFixed(1)}°C');
      logger.data('Humidity', '${status.humidity.toStringAsFixed(1)}%');
      logger.data('Device Status', '0x${status.deviceStatus}');
      logger.data('Error Status', '0x${status.errorStatus}');

      if (status.hasErrors) {
        logger.fail('Device has errors: ${status.errorMessages.join(", ")}');
      }

      if (status.isBatteryLow) {
        logger.ble('Warning: Battery low (${status.batteryLevel}%)');
      }

      assertValidDeviceStatus(status);

      logger.pass('Device status valid');
    },
    timeout: TestConfig.statusTimeout,
  );
}
