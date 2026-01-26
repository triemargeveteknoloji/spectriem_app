import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../models/device_info.dart';
import '../../models/device_status.dart';
import '../../models/scan_configuration.dart';
import '../../models/scan_data.dart';
import 'ble_adapter.dart';
import 'multi_packet_receiver.dart';
import 'nano_gatt.dart';
import 'nir_scan_service.dart';

/// BLE implementation of [NirScanService] for NIRScan Nano devices.
class BleNirScanService implements NirScanService {
  final BleAdapter _adapter;

  final _connectionStateController =
      StreamController<NirConnectionState>.broadcast();
  final _discoveredDevicesController =
      StreamController<NirScanDevice>.broadcast();

  NirConnectionState _currentState = NirConnectionState.disconnected;
  NirScanDevice? _connectedDevice;
  BluetoothDevice? _bleDevice;
  List<BluetoothService>? _services;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  final List<StreamSubscription> _notificationSubscriptions = [];

  BleNirScanService({BleAdapter? adapter})
      : _adapter = adapter ?? FlutterBluePlusAdapter() {
    _connectionStateController.add(_currentState);
  }

  @override
  Stream<NirConnectionState> get connectionState =>
      _connectionStateController.stream;

  @override
  Stream<NirScanDevice> get discoveredDevices =>
      _discoveredDevicesController.stream;

  @override
  NirScanDevice? get connectedDevice => _connectedDevice;

  @override
  Future<void> startDeviceScan({Duration? timeout}) async {
    await _scanSubscription?.cancel();

    _scanSubscription = _adapter.scanResults.listen((results) {
      for (final result in results) {
        if (NanoDevicePatterns.isNanoDevice(result.advertisementData.advName)) {
          _discoveredDevicesController.add(NirScanDevice(
            id: result.device.remoteId.str,
            name: result.advertisementData.advName,
            rssi: result.rssi,
          ));
        }
      }
    });

    await _adapter.startScan(timeout: timeout);

    // Wait until scanning stops (either by timeout or manual stop)
    await _adapter.isScanning.firstWhere((isScanning) => !isScanning);
  }

  @override
  Future<void> stopDeviceScan() async {
    await _adapter.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  @override
  Future<void> connect(String deviceId) async {
    _setConnectionState(NirConnectionState.connecting);
    print('🔵 [BLE] Connecting to device: $deviceId');

    try {
      _bleDevice = _adapter.getDevice(deviceId);

      await _bleDevice!.connect(timeout: const Duration(seconds: 15));
      print('✅ [BLE] Connected to device');

      _connectionSubscription = _bleDevice!.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          print('⚠️  [BLE] Device disconnected');
          _handleDisconnection();
        }
      });

      _services = await _bleDevice!.discoverServices();
      print('✅ [BLE] Services discovered: ${_services?.length ?? 0}');

      // Subscribe to all notifications as per protocol (Flow 1)
      print(
          '🔔 [BLE] Subscribing to ${NanoGatt.notificationCharacteristics.length} notification characteristics...');
      await subscribeToAllNotifications(skipConnectionCheck: true);
      print('✅ [BLE] All notifications subscribed');

      _connectedDevice = NirScanDevice(
        id: deviceId,
        name: _bleDevice!.platformName,
        rssi: 0,
      );

      _setConnectionState(NirConnectionState.connected);
      print(
          '🎉 [BLE] Connection fully established to ${_bleDevice!.platformName}');
    } catch (e) {
      _handleDisconnection();
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    _setConnectionState(NirConnectionState.disconnecting);

    await _cancelNotificationSubscriptions();
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;

    await _bleDevice?.disconnect();
    _bleDevice = null;
    _services = null;
    _connectedDevice = null;

    _setConnectionState(NirConnectionState.disconnected);
  }

  void _setConnectionState(NirConnectionState state) {
    _currentState = state;
    _connectionStateController.add(state);
  }

  void _handleDisconnection() {
    _connectedDevice = null;
    _bleDevice = null;
    _services = null;
    _setConnectionState(NirConnectionState.disconnected);
  }

  Future<void> _cancelNotificationSubscriptions() async {
    for (final subscription in _notificationSubscriptions) {
      await subscription.cancel();
    }
    _notificationSubscriptions.clear();
  }

  void _ensureConnected() {
    if (_currentState != NirConnectionState.connected || _bleDevice == null) {
      throw const NotConnectedException();
    }
  }

  BluetoothCharacteristic? _findCharacteristic(Guid uuid) {
    if (_services == null) return null;

    for (final service in _services!) {
      for (final char in service.characteristics) {
        if (char.uuid == uuid) {
          return char;
        }
      }
    }
    return null;
  }

  @override
  Future<DeviceInfo> getDeviceInfo() async {
    _ensureConnected();

    final manufacturerName =
        await _readStringCharacteristic(NanoGatt.disManufName);
    final modelNumber =
        await _readStringCharacteristic(NanoGatt.disModelNumber);
    final serialNumber =
        await _readStringCharacteristic(NanoGatt.disSerialNumber);
    final hardwareRevision = await _readStringCharacteristic(NanoGatt.disHwRev);
    final tivaFirmwareRevision =
        await _readStringCharacteristic(NanoGatt.disTivaFwRev);
    final spectrumLibraryRevision =
        await _readUint16Characteristic(NanoGatt.disSpeccRev);

    return DeviceInfo(
      manufacturerName: manufacturerName,
      modelNumber: modelNumber,
      serialNumber: serialNumber,
      hardwareRevision: hardwareRevision,
      tivaFirmwareRevision: tivaFirmwareRevision,
      spectrumLibraryRevision: spectrumLibraryRevision.toString(),
    );
  }

  Future<String> _readStringCharacteristic(Guid uuid) async {
    final char = _findCharacteristic(uuid);
    if (char == null) {
      throw NirScanException('Characteristic not found: $uuid');
    }
    final bytes = await char.read();
    return String.fromCharCodes(bytes);
  }

  Future<int> _readUint16Characteristic(Guid uuid) async {
    final char = _findCharacteristic(uuid);
    if (char == null) {
      throw NirScanException('Characteristic not found: $uuid');
    }
    final bytes = await char.read();
    if (bytes.length < 2) {
      throw NirScanException('Invalid uint16 data for $uuid');
    }
    // Little-endian
    return (bytes[1] << 8) | (bytes[0] & 0xFF);
  }

  Future<int> _readUint8Characteristic(Guid uuid) async {
    final char = _findCharacteristic(uuid);
    if (char == null) {
      throw NirScanException('Characteristic not found: $uuid');
    }
    final bytes = await char.read();
    if (bytes.isEmpty) {
      throw NirScanException('Invalid uint8 data for $uuid');
    }
    return bytes[0] & 0xFF;
  }

  Future<int> _readInt16Characteristic(Guid uuid) async {
    final char = _findCharacteristic(uuid);
    if (char == null) {
      throw NirScanException('Characteristic not found: $uuid');
    }
    final bytes = await char.read();
    if (bytes.length < 2) {
      throw NirScanException('Invalid int16 data for $uuid');
    }
    // Little-endian signed
    final value = (bytes[1] << 8) | (bytes[0] & 0xFF);
    // Convert to signed if needed
    return value > 32767 ? value - 65536 : value;
  }

  /// Subscribe to notifications for a characteristic.
  /// Returns a stream that emits notification data.
  Future<Stream<List<int>>> subscribeToNotifications(Guid uuid) async {
    _ensureConnected();

    final char = _findCharacteristic(uuid);
    if (char == null) {
      throw NirScanException('Characteristic not found: $uuid');
    }

    await char.setNotifyValue(true);
    return char.onValueReceived;
  }

  /// Subscribe to all notification characteristics in sequence.
  /// This should be called after connection for full sensor functionality.
  /// Can be called from connect() or manually after connection is established.
  Future<void> subscribeToAllNotifications({
    Duration delayBetween = const Duration(milliseconds: 100),
    bool skipConnectionCheck = false,
  }) async {
    if (!skipConnectionCheck) {
      _ensureConnected();
    }

    for (final uuid in NanoGatt.notificationCharacteristics) {
      final char = _findCharacteristic(uuid);
      if (char != null) {
        await char.setNotifyValue(true);
        await Future.delayed(delayBetween);
      }
    }
  }

  @override
  Future<DeviceStatus> getDeviceStatus() async {
    _ensureConnected();

    final batteryLevel = await _readUint8Characteristic(NanoGatt.basBattLvl);
    final tempRaw =
        await _readInt16Characteristic(NanoGatt.ggisTempMeasurement);
    final humidRaw =
        await _readUint16Characteristic(NanoGatt.ggisHumidMeasurement);
    final devStatusRaw =
        await _readUint16Characteristic(NanoGatt.ggisDevStatus);
    final errStatusRaw =
        await _readUint16Characteristic(NanoGatt.ggisErrStatus);

    return DeviceStatus(
      batteryLevel: batteryLevel,
      temperature: tempRaw / 100.0,
      humidity: humidRaw / 100.0,
      deviceStatus: devStatusRaw.toRadixString(16).padLeft(2, '0'),
      errorStatus: errStatusRaw.toRadixString(16).padLeft(2, '0'),
    );
  }

  @override
  Future<ScanData> performScan({bool saveToSd = false}) async {
    _ensureConnected();
    print('🔵 [SCAN] Starting scan...');

    // Sync device time before scan (as per protocol Flow 4B)
    print('🕐 [SCAN] Syncing device time...');
    await syncTime();
    print('✅ [SCAN] Time synced');

    // Ensure calibration data is cached (as per protocol Flow 4A)
    print('🔬 [SCAN] Fetching calibration data...');
    await _ensureCalibrationData();
    print(
        '✅ [SCAN] Calibration cached: coeff=${_cachedRefCalCoeff?.length ?? 0} bytes, matrix=${_cachedRefCalMatrix?.length ?? 0} bytes');

    // 1. Subscribe to start scan notifications and trigger scan
    final startScanChar = _findCharacteristic(NanoGatt.gsdisStartScan);
    if (startScanChar == null) {
      throw NirScanException('Start scan characteristic not found');
    }

    await startScanChar.setNotifyValue(true);

    // Create completer to wait for scan complete notification
    final scanCompleter = Completer<List<int>>();
    late StreamSubscription<List<int>> startScanSubscription;

    startScanSubscription = startScanChar.onValueReceived.listen((data) {
      if (!scanCompleter.isCompleted && data.isNotEmpty) {
        scanCompleter.complete(data);
        startScanSubscription.cancel();
      }
    });

    // Write save flag to start scan
    await startScanChar.write([saveToSd ? 0x01 : 0x00]);

    // 2. Wait for scan complete notification
    final scanResult = await scanCompleter.future;

    if (scanResult.isEmpty || scanResult[0] != 0xFF) {
      throw ScanFailedException(
        'Scan did not complete successfully: ${scanResult.isNotEmpty ? scanResult[0] : "empty"}',
      );
    }

    // 3. Extract scan index (4 bytes after 0xFF)
    final scanIndex = scanResult.length >= 5
        ? scanResult.sublist(1, 5)
        : [0x00, 0x00, 0x00, 0x00];

    // 4. Request scan metadata
    final scanName = await _requestScanMetadata(
      NanoGatt.gsdisReqScanName,
      NanoGatt.gsdisRetScanName,
      scanIndex,
    );

    final scanTypeBytes = await _requestScanMetadata(
      NanoGatt.gsdisReqScanType,
      NanoGatt.gsdisRetScanType,
      scanIndex,
    );

    final scanDateBytes = await _requestScanMetadata(
      NanoGatt.gsdisReqScanDate,
      NanoGatt.gsdisRetScanDate,
      scanIndex,
    );

    final pktFmtVerBytes = await _requestScanMetadata(
      NanoGatt.gsdisReqPktFmtVer,
      NanoGatt.gsdisRetPktFmtVer,
      scanIndex,
    );

    // 5. Request serialized scan data (multi-packet)
    final rawData = await _requestMultiPacketData(
      NanoGatt.gsdisReqSerScanDataStruct,
      NanoGatt.gsdisRetSerScanDataStruct,
      scanIndex,
    );

    // 6. Parse metadata and return ScanData
    final name = String.fromCharCodes(scanName);
    final type = scanTypeBytes.isNotEmpty
        ? scanTypeBytes[0].toRadixString(16).padLeft(2, '0')
        : '00';
    final date = String.fromCharCodes(scanDateBytes);
    final packetFormatVersion = pktFmtVerBytes.isNotEmpty
        ? _parseUint32LittleEndian(pktFmtVerBytes).toString()
        : '0';

    final scanData = ScanData(
      name: name,
      type: type,
      date: date,
      packetFormatVersion: packetFormatVersion,
      rawData: Uint8List.fromList(rawData),
      scanIndex: scanIndex,
    );

    // Log scan completion
    print('');
    print('🎉 [SCAN] ============ SCAN COMPLETED ============');
    print('📦 [SCAN] Raw Data Size: ${scanData.rawData.length} bytes');
    print('📝 [SCAN] Name: ${scanData.name}');
    print('📅 [SCAN] Date: ${scanData.date}');
    print('🔢 [SCAN] Type: ${scanData.type}');
    print('📌 [SCAN] Version: ${scanData.packetFormatVersion}');
    print('🔬 [SCAN] First 20 bytes: ${scanData.rawData.take(20).toList()}');
    print(
        '🔬 [SCAN] Last 20 bytes: ${scanData.rawData.skip(scanData.rawData.length - 20).take(20).toList()}');
    print(
        '✅ [SCAN] Calibration available: coeff=${_cachedRefCalCoeff?.length ?? 0}B, matrix=${_cachedRefCalMatrix?.length ?? 0}B');
    print('🎉 [SCAN] =========================================');
    print('');

    return scanData;
  }

  Future<List<int>> _requestScanMetadata(
    Guid requestUuid,
    Guid responseUuid,
    List<int> scanIndex,
  ) async {
    final requestChar = _findCharacteristic(requestUuid);
    final responseChar = _findCharacteristic(responseUuid);

    if (requestChar == null || responseChar == null) {
      throw NirScanException('Scan metadata characteristics not found');
    }

    await responseChar.setNotifyValue(true);

    final completer = Completer<List<int>>();
    late StreamSubscription<List<int>> subscription;

    subscription = responseChar.onValueReceived.listen((data) {
      if (!completer.isCompleted) {
        completer.complete(data);
        subscription.cancel();
      }
    });

    await requestChar.write(scanIndex);

    return completer.future;
  }

  Future<List<int>> _requestMultiPacketData(
    Guid requestUuid,
    Guid responseUuid,
    List<int> scanIndex,
  ) async {
    final requestChar = _findCharacteristic(requestUuid);
    final responseChar = _findCharacteristic(responseUuid);

    if (requestChar == null || responseChar == null) {
      throw NirScanException('Scan data characteristics not found');
    }

    await responseChar.setNotifyValue(true);

    final receiver = MultiPacketReceiver();
    final completer = Completer<List<int>>();
    late StreamSubscription<List<int>> subscription;

    subscription = responseChar.onValueReceived.listen((data) {
      receiver.onPacketReceived(data);
      if (receiver.isComplete && !completer.isCompleted) {
        completer.complete(receiver.data);
        subscription.cancel();
      }
    });

    await requestChar.write(scanIndex);

    return completer.future;
  }

  int _parseUint32LittleEndian(List<int> bytes) {
    if (bytes.length < 4) return 0;
    return (bytes[3] << 24) | (bytes[2] << 16) | (bytes[1] << 8) | bytes[0];
  }

  @override
  Future<List<ScanConfiguration>> getScanConfigurations() async {
    _ensureConnected();
    throw UnsupportedError('getScanConfigurations not implemented yet');
  }

  @override
  Future<ScanConfiguration> getActiveScanConfiguration() async {
    _ensureConnected();
    throw UnsupportedError('getActiveScanConfiguration not implemented yet');
  }

  @override
  Future<void> setActiveScanConfiguration(int configIndex) async {
    _ensureConnected();
    throw UnsupportedError('setActiveScanConfiguration not implemented yet');
  }

  @override
  Future<int> getStoredScanCount() async {
    _ensureConnected();
    throw UnsupportedError('getStoredScanCount not implemented yet');
  }

  @override
  Future<ScanData> getStoredScan(List<int> scanIndex) async {
    _ensureConnected();
    throw UnsupportedError('getStoredScan not implemented yet');
  }

  @override
  Future<void> deleteStoredScan(List<int> scanIndex) async {
    _ensureConnected();
    throw UnsupportedError('deleteStoredScan not implemented yet');
  }

  @override
  Future<void> syncTime() async {
    _ensureConnected();

    final char = _findCharacteristic(NanoGatt.gdtsTime);
    if (char == null) {
      throw NirScanException('GDTS Time characteristic not found');
    }

    final now = DateTime.now();
    final timeBytes = [
      now.year - 2000, // Year offset from 2000 (0-99)
      now.month, // Month (1-12)
      now.day, // Day (1-31)
      now.weekday % 7, // DayOfWeek (0=Sunday, 1=Monday, ..., 6=Saturday)
      now.hour, // Hour (0-23)
      now.minute, // Minute (0-59)
      now.second, // Second (0-59)
    ];

    await char.write(timeBytes);
  }

  // Calibration data cache
  List<int>? _cachedRefCalCoeff;
  List<int>? _cachedRefCalMatrix;

  /// Ensures calibration data is available (fetches if not cached)
  Future<void> _ensureCalibrationData() async {
    if (_cachedRefCalCoeff != null && _cachedRefCalMatrix != null) {
      return; // Already cached
    }

    // Fetch calibration coefficients
    if (_cachedRefCalCoeff == null) {
      _cachedRefCalCoeff = await _fetchCalibrationCoefficients();
    }

    // Fetch calibration matrix
    if (_cachedRefCalMatrix == null) {
      _cachedRefCalMatrix = await _fetchCalibrationMatrix();
    }
  }

  /// Fetches reference calibration coefficients (multi-packet)
  Future<List<int>> _fetchCalibrationCoefficients() async {
    final reqChar = _findCharacteristic(NanoGatt.gcisReqRefCalCoeff);
    final retChar = _findCharacteristic(NanoGatt.gcisRetRefCalCoeff);

    if (reqChar == null || retChar == null) {
      throw NirScanException(
          'Calibration coefficient characteristics not found');
    }

    await retChar.setNotifyValue(true);

    final receiver = MultiPacketReceiver();
    final completer = Completer<List<int>>();

    final subscription = retChar.onValueReceived.listen((data) {
      receiver.onPacketReceived(data);
      if (receiver.isComplete) {
        completer.complete(receiver.data);
      }
    });

    // Request calibration coefficients
    await reqChar.write([0x00]); // Dummy byte to trigger

    try {
      final coeffData = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () =>
            throw TimeoutException('Calibration coefficient fetch timeout'),
      );
      return coeffData;
    } finally {
      await subscription.cancel();
    }
  }

  /// Fetches reference calibration matrix (multi-packet)
  Future<List<int>> _fetchCalibrationMatrix() async {
    final reqChar = _findCharacteristic(NanoGatt.gcisReqRefCalMatrix);
    final retChar = _findCharacteristic(NanoGatt.gcisRetRefCalMatrix);

    if (reqChar == null || retChar == null) {
      throw NirScanException('Calibration matrix characteristics not found');
    }

    await retChar.setNotifyValue(true);

    final receiver = MultiPacketReceiver();
    final completer = Completer<List<int>>();

    final subscription = retChar.onValueReceived.listen((data) {
      receiver.onPacketReceived(data);
      if (receiver.isComplete) {
        completer.complete(receiver.data);
      }
    });

    // Request calibration matrix
    await reqChar.write([0x00]); // Dummy byte to trigger

    try {
      final matrixData = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () =>
            throw TimeoutException('Calibration matrix fetch timeout'),
      );
      return matrixData;
    } finally {
      await subscription.cancel();
    }
  }

  @override
  Future<void> setScanNameStub(String stub) async {
    _ensureConnected();
    throw UnsupportedError('setScanNameStub not implemented yet');
  }

  @override
  Future<void> setTemperatureThreshold(double minTemp, double maxTemp) async {
    _ensureConnected();
    throw UnsupportedError('setTemperatureThreshold not implemented yet');
  }

  @override
  Future<void> setHumidityThreshold(double minHumid, double maxHumid) async {
    _ensureConnected();
    throw UnsupportedError('setHumidityThreshold not implemented yet');
  }

  @override
  Future<CalibrationData> getCalibrationData() async {
    _ensureConnected();
    throw UnsupportedError('getCalibrationData not implemented yet');
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _cancelNotificationSubscriptions();
    _connectionStateController.close();
    _discoveredDevicesController.close();
  }
}
