import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import '../../models/device_info.dart';
import '../../models/device_status.dart';
import '../../models/scan_configuration.dart';
import '../../models/scan_data.dart';
import 'nir_scan_service.dart';

/// Mock implementation of [NirScanService] for testing without hardware.
///
/// Simulates device discovery, connection, and scan operations with
/// configurable delays and synthetic data.
class MockNirScanService implements NirScanService {
  final _connectionStateController =
      StreamController<NirConnectionState>.broadcast();
  final _discoveredDevicesController =
      StreamController<NirScanDevice>.broadcast();

  NirConnectionState _state = NirConnectionState.disconnected;
  NirScanDevice? _connectedDevice;
  Timer? _scanTimer;

  /// Simulated delay for operations (for realistic timing)
  final Duration operationDelay;

  /// Simulated delay for scan operations
  final Duration scanDelay;

  /// Interval between device emissions during scan
  final Duration deviceEmitInterval;

  /// Whether to simulate errors randomly
  final bool simulateErrors;

  /// Error probability when simulateErrors is true (0.0 - 1.0)
  double errorProbability;

  final _random = Random();

  MockNirScanService({
    this.operationDelay = const Duration(milliseconds: 100),
    this.scanDelay = const Duration(seconds: 2),
    this.deviceEmitInterval = const Duration(milliseconds: 500),
    this.simulateErrors = false,
    this.errorProbability = 0.1,
  });

  @override
  Stream<NirConnectionState> get connectionState =>
      _connectionStateController.stream;

  @override
  Stream<NirScanDevice> get discoveredDevices =>
      _discoveredDevicesController.stream;

  @override
  NirScanDevice? get connectedDevice => _connectedDevice;

  void _emitConnectionState(NirConnectionState state) {
    _state = state;
    _connectionStateController.add(state);
  }

  void _checkError(String operation) {
    if (simulateErrors && _random.nextDouble() < errorProbability) {
      throw NirScanException('Simulated error during $operation');
    }
  }

  @override
  Future<void> startDeviceScan({Duration? timeout}) async {
    // Skip delay if zero (for testing)
    if (operationDelay > Duration.zero) {
      await Future.delayed(operationDelay);
    }

    // Emit mock devices immediately if interval is zero (for testing)
    if (deviceEmitInterval == Duration.zero) {
      // Create all devices first
      const devices = [
        NirScanDevice(id: 'mock-device-1', name: 'NIRScan Nano B', rssi: -65),
        NirScanDevice(id: 'mock-device-2', name: 'NIRScan Nano C', rssi: -70),
        NirScanDevice(id: 'mock-device-3', name: 'NIRScan Nano D', rssi: -75),
      ];
      // Emit each device and yield to event loop
      for (final device in devices) {
        _discoveredDevicesController.add(device);
        await Future.value(); // Yield to allow listener processing
      }
    } else {
      // Emit devices at configured interval
      _scanTimer = Timer.periodic(deviceEmitInterval, (timer) {
        if (timer.tick <= 3) {
          _discoveredDevicesController.add(NirScanDevice(
            id: 'mock-device-${timer.tick}',
            name: 'NIRScan Nano ${String.fromCharCode(65 + timer.tick)}',
            rssi: -60 - _random.nextInt(30),
          ));
        }
      });
    }

    // Auto-stop after timeout (skip if testing mode with zero delays)
    if (timeout != null &&
        timeout > Duration.zero &&
        operationDelay > Duration.zero) {
      Future.delayed(timeout, stopDeviceScan);
    }
  }

  @override
  Future<void> stopDeviceScan() async {
    _scanTimer?.cancel();
    _scanTimer = null;
  }

  @override
  Future<void> connect(String deviceId) async {
    _emitConnectionState(NirConnectionState.connecting);
    if (operationDelay > Duration.zero) {
      await Future.delayed(operationDelay * 5);
    }

    _checkError('connect');

    _connectedDevice = NirScanDevice(
      id: deviceId,
      name: 'NIRScan Nano Mock',
      rssi: -65,
    );
    _emitConnectionState(NirConnectionState.connected);
  }

  @override
  Future<void> disconnect() async {
    _emitConnectionState(NirConnectionState.disconnecting);
    if (operationDelay > Duration.zero) {
      await Future.delayed(operationDelay);
    }

    _connectedDevice = null;
    _emitConnectionState(NirConnectionState.disconnected);
  }

  void _ensureConnected() {
    if (_state != NirConnectionState.connected || _connectedDevice == null) {
      throw const NotConnectedException();
    }
  }

  @override
  Future<DeviceInfo> getDeviceInfo() async {
    _ensureConnected();
    if (operationDelay > Duration.zero) {
      await Future.delayed(operationDelay * 3);
    }
    _checkError('getDeviceInfo');

    return const DeviceInfo(
      manufacturerName: 'Texas Instruments',
      modelNumber: 'NIRScan Nano EVM',
      serialNumber: 'MOCK-12345-67890',
      hardwareRevision: '2.0.0',
      tivaFirmwareRevision: '2.4.4',
      spectrumLibraryRevision: '2.1.0.11',
    );
  }

  @override
  Future<DeviceStatus> getDeviceStatus() async {
    _ensureConnected();
    if (operationDelay > Duration.zero) {
      await Future.delayed(operationDelay * 2);
    }
    _checkError('getDeviceStatus');

    return DeviceStatus(
      batteryLevel: 50 + _random.nextInt(50),
      temperature: 20.0 + _random.nextDouble() * 10,
      humidity: 30.0 + _random.nextDouble() * 40,
      deviceStatus: '00',
      errorStatus: '00',
    );
  }

  @override
  Future<ScanData> performScan({bool saveToSd = false}) async {
    _ensureConnected();
    await Future.delayed(scanDelay);
    _checkError('performScan');

    final now = DateTime.now();
    final dateStr =
        '${now.year % 100}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

    // Generate mock spectral data
    final Uint8List mockData = _generateMockSpectralData();

    return ScanData(
      name: 'MockScan_${now.millisecondsSinceEpoch}',
      type: '00',
      date: dateStr,
      packetFormatVersion: '01 00',
      rawData: mockData,
      scanIndex: saveToSd ? [0, 0, 0, _random.nextInt(256)] : null,
    );
  }

  Uint8List _generateMockSpectralData() {
    // Generate a realistic-looking NIR spectrum (228 points from 900-1700nm)
    const points = 228;
    final data = List<double>.generate(points, (i) {
      final wavelength = 900.0 + (i * 800.0 / points);
      // Simulate water absorption peaks around 970nm, 1200nm, 1450nm
      var intensity = 0.5;
      intensity +=
          0.3 * exp(-pow((wavelength - 970) / 30, 2)); // Water O-H stretch
      intensity +=
          0.2 * exp(-pow((wavelength - 1200) / 50, 2)); // C-H combination
      intensity += 0.4 *
          exp(-pow((wavelength - 1450) / 40, 2)); // Water O-H first overtone
      intensity += (_random.nextDouble() - 0.5) * 0.05; // Noise
      return intensity.clamp(0.0, 1.0);
    });

    // Convert to bytes (simplified - real format is more complex)
    final buffer = ByteData(points * 4);
    for (var i = 0; i < points; i++) {
      buffer.setFloat32(i * 4, data[i], Endian.little);
    }
    return buffer.buffer.asUint8List();
  }

  @override
  Future<List<ScanConfiguration>> getScanConfigurations() async {
    _ensureConnected();
    await Future.delayed(operationDelay * 2);
    _checkError('getScanConfigurations');

    return [
      ScanConfiguration(
        index: 0,
        name: 'Column 1',
        rawData: Uint8List(64),
        startWavelength: 900,
        endWavelength: 1700,
        resolution: 10,
      ),
      ScanConfiguration(
        index: 1,
        name: 'Hadamard',
        rawData: Uint8List(64),
        startWavelength: 900,
        endWavelength: 1700,
        resolution: 3.5,
      ),
      ScanConfiguration(
        index: 2,
        name: 'Quick Scan',
        rawData: Uint8List(64),
        startWavelength: 1000,
        endWavelength: 1600,
        resolution: 20,
      ),
    ];
  }

  @override
  Future<ScanConfiguration> getActiveScanConfiguration() async {
    _ensureConnected();
    await Future.delayed(operationDelay);
    _checkError('getActiveScanConfiguration');

    return ScanConfiguration(
      index: 0,
      name: 'Column 1',
      rawData: Uint8List(64),
      startWavelength: 900,
      endWavelength: 1700,
      resolution: 10,
    );
  }

  @override
  Future<void> setActiveScanConfiguration(int configIndex) async {
    _ensureConnected();
    await Future.delayed(operationDelay);
    _checkError('setActiveScanConfiguration');
  }

  @override
  Future<int> getStoredScanCount() async {
    _ensureConnected();
    await Future.delayed(operationDelay);
    _checkError('getStoredScanCount');
    return 5;
  }

  @override
  Future<ScanData> getStoredScan(List<int> scanIndex) async {
    _ensureConnected();
    await Future.delayed(operationDelay * 3);
    _checkError('getStoredScan');

    return ScanData(
      name: 'StoredScan_${scanIndex.join('')}',
      type: '00',
      date: '250125120000',
      packetFormatVersion: '01 00',
      rawData: _generateMockSpectralData(),
      scanIndex: scanIndex,
    );
  }

  @override
  Future<void> deleteStoredScan(List<int> scanIndex) async {
    _ensureConnected();
    await Future.delayed(operationDelay);
    _checkError('deleteStoredScan');
  }

  @override
  Future<void> syncTime() async {
    _ensureConnected();
    await Future.delayed(operationDelay);
    _checkError('syncTime');
  }

  @override
  Future<void> setScanNameStub(String stub) async {
    _ensureConnected();
    await Future.delayed(operationDelay);
    _checkError('setScanNameStub');
  }

  @override
  Future<void> setTemperatureThreshold(double minTemp, double maxTemp) async {
    _ensureConnected();
    await Future.delayed(operationDelay);
    _checkError('setTemperatureThreshold');
  }

  @override
  Future<void> setHumidityThreshold(double minHumid, double maxHumid) async {
    _ensureConnected();
    await Future.delayed(operationDelay);
    _checkError('setHumidityThreshold');
  }

  @override
  Future<void> resetErrorStatus() async {
    _ensureConnected();
    if (operationDelay > Duration.zero) {
      await Future.delayed(operationDelay);
    }
    _checkError('resetErrorStatus');
  }

  @override
  Future<CalibrationData> getCalibrationData() async {
    _ensureConnected();
    await Future.delayed(operationDelay * 5);
    _checkError('getCalibrationData');

    return CalibrationData(
      spectrumCoefficients: Uint8List(48),
      coefficients: Uint8List(1024),
      matrix: Uint8List(2048),
    );
  }

  /// Test helper: Simulate a connection without going through connect() method.
  /// Useful for testing scenarios where you need instant connection state changes.
  void simulateConnection() {
    _connectedDevice = const NirScanDevice(
      id: 'mock-test-device',
      name: 'NIRScan Nano Test',
      rssi: -65,
    );
    _emitConnectionState(NirConnectionState.connected);
  }

  /// Test helper: Simulate a disconnection without going through disconnect() method.
  /// Useful for testing scenarios where you need instant disconnection state changes.
  void simulateDisconnection() {
    _connectedDevice = null;
    _emitConnectionState(NirConnectionState.disconnected);
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _connectionStateController.close();
    _discoveredDevicesController.close();
  }
}
