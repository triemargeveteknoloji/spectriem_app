import 'dart:async';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:spectriem_app/models/device_info.dart';
import 'package:spectriem_app/models/device_status.dart';
import 'package:spectriem_app/providers/ble_providers.dart';
import 'package:spectriem_app/providers/log_provider.dart';
import 'package:spectriem_app/services/ble/nir_scan_service.dart';

part 'bluetooth_connection_notifier.freezed.dart';
part 'bluetooth_connection_notifier.g.dart';

enum ScreenState {
  idle,
  scanning,
  connecting,
  connected,
  error,
}

@freezed
class BluetoothConnectionState with _$BluetoothConnectionState {
  const factory BluetoothConnectionState({
    required ScreenState screenState,
    required List<NirScanDevice> discoveredDevices,
    required bool logPanelExpanded,
    DeviceInfo? deviceInfo,
    DeviceStatus? deviceStatus,
    String? errorMessage,
  }) = _BluetoothConnectionState;
}

@riverpod
class BluetoothConnection extends _$BluetoothConnection {
  StreamSubscription<NirScanDevice>? _deviceSubscription;
  StreamSubscription<NirConnectionState>? _connectionStateSubscription;

  @override
  BluetoothConnectionState build() {
    // Subscribe to connection state changes directly
    final bleService = ref.watch(nirScanServiceProvider);
    _connectionStateSubscription =
        bleService.connectionState.listen((connState) {
      _onConnectionStateChanged(connState);
    });

    // Cleanup on dispose
    ref.onDispose(() {
      _deviceSubscription?.cancel();
      _connectionStateSubscription?.cancel();
    });

    return const BluetoothConnectionState(
      screenState: ScreenState.idle,
      discoveredDevices: [],
      logPanelExpanded: false,
    );
  }

  void _onConnectionStateChanged(NirConnectionState connectionState) {
    // Use scheduleMicrotask to avoid state modification during build
    scheduleMicrotask(() {
      switch (connectionState) {
        case NirConnectionState.disconnected:
          state = state.copyWith(
            screenState: ScreenState.idle,
            deviceInfo: null,
            deviceStatus: null,
          );
        case NirConnectionState.connecting:
          state = state.copyWith(screenState: ScreenState.connecting);
        case NirConnectionState.connected:
          state = state.copyWith(screenState: ScreenState.connected);
          _loadDeviceInfo();
        case NirConnectionState.disconnecting:
          break;
      }
    });
  }

  Future<void> startScanning() async {
    final bleService = ref.read(nirScanServiceProvider);
    final logService = ref.read(logServiceProvider);

    logService.info('Starting device scan...', tag: 'BLE');
    state = state.copyWith(
      screenState: ScreenState.scanning,
      discoveredDevices: [],
    );

    _deviceSubscription = bleService.discoveredDevices.listen((device) {
      logService.debug('Found device: ${device.name}', tag: 'BLE');
      // Add device if not already in list
      // Use scheduleMicrotask to avoid state modification during listener processing
      scheduleMicrotask(() {
        if (!state.discoveredDevices.any((d) => d.id == device.id)) {
          state = state.copyWith(
            discoveredDevices: [...state.discoveredDevices, device],
          );
        }
      });
    });

    try {
      await bleService.startDeviceScan(
        timeout: const Duration(seconds: 10),
      );
    } catch (e) {
      logService.error('Scan failed: $e', tag: 'BLE');
    }

    await _deviceSubscription?.cancel();
    if (state.screenState == ScreenState.scanning) {
      logService.info('Scan completed', tag: 'BLE');
      state = state.copyWith(screenState: ScreenState.idle);
    }
  }

  Future<void> stopScanning() async {
    final bleService = ref.read(nirScanServiceProvider);
    final logService = ref.read(logServiceProvider);

    logService.info('Stopping scan', tag: 'BLE');
    await bleService.stopDeviceScan();
    await _deviceSubscription?.cancel();
    state = state.copyWith(screenState: ScreenState.idle);
  }

  Future<void> connectToDevice(NirScanDevice device) async {
    final bleService = ref.read(nirScanServiceProvider);
    final logService = ref.read(logServiceProvider);

    logService.info('Connecting to ${device.name}...', tag: 'BLE');
    state = state.copyWith(screenState: ScreenState.connecting);

    try {
      await bleService.connect(device.id);
    } catch (e) {
      logService.error('Connection failed: $e', tag: 'BLE');
      state = state.copyWith(
        screenState: ScreenState.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> disconnect() async {
    final bleService = ref.read(nirScanServiceProvider);
    final logService = ref.read(logServiceProvider);

    logService.info('Disconnecting...', tag: 'BLE');
    try {
      await bleService.disconnect();
    } catch (e) {
      logService.error('Disconnect failed: $e', tag: 'BLE');
    }
  }

  Future<void> _loadDeviceInfo() async {
    final bleService = ref.read(nirScanServiceProvider);
    final logService = ref.read(logServiceProvider);

    try {
      logService.debug('Loading device info...', tag: 'BLE');
      final info = await bleService.getDeviceInfo();
      final status = await bleService.getDeviceStatus();
      logService.info(
        'Device: ${info.manufacturerName} ${info.modelNumber}',
        tag: 'BLE',
      );
      state = state.copyWith(
        deviceInfo: info,
        deviceStatus: status,
      );
    } catch (e) {
      logService.error('Failed to load device info: $e', tag: 'BLE');
    }
  }

  void toggleLogPanel() {
    state = state.copyWith(logPanelExpanded: !state.logPanelExpanded);
  }
}
