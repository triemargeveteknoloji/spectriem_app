import 'dart:async';
import 'dart:typed_data';

import '../../../models/device_info.dart';
import '../../../models/device_status.dart';
import '../../../models/scan_data.dart';
import '../../../models/scan_configuration.dart';

/// Connection state for NIRScan device
enum NirConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
}

/// Represents a discovered NIRScan device
class NirScanDevice {
  final String id;
  final String name;
  final int rssi;

  const NirScanDevice({
    required this.id,
    required this.name,
    required this.rssi,
  });

  @override
  String toString() => 'NirScanDevice(id: $id, name: $name, rssi: $rssi)';
}

/// Abstract interface for NIRScan Nano communication.
///
/// This interface can be implemented by:
/// - [BleNirScanService] for actual BLE communication
/// - [MockNirScanService] for testing without hardware
abstract class NirScanService {
  /// Stream of connection state changes
  Stream<NirConnectionState> get connectionState;

  /// Stream of discovered devices during scanning
  Stream<NirScanDevice> get discoveredDevices;

  /// Currently connected device, null if not connected
  NirScanDevice? get connectedDevice;

  /// Start scanning for NIRScan devices
  ///
  /// Discovered devices will be emitted through [discoveredDevices] stream.
  Future<void> startDeviceScan({Duration? timeout});

  /// Stop scanning for devices
  Future<void> stopDeviceScan();

  /// Connect to a specific device
  Future<void> connect(String deviceId);

  /// Disconnect from currently connected device
  Future<void> disconnect();

  /// Get device information (manufacturer, model, serial, firmware versions)
  Future<DeviceInfo> getDeviceInfo();

  /// Get device status (battery, temperature, humidity, errors)
  Future<DeviceStatus> getDeviceStatus();

  /// Perform a spectral scan
  ///
  /// [saveToSd] - If true, saves scan to device SD card
  /// Returns the scan data including spectral information
  Future<ScanData> performScan({bool saveToSd = false});

  /// Get list of stored scan configurations
  Future<List<ScanConfiguration>> getScanConfigurations();

  /// Get the currently active scan configuration
  Future<ScanConfiguration> getActiveScanConfiguration();

  /// Set the active scan configuration
  Future<void> setActiveScanConfiguration(int configIndex);

  /// Get number of scans stored on SD card
  Future<int> getStoredScanCount();

  /// Get a stored scan by index
  Future<ScanData> getStoredScan(List<int> scanIndex);

  /// Delete a stored scan
  Future<void> deleteStoredScan(List<int> scanIndex);

  /// Set device time to current system time
  Future<void> syncTime();

  /// Set scan name prefix/stub
  Future<void> setScanNameStub(String stub);

  /// Set temperature threshold for warnings
  Future<void> setTemperatureThreshold(double minTemp, double maxTemp);

  /// Set humidity threshold for warnings
  Future<void> setHumidityThreshold(double minHumid, double maxHumid);

  /// Get calibration data (coefficients and matrix)
  Future<CalibrationData> getCalibrationData();

  /// Dispose resources
  void dispose();
}

/// Calibration data from the device
class CalibrationData {
  final Uint8List spectrumCoefficients;
  final Uint8List coefficients;
  final Uint8List matrix;

  const CalibrationData({
    required this.spectrumCoefficients,
    required this.coefficients,
    required this.matrix,
  });
}

/// Exception thrown when NIRScan operations fail
class NirScanException implements Exception {
  final String message;
  final dynamic cause;

  const NirScanException(this.message, [this.cause]);

  @override
  String toString() => 'NirScanException: $message${cause != null ? ' ($cause)' : ''}';
}

/// Exception thrown when device is not connected
class NotConnectedException extends NirScanException {
  const NotConnectedException() : super('Device not connected');
}

/// Exception thrown when BLE operation times out
class BleTimeoutException extends NirScanException {
  const BleTimeoutException(String operation)
      : super('BLE operation timed out: $operation');
}

/// Exception thrown when scan fails
class ScanFailedException extends NirScanException {
  const ScanFailedException(String reason) : super('Scan failed: $reason');
}

/// Exception thrown when calibration is required before scan
class CalibrationRequiredException extends NirScanException {
  const CalibrationRequiredException()
      : super('Calibration required before scan. Call getCalibrationData() first.');
}
