import 'dart:typed_data';

import 'package:spectriem_app/services/ble/nir_scan_service.dart';
import 'package:spectriem_app/models/device_info.dart';
import 'package:spectriem_app/models/device_status.dart';
import 'package:spectriem_app/models/scan_data.dart';

/// Shared state container for NIR sensor integration tests.
///
/// Holds data collected across test steps including discovered devices,
/// connection state, scan results, and timing metrics.
class TestContext {
  /// Service instance (will be the observable wrapper)
  late NirScanService service;

  /// Discovered devices during scan
  final List<NirScanDevice> discoveredDevices = [];

  /// Selected device for connection
  NirScanDevice? selectedDevice;

  /// Device information retrieved after connection
  DeviceInfo? deviceInfo;

  /// Device status (battery, temperature, humidity, errors)
  DeviceStatus? deviceStatus;

  /// Scan data from spectral scan
  ScanData? scanData;

  /// Calibration coefficients (raw bytes)
  Uint8List? calibrationCoefficients;

  /// Calibration matrix (raw bytes)
  Uint8List? calibrationMatrix;

  /// Sets calibration data from CalibrationData object
  set calibrationData(CalibrationData data) {
    calibrationCoefficients = data.coefficients;
    calibrationMatrix = data.matrix;
  }

  /// Timing metrics for each test step
  final Map<String, Duration> stepDurations = {};

  /// Test start timestamp
  DateTime? testStartTime;

  /// Records the duration of a named test step.
  void recordStepDuration(String stepName, Duration duration) {
    stepDurations[stepName] = duration;
  }

  /// Resets all state for a fresh test run.
  void reset() {
    discoveredDevices.clear();
    selectedDevice = null;
    deviceInfo = null;
    deviceStatus = null;
    scanData = null;
    calibrationCoefficients = null;
    calibrationMatrix = null;
    stepDurations.clear();
    testStartTime = null;
  }

  /// Total elapsed time since test started.
  Duration get totalDuration {
    if (testStartTime == null) return Duration.zero;
    return DateTime.now().difference(testStartTime!);
  }

  /// Generates a human-readable summary of the test results.
  String getSummary() {
    final buffer = StringBuffer();
    buffer.writeln('=== Test Summary ===');
    buffer.writeln('Total duration: ${totalDuration.inSeconds}s');
    buffer.writeln('Devices found: ${discoveredDevices.length}');
    buffer.writeln('Connected to: ${selectedDevice?.name ?? "none"}');
    buffer.writeln('Device info: ${deviceInfo != null ? "OK" : "MISSING"}');
    buffer.writeln('Status: ${deviceStatus != null ? "OK" : "MISSING"}');
    buffer.writeln(
      'Scan data: ${scanData != null ? "${scanData!.rawData.length} bytes" : "MISSING"}',
    );
    buffer.writeln(
      'Calibration: ${calibrationCoefficients != null ? "OK" : "MISSING"}',
    );
    buffer.writeln('Step durations:');
    for (final entry in stepDurations.entries) {
      buffer.writeln('  ${entry.key}: ${entry.value.inMilliseconds}ms');
    }
    return buffer.toString();
  }
}
