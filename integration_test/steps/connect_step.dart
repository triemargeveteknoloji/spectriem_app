import 'dart:async';

import '../core/test_context.dart';
import '../core/step_executor.dart';
import '../config/test_config.dart';
import '../observability/integration_logger.dart';
import 'package:spectriem_app/services/ble/nir_scan_service.dart';

Future<void> executeConnectStep(
  TestContext context,
  StepExecutor executor,
  IntegrationLogger logger,
) async {
  await executor.execute(
    'CONNECT: Connecting to ${context.selectedDevice?.name ?? "device"}',
    () async {
      if (context.selectedDevice == null) {
        throw StateError('No device selected. Run scan step first.');
      }

      final completer = Completer<void>();
      final subscription = context.service.connectionState.listen((state) {
        logger.state('connection', state.toString().split('.').last);
        if (state == NirConnectionState.connected) {
          if (!completer.isCompleted) completer.complete();
        }
      });

      await context.service.connect(context.selectedDevice!.id);

      await completer.future;
      await subscription.cancel();

      if (context.service.connectedDevice == null) {
        throw StateError('Connection failed - no connected device');
      }

      logger.pass('Connected to ${context.service.connectedDevice!.name}');
    },
    timeout: TestConfig.connectionTimeout,
  );
}
