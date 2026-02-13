import 'dart:async';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:spectriem_app/models/scan_configuration.dart';
import 'package:spectriem_app/providers/ble_providers.dart';
import 'package:spectriem_app/providers/log_provider.dart';
import 'package:spectriem_app/services/ble/nir_scan_service.dart';

part 'sensor_communication_notifier.freezed.dart';
part 'sensor_communication_notifier.g.dart';

@freezed
class SensorCommunicationState with _$SensorCommunicationState {
  const factory SensorCommunicationState({
    required bool isConnected,
    required bool logPanelExpanded,
    List<ScanConfiguration>? configurations,
    int? selectedConfigIndex,
    // null = not attempted, true = loaded, false = failed
    bool? isCalibrationLoaded,
  }) = _SensorCommunicationState;
}

@riverpod
class SensorCommunication extends _$SensorCommunication {
  StreamSubscription<NirConnectionState>? _connectionStateSubscription;

  @override
  SensorCommunicationState build() {
    final bleService = ref.read(nirScanServiceProvider);
    _connectionStateSubscription =
        bleService.connectionState.listen(_onConnectionStateChanged);

    ref.onDispose(() {
      _connectionStateSubscription?.cancel();
    });

    return const SensorCommunicationState(
      isConnected: false,
      logPanelExpanded: false,
    );
  }

  void _onConnectionStateChanged(NirConnectionState connectionState) {
    final wasConnected = state.isConnected;
    final isNowConnected = connectionState == NirConnectionState.connected;

    state = state.copyWith(isConnected: isNowConnected);

    if (isNowConnected && !wasConnected) {
      _initializePostConnection();
    } else if (!isNowConnected) {
      state = state.copyWith(
        configurations: null,
        selectedConfigIndex: null,
        isCalibrationLoaded: null,
      );
    }
  }

  Future<void> _initializePostConnection() async {
    final logService = ref.read(logServiceProvider);

    logService.info(
      '[POST-CONNECT] Starting post-connection initialization sequence',
      tag: 'BLE',
    );

    // Step 1: Calibration (mandatory per TI manual, but non-blocking for configs)
    logService.info(
      '[POST-CONNECT] Step 1/2: Fetching calibration data from device...',
      tag: 'CAL',
    );
    try {
      final nirScanService = ref.read(nirScanServiceProvider);
      final calData = await nirScanService.getCalibrationData();
      state = state.copyWith(isCalibrationLoaded: true);
      logService.info(
        '[POST-CONNECT] Calibration loaded successfully: '
        'specCoeff=${calData.spectrumCoefficients.length}B, '
        'refCoeff=${calData.coefficients.length}B, '
        'refMatrix=${calData.matrix.length}B',
        tag: 'CAL',
      );
    } catch (e, st) {
      state = state.copyWith(isCalibrationLoaded: false);
      logService.error(
        '[POST-CONNECT] Calibration FAILED: $e - will retry before scan. '
        'Device may need re-connection if this persists.',
        tag: 'CAL',
      );
      logService.debug(
        '[POST-CONNECT] Calibration failure stack trace: $st',
        tag: 'CAL',
      );
    }

    // Step 2: Load configurations (always attempt, even if calibration failed)
    logService.info(
      '[POST-CONNECT] Step 2/2: Loading scan configurations...',
      tag: 'BLE',
    );
    await loadConfigurations();
    logService.info(
      '[POST-CONNECT] Post-connection initialization complete. '
      'calLoaded=${state.isCalibrationLoaded}, '
      'configCount=${state.configurations?.length ?? 0}',
      tag: 'BLE',
    );
  }

  Future<void> loadConfigurations() async {
    if (!state.isConnected) return;

    final bleService = ref.read(nirScanServiceProvider);
    final logService = ref.read(logServiceProvider);

    try {
      logService.debug('Loading scan configurations...', tag: 'UI');
      final configs = await bleService.getScanConfigurations();
      state = state.copyWith(
        configurations: configs,
        selectedConfigIndex: configs.isNotEmpty ? configs.first.index : null,
      );
      logService.info('Loaded ${configs.length} configurations', tag: 'UI');
    } catch (e) {
      logService.error('Failed to load configurations: $e', tag: 'UI');
    }
  }

  Future<void> selectConfig(int? index) async {
    if (index == null || index == state.selectedConfigIndex) return;

    final bleService = ref.read(nirScanServiceProvider);
    final logService = ref.read(logServiceProvider);

    logService.info('↑ CMD: setActiveScanConfiguration($index)', tag: 'UI');
    try {
      await bleService.setActiveScanConfiguration(index);
      logService.info('↓ RSP: OK', tag: 'UI');
      state = state.copyWith(selectedConfigIndex: index);
    } on NirScanException catch (e) {
      logService.error('↓ ERR: $e', tag: 'UI');
    }
  }

  void toggleLogPanel() {
    state = state.copyWith(logPanelExpanded: !state.logPanelExpanded);
  }
}

@riverpod
class CommandExecution extends _$CommandExecution {
  @override
  FutureOr<Object?> build() {
    return null;
  }

  Future<void> executeCommand(String command) async {
    final bleService = ref.read(nirScanServiceProvider);
    final logService = ref.read(logServiceProvider);

    if (bleService.connectedDevice == null) {
      return;
    }

    logService.info('↑ CMD: $command', tag: 'UI');

    state = await AsyncValue.guard(() async {
      switch (command) {
        case 'getDeviceInfo':
          final result = await bleService.getDeviceInfo();
          logService.info('↓ RSP: ${result.manufacturerName}', tag: 'UI');
          return result;

        case 'getDeviceStatus':
          final result = await bleService.getDeviceStatus();
          logService.info('↓ RSP: Battery ${result.batteryLevel}%', tag: 'UI');
          return result;

        case 'performScan':
          final result = await bleService.performScan();
          logService.info('↓ RSP: ${result.name}', tag: 'UI');
          return result;

        case 'syncTime':
          await bleService.syncTime();
          logService.info('↓ RSP: OK', tag: 'UI');
          return 'OK';

        case 'getScanConfigurations':
          final result = await bleService.getScanConfigurations();
          logService.info('↓ RSP: ${result.length} configs', tag: 'UI');
          return result;

        case 'getCalibrationData':
          final result = await bleService.getCalibrationData();
          logService.info(
              '↓ RSP: SpecCoeff ${result.spectrumCoefficients.length}B, RefCoeff ${result.coefficients.length}B, Matrix ${result.matrix.length}B',
              tag: 'UI');
          return result;

        default:
          throw Exception('Unknown command: $command');
      }
    });

    state.whenOrNull(
      error: (error, stack) {
        logService.error('↓ ERR: $error', tag: 'UI');
      },
    );
  }
}
