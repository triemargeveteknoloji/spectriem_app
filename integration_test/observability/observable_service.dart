import 'dart:async';

import 'package:spectriem_app/models/device_info.dart';
import 'package:spectriem_app/models/device_status.dart';
import 'package:spectriem_app/models/scan_configuration.dart';
import 'package:spectriem_app/models/scan_data.dart';
import 'package:spectriem_app/services/ble/nir_scan_service.dart';

import 'integration_logger.dart';

/// Decorator that wraps [NirScanService] with logging for full observability.
///
/// All method calls are delegated to the underlying service with logging
/// before and after each operation. Stream events are also logged.
class ObservableNirScanService implements NirScanService {
  final NirScanService _delegate;
  final IntegrationLogger _logger;

  late final StreamController<NirConnectionState> _connectionStateController;
  late final StreamController<NirScanDevice> _discoveredDevicesController;

  NirConnectionState? _lastConnectionState;

  ObservableNirScanService(this._delegate, this._logger) {
    _connectionStateController = StreamController<NirConnectionState>.broadcast();
    _discoveredDevicesController = StreamController<NirScanDevice>.broadcast();

    _delegate.connectionState.listen((state) {
      final oldState = _lastConnectionState?.name ?? 'initial';
      _logger.state(oldState, state.name);
      _lastConnectionState = state;
      _connectionStateController.add(state);
    });

    _delegate.discoveredDevices.listen((device) {
      _logger.ble('Found device: ${device.name} [${device.id}] RSSI: ${device.rssi}');
      _discoveredDevicesController.add(device);
    });
  }

  @override
  Stream<NirConnectionState> get connectionState => _connectionStateController.stream;

  @override
  Stream<NirScanDevice> get discoveredDevices => _discoveredDevicesController.stream;

  @override
  NirScanDevice? get connectedDevice => _delegate.connectedDevice;

  @override
  Future<void> startDeviceScan({Duration? timeout}) async {
    final timeoutStr = timeout != null ? '${timeout.inSeconds}s' : 'no timeout';
    _logger.ble('Scanning for devices (timeout: $timeoutStr)');
    await _delegate.startDeviceScan(timeout: timeout);
  }

  @override
  Future<void> stopDeviceScan() async {
    _logger.ble('Stopping device scan');
    await _delegate.stopDeviceScan();
    _logger.ble('Device scan stopped');
  }

  @override
  Future<void> connect(String deviceId) async {
    _logger.ble('Connecting to $deviceId');
    await _delegate.connect(deviceId);
    _logger.ble('Connected successfully');
  }

  @override
  Future<void> disconnect() async {
    _logger.ble('Disconnecting');
    await _delegate.disconnect();
    _logger.ble('Disconnected');
  }

  @override
  Future<DeviceInfo> getDeviceInfo() async {
    _logger.ble('Reading device info...');
    final info = await _delegate.getDeviceInfo();
    _logger.data('Manufacturer', info.manufacturerName);
    _logger.data('Model', info.modelNumber);
    _logger.data('Serial', info.serialNumber);
    _logger.data('Hardware', info.hardwareRevision);
    _logger.data('Tiva FW', info.tivaFirmwareRevision);
    _logger.data('Spectrum Lib', info.spectrumLibraryRevision);
    return info;
  }

  @override
  Future<DeviceStatus> getDeviceStatus() async {
    _logger.ble('Reading device status...');
    final status = await _delegate.getDeviceStatus();
    _logger.data('Battery', '${status.batteryLevel}%');
    _logger.data('Temperature', '${status.temperature.toStringAsFixed(1)}C');
    _logger.data('Humidity', '${status.humidity.toStringAsFixed(1)}%');
    _logger.data('Device Status', status.deviceStatus);
    _logger.data('Error Status', status.errorStatus);
    if (status.hasErrors) {
      _logger.data('Errors', status.errorMessages.join(', '));
    }
    return status;
  }

  @override
  Future<ScanData> performScan({bool saveToSd = false}) async {
    _logger.log(LogCategory.scan, 'Starting scan (saveToSd: $saveToSd)');
    final data = await _delegate.performScan(saveToSd: saveToSd);
    _logger.log(LogCategory.scan, 'Scan complete: ${data.name}');
    _logger.data('Type', data.type);
    _logger.data('Date', data.date);
    _logger.data('Data size', '${data.rawData.length} bytes');
    return data;
  }

  @override
  Future<List<ScanConfiguration>> getScanConfigurations() async {
    _logger.ble('Reading scan configurations...');
    final configs = await _delegate.getScanConfigurations();
    _logger.data('Configuration count', configs.length);
    for (final config in configs) {
      _logger.data('Config[${ config.index}]', '${config.name} (${config.wavelengthRange})');
    }
    return configs;
  }

  @override
  Future<ScanConfiguration> getActiveScanConfiguration() async {
    _logger.ble('Reading active scan configuration...');
    final config = await _delegate.getActiveScanConfiguration();
    _logger.data('Active config', '${config.name} (index: ${config.index})');
    _logger.data('Range', config.wavelengthRange);
    _logger.data('Resolution', '${config.resolution}nm');
    return config;
  }

  @override
  Future<void> setActiveScanConfiguration(int configIndex) async {
    _logger.ble('Setting active configuration to index $configIndex');
    await _delegate.setActiveScanConfiguration(configIndex);
    _logger.ble('Configuration set');
  }

  @override
  Future<int> getStoredScanCount() async {
    _logger.ble('Reading stored scan count...');
    final count = await _delegate.getStoredScanCount();
    _logger.data('Stored scans', count);
    return count;
  }

  @override
  Future<ScanData> getStoredScan(List<int> scanIndex) async {
    _logger.ble('Reading stored scan at index $scanIndex');
    final data = await _delegate.getStoredScan(scanIndex);
    _logger.data('Retrieved scan', '${data.name} (${data.rawData.length} bytes)');
    return data;
  }

  @override
  Future<void> deleteStoredScan(List<int> scanIndex) async {
    _logger.ble('Deleting stored scan at index $scanIndex');
    await _delegate.deleteStoredScan(scanIndex);
    _logger.ble('Scan deleted');
  }

  @override
  Future<void> syncTime() async {
    _logger.ble('Syncing device time to system time');
    await _delegate.syncTime();
    _logger.ble('Time synced');
  }

  @override
  Future<void> setScanNameStub(String stub) async {
    _logger.ble('Setting scan name stub: "$stub"');
    await _delegate.setScanNameStub(stub);
    _logger.ble('Scan name stub set');
  }

  @override
  Future<void> setTemperatureThreshold(double minTemp, double maxTemp) async {
    _logger.ble('Setting temperature threshold: $minTemp - $maxTemp C');
    await _delegate.setTemperatureThreshold(minTemp, maxTemp);
    _logger.ble('Temperature threshold set');
  }

  @override
  Future<void> setHumidityThreshold(double minHumid, double maxHumid) async {
    _logger.ble('Setting humidity threshold: $minHumid - $maxHumid %');
    await _delegate.setHumidityThreshold(minHumid, maxHumid);
    _logger.ble('Humidity threshold set');
  }

  @override
  Future<void> resetErrorStatus() async {
    _logger.ble('Resetting error status via GCS command...');
    await _delegate.resetErrorStatus();
    _logger.ble('Error status reset complete');
  }

  @override
  Future<CalibrationData> getCalibrationData() async {
    _logger.log(LogCategory.cal, 'Fetching calibration data (spectrum coeff + ref coeff + matrix)...');
    final data = await _delegate.getCalibrationData();
    _logger.log(LogCategory.cal, 'Calibration data received');
    _logger.data('Spectrum coeff size', '${data.spectrumCoefficients.length} bytes');
    _logger.data('Ref coefficients size', '${data.coefficients.length} bytes');
    _logger.data('Ref matrix size', '${data.matrix.length} bytes');
    if (data.spectrumCoefficients.isNotEmpty) {
      final hexPreview = data.spectrumCoefficients
          .take(16)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(' ');
      _logger.data('Spectrum coeff hex preview', '$hexPreview...');
    }
    return data;
  }

  @override
  void dispose() {
    _logger.ble('Disposing service');
    _connectionStateController.close();
    _discoveredDevicesController.close();
    _delegate.dispose();
    _logger.ble('Service disposed');
  }
}
