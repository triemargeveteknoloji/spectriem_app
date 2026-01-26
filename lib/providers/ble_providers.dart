import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spectriem_app/providers/log_provider.dart';
import 'package:spectriem_app/services/ble/nir_scan_service.dart';
import 'package:spectriem_app/services/ble/ble_nir_scan_service.dart';
import 'package:spectriem_app/services/ble/mock_nir_scan_service.dart';

final nirScanServiceProvider = Provider<NirScanService>((ref) {
  final logService = ref.watch(logServiceProvider);

  final NirScanService service;
  if (Platform.isAndroid || Platform.isIOS) {
    service = BleNirScanService(logger: logService);
  } else {
    service = MockNirScanService();
  }

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

final connectionStateProvider = StreamProvider<NirConnectionState>((ref) {
  final service = ref.watch(nirScanServiceProvider);
  return service.connectionState;
});

final discoveredDevicesProvider = StreamProvider<NirScanDevice>((ref) {
  final service = ref.watch(nirScanServiceProvider);
  return service.discoveredDevices;
});

final connectedDeviceProvider = Provider<NirScanDevice?>((ref) {
  final service = ref.watch(nirScanServiceProvider);
  return service.connectedDevice;
});
