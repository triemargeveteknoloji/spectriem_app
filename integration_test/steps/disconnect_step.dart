import 'dart:async';

import '../core/test_context.dart';
import '../core/step_executor.dart';
import '../config/test_config.dart';
import '../observability/integration_logger.dart';
import 'package:spectriem_app/services/ble/nir_scan_service.dart';

Future<void> executeDisconnectStep(
  TestContext context,
  StepExecutor executor,
  IntegrationLogger logger,
) async {
  await executor.execute(
    'DISCONNECT: Disconnecting from device',
    () async {
      if (context.service.connectedDevice == null) {
        logger.ble('Already disconnected, skipping');
        return;
      }

      final deviceName = context.service.connectedDevice!.name;

      final completer = Completer<void>();
      final subscription = context.service.connectionState.listen((state) {
        logger.state('connection', state.toString().split('.').last);
        if (state == NirConnectionState.disconnected) {
          if (!completer.isCompleted) completer.complete();
        }
      });

      await context.service.disconnect();

      await completer.future;
      await subscription.cancel();

      if (context.service.connectedDevice != null) {
        throw StateError('Disconnect failed - device still connected');
      }

      logger.pass('Disconnected from $deviceName');
    },
    timeout: TestConfig.disconnectTimeout,
  );
}
