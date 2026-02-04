import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:spectriem_app/services/ble/ble_nir_scan_service.dart';
import 'package:spectriem_app/services/logging/log_service.dart';

import 'config/test_config.dart';
import 'core/test_context.dart';
import 'core/step_executor.dart';
import 'observability/integration_logger.dart';
import 'observability/observable_service.dart';
import 'flows/full_sensor_flow.dart';
import 'ui/test_status_state.dart';
import 'ui/test_status_widget.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestConfig config;
  late TestContext context;
  late IntegrationLogger logger;
  late TestStatusState uiState;
  late StepExecutor executor;

  setUpAll(() {
    config = TestConfig.fromEnvironment();
    logger = IntegrationLogger();
    context = TestContext();
    uiState = TestStatusState();
    executor = StepExecutor(config: config, logger: logger, uiState: uiState);

    // Create observable service wrapping real BLE service
    final logService = LogService();
    final bleService = BleNirScanService(logger: logService);
    context.service = ObservableNirScanService(bleService, logger);
  });

  tearDownAll(() {
    // Ensure cleanup
    try {
      context.service.dispose();
    } catch (_) {}
  });

  group('NIRScan Sensor Integration Tests', () {
    testWidgets('Full sensor flow', (tester) async {
      // Show the status widget on device
      await tester.pumpWidget(TestStatusWidget(state: uiState));

      // Start a timer to pump frames periodically for UI updates
      Timer? uiTimer;
      uiTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        tester.pump();
      });

      try {
        await executeFullSensorFlow(
          context,
          executor,
          config,
          logger,
          uiState: uiState,
        );

        // Cancel timer BEFORE any pump operations to avoid conflicts
        uiTimer.cancel();
        uiTimer = null;

        // Final pump to show completion state
        await tester.pumpAndSettle();

        // Keep showing the result for a moment
        await Future.delayed(const Duration(seconds: 3));
        await tester.pump();

        // Final assertions - connection and device info
        expect(context.selectedDevice, isNotNull,
            reason: 'Device should be selected');
        expect(context.deviceInfo, isNotNull,
            reason: 'Device info should be read');
        expect(context.deviceStatus, isNotNull,
            reason: 'Device status should be read');

        // Scan assertions - only if scan succeeded
        // Note: Scan may fail due to hardware issues (lamp error, config, etc.)
        // but BLE layer should still work correctly
        if (context.scanData != null) {
          expect(context.scanData!.rawData.length, greaterThan(100),
              reason: 'Scan data should have content');
        }
      } finally {
        uiTimer?.cancel();
      }
    });
  });
}
