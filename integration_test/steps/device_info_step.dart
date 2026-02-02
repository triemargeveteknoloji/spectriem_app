import '../core/test_context.dart';
import '../core/step_executor.dart';
import '../config/test_config.dart';
import '../observability/integration_logger.dart';
import '../assertions/sensor_assertions.dart';

Future<void> executeDeviceInfoStep(
  TestContext context,
  StepExecutor executor,
  IntegrationLogger logger,
) async {
  await executor.execute(
    'DEVICE_INFO: Reading device information',
    () async {
      final info = await context.service.getDeviceInfo();

      context.deviceInfo = info;

      logger.data('Manufacturer', info.manufacturerName);
      logger.data('Model', info.modelNumber);
      logger.data('Serial', info.serialNumber);
      logger.data('HW Revision', info.hardwareRevision);
      logger.data('Tiva FW', info.tivaFirmwareRevision);
      logger.data('Spectrum Lib', info.spectrumLibraryRevision);

      assertValidDeviceInfo(info);

      logger.pass('Device info valid');
    },
    timeout: TestConfig.deviceInfoTimeout,
  );
}
