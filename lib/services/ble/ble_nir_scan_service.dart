import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../models/device_info.dart';
import '../../models/device_status.dart';
import '../../models/scan_configuration.dart';
import '../../models/scan_data.dart';
import '../logging/log_service.dart';
import 'ble_adapter.dart';
import 'multi_packet_receiver.dart';
import 'nano_gatt.dart';
import 'nir_scan_service.dart';

/// BLE implementation of [NirScanService] for NIRScan Nano devices.
class BleNirScanService implements NirScanService {
  final BleAdapter _adapter;
  final LogService _logger;

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

  BleNirScanService({
    BleAdapter? adapter,
    required LogService logger,
  })  : _adapter = adapter ?? FlutterBluePlusAdapter(),
        _logger = logger {
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
    _logger.info('[BLE] Connecting to device: $deviceId (timeout: 15s)',
        tag: 'BLE');

    try {
      _bleDevice = _adapter.getDevice(deviceId);

      await _bleDevice!.connect(timeout: const Duration(seconds: 15));
      _logger.info(
          '[BLE] Connected successfully | Device: ${_bleDevice!.platformName} | MTU: pending',
          tag: 'BLE');

      _connectionSubscription = _bleDevice!.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _logger.warning(
              '[BLE] Device disconnected | ID: $deviceId | State: ${_currentState.toString().split('.').last}',
              tag: 'BLE');
          _handleDisconnection();
        }
      });

      _services = await _bleDevice!.discoverServices();
      _logger.info(
          '[BLE] Services discovered: ${_services?.length ?? 0} services | Device: $deviceId',
          tag: 'BLE');

      // Subscribe to all notifications as per protocol (Flow 1)
      _logger.info(
          '[BLE] Subscribing to ${NanoGatt.notificationCharacteristics.length} notification characteristics...',
          tag: 'BLE');
      await subscribeToAllNotifications(skipConnectionCheck: true);
      _logger.info('[BLE] All notifications subscribed', tag: 'BLE');

      _connectedDevice = NirScanDevice(
        id: deviceId,
        name: _bleDevice!.platformName,
        rssi: 0,
      );

      _setConnectionState(NirConnectionState.connected);
      _logger.info(
          '[BLE] Connection fully established to ${_bleDevice!.platformName}',
          tag: 'BLE');
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
    final deviceName = _connectedDevice?.name ?? 'Unknown';
    _logger.info(
        '[SCAN] Starting scan | Device: $deviceName | SaveToSD: $saveToSd',
        tag: 'BLE');

    // Sync device time before scan (as per protocol Flow 4B)
    _logger.info(
        '[SCAN] Syncing device time | Current: ${DateTime.now().toIso8601String()}',
        tag: 'BLE');
    await syncTime();
    _logger.info('[SCAN] Time synced successfully', tag: 'BLE');

    // Ensure calibration data is cached (as per protocol Flow 4A)
    final calCached = _cachedRefCalCoeff != null && _cachedRefCalMatrix != null;
    _logger.info('[SCAN] Calibration check | Cached: $calCached', tag: 'BLE');
    await _ensureCalibrationData();
    _logger.info(
        '[SCAN] Calibration ready | Coeff: ${_cachedRefCalCoeff?.length ?? 0}B | Matrix: ${_cachedRefCalMatrix?.length ?? 0}B',
        tag: 'BLE');

    // Ensure active scan configuration is set (as per protocol Flow 8)
    _logger.info('[SCAN] Checking active scan configuration...', tag: 'BLE');
    await _ensureActiveScanConfig();
    _logger.info('[SCAN] Active scan configuration confirmed', tag: 'BLE');

    // 1. Subscribe to start scan notifications and trigger scan
    _logger.info('[SCAN] Finding start scan characteristic...', tag: 'BLE');
    final startScanChar = _findCharacteristic(NanoGatt.gsdisStartScan);
    if (startScanChar == null) {
      _logger.info('[SCAN] Start scan characteristic not found!', tag: 'BLE');
      throw NirScanException('Start scan characteristic not found');
    }
    _logger.info('[SCAN] Start scan characteristic found', tag: 'BLE');

    // NOTE: We already subscribed to this characteristic during connection setup
    // No need to call setNotifyValue again
    _logger.info('[SCAN] Already subscribed to notifications during connection',
        tag: 'BLE');

    // Create completer to wait for scan complete notification
    final scanCompleter = Completer<List<int>>();
    late StreamSubscription<List<int>> startScanSubscription;

    startScanSubscription = startScanChar.onValueReceived.listen((data) {
      final firstByte = data.isNotEmpty
          ? '0x${data[0].toRadixString(16).toUpperCase().padLeft(2, '0')}'
          : 'empty';
      _logger.info(
          '[SCAN] Notification | Size: ${data.length}B | First: $firstByte',
          tag: 'BLE');
      if (!scanCompleter.isCompleted && data.isNotEmpty) {
        if (data[0] == 0xFF) {
          _logger.info('[SCAN] SUCCESS (0xFF)', tag: 'BLE');
        } else {
          _logger.warning('[SCAN] Unexpected: $firstByte', tag: 'BLE');
        }
        scanCompleter.complete(data);
        startScanSubscription.cancel();
      }
    });

    // Write save flag to start scan
    final scanCmd = saveToSd ? 0x01 : 0x00;
    _logger.info(
        '[SCAN] Trigger | Cmd: 0x${scanCmd.toRadixString(16).toUpperCase()}',
        tag: 'BLE');
    await startScanChar.write([scanCmd]);
    _logger.info('[SCAN] Command sent, awaiting device (timeout: 60s)...',
        tag: 'BLE');

    // 2. Wait for scan complete notification
    final scanResult = await scanCompleter.future;
    _logger.info('[SCAN] Hardware complete | Result: ${scanResult.length}B',
        tag: 'BLE');

    if (scanResult.isEmpty || scanResult[0] != 0xFF) {
      final errCode = scanResult.isNotEmpty
          ? '0x${scanResult[0].toRadixString(16).toUpperCase()}'
          : 'empty';
      _logger.error('[SCAN] FAILED | Error: $errCode', tag: 'BLE');
      throw ScanFailedException(
        'Scan failed with error code: $errCode',
      );
    }

    // 3. Extract scan index (4 bytes after 0xFF)
    final scanIndex = scanResult.length >= 5
        ? scanResult.sublist(1, 5)
        : [0x00, 0x00, 0x00, 0x00];
    _logger.info(
        '[SCAN] Scan index: ${scanIndex.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
        tag: 'BLE');

    // 4. Request scan metadata
    _logger.info('[SCAN] Requesting scan name...', tag: 'BLE');
    final scanName = await _requestScanMetadata(
      NanoGatt.gsdisReqScanName,
      NanoGatt.gsdisRetScanName,
      scanIndex,
    );
    _logger.info('[SCAN] Scan name: ${String.fromCharCodes(scanName)}',
        tag: 'BLE');

    _logger.info('[SCAN] Requesting scan type...', tag: 'BLE');
    final scanTypeBytes = await _requestScanMetadata(
      NanoGatt.gsdisReqScanType,
      NanoGatt.gsdisRetScanType,
      scanIndex,
    );
    _logger.info(
        '[SCAN] Scan type: ${scanTypeBytes.isNotEmpty ? scanTypeBytes[0].toRadixString(16) : "empty"}',
        tag: 'BLE');

    _logger.info('[SCAN] Requesting scan date...', tag: 'BLE');
    final scanDateBytes = await _requestScanMetadata(
      NanoGatt.gsdisReqScanDate,
      NanoGatt.gsdisRetScanDate,
      scanIndex,
    );
    _logger.info('[SCAN] Scan date: ${String.fromCharCodes(scanDateBytes)}',
        tag: 'BLE');

    _logger.info('[SCAN] Requesting packet format version...', tag: 'BLE');
    final pktFmtVerBytes = await _requestScanMetadata(
      NanoGatt.gsdisReqPktFmtVer,
      NanoGatt.gsdisRetPktFmtVer,
      scanIndex,
    );
    _logger.info('[SCAN] Packet format version received', tag: 'BLE');

    // 5. Request serialized scan data (multi-packet)
    _logger.info('[SCAN] Requesting raw scan data (multi-packet)...',
        tag: 'BLE');
    final rawData = await _requestMultiPacketData(
      NanoGatt.gsdisReqSerScanDataStruct,
      NanoGatt.gsdisRetSerScanDataStruct,
      scanIndex,
    );
    _logger.info('[SCAN] Raw scan data received: ${rawData.length} bytes',
        tag: 'BLE');

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
    _logger.info('', tag: 'BLE');
    _logger.info('[SCAN] ============ SCAN COMPLETED ============', tag: 'BLE');
    _logger.info('[SCAN] Raw Data Size: ${scanData.rawData.length} bytes',
        tag: 'BLE');
    _logger.info('📝 [SCAN] Name: ${scanData.name}', tag: 'BLE');
    _logger.info('📅 [SCAN] Date: ${scanData.date}', tag: 'BLE');
    _logger.info('🔢 [SCAN] Type: ${scanData.type}', tag: 'BLE');
    _logger.info('📌 [SCAN] Version: ${scanData.packetFormatVersion}',
        tag: 'BLE');
    _logger.info('[SCAN] First 20 bytes: ${scanData.rawData.take(20).toList()}',
        tag: 'BLE');
    _logger.info(
        '[SCAN] Last 20 bytes: ${scanData.rawData.skip(scanData.rawData.length - 20).take(20).toList()}',
        tag: 'BLE');
    _logger.info(
        '[SCAN] Calibration available: coeff=${_cachedRefCalCoeff?.length ?? 0}B, matrix=${_cachedRefCalMatrix?.length ?? 0}B',
        tag: 'BLE');
    _logger.info('[SCAN] =========================================',
        tag: 'BLE');
    _logger.info('', tag: 'BLE');

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

    // NOTE: Already subscribed during connection setup
    // await responseChar.setNotifyValue(true);

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

    // NOTE: Already subscribed during connection setup
    // await responseChar.setNotifyValue(true);

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
    _logger.info('[CAL] Starting calibration coefficient fetch...', tag: 'BLE');
    final reqChar = _findCharacteristic(NanoGatt.gcisReqRefCalCoeff);
    final retChar = _findCharacteristic(NanoGatt.gcisRetRefCalCoeff);

    if (reqChar == null || retChar == null) {
      _logger.info('[CAL] Calibration characteristics not found!', tag: 'BLE');
      throw NirScanException(
          'Calibration coefficient characteristics not found');
    }

    _logger.info('[CAL] Characteristics found, setting up listener...',
        tag: 'BLE');
    // NOTE: Already subscribed during connection setup
    // await retChar.setNotifyValue(true);

    final receiver = MultiPacketReceiver();
    final completer = Completer<List<int>>();
    int packetCount = 0;

    final subscription = retChar.onValueReceived.listen((data) {
      packetCount++;
      _logger.info(
          '[CAL] Received coeff packet #$packetCount (${data.length} bytes)',
          tag: 'BLE');
      receiver.onPacketReceived(data);
      if (receiver.isComplete) {
        _logger.info(
            '[CAL] Coefficient data complete (${receiver.data.length} bytes)',
            tag: 'BLE');
        completer.complete(receiver.data);
      }
    });

    // Request calibration coefficients
    _logger.info('[CAL] Requesting calibration coefficients...', tag: 'BLE');
    await reqChar.write([0x00]); // Dummy byte to trigger
    _logger.info('[CAL] Request sent, waiting for response...', tag: 'BLE');

    try {
      final coeffData = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _logger.info(
              '[CAL] Coefficient fetch timeout! Received $packetCount packets',
              tag: 'BLE');
          throw TimeoutException('Calibration coefficient fetch timeout');
        },
      );
      _logger.info(
          '[CAL] Coefficient fetch complete: ${coeffData.length} bytes',
          tag: 'BLE');
      return coeffData;
    } finally {
      await subscription.cancel();
      _logger.info('[CAL] Coefficient subscription cancelled', tag: 'BLE');
    }
  }

  /// Fetches reference calibration matrix (multi-packet)
  Future<List<int>> _fetchCalibrationMatrix() async {
    _logger.info('[CAL] Starting calibration matrix fetch...', tag: 'BLE');
    final reqChar = _findCharacteristic(NanoGatt.gcisReqRefCalMatrix);
    final retChar = _findCharacteristic(NanoGatt.gcisRetRefCalMatrix);

    if (reqChar == null || retChar == null) {
      _logger.info('[CAL] Matrix characteristics not found!', tag: 'BLE');
      throw NirScanException('Calibration matrix characteristics not found');
    }

    _logger.info('[CAL] Matrix characteristics found, setting up listener...',
        tag: 'BLE');
    // NOTE: Already subscribed during connection setup
    // await retChar.setNotifyValue(true);

    final receiver = MultiPacketReceiver();
    final completer = Completer<List<int>>();
    int packetCount = 0;

    final subscription = retChar.onValueReceived.listen((data) {
      packetCount++;
      _logger.info(
          '[CAL] Received matrix packet #$packetCount (${data.length} bytes)',
          tag: 'BLE');
      receiver.onPacketReceived(data);
      if (receiver.isComplete) {
        _logger.info(
            '[CAL] Matrix data complete (${receiver.data.length} bytes)',
            tag: 'BLE');
        completer.complete(receiver.data);
      }
    });

    // Request calibration matrix
    _logger.info('[CAL] Requesting calibration matrix...', tag: 'BLE');
    await reqChar.write([0x00]); // Dummy byte to trigger
    _logger.info('[CAL] Matrix request sent, waiting for response...',
        tag: 'BLE');

    try {
      final matrixData = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _logger.info(
              '[CAL] Matrix fetch timeout! Received $packetCount packets',
              tag: 'BLE');
          throw TimeoutException('Calibration matrix fetch timeout');
        },
      );
      _logger.info('[CAL] Matrix fetch complete: ${matrixData.length} bytes',
          tag: 'BLE');
      return matrixData;
    } finally {
      await subscription.cancel();
      _logger.info('[CAL] Matrix subscription cancelled', tag: 'BLE');
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

  /// Ensures active scan configuration is set on device.
  /// Reads current active config, and if not set (0xFFFF), writes default (index 0).
  Future<void> _ensureActiveScanConfig() async {
    final char = _findCharacteristic(NanoGatt.gscisActiveScanConf);
    if (char == null) {
      _logger.warning('[SCAN] Active scan config characteristic not found!',
          tag: 'BLE');
      throw NirScanException('Active scan config characteristic not found');
    }

    // Read current active config
    _logger.info('[SCAN] Reading current active config...', tag: 'BLE');
    final configBytes = await char.read();
    if (configBytes.length < 2) {
      _logger.warning('[SCAN] Invalid config data: ${configBytes.length} bytes',
          tag: 'BLE');
      throw NirScanException('Invalid active config data');
    }

    // Parse as little-endian uint16
    final currentConfig = (configBytes[1] << 8) | (configBytes[0] & 0xFF);
    _logger.info(
        '[SCAN] Current active config: 0x${currentConfig.toRadixString(16).toUpperCase().padLeft(4, '0')}',
        tag: 'BLE');

    // If not set (0xFFFF), write default config (index 0)
    if (currentConfig == 0xFFFF) {
      _logger.info('[SCAN] No active config set, writing default (index 0)...',
          tag: 'BLE');
      final defaultConfigBytes = [0x00, 0x00]; // Index 0, little-endian
      await char.write(defaultConfigBytes);
      _logger.info('[SCAN] Default config (0) written successfully',
          tag: 'BLE');
    } else {
      _logger.info('[SCAN] Active config already set (index: $currentConfig)',
          tag: 'BLE');
    }
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
