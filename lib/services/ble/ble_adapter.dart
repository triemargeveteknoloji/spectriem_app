import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Abstraction over FlutterBluePlus for testability.
///
/// This allows mocking BLE operations in unit tests.
abstract class BleAdapter {
  /// Stream of scan results during device discovery.
  Stream<List<ScanResult>> get scanResults;

  /// Stream indicating whether scanning is in progress.
  Stream<bool> get isScanning;

  /// Start scanning for BLE devices.
  Future<void> startScan({Duration? timeout, List<Guid>? withServices});

  /// Stop scanning for devices.
  Future<void> stopScan();

  /// Get a BluetoothDevice by its ID.
  BluetoothDevice getDevice(String deviceId);
}

/// Production implementation of [BleAdapter] using FlutterBluePlus.
class FlutterBluePlusAdapter implements BleAdapter {
  @override
  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  @override
  Stream<bool> get isScanning => FlutterBluePlus.isScanning;

  @override
  Future<void> startScan({Duration? timeout, List<Guid>? withServices}) {
    return FlutterBluePlus.startScan(
      timeout: timeout ?? const Duration(seconds: 15),
      withServices: withServices ?? [],
    );
  }

  @override
  Future<void> stopScan() => FlutterBluePlus.stopScan();

  @override
  BluetoothDevice getDevice(String deviceId) {
    return BluetoothDevice.fromId(deviceId);
  }
}
