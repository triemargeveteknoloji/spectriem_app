import '../config/test_config.dart';
import '../core/step_executor.dart';
import '../core/test_context.dart';
import '../observability/integration_logger.dart';
import '../ui/test_status_state.dart';
import '../steps/scan_step.dart';
import '../steps/connect_step.dart';
import '../steps/device_info_step.dart';
import '../steps/status_step.dart';
import '../steps/perform_scan_step.dart';
import '../steps/calibration_step.dart';
import '../steps/disconnect_step.dart';

/// Executes the full NIR sensor integration test flow.
///
/// This flow orchestrates all test steps in the correct sequence:
/// 1. Scan for devices
/// 2. Connect to selected device
/// 3. Read device info
/// 4. Read device status
/// 5. Perform spectral scan
/// 6. Verify calibration
/// 7. Disconnect
///
/// Each step stores its results in [context] for final assertions.
/// The flow uses [executor] for timing and optional user confirmation in
/// semi-auto mode.
/// Step names for UI display.
const List<String> stepNames = [
  'Scan for devices',
  'Connect to device',
  'Read device info',
  'Read device status',
  'Perform spectral scan',
  'Verify calibration',
  'Disconnect',
];

Future<void> executeFullSensorFlow(
  TestContext context,
  StepExecutor executor,
  TestConfig config,
  IntegrationLogger logger, {
  TestStatusState? uiState,
}) async {
  context.testStartTime = DateTime.now();
  executor.reset();

  // Initialize UI state with step names
  uiState?.initialize('NIRScan Integration Test', stepNames);

  logger.separator();
  logger.step('NIRScan Integration Test Suite');
  logger.data('Mode', config.testMode.name);
  if (config.preferredDeviceName != null) {
    logger.data('Preferred device', config.preferredDeviceName);
  }
  logger.separator();

  final stopwatch = Stopwatch();

  // Step 1: Scan for devices
  stopwatch.start();
  await executeScanStep(context, executor, config, logger);
  context.recordStepDuration('scan', stopwatch.elapsed);
  stopwatch.reset();

  // Step 2: Connect to selected device
  stopwatch.start();
  await executeConnectStep(context, executor, logger);
  context.recordStepDuration('connect', stopwatch.elapsed);
  stopwatch.reset();

  // Step 3: Read device info
  stopwatch.start();
  await executeDeviceInfoStep(context, executor, logger);
  context.recordStepDuration('deviceInfo', stopwatch.elapsed);
  stopwatch.reset();

  // Step 4: Read device status
  stopwatch.start();
  await executeStatusStep(context, executor, logger);
  context.recordStepDuration('status', stopwatch.elapsed);
  stopwatch.reset();

  // Step 5: Perform spectral scan
  stopwatch.start();
  await executePerformScanStep(context, executor, logger);
  context.recordStepDuration('performScan', stopwatch.elapsed);
  stopwatch.reset();

  // Step 6: Verify calibration
  stopwatch.start();
  await executeCalibrationStep(context, executor, logger);
  context.recordStepDuration('calibration', stopwatch.elapsed);
  stopwatch.reset();

  // Step 7: Disconnect
  stopwatch.start();
  await executeDisconnectStep(context, executor, logger);
  context.recordStepDuration('disconnect', stopwatch.elapsed);
  stopwatch.stop();

  // Print summary
  logger.separator();
  logger.step('Test Suite Complete');
  logger.data('Total duration', '${context.totalDuration.inSeconds}s');
  logger.separator();

  // Log detailed summary
  for (final line in context.getSummary().split('\n')) {
    logger.data('', line);
  }

  // Mark UI complete
  uiState?.complete();
}
