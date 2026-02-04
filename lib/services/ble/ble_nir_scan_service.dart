import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../models/device_info.dart';
import '../../models/device_status.dart';
import '../../models/scan_configuration.dart';
import '../../models/scan_data.dart';
import '../../utils/hex_format.dart';
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

      // Request larger MTU for efficient data transfer
      final mtu = await _bleDevice!.requestMtu(512);
      _logger.info(
          '[BLE] Connected successfully | Device: ${_bleDevice!.platformName} | MTU: $mtu',
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

  /// Find characteristic with Notify property (for subscription).
  /// Some sensors define separate Write and Notify characteristics with same UUID.
  /// This ensures we get the one that supports notifications.
  BluetoothCharacteristic? _findNotifyCharacteristic(Guid uuid) {
    if (_services == null) return null;

    for (final service in _services!) {
      for (final char in service.characteristics) {
        if (char.uuid == uuid && char.properties.notify) {
          return char;
        }
      }
    }
    // Fallback: try indicate property (some devices use indicate instead of notify)
    for (final service in _services!) {
      for (final char in service.characteristics) {
        if (char.uuid == uuid && char.properties.indicate) {
          return char;
        }
      }
    }
    return null;
  }

  /// Find characteristic with Write property (for sending commands).
  /// Some sensors define separate Write and Notify characteristics with same UUID.
  /// This ensures we get the one that supports writing.
  BluetoothCharacteristic? _findWriteCharacteristic(Guid uuid) {
    if (_services == null) return null;

    for (final service in _services!) {
      for (final char in service.characteristics) {
        if (char.uuid == uuid && char.properties.write) {
          return char;
        }
      }
    }
    // Fallback: try writeWithoutResponse
    for (final service in _services!) {
      for (final char in service.characteristics) {
        if (char.uuid == uuid && char.properties.writeWithoutResponse) {
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
      // FIX: Use _findNotifyCharacteristic to get the correct characteristic
      // Some sensors (like TI NIRscan Nano) define separate Write and Notify
      // characteristics with the same UUID - we need the one with Notify property
      final char = _findNotifyCharacteristic(uuid);
      final uuidShort = uuid.str.substring(4, 8).toUpperCase();

      if (char == null) {
        _logger.warning('[DIAG] No notify characteristic found for $uuidShort',
            tag: 'BLE');
        continue;
      }

      // Enable CCCD with confirmation logging
      try {
        await char.setNotifyValue(true);
        _logger.debug(
            '[DIAG] CCCD OK | Char: $uuidShort | isNotifying: ${char.isNotifying}',
            tag: 'BLE');
      } catch (e) {
        _logger.error('[DIAG] CCCD FAIL | Char: $uuidShort | Error: $e',
            tag: 'BLE');
        continue;
      }

      // DIAGNOSTIC: Global listener to catch ALL notifications
      // This helps identify if notifications arrive but aren't routed to performScan()
      char.onValueReceived.listen((data) {
        final firstByte = data.isNotEmpty
            ? '0x${data[0].toRadixString(16).padLeft(2, '0').toUpperCase()}'
            : 'empty';
        _logger.info(
          '[DIAG] Notify | Char: $uuidShort | Size: ${data.length}B | First: $firstByte',
          tag: 'BLE',
        );
      });

      await Future.delayed(delayBetween);
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

    // Check calibration data is available (required before scan)
    final hasCalibration =
        _cachedRefCalCoeff != null && _cachedRefCalMatrix != null;
    if (!hasCalibration) {
      _logger.warning(
          '[SCAN] Calibration required! Call getCalibrationData() first.',
          tag: 'BLE');
      throw const CalibrationRequiredException();
    }
    _logger.info(
        '[SCAN] Calibration verified | Coeff: ${_cachedRefCalCoeff!.length}B | Matrix: ${_cachedRefCalMatrix!.length}B',
        tag: 'BLE');

    // Ensure active scan configuration is set (as per protocol Flow 8)
    if (!_skipScanConfigCheck) {
      _logger.info('[SCAN] Checking active scan configuration...', tag: 'BLE');
      await _ensureActiveScanConfig();
      _logger.info('[SCAN] Active scan configuration confirmed', tag: 'BLE');
    }

    // DIAGNOSTIC: Read error status before scan to check sensor state
    _logger.info('[SCAN] Reading pre-scan error status...', tag: 'BLE');
    try {
      final errStatusChar = _findCharacteristic(NanoGatt.ggisErrStatus);
      if (errStatusChar != null) {
        final errStatus = await errStatusChar.read();
        final errValue = errStatus.length >= 2
            ? (errStatus[1] << 8) | (errStatus[0] & 0xFF)
            : (errStatus.isNotEmpty ? errStatus[0] : 0);
        _logger.info(
            '[SCAN] Pre-scan error status: 0x${errValue.toRadixString(16).toUpperCase().padLeft(4, '0')} (raw: ${errStatus.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')})',
            tag: 'BLE');
        if (errValue != 0) {
          _logger.warning(
              '[SCAN] Sensor has error flags set: 0x${errValue.toRadixString(16).toUpperCase()}',
              tag: 'BLE');
        }
      }
    } catch (e) {
      _logger.warning('[SCAN] Could not read error status: $e', tag: 'BLE');
    }

    // DIAGNOSTIC: Read device status before scan
    _logger.info('[SCAN] Reading pre-scan device status...', tag: 'BLE');
    try {
      final devStatusChar = _findCharacteristic(NanoGatt.ggisDevStatus);
      if (devStatusChar != null) {
        final devStatus = await devStatusChar.read();
        final devValue = devStatus.length >= 2
            ? (devStatus[1] << 8) | (devStatus[0] & 0xFF)
            : (devStatus.isNotEmpty ? devStatus[0] : 0);
        _logger.info(
            '[SCAN] Pre-scan device status: 0x${devValue.toRadixString(16).toUpperCase().padLeft(4, '0')} (raw: ${devStatus.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')})',
            tag: 'BLE');
      }
    } catch (e) {
      _logger.warning('[SCAN] Could not read device status: $e', tag: 'BLE');
    }

    // 1. Subscribe to start scan notifications and trigger scan
    // FIX: TI NIRscan Nano defines GSDIS_START_SCAN as TWO separate characteristics:
    //   - handle=0x0068: Write only (prop=0x08) - for sending scan command
    //   - handle=0x006a: Notify only (prop=0x10) - for receiving scan complete notification
    // flutter_blue_plus's default _findCharacteristic returns the first one (Write),
    // which has no CCCD descriptor, causing notification subscription to fail silently.
    _logger.info(
        '[SCAN] Finding start scan characteristics (write + notify)...',
        tag: 'BLE');

    final notifyChar = _findNotifyCharacteristic(NanoGatt.gsdisStartScan);
    final writeChar = _findWriteCharacteristic(NanoGatt.gsdisStartScan);

    if (notifyChar == null) {
      _logger.error(
          '[SCAN] Notify characteristic not found for GSDIS_START_SCAN!',
          tag: 'BLE');
      throw NirScanException('Start scan notify characteristic not found');
    }
    if (writeChar == null) {
      _logger.error(
          '[SCAN] Write characteristic not found for GSDIS_START_SCAN!',
          tag: 'BLE');
      throw NirScanException('Start scan write characteristic not found');
    }

    // DIAGNOSTIC: Log both characteristics
    _logger.info(
        '[SCAN] Notify char: notify=${notifyChar.properties.notify}, indicate=${notifyChar.properties.indicate}, handle=${notifyChar.characteristicUuid}',
        tag: 'BLE');
    _logger.info(
        '[SCAN] Write char: write=${writeChar.properties.write}, writeNoResp=${writeChar.properties.writeWithoutResponse}',
        tag: 'BLE');
    _logger.info('[SCAN] Notify char isNotifying: ${notifyChar.isNotifying}',
        tag: 'BLE');

    // Subscribe to the CORRECT characteristic (the one with Notify property)
    _logger.info('[SCAN] Subscribing to notify characteristic...', tag: 'BLE');
    await notifyChar.setNotifyValue(false);
    await Future.delayed(const Duration(milliseconds: 100));
    await notifyChar.setNotifyValue(true);
    _logger.info(
        '[SCAN] Subscription complete, isNotifying: ${notifyChar.isNotifying}',
        tag: 'BLE');

    // Create completer to wait for scan complete notification
    final scanCompleter = Completer<List<int>>();
    late StreamSubscription<List<int>> startScanSubscription;

    // DIAGNOSTIC: Timing tracker for scan flow
    final stopwatch = Stopwatch()..start();

    // FIX: Track when write is complete to ignore stale/cached notifications
    // This prevents lastValueStream cache issues where old 0xFF from previous scan
    // gets mistakenly interpreted as current scan success
    bool writeComplete = false;

    // FIX: Use ONLY onValueReceived - NOT lastValueStream!
    // lastValueStream emits cached values which causes stale data issues:
    // - Previous scan's 0xFF stays in cache
    // - Next scan reads old 0xFF at T+0ms and thinks it succeeded
    // - No actual scan is performed!
    startScanSubscription = notifyChar.onValueReceived.listen((data) {
      final firstByte = data.isNotEmpty
          ? '0x${data[0].toRadixString(16).toUpperCase().padLeft(2, '0')}'
          : 'empty';
      _logger.info(
          '[SCAN] Notification at T+${stopwatch.elapsedMilliseconds}ms | Size: ${data.length}B | First: $firstByte | WriteComplete: $writeComplete',
          tag: 'BLE');

      // FIX: Ignore notifications that arrive BEFORE write is complete
      // These are stale/cached values from previous operations
      if (!writeComplete) {
        _logger.debug('[SCAN] Ignoring pre-write notification: $firstByte',
            tag: 'BLE');
        return;
      }

      // Ignore empty notifications
      if (data.isEmpty) {
        _logger.debug('[SCAN] Ignoring empty notification', tag: 'BLE');
        return;
      }

      // Ignore write command echoes (0x00 = scan without save, 0x01 = scan with save)
      if (data.length == 1 && (data[0] == 0x00 || data[0] == 0x01)) {
        _logger.debug('[SCAN] Ignoring write echo: $firstByte', tag: 'BLE');
        return;
      }

      // This is an actual scan response
      if (!scanCompleter.isCompleted) {
        if (data[0] == 0xFF) {
          _logger.info('[SCAN] SUCCESS (0xFF) | Index bytes: ${data.length - 1}',
              tag: 'BLE');
        } else {
          _logger.warning('[SCAN] Device returned error: $firstByte', tag: 'BLE');
        }
        scanCompleter.complete(data);
      }
    });

    _logger.info(
        '[SCAN] Listener created at T+${stopwatch.elapsedMilliseconds}ms',
        tag: 'BLE');

    // Brief delay for listener registration at native layer
    await Future.delayed(const Duration(milliseconds: 200));
    _logger.info(
        '[SCAN] Delay done at T+${stopwatch.elapsedMilliseconds}ms, triggering scan...',
        tag: 'BLE');

    // Write save flag to start scan (use the WRITE characteristic)
    final scanCmd = saveToSd ? 0x01 : 0x00;
    _logger.info(
        '[SCAN] Trigger | Cmd: 0x${scanCmd.toRadixString(16).toUpperCase()} | Using write characteristic',
        tag: 'BLE');
    await writeChar.write([scanCmd], withoutResponse: false);

    // FIX: Mark write as complete - only NOW should we accept notifications
    writeComplete = true;
    _logger.info(
        '[SCAN] Write done at T+${stopwatch.elapsedMilliseconds}ms, awaiting device (timeout: 30s)...',
        tag: 'BLE');

    // 2. Wait for scan complete notification with timeout
    // Note: READ is not supported on this characteristic, so polling fallback won't work
    // The sensor should notify with 0xFF when scan is complete (~3-5 seconds)
    List<int> scanResult;
    try {
      scanResult = await scanCompleter.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          _logger.error('[SCAN] TIMEOUT after 30s - no notification received!',
              tag: 'BLE');
          throw TimeoutException('Scan notification timeout after 30 seconds');
        },
      );
    } on TimeoutException {
      // DIAGNOSTIC: Read error status after timeout to check sensor state
      _logger.info('[SCAN] Reading post-timeout error status...', tag: 'BLE');
      try {
        final errStatusChar = _findCharacteristic(NanoGatt.ggisErrStatus);
        if (errStatusChar != null) {
          final errStatus = await errStatusChar.read();
          final errValue = errStatus.length >= 2
              ? (errStatus[1] << 8) | (errStatus[0] & 0xFF)
              : (errStatus.isNotEmpty ? errStatus[0] : 0);
          _logger.info(
              '[SCAN] Post-timeout error status: 0x${errValue.toRadixString(16).toUpperCase().padLeft(4, '0')}',
              tag: 'BLE');
        }
        final devStatusChar = _findCharacteristic(NanoGatt.ggisDevStatus);
        if (devStatusChar != null) {
          final devStatus = await devStatusChar.read();
          final devValue = devStatus.length >= 2
              ? (devStatus[1] << 8) | (devStatus[0] & 0xFF)
              : (devStatus.isNotEmpty ? devStatus[0] : 0);
          _logger.info(
              '[SCAN] Post-timeout device status: 0x${devValue.toRadixString(16).toUpperCase().padLeft(4, '0')}',
              tag: 'BLE');
        }
      } catch (e) {
        _logger.warning('[SCAN] Could not read post-timeout status: $e',
            tag: 'BLE');
      }
      await startScanSubscription.cancel();
      rethrow;
    }
    await startScanSubscription.cancel();
    _logger.info('[SCAN] Hardware complete | Result: ${scanResult.length}B',
        tag: 'BLE');

    if (scanResult.isEmpty || scanResult[0] != 0xFF) {
      final errCode = scanResult.isNotEmpty ? scanResult[0] : -1;
      final errCodeHex = errCode >= 0
          ? '0x${errCode.toRadixString(16).toUpperCase().padLeft(2, '0')}'
          : 'empty';
      final errDescription = _getScanErrorDescription(errCode);
      _logger.error('[SCAN] FAILED | Error: $errCodeHex ($errDescription)',
          tag: 'BLE');
      throw ScanFailedException(
        'Scan failed: $errDescription (code: $errCodeHex)',
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

    // Log raw scan data in hex format for debugging
    final truncatedBytes = HexFormat.truncate(scanData.rawData, 64);
    _logger.info('Raw data (first 64 bytes): ${HexFormat.toHexString(truncatedBytes)}', tag: 'SCAN');

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

  /// Sets calibration data directly (for testing only)
  void setCalibrationDataForTesting(List<int> coefficients, List<int> matrix) {
    _cachedRefCalCoeff = coefficients;
    _cachedRefCalMatrix = matrix;
  }

  /// Skip scan config check (for testing only)
  bool _skipScanConfigCheck = false;
  void skipScanConfigCheckForTesting() {
    _skipScanConfigCheck = true;
  }

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
      _logger.debug(
          '[CAL] Received coeff packet #$packetCount (${data.length} bytes)',
          tag: 'BLE');
      receiver.onPacketReceived(data);
      if (receiver.isComplete) {
        _logger.debug(
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
      _logger.debug(
          '[CAL] Received matrix packet #$packetCount (${data.length} bytes)',
          tag: 'BLE');
      receiver.onPacketReceived(data);
      if (receiver.isComplete) {
        _logger.debug(
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
    await _ensureCalibrationData();
    return CalibrationData(
      coefficients: Uint8List.fromList(_cachedRefCalCoeff!),
      matrix: Uint8List.fromList(_cachedRefCalMatrix!),
    );
  }

  /// Ensures active scan configuration is set on device.
  /// Fetches config list from device and uses the first available config index.
  /// This follows TI SDK approach: config indices are stored IN the config list data,
  /// not as sequential 0, 1, 2... values.
  Future<void> _ensureActiveScanConfig() async {
    // Step 1: Read total number of stored configs
    int numConfigs = 0;
    final numConfigsChar = _findCharacteristic(NanoGatt.gscisNumStoredConf);
    if (numConfigsChar != null) {
      try {
        final numConfigsBytes = await numConfigsChar.read();
        numConfigs = numConfigsBytes.length >= 2
            ? (numConfigsBytes[1] << 8) | (numConfigsBytes[0] & 0xFF)
            : (numConfigsBytes.isNotEmpty ? numConfigsBytes[0] : 0);
        _logger.info('[SCAN] Total stored configs on device: $numConfigs',
            tag: 'BLE');
      } catch (e) {
        _logger.warning('[SCAN] Could not read config count: $e', tag: 'BLE');
      }
    }

    if (numConfigs == 0) {
      _logger.warning('[SCAN] No configs stored on device!', tag: 'BLE');
      throw NirScanException('No scan configurations stored on device');
    }

    // Step 2: Fetch config list to get actual config indices
    // TI SDK shows config index is at bytes [1] and [2] of each config list entry
    _logger.info('[SCAN] Fetching config list to get valid indices...',
        tag: 'BLE');
    final validConfigIndices = await _fetchConfigIndices();

    if (validConfigIndices.isEmpty) {
      _logger.warning('[SCAN] Could not fetch config indices, using fallback',
          tag: 'BLE');
      // Fallback: try index 0
      validConfigIndices.add(0);
    }

    _logger.info('[SCAN] Valid config indices from device: $validConfigIndices',
        tag: 'BLE');

    // Step 3: Read current active config
    // DIAGNOSTIC: Check if there are multiple characteristics with same UUID (like GSDIS_START_SCAN)
    final activeConfigChar = _findCharacteristic(NanoGatt.gscisActiveScanConf);
    final activeConfigWriteChar =
        _findWriteCharacteristic(NanoGatt.gscisActiveScanConf);

    if (activeConfigChar == null) {
      throw NirScanException('Active scan config characteristic not found');
    }

    _logger.info(
        '[SCAN] Active config char properties: read=${activeConfigChar.properties.read}, write=${activeConfigChar.properties.write}',
        tag: 'BLE');
    if (activeConfigWriteChar != null &&
        activeConfigWriteChar != activeConfigChar) {
      _logger.info(
          '[SCAN] Found separate write char for active config! write=${activeConfigWriteChar.properties.write}',
          tag: 'BLE');
    }

    _logger.info('[SCAN] Reading current active config...', tag: 'BLE');
    final configBytes = await activeConfigChar.read();
    if (configBytes.length < 2) {
      throw NirScanException('Invalid active config data');
    }

    final currentConfig = (configBytes[1] << 8) | (configBytes[0] & 0xFF);
    _logger.info(
        '[SCAN] Current active config: 0x${currentConfig.toRadixString(16).toUpperCase().padLeft(4, '0')} (index: $currentConfig)',
        tag: 'BLE');

    // Step 4: Check if current config is in valid list
    if (validConfigIndices.contains(currentConfig)) {
      _logger.info('[SCAN] Active config $currentConfig is valid, using as-is',
          tag: 'BLE');
      return;
    }

    // Step 5: Current config invalid, try to set first valid config
    final targetConfig = validConfigIndices.first;
    _logger.info(
        '[SCAN] Switching from invalid config $currentConfig to valid config $targetConfig...',
        tag: 'BLE');

    // Write new config index (little-endian uint16)
    // Use separate write characteristic if available (like GSDIS_START_SCAN pattern)
    final charToWrite = activeConfigWriteChar ?? activeConfigChar;
    final newConfigBytes = [targetConfig & 0xFF, (targetConfig >> 8) & 0xFF];
    _logger.info(
        '[SCAN] Writing config to char with write=${charToWrite.properties.write}',
        tag: 'BLE');
    await charToWrite.write(newConfigBytes, withoutResponse: false);
    _logger.info('[SCAN] Write complete, verifying...', tag: 'BLE');

    // Wait and verify
    await Future.delayed(const Duration(milliseconds: 300));
    final verifyBytes = await activeConfigChar.read();
    final verifiedConfig = verifyBytes.length >= 2
        ? (verifyBytes[1] << 8) | (verifyBytes[0] & 0xFF)
        : -1;
    _logger.info(
        '[SCAN] Config after write: $verifiedConfig (raw: ${verifyBytes.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')})',
        tag: 'BLE');

    if (verifiedConfig != targetConfig) {
      _logger.warning(
          '[SCAN] Config write may have failed (expected $targetConfig, got $verifiedConfig)',
          tag: 'BLE');
    }
  }

  /// Fetches the list of valid scan configuration indices from the device.
  /// Uses GSCIS_REQ_STORED_CONF_LIST / GSCIS_RET_STORED_CONF_LIST protocol.
  /// Returns list of config indices (from bytes [1] and [2] of each entry).
  Future<List<int>> _fetchConfigIndices() async {
    final requestChar = _findCharacteristic(NanoGatt.gscisReqStoredConfList);
    final responseChar =
        _findNotifyCharacteristic(NanoGatt.gscisRetStoredConfList);

    if (requestChar == null || responseChar == null) {
      _logger.warning('[SCAN] Config list characteristics not found',
          tag: 'BLE');
      return [];
    }

    final configIndices = <int>[];
    late StreamSubscription<List<int>> subscription;

    // Set up listener for config list responses
    subscription = responseChar.onValueReceived.listen((data) {
      if (data.isEmpty) return;

      _logger.debug(
          '[SCAN] Config list packet: ${data.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}',
          tag: 'BLE');

      // TI SDK format: byte[0] = packet index, byte[1-2] = config index (little-endian)
      if (data.length >= 3) {
        final configIndex = (data[2] << 8) | (data[1] & 0xFF);
        configIndices.add(configIndex);
        _logger.info('[SCAN] Found config index: $configIndex', tag: 'BLE');
      }
    });

    try {
      // Ensure subscription is active
      await responseChar.setNotifyValue(true);
      await Future.delayed(const Duration(milliseconds: 100));

      // Request config list
      await requestChar.write([0x00], withoutResponse: false);

      // Wait for responses (multi-packet)
      await Future.delayed(const Duration(milliseconds: 1000));

      subscription.cancel();
      return configIndices;
    } catch (e) {
      _logger.error('[SCAN] Failed to fetch config indices: $e', tag: 'BLE');
      subscription.cancel();
      return [];
    }
  }

  /// Maps scan error codes to human-readable descriptions.
  /// Reference: DLPU030G User's Guide, NNOStatusDefs.h
  String _getScanErrorDescription(int errorCode) {
    switch (errorCode) {
      case 0x01:
        return 'Lamp power failure';
      case 0x02:
        return 'ADC overflow/saturation';
      case 0x03:
        return 'Pattern stream error';
      case 0x04:
        return 'DLP subsystem failure';
      case -1:
        return 'Empty response';
      default:
        return 'Unknown error';
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
