import 'dart:io';

import '../config/test_config.dart';
import '../observability/integration_logger.dart';
import '../ui/test_status_state.dart';

typedef StepAction<T> = Future<T> Function();

/// Executes test steps with timing, logging, and optional user confirmation.
class StepExecutor {
  final TestConfig config;
  final IntegrationLogger logger;
  final TestStatusState? uiState;

  int _stepIndex = 0;

  StepExecutor({
    required this.config,
    required this.logger,
    this.uiState,
  });

  /// Reset step index for a new test run.
  void reset() {
    _stepIndex = 0;
  }

  /// Execute a test step with timing and logging.
  ///
  /// In semi-auto mode, waits for user confirmation before executing.
  /// Logs step start, duration, and pass/fail status.
  /// Updates UI state if provided.
  Future<T> execute<T>(
    String stepName,
    StepAction<T> action, {
    Duration? timeout,
  }) async {
    final currentIndex = _stepIndex++;

    logger.step(stepName);
    uiState?.startStep(currentIndex);

    if (config.isSemiAuto) {
      await _waitForUserConfirmation(stepName);
    }

    final stopwatch = Stopwatch()..start();

    try {
      final result = await (timeout != null
          ? action().timeout(timeout)
          : action());

      stopwatch.stop();
      final duration = stopwatch.elapsed;

      logger.pass('$stepName completed (${duration.inMilliseconds}ms)');
      uiState?.passStep(
        currentIndex,
        duration: duration,
        message: 'Completed in ${duration.inMilliseconds}ms',
      );

      return result;
    } catch (e) {
      stopwatch.stop();
      logger.fail('$stepName failed after ${stopwatch.elapsedMilliseconds}ms: $e');
      uiState?.failStep(currentIndex, message: e.toString());
      rethrow;
    }
  }

  /// Wait for user to press Enter in semi-auto mode.
  Future<void> _waitForUserConfirmation(String stepName) async {
    stdout.write('Press Enter to execute "$stepName"...');
    stdin.readLineSync();
  }
}
