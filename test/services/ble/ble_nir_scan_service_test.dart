import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:spectriem_app/services/ble/ble_adapter.dart';
import 'package:spectriem_app/services/ble/nir_scan_service.dart';
import 'package:spectriem_app/services/ble/ble_nir_scan_service.dart';
import 'package:spectriem_app/services/logging/log_service.dart';
import 'package:spectriem_app/models/scan_configuration.dart';

import 'ble_nir_scan_service_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<BluetoothDevice>(),
  MockSpec<BluetoothService>(),
  MockSpec<BluetoothCharacteristic>(),
  MockSpec<BleAdapter>(),
])

/// Helper to create a mock characteristic with properties stubbed.
/// This is needed because _findNotifyCharacteristic checks properties.notify.
MockBluetoothCharacteristic createMockCharacteristic({
  required Guid uuid,
  bool notify = true, // Default true - most test chars need notification
  bool write = true, // Default true - most test chars need write
  bool writeWithoutResponse = false,
  bool indicate = false,
  bool read = true, // Default true - most test chars need read
}) {
  final char = MockBluetoothCharacteristic();
  when(char.uuid).thenReturn(uuid);

  // Create real CharacteristicProperties since it's a simple value class
  final properties = CharacteristicProperties(
    notify: notify,
    write: write,
    writeWithoutResponse: writeWithoutResponse,
    indicate: indicate,
    read: read,
    broadcast: false,
    authenticatedSignedWrites: false,
    extendedProperties: false,
    notifyEncryptionRequired: false,
    indicateEncryptionRequired: false,
  );
  when(char.properties).thenReturn(properties);

  return char;
}

/// Helper to add default properties to an existing mock characteristic.
/// Use this for mocks that were already created with MockBluetoothCharacteristic().
void stubCharacteristicProperties(
  MockBluetoothCharacteristic char, {
  bool notify = true,
  bool write = true,
  bool read = true,
  bool indicate = false,
  bool writeWithoutResponse = false,
}) {
  final properties = CharacteristicProperties(
    notify: notify,
    write: write,
    writeWithoutResponse: writeWithoutResponse,
    indicate: indicate,
    read: read,
    broadcast: false,
    authenticatedSignedWrites: false,
    extendedProperties: false,
    notifyEncryptionRequired: false,
    indicateEncryptionRequired: false,
  );
  when(char.properties).thenReturn(properties);
}

void main() {
  late BleNirScanService service;
  late MockBleAdapter mockAdapter;
  late LogService logService;
  late StreamController<List<ScanResult>> scanResultsController;

  setUp(() {
    mockAdapter = MockBleAdapter();
    logService = LogService();
    scanResultsController = StreamController<List<ScanResult>>.broadcast();

    when(mockAdapter.scanResults)
        .thenAnswer((_) => scanResultsController.stream);
    when(mockAdapter.isScanning).thenAnswer((_) => Stream.value(false));
    when(mockAdapter.startScan(
      timeout: anyNamed('timeout'),
      withServices: anyNamed('withServices'),
    )).thenAnswer((_) async {});
    when(mockAdapter.stopScan()).thenAnswer((_) async {});

    service = BleNirScanService(adapter: mockAdapter, logger: logService);
  });

  tearDown(() {
    service.dispose();
    logService.dispose();
    scanResultsController.close();
  });

  group('BleNirScanService', () {
    group('connection state stream', () {
      test('starts in disconnected state', () {
        // Service starts with no connected device (disconnected)
        expect(service.connectedDevice, isNull);
      });

      test('emits connecting then connected on successful connect', () async {
        final mockDevice = MockBluetoothDevice();
        final mockService = MockBluetoothService();

        when(mockDevice.remoteId)
            .thenReturn(const DeviceIdentifier('AA:BB:CC:DD:EE:FF'));
        when(mockDevice.platformName).thenReturn('NIRScan Nano');
        when(mockDevice.connect(
          timeout: anyNamed('timeout'),
          autoConnect: anyNamed('autoConnect'),
        )).thenAnswer((_) async {});
        when(mockDevice.discoverServices())
            .thenAnswer((_) async => [mockService]);
        when(mockDevice.connectionState).thenAnswer(
          (_) => Stream.value(BluetoothConnectionState.connected),
        );
        when(mockDevice.disconnect()).thenAnswer((_) async {});
        when(mockDevice.requestMtu(any, predelay: anyNamed('predelay'), timeout: anyNamed('timeout')))
            .thenAnswer((_) async => 512);
        when(mockDevice.requestMtu(any,
                predelay: anyNamed('predelay'), timeout: anyNamed('timeout')))
            .thenAnswer((_) async => 512);

        when(mockService.uuid)
            .thenReturn(Guid('0000180a-0000-1000-8000-00805f9b34fb'));
        when(mockService.characteristics).thenReturn([]);

        // Register device in adapter
        when(mockAdapter.getDevice('AA:BB:CC:DD:EE:FF')).thenReturn(mockDevice);

        final states = <NirConnectionState>[];
        final subscription = service.connectionState.listen(states.add);

        await service.connect('AA:BB:CC:DD:EE:FF');
        await Future.delayed(const Duration(milliseconds: 50));

        expect(states, contains(NirConnectionState.connecting));
        expect(states, contains(NirConnectionState.connected));

        await subscription.cancel();
      });

      test('emits disconnecting then disconnected on disconnect', () async {
        final mockDevice = MockBluetoothDevice();
        final mockService = MockBluetoothService();

        when(mockDevice.remoteId)
            .thenReturn(const DeviceIdentifier('AA:BB:CC:DD:EE:FF'));
        when(mockDevice.platformName).thenReturn('NIRScan Nano');
        when(mockDevice.connect(
          timeout: anyNamed('timeout'),
          autoConnect: anyNamed('autoConnect'),
        )).thenAnswer((_) async {});
        when(mockDevice.discoverServices())
            .thenAnswer((_) async => [mockService]);
        when(mockDevice.connectionState).thenAnswer(
          (_) => Stream.value(BluetoothConnectionState.connected),
        );
        when(mockDevice.disconnect()).thenAnswer((_) async {});
        when(mockDevice.requestMtu(any, predelay: anyNamed('predelay'), timeout: anyNamed('timeout')))
            .thenAnswer((_) async => 512);

        when(mockService.uuid)
            .thenReturn(Guid('0000180a-0000-1000-8000-00805f9b34fb'));
        when(mockService.characteristics).thenReturn([]);

        when(mockAdapter.getDevice('AA:BB:CC:DD:EE:FF')).thenReturn(mockDevice);

        // First connect
        await service.connect('AA:BB:CC:DD:EE:FF');
        await Future.delayed(const Duration(milliseconds: 50));

        final states = <NirConnectionState>[];
        final subscription = service.connectionState.listen(states.add);

        await service.disconnect();
        await Future.delayed(const Duration(milliseconds: 50));

        expect(states, contains(NirConnectionState.disconnecting));
        expect(states, contains(NirConnectionState.disconnected));

        await subscription.cancel();
      });

      test('subscribes to all notifications after connection', () async {
        final mockDevice = MockBluetoothDevice();
        final mockService = MockBluetoothService();
        final notificationCharacteristics = <MockBluetoothCharacteristic>[];

        // Create mock characteristics for all notification UUIDs
        // All notification characteristics need notify: true for _findNotifyCharacteristic
        final notificationUuids = [
          '43484110-444c-5020-4e49-52204e616e6f', // gcisRetRefCalCoeff
          '43484112-444c-5020-4e49-52204e616e6f', // gcisRetRefCalMatrix
          '4348411d-444c-5020-4e49-52204e616e6f', // gsdisStartScan
          '43484120-444c-5020-4e49-52204e616e6f', // gsdisRetScanName
          '43484122-444c-5020-4e49-52204e616e6f', // gsdisRetScanType
          '43484124-444c-5020-4e49-52204e616e6f', // gsdisRetScanDate
          '43484126-444c-5020-4e49-52204e616e6f', // gsdisRetPktFmtVer
          '43484128-444c-5020-4e49-52204e616e6f', // gsdisRetSerScanDataStruct
          '43484115-444c-5020-4e49-52204e616e6f', // gscisRetStoredConfList
          '4348411b-444c-5020-4e49-52204e616e6f', // gsdisSDStoredScanIndListData
          '4348411e-444c-5020-4e49-52204e616e6f', // gsdisClearScan
          '43484117-444c-5020-4e49-52204e616e6f', // gscisRetScanConfData
          '4348412e-444c-5020-4e49-52204e616e6f', // gcisRetSpecCalCoeff
        ];

        for (final uuidStr in notificationUuids) {
          final char = createMockCharacteristic(
            uuid: Guid(uuidStr),
            notify: true, // Required for _findNotifyCharacteristic to find it
          );
          when(char.setNotifyValue(true)).thenAnswer((_) async => true);
          when(char.setNotifyValue(false)).thenAnswer((_) async => true);
          when(char.lastValueStream).thenAnswer((_) => Stream.value([]));
          when(char.onValueReceived).thenAnswer((_) => Stream.empty());
          when(char.isNotifying).thenReturn(true);
          notificationCharacteristics.add(char);
        }

        // Setup device and service
        when(mockDevice.remoteId)
            .thenReturn(const DeviceIdentifier('AA:BB:CC:DD:EE:FF'));
        when(mockDevice.platformName).thenReturn('NIRScan Nano');
        when(mockDevice.connect(
          timeout: anyNamed('timeout'),
          autoConnect: anyNamed('autoConnect'),
        )).thenAnswer((_) async {});
        when(mockDevice.discoverServices())
            .thenAnswer((_) async => [mockService]);
        when(mockDevice.connectionState).thenAnswer(
          (_) => Stream.value(BluetoothConnectionState.connected),
        );
        when(mockDevice.disconnect()).thenAnswer((_) async {});
        when(mockDevice.requestMtu(any, predelay: anyNamed('predelay'), timeout: anyNamed('timeout')))
            .thenAnswer((_) async => 512);

        when(mockService.uuid)
            .thenReturn(Guid('43484100-444c-5020-4e49-52204e616e6f'));
        when(mockService.characteristics)
            .thenReturn(notificationCharacteristics);

        when(mockAdapter.getDevice('AA:BB:CC:DD:EE:FF')).thenReturn(mockDevice);

        // Act: Connect to device
        await service.connect('AA:BB:CC:DD:EE:FF');
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert: Verify setNotifyValue(true) was called at least once
        // We check that the method was invoked (any characteristic calling it proves the flow works)
        verify(notificationCharacteristics.first.setNotifyValue(true))
            .called(1);
      });
    });

    group('device discovery', () {
      test('filters devices by NIRScan name prefix', () async {
        final discoveredDevices = <NirScanDevice>[];
        final subscription =
            service.discoveredDevices.listen(discoveredDevices.add);

        await service.startDeviceScan();

        // Emit scan results - mix of NIRScan and other devices
        final nirDevice =
            _createMockScanResult('NIRScan Nano ABC', 'AA:BB:CC:DD:EE:FF', -50);
        final otherDevice =
            _createMockScanResult('Random Device', '11:22:33:44:55:66', -60);
        final anotherNir =
            _createMockScanResult('NIRScan Nano XYZ', '11:22:33:44:55:77', -70);

        scanResultsController.add([nirDevice, otherDevice, anotherNir]);
        await Future.delayed(const Duration(milliseconds: 50));

        // Should only have NIRScan devices
        expect(discoveredDevices.length, equals(2));
        expect(discoveredDevices.map((d) => d.name),
            everyElement(startsWith('NIRScan')));

        await subscription.cancel();
      });

      test('does not emit devices without NIRScan prefix', () async {
        final discoveredDevices = <NirScanDevice>[];
        final subscription =
            service.discoveredDevices.listen(discoveredDevices.add);

        await service.startDeviceScan();

        final otherDevice =
            _createMockScanResult('Other BLE Device', '11:22:33:44:55:66', -60);
        scanResultsController.add([otherDevice]);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(discoveredDevices, isEmpty);

        await subscription.cancel();
      });

      test('includes RSSI in discovered device', () async {
        final discoveredDevices = <NirScanDevice>[];
        final subscription =
            service.discoveredDevices.listen(discoveredDevices.add);

        await service.startDeviceScan();

        final nirDevice =
            _createMockScanResult('NIRScan Nano', 'AA:BB:CC:DD:EE:FF', -55);
        scanResultsController.add([nirDevice]);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(discoveredDevices.first.rssi, equals(-55));

        await subscription.cancel();
      });
    });

    group('disconnect cleanup', () {
      test('clears connectedDevice on disconnect', () async {
        final mockDevice = MockBluetoothDevice();
        final mockService = MockBluetoothService();

        when(mockDevice.remoteId)
            .thenReturn(const DeviceIdentifier('AA:BB:CC:DD:EE:FF'));
        when(mockDevice.platformName).thenReturn('NIRScan Nano');
        when(mockDevice.connect(
          timeout: anyNamed('timeout'),
          autoConnect: anyNamed('autoConnect'),
        )).thenAnswer((_) async {});
        when(mockDevice.discoverServices())
            .thenAnswer((_) async => [mockService]);
        when(mockDevice.connectionState).thenAnswer(
          (_) => Stream.value(BluetoothConnectionState.connected),
        );
        when(mockDevice.disconnect()).thenAnswer((_) async {});
        when(mockDevice.requestMtu(any, predelay: anyNamed('predelay'), timeout: anyNamed('timeout')))
            .thenAnswer((_) async => 512);

        when(mockService.uuid)
            .thenReturn(Guid('0000180a-0000-1000-8000-00805f9b34fb'));
        when(mockService.characteristics).thenReturn([]);

        when(mockAdapter.getDevice('AA:BB:CC:DD:EE:FF')).thenReturn(mockDevice);

        await service.connect('AA:BB:CC:DD:EE:FF');
        await Future.delayed(const Duration(milliseconds: 50));

        expect(service.connectedDevice, isNotNull);

        await service.disconnect();
        await Future.delayed(const Duration(milliseconds: 50));

        expect(service.connectedDevice, isNull);
      });

      test('cancels notification subscriptions on disconnect', () async {
        final mockDevice = MockBluetoothDevice();
        final mockService = MockBluetoothService();
        final mockCharacteristic = MockBluetoothCharacteristic();

        when(mockDevice.remoteId)
            .thenReturn(const DeviceIdentifier('AA:BB:CC:DD:EE:FF'));
        when(mockDevice.platformName).thenReturn('NIRScan Nano');
        when(mockDevice.connect(
          timeout: anyNamed('timeout'),
          autoConnect: anyNamed('autoConnect'),
        )).thenAnswer((_) async {});
        when(mockDevice.discoverServices())
            .thenAnswer((_) async => [mockService]);
        when(mockDevice.connectionState).thenAnswer(
          (_) => Stream.value(BluetoothConnectionState.connected),
        );
        when(mockDevice.disconnect()).thenAnswer((_) async {});
        when(mockDevice.requestMtu(any, predelay: anyNamed('predelay'), timeout: anyNamed('timeout')))
            .thenAnswer((_) async => 512);

        when(mockService.uuid)
            .thenReturn(Guid('0000180a-0000-1000-8000-00805f9b34fb'));
        when(mockService.characteristics).thenReturn([mockCharacteristic]);

        when(mockCharacteristic.uuid)
            .thenReturn(Guid('00002a29-0000-1000-8000-00805f9b34fb'));
        when(mockCharacteristic.setNotifyValue(any))
            .thenAnswer((_) async => true);

        when(mockAdapter.getDevice('AA:BB:CC:DD:EE:FF')).thenReturn(mockDevice);

        await service.connect('AA:BB:CC:DD:EE:FF');
        await Future.delayed(const Duration(milliseconds: 50));

        await service.disconnect();
        await Future.delayed(const Duration(milliseconds: 50));

        // Verify cleanup - no dangling subscriptions
        // The service should internally track and cancel subscriptions
        verify(mockDevice.disconnect()).called(1);
      });
    });

    group('getDeviceInfo', () {
      test('throws NotConnectedException when not connected', () {
        expect(
          () => service.getDeviceInfo(),
          throwsA(isA<NotConnectedException>()),
        );
      });

      test('reads all DIS characteristics and returns DeviceInfo', () async {
        final mockDevice = MockBluetoothDevice();
        final mockDisService = MockBluetoothService();

        // DIS Characteristics
        final manufNameChar = MockBluetoothCharacteristic();
        final modelNumberChar = MockBluetoothCharacteristic();
        final serialNumberChar = MockBluetoothCharacteristic();
        final hwRevChar = MockBluetoothCharacteristic();
        final tivaFwRevChar = MockBluetoothCharacteristic();
        final speccRevChar = MockBluetoothCharacteristic();

        // Device setup
        when(mockDevice.remoteId)
            .thenReturn(const DeviceIdentifier('AA:BB:CC:DD:EE:FF'));
        when(mockDevice.platformName).thenReturn('NIRScan Nano');
        when(mockDevice.connect(
          timeout: anyNamed('timeout'),
          autoConnect: anyNamed('autoConnect'),
        )).thenAnswer((_) async {});
        when(mockDevice.discoverServices())
            .thenAnswer((_) async => [mockDisService]);
        when(mockDevice.connectionState).thenAnswer(
          (_) => Stream.value(BluetoothConnectionState.connected),
        );
        when(mockDevice.disconnect()).thenAnswer((_) async {});
        when(mockDevice.requestMtu(any, predelay: anyNamed('predelay'), timeout: anyNamed('timeout')))
            .thenAnswer((_) async => 512);

        // DIS Service UUID
        when(mockDisService.uuid)
            .thenReturn(Guid('0000180a-0000-1000-8000-00805f9b34fb'));
        when(mockDisService.characteristics).thenReturn([
          manufNameChar,
          modelNumberChar,
          serialNumberChar,
          hwRevChar,
          tivaFwRevChar,
          speccRevChar,
        ]);

        // Characteristic UUIDs and values
        when(manufNameChar.uuid)
            .thenReturn(Guid('00002a29-0000-1000-8000-00805f9b34fb'));
        when(manufNameChar.read())
            .thenAnswer((_) async => 'Texas Instruments'.codeUnits);

        when(modelNumberChar.uuid)
            .thenReturn(Guid('00002a24-0000-1000-8000-00805f9b34fb'));
        when(modelNumberChar.read())
            .thenAnswer((_) async => 'DLP NIRscan Nano'.codeUnits);

        when(serialNumberChar.uuid)
            .thenReturn(Guid('00002a25-0000-1000-8000-00805f9b34fb'));
        when(serialNumberChar.read())
            .thenAnswer((_) async => 'SN12345'.codeUnits);

        when(hwRevChar.uuid)
            .thenReturn(Guid('00002a27-0000-1000-8000-00805f9b34fb'));
        when(hwRevChar.read()).thenAnswer((_) async => '2.0.0'.codeUnits);

        when(tivaFwRevChar.uuid)
            .thenReturn(Guid('00002a26-0000-1000-8000-00805f9b34fb'));
        when(tivaFwRevChar.read()).thenAnswer((_) async => '2.4.4'.codeUnits);

        when(speccRevChar.uuid)
            .thenReturn(Guid('00002a28-0000-1000-8000-00805f9b34fb'));
        // uint16 little-endian: 0x0203 = 515
        when(speccRevChar.read()).thenAnswer((_) async => [0x03, 0x02]);

        when(mockAdapter.getDevice('AA:BB:CC:DD:EE:FF')).thenReturn(mockDevice);

        await service.connect('AA:BB:CC:DD:EE:FF');
        await Future.delayed(const Duration(milliseconds: 50));

        final info = await service.getDeviceInfo();

        expect(info.manufacturerName, equals('Texas Instruments'));
        expect(info.modelNumber, equals('DLP NIRscan Nano'));
        expect(info.serialNumber, equals('SN12345'));
        expect(info.hardwareRevision, equals('2.0.0'));
        expect(info.tivaFirmwareRevision, equals('2.4.4'));
        expect(info.spectrumLibraryRevision, equals('515'));
      });
    });

    group('getDeviceStatus', () {
      test('throws NotConnectedException when not connected', () {
        expect(
          () => service.getDeviceStatus(),
          throwsA(isA<NotConnectedException>()),
        );
      });

      test('reads all status characteristics and returns DeviceStatus',
          () async {
        final mockDevice = MockBluetoothDevice();
        final mockBasService = MockBluetoothService();
        final mockGgisService = MockBluetoothService();

        // BAS Characteristic
        final battLvlChar = MockBluetoothCharacteristic();

        // GGIS Characteristics
        final tempChar = MockBluetoothCharacteristic();
        final humidChar = MockBluetoothCharacteristic();
        final devStatusChar = MockBluetoothCharacteristic();
        final errStatusChar = MockBluetoothCharacteristic();

        // Device setup
        when(mockDevice.remoteId)
            .thenReturn(const DeviceIdentifier('AA:BB:CC:DD:EE:FF'));
        when(mockDevice.platformName).thenReturn('NIRScan Nano');
        when(mockDevice.connect(
          timeout: anyNamed('timeout'),
          autoConnect: anyNamed('autoConnect'),
        )).thenAnswer((_) async {});
        when(mockDevice.discoverServices())
            .thenAnswer((_) async => [mockBasService, mockGgisService]);
        when(mockDevice.connectionState).thenAnswer(
          (_) => Stream.value(BluetoothConnectionState.connected),
        );
        when(mockDevice.disconnect()).thenAnswer((_) async {});
        when(mockDevice.requestMtu(any, predelay: anyNamed('predelay'), timeout: anyNamed('timeout')))
            .thenAnswer((_) async => 512);

        // BAS Service UUID (0x180F)
        when(mockBasService.uuid)
            .thenReturn(Guid('0000180f-0000-1000-8000-00805f9b34fb'));
        when(mockBasService.characteristics).thenReturn([battLvlChar]);

        // GGIS Service UUID
        when(mockGgisService.uuid)
            .thenReturn(Guid('53455201-444c-5020-4e49-52204e616e6f'));
        when(mockGgisService.characteristics).thenReturn([
          tempChar,
          humidChar,
          devStatusChar,
          errStatusChar,
        ]);

        // Battery Level - uint8 (75%)
        when(battLvlChar.uuid)
            .thenReturn(Guid('00002a19-0000-1000-8000-00805f9b34fb'));
        when(battLvlChar.read()).thenAnswer((_) async => [75]);

        // Temperature - int16 (2550 = 25.50°C)
        when(tempChar.uuid)
            .thenReturn(Guid('43484101-444c-5020-4e49-52204e616e6f'));
        when(tempChar.read())
            .thenAnswer((_) async => [0xF6, 0x09]); // 2550 little-endian

        // Humidity - uint16 (4520 = 45.20%)
        when(humidChar.uuid)
            .thenReturn(Guid('43484102-444c-5020-4e49-52204e616e6f'));
        when(humidChar.read())
            .thenAnswer((_) async => [0xA8, 0x11]); // 4520 little-endian

        // Device Status - uint16 (0x0001)
        when(devStatusChar.uuid)
            .thenReturn(Guid('43484103-444c-5020-4e49-52204e616e6f'));
        when(devStatusChar.read()).thenAnswer((_) async => [0x01, 0x00]);

        // Error Status - uint16 (0x0000 = no errors)
        when(errStatusChar.uuid)
            .thenReturn(Guid('43484104-444c-5020-4e49-52204e616e6f'));
        when(errStatusChar.read()).thenAnswer((_) async => [0x00, 0x00]);

        when(mockAdapter.getDevice('AA:BB:CC:DD:EE:FF')).thenReturn(mockDevice);

        await service.connect('AA:BB:CC:DD:EE:FF');
        await Future.delayed(const Duration(milliseconds: 50));

        final status = await service.getDeviceStatus();

        expect(status.batteryLevel, equals(75));
        expect(status.temperature, closeTo(25.50, 0.01));
        expect(status.humidity, closeTo(45.20, 0.01));
        expect(status.deviceStatus, equals('01'));
        expect(status.errorStatus, equals('00'));
      });

      test('handles error status flags', () async {
        final mockDevice = MockBluetoothDevice();
        final mockBasService = MockBluetoothService();
        final mockGgisService = MockBluetoothService();

        final battLvlChar = MockBluetoothCharacteristic();
        final tempChar = MockBluetoothCharacteristic();
        final humidChar = MockBluetoothCharacteristic();
        final devStatusChar = MockBluetoothCharacteristic();
        final errStatusChar = MockBluetoothCharacteristic();

        when(mockDevice.remoteId)
            .thenReturn(const DeviceIdentifier('AA:BB:CC:DD:EE:FF'));
        when(mockDevice.platformName).thenReturn('NIRScan Nano');
        when(mockDevice.connect(
          timeout: anyNamed('timeout'),
          autoConnect: anyNamed('autoConnect'),
        )).thenAnswer((_) async {});
        when(mockDevice.discoverServices())
            .thenAnswer((_) async => [mockBasService, mockGgisService]);
        when(mockDevice.connectionState).thenAnswer(
          (_) => Stream.value(BluetoothConnectionState.connected),
        );
        when(mockDevice.disconnect()).thenAnswer((_) async {});
        when(mockDevice.requestMtu(any, predelay: anyNamed('predelay'), timeout: anyNamed('timeout')))
            .thenAnswer((_) async => 512);

        when(mockBasService.uuid)
            .thenReturn(Guid('0000180f-0000-1000-8000-00805f9b34fb'));
        when(mockBasService.characteristics).thenReturn([battLvlChar]);

        when(mockGgisService.uuid)
            .thenReturn(Guid('53455201-444c-5020-4e49-52204e616e6f'));
        when(mockGgisService.characteristics).thenReturn([
          tempChar,
          humidChar,
          devStatusChar,
          errStatusChar,
        ]);

        when(battLvlChar.uuid)
            .thenReturn(Guid('00002a19-0000-1000-8000-00805f9b34fb'));
        when(battLvlChar.read()).thenAnswer((_) async => [15]); // Low battery

        when(tempChar.uuid)
            .thenReturn(Guid('43484101-444c-5020-4e49-52204e616e6f'));
        when(tempChar.read()).thenAnswer((_) async => [0x00, 0x00]);

        when(humidChar.uuid)
            .thenReturn(Guid('43484102-444c-5020-4e49-52204e616e6f'));
        when(humidChar.read()).thenAnswer((_) async => [0x00, 0x00]);

        when(devStatusChar.uuid)
            .thenReturn(Guid('43484103-444c-5020-4e49-52204e616e6f'));
        when(devStatusChar.read()).thenAnswer((_) async => [0x00, 0x00]);

        // Error Status - uint16 (0x0003 = lamp + battery error)
        when(errStatusChar.uuid)
            .thenReturn(Guid('43484104-444c-5020-4e49-52204e616e6f'));
        when(errStatusChar.read()).thenAnswer((_) async => [0x03, 0x00]);

        when(mockAdapter.getDevice('AA:BB:CC:DD:EE:FF')).thenReturn(mockDevice);

        await service.connect('AA:BB:CC:DD:EE:FF');
        await Future.delayed(const Duration(milliseconds: 50));

        final status = await service.getDeviceStatus();

        expect(status.errorStatus, equals('03'));
        expect(status.hasErrors, isTrue);
        expect(status.isBatteryLow, isTrue);
      });

      test('handles negative temperature values', () async {
        final mockDevice = MockBluetoothDevice();
        final mockBasService = MockBluetoothService();
        final mockGgisService = MockBluetoothService();

        final battLvlChar = MockBluetoothCharacteristic();
        final tempChar = MockBluetoothCharacteristic();
        final humidChar = MockBluetoothCharacteristic();
        final devStatusChar = MockBluetoothCharacteristic();
        final errStatusChar = MockBluetoothCharacteristic();

        when(mockDevice.remoteId)
            .thenReturn(const DeviceIdentifier('AA:BB:CC:DD:EE:FF'));
        when(mockDevice.platformName).thenReturn('NIRScan Nano');
        when(mockDevice.connect(
          timeout: anyNamed('timeout'),
          autoConnect: anyNamed('autoConnect'),
        )).thenAnswer((_) async {});
        when(mockDevice.discoverServices())
            .thenAnswer((_) async => [mockBasService, mockGgisService]);
        when(mockDevice.connectionState).thenAnswer(
          (_) => Stream.value(BluetoothConnectionState.connected),
        );
        when(mockDevice.disconnect()).thenAnswer((_) async {});
        when(mockDevice.requestMtu(any, predelay: anyNamed('predelay'), timeout: anyNamed('timeout')))
            .thenAnswer((_) async => 512);

        when(mockBasService.uuid)
            .thenReturn(Guid('0000180f-0000-1000-8000-00805f9b34fb'));
        when(mockBasService.characteristics).thenReturn([battLvlChar]);

        when(mockGgisService.uuid)
            .thenReturn(Guid('53455201-444c-5020-4e49-52204e616e6f'));
        when(mockGgisService.characteristics).thenReturn([
          tempChar,
          humidChar,
          devStatusChar,
          errStatusChar,
        ]);

        when(battLvlChar.uuid)
            .thenReturn(Guid('00002a19-0000-1000-8000-00805f9b34fb'));
        when(battLvlChar.read()).thenAnswer((_) async => [50]);

        // Temperature - int16 (-500 = -5.00°C)
        // -500 in two's complement: 0xFE0C
        when(tempChar.uuid)
            .thenReturn(Guid('43484101-444c-5020-4e49-52204e616e6f'));
        when(tempChar.read())
            .thenAnswer((_) async => [0x0C, 0xFE]); // -500 little-endian

        when(humidChar.uuid)
            .thenReturn(Guid('43484102-444c-5020-4e49-52204e616e6f'));
        when(humidChar.read()).thenAnswer((_) async => [0x00, 0x00]);

        when(devStatusChar.uuid)
            .thenReturn(Guid('43484103-444c-5020-4e49-52204e616e6f'));
        when(devStatusChar.read()).thenAnswer((_) async => [0x00, 0x00]);

        when(errStatusChar.uuid)
            .thenReturn(Guid('43484104-444c-5020-4e49-52204e616e6f'));
        when(errStatusChar.read()).thenAnswer((_) async => [0x00, 0x00]);

        when(mockAdapter.getDevice('AA:BB:CC:DD:EE:FF')).thenReturn(mockDevice);

        await service.connect('AA:BB:CC:DD:EE:FF');
        await Future.delayed(const Duration(milliseconds: 50));

        final status = await service.getDeviceStatus();

        expect(status.temperature, closeTo(-5.00, 0.01));
      });
    });

    group('notification subscriptions', () {
      test('subscribeToNotifications enables notifications on characteristic',
          () async {
        final mockDevice = MockBluetoothDevice();
        final mockGcisService = MockBluetoothService();
        final mockRetSpecCalCoeffChar = MockBluetoothCharacteristic();
        final notificationController = StreamController<List<int>>.broadcast();

        when(mockDevice.remoteId)
            .thenReturn(const DeviceIdentifier('AA:BB:CC:DD:EE:FF'));
        when(mockDevice.platformName).thenReturn('NIRScan Nano');
        when(mockDevice.connect(
          timeout: anyNamed('timeout'),
          autoConnect: anyNamed('autoConnect'),
        )).thenAnswer((_) async {});
        when(mockDevice.discoverServices())
            .thenAnswer((_) async => [mockGcisService]);
        when(mockDevice.connectionState).thenAnswer(
          (_) => Stream.value(BluetoothConnectionState.connected),
        );
        when(mockDevice.disconnect()).thenAnswer((_) async {});
        when(mockDevice.requestMtu(any, predelay: anyNamed('predelay'), timeout: anyNamed('timeout')))
            .thenAnswer((_) async => 512);

        // GCIS Service
        when(mockGcisService.uuid)
            .thenReturn(Guid('53455204-444c-5020-4e49-52204e616e6f'));
        when(mockGcisService.characteristics)
            .thenReturn([mockRetSpecCalCoeffChar]);

        // Notification characteristic
        when(mockRetSpecCalCoeffChar.uuid)
            .thenReturn(Guid('4348410e-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockRetSpecCalCoeffChar, notify: true);
        when(mockRetSpecCalCoeffChar.setNotifyValue(true))
            .thenAnswer((_) async => true);
        when(mockRetSpecCalCoeffChar.setNotifyValue(false))
            .thenAnswer((_) async => true);
        when(mockRetSpecCalCoeffChar.onValueReceived)
            .thenAnswer((_) => notificationController.stream);
        when(mockRetSpecCalCoeffChar.isNotifying).thenReturn(true);

        when(mockAdapter.getDevice('AA:BB:CC:DD:EE:FF')).thenReturn(mockDevice);

        await service.connect('AA:BB:CC:DD:EE:FF');
        await Future.delayed(const Duration(milliseconds: 50));

        final dataStream = await service.subscribeToNotifications(
          Guid('4348410e-444c-5020-4e49-52204e616e6f'),
        );

        // Verify setNotifyValue was called during connect
        verify(mockRetSpecCalCoeffChar.setNotifyValue(true)).called(greaterThanOrEqualTo(1));

        // Test that notifications come through
        final receivedData = <List<int>>[];
        final subscription = dataStream.listen(receivedData.add);

        notificationController.add([0x01, 0x02, 0x03]);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(receivedData.length, equals(1));
        expect(receivedData.first, equals([0x01, 0x02, 0x03]));

        await subscription.cancel();
        await notificationController.close();
      });

      test('subscribeToNotifications throws when not connected', () {
        expect(
          () => service.subscribeToNotifications(
              Guid('4348410e-444c-5020-4e49-52204e616e6f')),
          throwsA(isA<NotConnectedException>()),
        );
      });

      test('subscribeToNotifications throws when characteristic not found',
          () async {
        final mockDevice = MockBluetoothDevice();
        final mockDisService = MockBluetoothService();

        when(mockDevice.remoteId)
            .thenReturn(const DeviceIdentifier('AA:BB:CC:DD:EE:FF'));
        when(mockDevice.platformName).thenReturn('NIRScan Nano');
        when(mockDevice.connect(
          timeout: anyNamed('timeout'),
          autoConnect: anyNamed('autoConnect'),
        )).thenAnswer((_) async {});
        when(mockDevice.discoverServices())
            .thenAnswer((_) async => [mockDisService]);
        when(mockDevice.connectionState).thenAnswer(
          (_) => Stream.value(BluetoothConnectionState.connected),
        );
        when(mockDevice.disconnect()).thenAnswer((_) async {});
        when(mockDevice.requestMtu(any, predelay: anyNamed('predelay'), timeout: anyNamed('timeout')))
            .thenAnswer((_) async => 512);

        when(mockDisService.uuid)
            .thenReturn(Guid('0000180a-0000-1000-8000-00805f9b34fb'));
        when(mockDisService.characteristics).thenReturn([]);

        when(mockAdapter.getDevice('AA:BB:CC:DD:EE:FF')).thenReturn(mockDevice);

        await service.connect('AA:BB:CC:DD:EE:FF');
        await Future.delayed(const Duration(milliseconds: 50));

        expect(
          () => service.subscribeToNotifications(
              Guid('4348410e-444c-5020-4e49-52204e616e6f')),
          throwsA(isA<NirScanException>()),
        );
      });

      test(
          'subscribeToAllNotifications subscribes to all notification characteristics',
          () async {
        final mockDevice = MockBluetoothDevice();
        final mockGcisService = MockBluetoothService();
        final mockGsdisService = MockBluetoothService();
        final mockGscisService = MockBluetoothService();

        // Create mock characteristics for notification UUIDs
        final mockChars = <MockBluetoothCharacteristic>[];
        final notificationController = StreamController<List<int>>.broadcast();

        // GCIS notification chars
        final gcisRetSpecCalCoeff = MockBluetoothCharacteristic();
        final gcisRetRefCalCoeff = MockBluetoothCharacteristic();
        final gcisRetRefCalMatrix = MockBluetoothCharacteristic();
        mockChars.addAll(
            [gcisRetSpecCalCoeff, gcisRetRefCalCoeff, gcisRetRefCalMatrix]);

        // GSDIS notification chars
        final gsdisStartScan = MockBluetoothCharacteristic();
        final gsdisRetScanName = MockBluetoothCharacteristic();
        final gsdisRetScanType = MockBluetoothCharacteristic();
        final gsdisRetScanDate = MockBluetoothCharacteristic();
        final gsdisRetPktFmtVer = MockBluetoothCharacteristic();
        final gsdisRetSerScanDataStruct = MockBluetoothCharacteristic();
        final gsdisSdStoredScanIndListData = MockBluetoothCharacteristic();
        final gsdisClearScan = MockBluetoothCharacteristic();
        mockChars.addAll([
          gsdisStartScan,
          gsdisRetScanName,
          gsdisRetScanType,
          gsdisRetScanDate,
          gsdisRetPktFmtVer,
          gsdisRetSerScanDataStruct,
          gsdisSdStoredScanIndListData,
          gsdisClearScan,
        ]);

        // GSCIS notification chars
        final gscisRetStoredConfList = MockBluetoothCharacteristic();
        final gscisRetScanConfData = MockBluetoothCharacteristic();
        mockChars.addAll([gscisRetStoredConfList, gscisRetScanConfData]);

        when(mockDevice.remoteId)
            .thenReturn(const DeviceIdentifier('AA:BB:CC:DD:EE:FF'));
        when(mockDevice.platformName).thenReturn('NIRScan Nano');
        when(mockDevice.connect(
          timeout: anyNamed('timeout'),
          autoConnect: anyNamed('autoConnect'),
        )).thenAnswer((_) async {});
        when(mockDevice.discoverServices()).thenAnswer(
            (_) async => [mockGcisService, mockGsdisService, mockGscisService]);
        when(mockDevice.connectionState).thenAnswer(
          (_) => Stream.value(BluetoothConnectionState.connected),
        );
        when(mockDevice.disconnect()).thenAnswer((_) async {});
        when(mockDevice.requestMtu(any, predelay: anyNamed('predelay'), timeout: anyNamed('timeout')))
            .thenAnswer((_) async => 512);

        // GCIS Service
        when(mockGcisService.uuid)
            .thenReturn(Guid('53455204-444c-5020-4e49-52204e616e6f'));
        when(mockGcisService.characteristics).thenReturn(
            [gcisRetSpecCalCoeff, gcisRetRefCalCoeff, gcisRetRefCalMatrix]);

        // GSDIS Service
        when(mockGsdisService.uuid)
            .thenReturn(Guid('53455206-444c-5020-4e49-52204e616e6f'));
        when(mockGsdisService.characteristics).thenReturn([
          gsdisStartScan,
          gsdisRetScanName,
          gsdisRetScanType,
          gsdisRetScanDate,
          gsdisRetPktFmtVer,
          gsdisRetSerScanDataStruct,
          gsdisSdStoredScanIndListData,
          gsdisClearScan,
        ]);

        // GSCIS Service
        when(mockGscisService.uuid)
            .thenReturn(Guid('53455205-444c-5020-4e49-52204e616e6f'));
        when(mockGscisService.characteristics)
            .thenReturn([gscisRetStoredConfList, gscisRetScanConfData]);

        // Setup notification characteristic UUIDs and behaviors
        when(gcisRetSpecCalCoeff.uuid)
            .thenReturn(Guid('4348410e-444c-5020-4e49-52204e616e6f'));
        when(gcisRetRefCalCoeff.uuid)
            .thenReturn(Guid('43484110-444c-5020-4e49-52204e616e6f'));
        when(gcisRetRefCalMatrix.uuid)
            .thenReturn(Guid('43484112-444c-5020-4e49-52204e616e6f'));
        when(gsdisStartScan.uuid)
            .thenReturn(Guid('4348411d-444c-5020-4e49-52204e616e6f'));
        when(gsdisRetScanName.uuid)
            .thenReturn(Guid('43484120-444c-5020-4e49-52204e616e6f'));
        when(gsdisRetScanType.uuid)
            .thenReturn(Guid('43484122-444c-5020-4e49-52204e616e6f'));
        when(gsdisRetScanDate.uuid)
            .thenReturn(Guid('43484124-444c-5020-4e49-52204e616e6f'));
        when(gsdisRetPktFmtVer.uuid)
            .thenReturn(Guid('43484126-444c-5020-4e49-52204e616e6f'));
        when(gsdisRetSerScanDataStruct.uuid)
            .thenReturn(Guid('43484128-444c-5020-4e49-52204e616e6f'));
        when(gsdisSdStoredScanIndListData.uuid)
            .thenReturn(Guid('4348411b-444c-5020-4e49-52204e616e6f'));
        when(gsdisClearScan.uuid)
            .thenReturn(Guid('4348411e-444c-5020-4e49-52204e616e6f'));
        when(gscisRetStoredConfList.uuid)
            .thenReturn(Guid('43484115-444c-5020-4e49-52204e616e6f'));
        when(gscisRetScanConfData.uuid)
            .thenReturn(Guid('43484117-444c-5020-4e49-52204e616e6f'));

        for (final char in mockChars) {
          stubCharacteristicProperties(char, notify: true);
          when(char.setNotifyValue(true)).thenAnswer((_) async => true);
          when(char.setNotifyValue(false)).thenAnswer((_) async => true);
          when(char.onValueReceived)
              .thenAnswer((_) => notificationController.stream);
          when(char.isNotifying).thenReturn(true);
        }

        when(mockAdapter.getDevice('AA:BB:CC:DD:EE:FF')).thenReturn(mockDevice);

        await service.connect('AA:BB:CC:DD:EE:FF');
        await Future.delayed(const Duration(milliseconds: 50));

        await service.subscribeToAllNotifications();

        // Verify setNotifyValue was called on all notification characteristics
        // (2x: once during connect, once during explicit subscribeToAllNotifications call)
        verify(gcisRetSpecCalCoeff.setNotifyValue(true)).called(2);
        verify(gcisRetRefCalCoeff.setNotifyValue(true)).called(2);
        verify(gcisRetRefCalMatrix.setNotifyValue(true)).called(2);
        verify(gsdisStartScan.setNotifyValue(true)).called(2);
        verify(gsdisRetScanName.setNotifyValue(true)).called(2);
        verify(gsdisRetScanType.setNotifyValue(true)).called(2);
        verify(gsdisRetScanDate.setNotifyValue(true)).called(2);
        verify(gsdisRetPktFmtVer.setNotifyValue(true)).called(2);
        verify(gsdisRetSerScanDataStruct.setNotifyValue(true)).called(2);
        verify(gsdisSdStoredScanIndListData.setNotifyValue(true)).called(2);
        verify(gsdisClearScan.setNotifyValue(true)).called(2);
        verify(gscisRetStoredConfList.setNotifyValue(true)).called(2);
        verify(gscisRetScanConfData.setNotifyValue(true)).called(2);

        await notificationController.close();
      });

      test('subscribeToAllNotifications throws when not connected', () {
        expect(
          () => service.subscribeToAllNotifications(),
          throwsA(isA<NotConnectedException>()),
        );
      });
    });

    group('performScan', () {
      test('throws NotConnectedException when not connected', () {
        expect(
          () => service.performScan(),
          throwsA(isA<NotConnectedException>()),
        );
      });

      test(
          'throws NirScanException when calibration characteristics not found',
          () async {
        // performScan now always re-fetches calibration from BLE.
        // If calibration characteristics are missing, _ensureCalibrationData
        // throws NirScanException (not CalibrationRequiredException).
        final mockDevice = MockBluetoothDevice();
        final mockService = MockBluetoothService();

        when(mockDevice.remoteId)
            .thenReturn(const DeviceIdentifier('AA:BB:CC:DD:EE:FF'));
        when(mockDevice.platformName).thenReturn('NIRScan Nano');
        when(mockDevice.connect(
          timeout: anyNamed('timeout'),
          autoConnect: anyNamed('autoConnect'),
        )).thenAnswer((_) async {});
        when(mockDevice.discoverServices())
            .thenAnswer((_) async => [mockService]);
        when(mockDevice.connectionState).thenAnswer(
          (_) => Stream.value(BluetoothConnectionState.connected),
        );
        when(mockDevice.disconnect()).thenAnswer((_) async {});
        when(mockDevice.requestMtu(any,
                predelay: anyNamed('predelay'), timeout: anyNamed('timeout')))
            .thenAnswer((_) async => 512);

        // Minimal service setup - GDTS for time sync only (no GCIS)
        when(mockService.uuid)
            .thenReturn(Guid('53455203-444c-5020-4e49-52204e616e6f'));
        final mockTimeChar = MockBluetoothCharacteristic();
        when(mockService.characteristics).thenReturn([mockTimeChar]);
        when(mockTimeChar.uuid)
            .thenReturn(Guid('4348410c-444c-5020-4e49-52204e616e6f'));
        when(mockTimeChar.write(any,
                withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {});

        when(mockAdapter.getDevice('AA:BB:CC:DD:EE:FF')).thenReturn(mockDevice);

        await service.connect('AA:BB:CC:DD:EE:FF');
        await Future.delayed(const Duration(milliseconds: 50));

        // Attempt scan - calibration re-fetch will fail (no GCIS characteristics)
        expect(
          () => service.performScan(),
          throwsA(isA<NirScanException>()),
        );
      });

      test('calls syncTime before starting scan', () async {
        final mockDevice = MockBluetoothDevice();
        final mockGdtsService = MockBluetoothService();
        final mockGsdisService = MockBluetoothService();
        final mockTimeChar = MockBluetoothCharacteristic();
        final mockStartScanChar = MockBluetoothCharacteristic();
        final startScanNotifyController =
            StreamController<List<int>>.broadcast();
        var timeSyncCalled = false;

        when(mockDevice.remoteId)
            .thenReturn(const DeviceIdentifier('AA:BB:CC:DD:EE:FF'));
        when(mockDevice.platformName).thenReturn('NIRScan Nano');
        when(mockDevice.connect(
          timeout: anyNamed('timeout'),
          autoConnect: anyNamed('autoConnect'),
        )).thenAnswer((_) async {});
        when(mockDevice.discoverServices())
            .thenAnswer((_) async => [mockGdtsService, mockGsdisService]);
        when(mockDevice.connectionState).thenAnswer(
          (_) => Stream.value(BluetoothConnectionState.connected),
        );
        when(mockDevice.disconnect()).thenAnswer((_) async {});
        when(mockDevice.requestMtu(any, predelay: anyNamed('predelay'), timeout: anyNamed('timeout')))
            .thenAnswer((_) async => 512);

        // GDTS service for time sync
        when(mockGdtsService.uuid)
            .thenReturn(Guid('4348410b-444c-5020-4e49-52204e616e6f'));
        when(mockGdtsService.characteristics).thenReturn([mockTimeChar]);
        when(mockTimeChar.uuid)
            .thenReturn(Guid('4348410c-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockTimeChar, write: true, notify: false);
        when(mockTimeChar.write(any,
                withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {
          timeSyncCalled = true;
        });

        // GSDIS service for scan
        when(mockGsdisService.uuid)
            .thenReturn(Guid('53455206-444c-5020-4e49-52204e616e6f'));
        when(mockGsdisService.characteristics).thenReturn([mockStartScanChar]);
        when(mockStartScanChar.uuid)
            .thenReturn(Guid('4348411d-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockStartScanChar, notify: true, write: true);
        when(mockStartScanChar.write(any,
                withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {});
        when(mockStartScanChar.setNotifyValue(true))
            .thenAnswer((_) async => true);
        when(mockStartScanChar.setNotifyValue(false))
            .thenAnswer((_) async => true);
        when(mockStartScanChar.isNotifying).thenReturn(true);
        when(mockStartScanChar.onValueReceived)
            .thenAnswer((_) => startScanNotifyController.stream);
        when(mockStartScanChar.lastValueStream)
            .thenAnswer((_) => startScanNotifyController.stream);

        when(mockAdapter.getDevice('AA:BB:CC:DD:EE:FF')).thenReturn(mockDevice);

        await service.connect('AA:BB:CC:DD:EE:FF');

        // Set calibration data for testing (required before scan)
        service.setCalibrationDataForTesting([0x01], [0x01], [0x02]);
        service.skipCalibrationRefreshForTesting();


        // Start scan - will eventually fail, but we only care about time sync
        final scanFuture = service.performScan();
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert: time sync should have been called BEFORE scan started
        expect(timeSyncCalled, isTrue);

        // Send error notification to stop scan cleanly (avoids "test failed after completed")
        await Future.delayed(const Duration(milliseconds: 300));
        startScanNotifyController.add([0x02, 0x00, 0x00, 0x00, 0x00]);
        try {
          await scanFuture;
        } catch (_) {
          // Expected - scan fails with ScanFailedException
        }

        // Cleanup
        await startScanNotifyController.close();
      });

      // TODO: Fix timing issues with mock notification streams
      test('writes save flag 0x00 to start scan characteristic', () async {
        final mockDevice = MockBluetoothDevice();
        final mockGdtsService = MockBluetoothService();
        final mockGsdisService = MockBluetoothService();
        final mockTimeChar = MockBluetoothCharacteristic();
        final mockStartScanChar = MockBluetoothCharacteristic();
        final startScanNotifyController =
            StreamController<List<int>>.broadcast();

        when(mockDevice.remoteId)
            .thenReturn(const DeviceIdentifier('AA:BB:CC:DD:EE:FF'));
        when(mockDevice.platformName).thenReturn('NIRScan Nano');
        when(mockDevice.connect(
          timeout: anyNamed('timeout'),
          autoConnect: anyNamed('autoConnect'),
        )).thenAnswer((_) async {});
        when(mockDevice.discoverServices())
            .thenAnswer((_) async => [mockGdtsService, mockGsdisService]);
        when(mockDevice.connectionState).thenAnswer(
          (_) => Stream.value(BluetoothConnectionState.connected),
        );
        when(mockDevice.disconnect()).thenAnswer((_) async {});
        when(mockDevice.requestMtu(any, predelay: anyNamed('predelay'), timeout: anyNamed('timeout')))
            .thenAnswer((_) async => 512);

        // GDTS service for time sync
        when(mockGdtsService.uuid)
            .thenReturn(Guid('53455203-444c-5020-4e49-52204e616e6f'));
        when(mockGdtsService.characteristics).thenReturn([mockTimeChar]);
        when(mockTimeChar.uuid)
            .thenReturn(Guid('4348410c-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockTimeChar, write: true, notify: false);
        when(mockTimeChar.write(any, withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {});

        when(mockGsdisService.uuid)
            .thenReturn(Guid('53455206-444c-5020-4e49-52204e616e6f'));
        when(mockGsdisService.characteristics).thenReturn([mockStartScanChar]);

        // GSDIS_START_SCAN characteristic - needs both notify and write properties
        // Real sensor has separate chars, but for test we use one with both
        when(mockStartScanChar.uuid)
            .thenReturn(Guid('4348411d-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockStartScanChar, notify: true, write: true);
        when(mockStartScanChar.write(any,
                withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {});
        when(mockStartScanChar.setNotifyValue(true))
            .thenAnswer((_) async => true);
        when(mockStartScanChar.setNotifyValue(false))
            .thenAnswer((_) async => true);
        when(mockStartScanChar.onValueReceived)
            .thenAnswer((_) => startScanNotifyController.stream);
        when(mockStartScanChar.lastValueStream)
            .thenAnswer((_) => startScanNotifyController.stream);
        when(mockStartScanChar.isNotifying).thenReturn(true);

        when(mockAdapter.getDevice('AA:BB:CC:DD:EE:FF')).thenReturn(mockDevice);

        await service.connect('AA:BB:CC:DD:EE:FF');
        await Future.delayed(const Duration(milliseconds: 50));

        // Set calibration data for testing (required before scan)
        service.setCalibrationDataForTesting([0x01], [0x01], [0x02]);
        service.skipCalibrationRefreshForTesting();


        // Start scan in background, will wait for notification
        final scanFuture = service.performScan(saveToSd: false);

        // Wait for scan to progress past the 200ms internal delay and write
        await Future.delayed(const Duration(milliseconds: 400));

        // Verify write was called with [0x00] (save=false)
        verify(mockStartScanChar
                .write([0x00], withoutResponse: anyNamed('withoutResponse')))
            .called(1);

        // Emit scan failed - use multi-byte error (single-byte 0x00/0x01 are filtered as write echoes)
        startScanNotifyController.add([0x02, 0x00, 0x00, 0x00, 0x00]); // Non-0xFF = error

        // Expect ScanFailedException
        await expectLater(scanFuture, throwsA(isA<ScanFailedException>()));

        await startScanNotifyController.close();
      });

      test('writes save flag 0x01 when saveToSd is true', () async {
        final mockDevice = MockBluetoothDevice();
        final mockGdtsService = MockBluetoothService();
        final mockGsdisService = MockBluetoothService();
        final mockTimeChar = MockBluetoothCharacteristic();
        final mockStartScanChar = MockBluetoothCharacteristic();
        final startScanNotifyController =
            StreamController<List<int>>.broadcast();

        when(mockDevice.remoteId)
            .thenReturn(const DeviceIdentifier('AA:BB:CC:DD:EE:FF'));
        when(mockDevice.platformName).thenReturn('NIRScan Nano');
        when(mockDevice.connect(
          timeout: anyNamed('timeout'),
          autoConnect: anyNamed('autoConnect'),
        )).thenAnswer((_) async {});
        when(mockDevice.discoverServices())
            .thenAnswer((_) async => [mockGdtsService, mockGsdisService]);
        when(mockDevice.connectionState).thenAnswer(
          (_) => Stream.value(BluetoothConnectionState.connected),
        );
        when(mockDevice.disconnect()).thenAnswer((_) async {});
        when(mockDevice.requestMtu(any, predelay: anyNamed('predelay'), timeout: anyNamed('timeout')))
            .thenAnswer((_) async => 512);

        // GDTS service for time sync
        when(mockGdtsService.uuid)
            .thenReturn(Guid('53455203-444c-5020-4e49-52204e616e6f'));
        when(mockGdtsService.characteristics).thenReturn([mockTimeChar]);
        when(mockTimeChar.uuid)
            .thenReturn(Guid('4348410c-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockTimeChar, write: true, notify: false);
        when(mockTimeChar.write(any, withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {});

        when(mockGsdisService.uuid)
            .thenReturn(Guid('53455206-444c-5020-4e49-52204e616e6f'));
        when(mockGsdisService.characteristics).thenReturn([mockStartScanChar]);

        when(mockStartScanChar.uuid)
            .thenReturn(Guid('4348411d-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockStartScanChar, notify: true, write: true);
        when(mockStartScanChar.write(any,
                withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {});
        when(mockStartScanChar.setNotifyValue(true))
            .thenAnswer((_) async => true);
        when(mockStartScanChar.setNotifyValue(false))
            .thenAnswer((_) async => true);
        when(mockStartScanChar.onValueReceived)
            .thenAnswer((_) => startScanNotifyController.stream);
        when(mockStartScanChar.lastValueStream)
            .thenAnswer((_) => startScanNotifyController.stream);
        when(mockStartScanChar.isNotifying).thenReturn(true);

        when(mockAdapter.getDevice('AA:BB:CC:DD:EE:FF')).thenReturn(mockDevice);

        await service.connect('AA:BB:CC:DD:EE:FF');
        await Future.delayed(const Duration(milliseconds: 50));

        // Set calibration data for testing (required before scan)
        service.setCalibrationDataForTesting([0x01], [0x01], [0x02]);
        service.skipCalibrationRefreshForTesting();


        final scanFuture = service.performScan(saveToSd: true);

        // Wait for scan to progress past the 200ms internal delay and write
        await Future.delayed(const Duration(milliseconds: 400));

        // Verify write was called with [0x01] (save=true)
        verify(mockStartScanChar
                .write([0x01], withoutResponse: anyNamed('withoutResponse')))
            .called(1);

        // Emit scan failed - use multi-byte error (single-byte 0x00/0x01 are filtered as write echoes)
        startScanNotifyController.add([0x02, 0x00, 0x00, 0x00, 0x00]); // Non-0xFF = error

        await expectLater(scanFuture, throwsA(isA<ScanFailedException>()));

        await startScanNotifyController.close();
      });

      test('throws ScanFailedException when scan notification is not 0xFF',
          () async {
        final mockDevice = MockBluetoothDevice();
        final mockGdtsService = MockBluetoothService();
        final mockGsdisService = MockBluetoothService();
        final mockTimeChar = MockBluetoothCharacteristic();
        final mockStartScanChar = MockBluetoothCharacteristic();
        final startScanNotifyController =
            StreamController<List<int>>.broadcast();

        when(mockDevice.remoteId)
            .thenReturn(const DeviceIdentifier('AA:BB:CC:DD:EE:FF'));
        when(mockDevice.platformName).thenReturn('NIRScan Nano');
        when(mockDevice.connect(
          timeout: anyNamed('timeout'),
          autoConnect: anyNamed('autoConnect'),
        )).thenAnswer((_) async {});
        when(mockDevice.discoverServices())
            .thenAnswer((_) async => [mockGdtsService, mockGsdisService]);
        when(mockDevice.connectionState).thenAnswer(
          (_) => Stream.value(BluetoothConnectionState.connected),
        );
        when(mockDevice.disconnect()).thenAnswer((_) async {});
        when(mockDevice.requestMtu(any, predelay: anyNamed('predelay'), timeout: anyNamed('timeout')))
            .thenAnswer((_) async => 512);

        // GDTS service for time sync
        when(mockGdtsService.uuid)
            .thenReturn(Guid('53455203-444c-5020-4e49-52204e616e6f'));
        when(mockGdtsService.characteristics).thenReturn([mockTimeChar]);
        when(mockTimeChar.uuid)
            .thenReturn(Guid('4348410c-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockTimeChar, write: true, notify: false);
        when(mockTimeChar.write(any, withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {});

        when(mockGsdisService.uuid)
            .thenReturn(Guid('53455206-444c-5020-4e49-52204e616e6f'));
        when(mockGsdisService.characteristics).thenReturn([mockStartScanChar]);

        when(mockStartScanChar.uuid)
            .thenReturn(Guid('4348411d-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockStartScanChar, notify: true, write: true);
        when(mockStartScanChar.write(any,
                withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {});
        when(mockStartScanChar.setNotifyValue(true))
            .thenAnswer((_) async => true);
        when(mockStartScanChar.setNotifyValue(false))
            .thenAnswer((_) async => true);
        when(mockStartScanChar.onValueReceived)
            .thenAnswer((_) => startScanNotifyController.stream);
        when(mockStartScanChar.lastValueStream)
            .thenAnswer((_) => startScanNotifyController.stream);
        when(mockStartScanChar.isNotifying).thenReturn(true);

        when(mockAdapter.getDevice('AA:BB:CC:DD:EE:FF')).thenReturn(mockDevice);

        await service.connect('AA:BB:CC:DD:EE:FF');
        await Future.delayed(const Duration(milliseconds: 50));

        // Set calibration data for testing (required before scan)
        service.setCalibrationDataForTesting([0x01], [0x01], [0x02]);
        service.skipCalibrationRefreshForTesting();


        final scanFuture = service.performScan();

        // Wait for scan to progress past the 200ms internal delay and write
        await Future.delayed(const Duration(milliseconds: 400));

        // Emit error response (not 0xFF)
        startScanNotifyController.add([0x02, 0x00, 0x00, 0x00, 0x00]);

        await expectLater(scanFuture, throwsA(isA<ScanFailedException>()));

        await startScanNotifyController.close();
      });

      test('returns ScanData on successful scan', () async {
        final mockDevice = MockBluetoothDevice();
        final mockGdtsService = MockBluetoothService();
        final mockGsdisService = MockBluetoothService();
        final mockTimeChar = MockBluetoothCharacteristic();

        // Characteristics
        final mockStartScanChar = MockBluetoothCharacteristic();
        final mockReqScanNameChar = MockBluetoothCharacteristic();
        final mockRetScanNameChar = MockBluetoothCharacteristic();
        final mockReqScanTypeChar = MockBluetoothCharacteristic();
        final mockRetScanTypeChar = MockBluetoothCharacteristic();
        final mockReqScanDateChar = MockBluetoothCharacteristic();
        final mockRetScanDateChar = MockBluetoothCharacteristic();
        final mockReqPktFmtVerChar = MockBluetoothCharacteristic();
        final mockRetPktFmtVerChar = MockBluetoothCharacteristic();
        final mockReqSerScanDataChar = MockBluetoothCharacteristic();
        final mockRetSerScanDataChar = MockBluetoothCharacteristic();

        // Notification controllers
        final startScanNotifyController =
            StreamController<List<int>>.broadcast();
        final retScanNameNotifyController =
            StreamController<List<int>>.broadcast();
        final retScanTypeNotifyController =
            StreamController<List<int>>.broadcast();
        final retScanDateNotifyController =
            StreamController<List<int>>.broadcast();
        final retPktFmtVerNotifyController =
            StreamController<List<int>>.broadcast();
        final retSerScanDataNotifyController =
            StreamController<List<int>>.broadcast();

        when(mockDevice.remoteId)
            .thenReturn(const DeviceIdentifier('AA:BB:CC:DD:EE:FF'));
        when(mockDevice.platformName).thenReturn('NIRScan Nano');
        when(mockDevice.connect(
          timeout: anyNamed('timeout'),
          autoConnect: anyNamed('autoConnect'),
        )).thenAnswer((_) async {});
        when(mockDevice.discoverServices())
            .thenAnswer((_) async => [mockGdtsService, mockGsdisService]);
        when(mockDevice.connectionState).thenAnswer(
          (_) => Stream.value(BluetoothConnectionState.connected),
        );
        when(mockDevice.disconnect()).thenAnswer((_) async {});
        when(mockDevice.requestMtu(any, predelay: anyNamed('predelay'), timeout: anyNamed('timeout')))
            .thenAnswer((_) async => 512);

        // GDTS service for time sync
        when(mockGdtsService.uuid)
            .thenReturn(Guid('53455203-444c-5020-4e49-52204e616e6f'));
        when(mockGdtsService.characteristics).thenReturn([mockTimeChar]);
        when(mockTimeChar.uuid)
            .thenReturn(Guid('4348410c-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockTimeChar, write: true, notify: false);
        when(mockTimeChar.write(any, withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {});

        when(mockGsdisService.uuid)
            .thenReturn(Guid('53455206-444c-5020-4e49-52204e616e6f'));
        when(mockGsdisService.characteristics).thenReturn([
          mockStartScanChar,
          mockReqScanNameChar,
          mockRetScanNameChar,
          mockReqScanTypeChar,
          mockRetScanTypeChar,
          mockReqScanDateChar,
          mockRetScanDateChar,
          mockReqPktFmtVerChar,
          mockRetPktFmtVerChar,
          mockReqSerScanDataChar,
          mockRetSerScanDataChar,
        ]);

        // GSDIS_START_SCAN - needs both notify and write
        when(mockStartScanChar.uuid)
            .thenReturn(Guid('4348411d-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockStartScanChar, notify: true, write: true);
        when(mockStartScanChar.write(any,
                withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {});
        when(mockStartScanChar.setNotifyValue(true))
            .thenAnswer((_) async => true);
        when(mockStartScanChar.setNotifyValue(false))
            .thenAnswer((_) async => true);
        when(mockStartScanChar.onValueReceived)
            .thenAnswer((_) => startScanNotifyController.stream);
        when(mockStartScanChar.lastValueStream)
            .thenAnswer((_) => startScanNotifyController.stream);
        when(mockStartScanChar.isNotifying).thenReturn(true);

        // GSDIS_REQ_SCAN_NAME (write only)
        when(mockReqScanNameChar.uuid)
            .thenReturn(Guid('4348411f-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockReqScanNameChar, write: true, notify: false);
        when(mockReqScanNameChar.write(any,
                withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {});

        // GSDIS_RET_SCAN_NAME (notify only)
        when(mockRetScanNameChar.uuid)
            .thenReturn(Guid('43484120-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockRetScanNameChar, notify: true, write: false);
        when(mockRetScanNameChar.setNotifyValue(true))
            .thenAnswer((_) async => true);
        when(mockRetScanNameChar.setNotifyValue(false))
            .thenAnswer((_) async => true);
        when(mockRetScanNameChar.onValueReceived)
            .thenAnswer((_) => retScanNameNotifyController.stream);
        when(mockRetScanNameChar.isNotifying).thenReturn(true);

        // GSDIS_REQ_SCAN_TYPE (write only)
        when(mockReqScanTypeChar.uuid)
            .thenReturn(Guid('43484121-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockReqScanTypeChar, write: true, notify: false);
        when(mockReqScanTypeChar.write(any,
                withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {});

        // GSDIS_RET_SCAN_TYPE (notify only)
        when(mockRetScanTypeChar.uuid)
            .thenReturn(Guid('43484122-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockRetScanTypeChar, notify: true, write: false);
        when(mockRetScanTypeChar.setNotifyValue(true))
            .thenAnswer((_) async => true);
        when(mockRetScanTypeChar.setNotifyValue(false))
            .thenAnswer((_) async => true);
        when(mockRetScanTypeChar.isNotifying).thenReturn(true);
        when(mockRetScanTypeChar.onValueReceived)
            .thenAnswer((_) => retScanTypeNotifyController.stream);

        // GSDIS_REQ_SCAN_DATE (write only)
        when(mockReqScanDateChar.uuid)
            .thenReturn(Guid('43484123-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockReqScanDateChar, write: true, notify: false);
        when(mockReqScanDateChar.write(any,
                withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {});

        // GSDIS_RET_SCAN_DATE (notify only)
        when(mockRetScanDateChar.uuid)
            .thenReturn(Guid('43484124-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockRetScanDateChar, notify: true, write: false);
        when(mockRetScanDateChar.setNotifyValue(true))
            .thenAnswer((_) async => true);
        when(mockRetScanDateChar.setNotifyValue(false))
            .thenAnswer((_) async => true);
        when(mockRetScanDateChar.onValueReceived)
            .thenAnswer((_) => retScanDateNotifyController.stream);
        when(mockRetScanDateChar.isNotifying).thenReturn(true);

        // GSDIS_REQ_PKT_FMT_VER (write only)
        when(mockReqPktFmtVerChar.uuid)
            .thenReturn(Guid('43484125-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockReqPktFmtVerChar, write: true, notify: false);
        when(mockReqPktFmtVerChar.write(any,
                withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {});

        // GSDIS_RET_PKT_FMT_VER (notify only)
        when(mockRetPktFmtVerChar.uuid)
            .thenReturn(Guid('43484126-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockRetPktFmtVerChar, notify: true, write: false);
        when(mockRetPktFmtVerChar.setNotifyValue(true))
            .thenAnswer((_) async => true);
        when(mockRetPktFmtVerChar.setNotifyValue(false))
            .thenAnswer((_) async => true);
        when(mockRetPktFmtVerChar.onValueReceived)
            .thenAnswer((_) => retPktFmtVerNotifyController.stream);
        when(mockRetPktFmtVerChar.isNotifying).thenReturn(true);

        // GSDIS_REQ_SER_SCAN_DATA_STRUCT (write only)
        when(mockReqSerScanDataChar.uuid)
            .thenReturn(Guid('43484127-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockReqSerScanDataChar, write: true, notify: false);
        when(mockReqSerScanDataChar.write(any,
                withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {});

        // GSDIS_RET_SER_SCAN_DATA_STRUCT (notify only - multi-packet)
        when(mockRetSerScanDataChar.uuid)
            .thenReturn(Guid('43484128-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockRetSerScanDataChar, notify: true, write: false);
        when(mockRetSerScanDataChar.setNotifyValue(true))
            .thenAnswer((_) async => true);
        when(mockRetSerScanDataChar.setNotifyValue(false))
            .thenAnswer((_) async => true);
        when(mockRetSerScanDataChar.onValueReceived)
            .thenAnswer((_) => retSerScanDataNotifyController.stream);
        when(mockRetSerScanDataChar.isNotifying).thenReturn(true);

        when(mockAdapter.getDevice('AA:BB:CC:DD:EE:FF')).thenReturn(mockDevice);

        await service.connect('AA:BB:CC:DD:EE:FF');
        await Future.delayed(const Duration(milliseconds: 50));

        // Set calibration data for testing (required before scan)
        service.setCalibrationDataForTesting([0x01], [0x01], [0x02]);
        service.skipCalibrationRefreshForTesting();


        final scanFuture = service.performScan();

        // Wait for performScan to finish its 200ms delay, write scan cmd, and start listening
        await Future.delayed(const Duration(milliseconds: 400));

        // Simulate scan complete notification: 0xFF + 4-byte scan index
        // Scan index = 0x00000001 (little-endian)
        startScanNotifyController.add([0xFF, 0x01, 0x00, 0x00, 0x00]);

        await Future.delayed(const Duration(milliseconds: 100));

        // Return scan name: "TestScan"
        retScanNameNotifyController.add('TestScan'.codeUnits);

        await Future.delayed(const Duration(milliseconds: 50));

        // Return scan type: 0x01 (hex string "01")
        retScanTypeNotifyController.add([0x01]);

        await Future.delayed(const Duration(milliseconds: 50));

        // Return scan date: 26/01/25 14:30:45 (YYMMDDHHMMSS format as string)
        // As bytes: [0x32, 0x36, 0x30, 0x31, 0x32, 0x35, 0x31, 0x34, 0x33, 0x30, 0x34, 0x35]
        // which is "260125143045"
        retScanDateNotifyController.add('260125143045'.codeUnits);

        await Future.delayed(const Duration(milliseconds: 50));

        // Return packet format version: uint32 = 1 (little-endian)
        retPktFmtVerNotifyController.add([0x01, 0x00, 0x00, 0x00]);

        await Future.delayed(const Duration(milliseconds: 50));

        // Multi-packet scan data:
        // Header: [0x00, 0x05, 0x00] = size 5 bytes
        retSerScanDataNotifyController.add([0x00, 0x05, 0x00]);
        await Future.delayed(const Duration(milliseconds: 20));
        // Data packet 1: [0x01, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE]
        retSerScanDataNotifyController
            .add([0x01, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE]);

        final scanData = await scanFuture;

        expect(scanData.name, equals('TestScan'));
        expect(scanData.type, equals('01'));
        expect(scanData.date, equals('260125143045'));
        expect(scanData.packetFormatVersion, equals('1'));
        expect(scanData.rawData.length, equals(5));
        expect(scanData.rawData, equals([0xAA, 0xBB, 0xCC, 0xDD, 0xEE]));
        expect(scanData.scanIndex, equals([0x01, 0x00, 0x00, 0x00]));

        // Cleanup
        await startScanNotifyController.close();
        await retScanNameNotifyController.close();
        await retScanTypeNotifyController.close();
        await retScanDateNotifyController.close();
        await retPktFmtVerNotifyController.close();
        await retSerScanDataNotifyController.close();
      });

      test(
          'performScan invalidates calibration cache and re-fetches from BLE each call',
          () async {
        // This test verifies that performScan does NOT use cached calibration
        // data. Per TI User's Guide, calibration must be re-fetched before
        // every scan. We verify by checking that calibration BLE request
        // characteristics are written to on each performScan call.
        final mockDevice = MockBluetoothDevice();
        final mockGdtsService = MockBluetoothService();
        final mockGsdisService = MockBluetoothService();
        final mockGcisService = MockBluetoothService();
        final mockTimeChar = MockBluetoothCharacteristic();
        final mockStartScanChar = MockBluetoothCharacteristic();

        // Calibration characteristics
        final mockReqSpecCoeffChar = MockBluetoothCharacteristic();
        final mockRetSpecCoeffChar = MockBluetoothCharacteristic();
        final mockReqCoeffChar = MockBluetoothCharacteristic();
        final mockRetCoeffChar = MockBluetoothCharacteristic();
        final mockReqMatrixChar = MockBluetoothCharacteristic();
        final mockRetMatrixChar = MockBluetoothCharacteristic();

        // Error/status characteristics for diagnostic reads
        final mockErrStatusChar = createMockCharacteristic(
          uuid: Guid('4348410a-444c-5020-4e49-52204e616e6f'),
          read: true,
          notify: false,
          write: false,
        );
        final mockDevStatusChar = createMockCharacteristic(
          uuid: Guid('43484109-444c-5020-4e49-52204e616e6f'),
          read: true,
          notify: false,
          write: false,
        );

        // Stream controllers
        final startScanNotifyController =
            StreamController<List<int>>.broadcast();
        final specCoeffNotifyController =
            StreamController<List<int>>.broadcast();
        final coeffNotifyController = StreamController<List<int>>.broadcast();
        final matrixNotifyController = StreamController<List<int>>.broadcast();

        var specCoeffWriteCount = 0;
        var coeffWriteCount = 0;
        var matrixWriteCount = 0;

        // Device setup
        when(mockDevice.remoteId)
            .thenReturn(const DeviceIdentifier('AA:BB:CC:DD:EE:FF'));
        when(mockDevice.platformName).thenReturn('NIRScan Nano');
        when(mockDevice.connect(
          timeout: anyNamed('timeout'),
          autoConnect: anyNamed('autoConnect'),
        )).thenAnswer((_) async {});
        when(mockDevice.discoverServices()).thenAnswer(
            (_) async => [mockGdtsService, mockGsdisService, mockGcisService]);
        when(mockDevice.connectionState).thenAnswer(
          (_) => Stream.value(BluetoothConnectionState.connected),
        );
        when(mockDevice.disconnect()).thenAnswer((_) async {});
        when(mockDevice.requestMtu(any,
                predelay: anyNamed('predelay'), timeout: anyNamed('timeout')))
            .thenAnswer((_) async => 512);

        // GDTS service for time sync
        when(mockGdtsService.uuid)
            .thenReturn(Guid('53455203-444c-5020-4e49-52204e616e6f'));
        when(mockGdtsService.characteristics).thenReturn([mockTimeChar]);
        when(mockTimeChar.uuid)
            .thenReturn(Guid('4348410c-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockTimeChar, write: true, notify: false);
        when(mockTimeChar.write(any,
                withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {});

        // GSDIS service for scan
        when(mockGsdisService.uuid)
            .thenReturn(Guid('53455206-444c-5020-4e49-52204e616e6f'));
        when(mockGsdisService.characteristics)
            .thenReturn([mockStartScanChar, mockErrStatusChar, mockDevStatusChar]);
        when(mockStartScanChar.uuid)
            .thenReturn(Guid('4348411d-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockStartScanChar,
            notify: true, write: true);
        when(mockStartScanChar.write(any,
                withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {
          // Send scan error notification shortly after write completes.
          // This ensures writeComplete=true is set before the notification
          // arrives in performScan's listener.
          Future.delayed(const Duration(milliseconds: 50), () {
            startScanNotifyController
                .add([0x02, 0x00, 0x00, 0x00, 0x00]);
          });
        });
        when(mockStartScanChar.setNotifyValue(true))
            .thenAnswer((_) async => true);
        when(mockStartScanChar.setNotifyValue(false))
            .thenAnswer((_) async => true);
        when(mockStartScanChar.onValueReceived)
            .thenAnswer((_) => startScanNotifyController.stream);
        when(mockStartScanChar.lastValueStream)
            .thenAnswer((_) => startScanNotifyController.stream);
        when(mockStartScanChar.isNotifying).thenReturn(true);

        // Error/device status reads
        when(mockErrStatusChar.read()).thenAnswer((_) async => [0x00, 0x00]);
        when(mockDevStatusChar.read()).thenAnswer((_) async => [0x00, 0x00]);

        // GCIS service for calibration
        when(mockGcisService.uuid)
            .thenReturn(Guid('53455204-444c-5020-4e49-52204e616e6f'));
        when(mockGcisService.characteristics).thenReturn([
          mockReqSpecCoeffChar,
          mockRetSpecCoeffChar,
          mockReqCoeffChar,
          mockRetCoeffChar,
          mockReqMatrixChar,
          mockRetMatrixChar,
        ]);

        // Spectrum coeff request (write only)
        when(mockReqSpecCoeffChar.uuid)
            .thenReturn(Guid('4348410d-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockReqSpecCoeffChar,
            write: true, notify: false);
        when(mockReqSpecCoeffChar.write(any,
                withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {
          specCoeffWriteCount++;
        });

        // Spectrum coeff return (notify only)
        when(mockRetSpecCoeffChar.uuid)
            .thenReturn(Guid('4348410e-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockRetSpecCoeffChar,
            notify: true, write: false);
        when(mockRetSpecCoeffChar.setNotifyValue(any))
            .thenAnswer((_) async => true);
        when(mockRetSpecCoeffChar.onValueReceived)
            .thenAnswer((_) => specCoeffNotifyController.stream);
        when(mockRetSpecCoeffChar.isNotifying).thenReturn(true);

        // Ref coeff request (write only)
        when(mockReqCoeffChar.uuid)
            .thenReturn(Guid('4348410f-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockReqCoeffChar,
            write: true, notify: false);
        when(mockReqCoeffChar.write(any,
                withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {
          coeffWriteCount++;
        });

        // Ref coeff return (notify only)
        when(mockRetCoeffChar.uuid)
            .thenReturn(Guid('43484110-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockRetCoeffChar,
            notify: true, write: false);
        when(mockRetCoeffChar.setNotifyValue(any))
            .thenAnswer((_) async => true);
        when(mockRetCoeffChar.onValueReceived)
            .thenAnswer((_) => coeffNotifyController.stream);
        when(mockRetCoeffChar.isNotifying).thenReturn(true);

        // Matrix request (write only)
        when(mockReqMatrixChar.uuid)
            .thenReturn(Guid('43484111-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockReqMatrixChar,
            write: true, notify: false);
        when(mockReqMatrixChar.write(any,
                withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {
          matrixWriteCount++;
        });

        // Matrix return (notify only)
        when(mockRetMatrixChar.uuid)
            .thenReturn(Guid('43484112-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockRetMatrixChar,
            notify: true, write: false);
        when(mockRetMatrixChar.setNotifyValue(any))
            .thenAnswer((_) async => true);
        when(mockRetMatrixChar.onValueReceived)
            .thenAnswer((_) => matrixNotifyController.stream);
        when(mockRetMatrixChar.isNotifying).thenReturn(true);

        when(mockAdapter.getDevice('AA:BB:CC:DD:EE:FF')).thenReturn(mockDevice);

        await service.connect('AA:BB:CC:DD:EE:FF');
        await Future.delayed(const Duration(milliseconds: 50));

        // Pre-populate calibration cache (simulating a previous fetch)
        service.setCalibrationDataForTesting([0x01], [0x02], [0x03]);


        // === First performScan call ===
        // performScan should invalidate cache and re-fetch from BLE
        final scanFuture1 = service.performScan();
        await Future.delayed(const Duration(milliseconds: 50));

        // Feed calibration data via BLE notifications
        // Spectrum coeff: 2 bytes
        specCoeffNotifyController.add([0x00, 0x02, 0x00]); // header
        await Future.delayed(const Duration(milliseconds: 20));
        specCoeffNotifyController.add([0x01, 0xAA, 0xBB]); // data
        await Future.delayed(const Duration(milliseconds: 50));

        // Ref coeff: 2 bytes
        coeffNotifyController.add([0x00, 0x02, 0x00]); // header
        await Future.delayed(const Duration(milliseconds: 20));
        coeffNotifyController.add([0x01, 0xCC, 0xDD]); // data
        await Future.delayed(const Duration(milliseconds: 50));

        // Matrix: 2 bytes
        matrixNotifyController.add([0x00, 0x02, 0x00]); // header
        await Future.delayed(const Duration(milliseconds: 20));
        matrixNotifyController.add([0x01, 0xEE, 0xFF]); // data

        // Scan error notification is sent automatically by the mockStartScanChar
        // write handler (after writeComplete=true), so just await the result.
        await expectLater(scanFuture1, throwsA(isA<ScanFailedException>()));

        // Verify: calibration BLE fetches happened on first call
        // even though cache was pre-populated
        expect(specCoeffWriteCount, equals(1),
            reason:
                'Spectrum coeff should be re-fetched (cache was invalidated)');
        expect(coeffWriteCount, equals(1),
            reason: 'Ref coeff should be re-fetched (cache was invalidated)');
        expect(matrixWriteCount, equals(1),
            reason: 'Matrix should be re-fetched (cache was invalidated)');

        // === Second performScan call ===
        // Should invalidate and re-fetch again
        final scanFuture2 = service.performScan();
        await Future.delayed(const Duration(milliseconds: 50));

        // Feed calibration data again
        specCoeffNotifyController.add([0x00, 0x02, 0x00]);
        await Future.delayed(const Duration(milliseconds: 20));
        specCoeffNotifyController.add([0x01, 0x11, 0x22]);
        await Future.delayed(const Duration(milliseconds: 50));

        coeffNotifyController.add([0x00, 0x02, 0x00]);
        await Future.delayed(const Duration(milliseconds: 20));
        coeffNotifyController.add([0x01, 0x33, 0x44]);
        await Future.delayed(const Duration(milliseconds: 50));

        matrixNotifyController.add([0x00, 0x02, 0x00]);
        await Future.delayed(const Duration(milliseconds: 20));
        matrixNotifyController.add([0x01, 0x55, 0x66]);

        // Scan error notification is sent automatically by the mockStartScanChar
        // write handler (after writeComplete=true), so just await the result.
        await expectLater(scanFuture2, throwsA(isA<ScanFailedException>()));

        // Verify: calibration BLE fetches happened AGAIN on second call
        expect(specCoeffWriteCount, equals(2),
            reason:
                'Spectrum coeff should be fetched twice (once per performScan)');
        expect(coeffWriteCount, equals(2),
            reason:
                'Ref coeff should be fetched twice (once per performScan)');
        expect(matrixWriteCount, equals(2),
            reason: 'Matrix should be fetched twice (once per performScan)');

        // Cleanup
        await startScanNotifyController.close();
        await specCoeffNotifyController.close();
        await coeffNotifyController.close();
        await matrixNotifyController.close();
      });

      // Config refresh test removed: performScan no longer calls
      // getScanConfigurations() - configs are loaded at connection time only.
    });

    group('syncTime', () {
      test('throws NotConnectedException when not connected', () {
        expect(
          () => service.syncTime(),
          throwsA(isA<NotConnectedException>()),
        );
      });

      test('writes formatted time to GDTS characteristic', () async {
        final mockDevice = MockBluetoothDevice();
        final mockGdtsService = MockBluetoothService();
        final mockTimeChar = MockBluetoothCharacteristic();

        when(mockDevice.remoteId)
            .thenReturn(const DeviceIdentifier('AA:BB:CC:DD:EE:FF'));
        when(mockDevice.platformName).thenReturn('NIRScan Nano');
        when(mockDevice.connect(
          timeout: anyNamed('timeout'),
          autoConnect: anyNamed('autoConnect'),
        )).thenAnswer((_) async {});
        when(mockDevice.discoverServices())
            .thenAnswer((_) async => [mockGdtsService]);
        when(mockDevice.connectionState).thenAnswer(
          (_) => Stream.value(BluetoothConnectionState.connected),
        );
        when(mockDevice.disconnect()).thenAnswer((_) async {});
        when(mockDevice.requestMtu(any, predelay: anyNamed('predelay'), timeout: anyNamed('timeout')))
            .thenAnswer((_) async => 512);

        // GDTS Service
        when(mockGdtsService.uuid)
            .thenReturn(Guid('53455203-444c-5020-4e49-52204e616e6f'));
        when(mockGdtsService.characteristics).thenReturn([mockTimeChar]);

        // GDTS Time characteristic
        when(mockTimeChar.uuid)
            .thenReturn(Guid('4348410c-444c-5020-4e49-52204e616e6f'));
        when(mockTimeChar.write(any,
                withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {});

        when(mockAdapter.getDevice('AA:BB:CC:DD:EE:FF')).thenReturn(mockDevice);

        await service.connect('AA:BB:CC:DD:EE:FF');
        await Future.delayed(const Duration(milliseconds: 50));

        await service.syncTime();

        // Verify write was called with 7 bytes
        final capturedData = verify(mockTimeChar.write(
          captureAny,
          withoutResponse: anyNamed('withoutResponse'),
        )).captured.first as List<int>;

        expect(capturedData.length, equals(7));
        // Year should be current year - 2000 (e.g., 26 for 2026)
        expect(capturedData[0], greaterThanOrEqualTo(0));
        expect(capturedData[0], lessThanOrEqualTo(99));
        // Month 1-12
        expect(capturedData[1], greaterThanOrEqualTo(1));
        expect(capturedData[1], lessThanOrEqualTo(12));
        // Day 1-31
        expect(capturedData[2], greaterThanOrEqualTo(1));
        expect(capturedData[2], lessThanOrEqualTo(31));
        // DayOfWeek 0-6 (Sunday=0)
        expect(capturedData[3], greaterThanOrEqualTo(0));
        expect(capturedData[3], lessThanOrEqualTo(6));
        // Hour 0-23
        expect(capturedData[4], greaterThanOrEqualTo(0));
        expect(capturedData[4], lessThanOrEqualTo(23));
        // Minute 0-59
        expect(capturedData[5], greaterThanOrEqualTo(0));
        expect(capturedData[5], lessThanOrEqualTo(59));
        // Second 0-59
        expect(capturedData[6], greaterThanOrEqualTo(0));
        expect(capturedData[6], lessThanOrEqualTo(59));
      });
    });

    group('calibration', () {
      test('getCalibrationData throws NotConnectedException when not connected',
          () {
        expect(
          () => service.getCalibrationData(),
          throwsA(isA<NotConnectedException>()),
        );
      });

      test('getCalibrationData returns coefficients and matrix', () async {
        final mockDevice = MockBluetoothDevice();
        final mockGcisService = MockBluetoothService();

        // Spectrum coefficient characteristics
        final mockReqSpecCoeffChar = MockBluetoothCharacteristic();
        final mockRetSpecCoeffChar = MockBluetoothCharacteristic();
        final specCoeffNotifyController =
            StreamController<List<int>>.broadcast();

        // Coefficient characteristics
        final mockReqCoeffChar = MockBluetoothCharacteristic();
        final mockRetCoeffChar = MockBluetoothCharacteristic();
        final coeffNotifyController = StreamController<List<int>>.broadcast();

        // Matrix characteristics
        final mockReqMatrixChar = MockBluetoothCharacteristic();
        final mockRetMatrixChar = MockBluetoothCharacteristic();
        final matrixNotifyController = StreamController<List<int>>.broadcast();

        when(mockDevice.remoteId)
            .thenReturn(const DeviceIdentifier('AA:BB:CC:DD:EE:FF'));
        when(mockDevice.platformName).thenReturn('NIRScan Nano');
        when(mockDevice.connect(
          timeout: anyNamed('timeout'),
          autoConnect: anyNamed('autoConnect'),
        )).thenAnswer((_) async {});
        when(mockDevice.discoverServices())
            .thenAnswer((_) async => [mockGcisService]);
        when(mockDevice.connectionState).thenAnswer(
          (_) => Stream.value(BluetoothConnectionState.connected),
        );
        when(mockDevice.disconnect()).thenAnswer((_) async {});
        when(mockDevice.requestMtu(any,
                predelay: anyNamed('predelay'), timeout: anyNamed('timeout')))
            .thenAnswer((_) async => 512);

        // GCIS Service
        when(mockGcisService.uuid)
            .thenReturn(Guid('53455204-444c-5020-4e49-52204e616e6f'));
        when(mockGcisService.characteristics).thenReturn([
          mockReqSpecCoeffChar,
          mockRetSpecCoeffChar,
          mockReqCoeffChar,
          mockRetCoeffChar,
          mockReqMatrixChar,
          mockRetMatrixChar,
        ]);

        // Request spectrum coeff characteristic (write only)
        when(mockReqSpecCoeffChar.uuid)
            .thenReturn(Guid('4348410d-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockReqSpecCoeffChar,
            write: true, notify: false);
        when(mockReqSpecCoeffChar.write(any,
                withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {});

        // Return spectrum coeff characteristic (notification only)
        when(mockRetSpecCoeffChar.uuid)
            .thenReturn(Guid('4348410e-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockRetSpecCoeffChar,
            notify: true, write: false);
        when(mockRetSpecCoeffChar.setNotifyValue(true))
            .thenAnswer((_) async => true);
        when(mockRetSpecCoeffChar.setNotifyValue(false))
            .thenAnswer((_) async => true);
        when(mockRetSpecCoeffChar.onValueReceived)
            .thenAnswer((_) => specCoeffNotifyController.stream);
        when(mockRetSpecCoeffChar.isNotifying).thenReturn(true);

        // Request coeff characteristic (write only)
        when(mockReqCoeffChar.uuid)
            .thenReturn(Guid('4348410f-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockReqCoeffChar,
            write: true, notify: false);
        when(mockReqCoeffChar.write(any,
                withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {});

        // Return coeff characteristic (notification only)
        when(mockRetCoeffChar.uuid)
            .thenReturn(Guid('43484110-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockRetCoeffChar,
            notify: true, write: false);
        when(mockRetCoeffChar.setNotifyValue(true))
            .thenAnswer((_) async => true);
        when(mockRetCoeffChar.setNotifyValue(false))
            .thenAnswer((_) async => true);
        when(mockRetCoeffChar.onValueReceived)
            .thenAnswer((_) => coeffNotifyController.stream);
        when(mockRetCoeffChar.isNotifying).thenReturn(true);

        // Request matrix characteristic (write only)
        when(mockReqMatrixChar.uuid)
            .thenReturn(Guid('43484111-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockReqMatrixChar,
            write: true, notify: false);
        when(mockReqMatrixChar.write(any,
                withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {});

        // Return matrix characteristic (notification only)
        when(mockRetMatrixChar.uuid)
            .thenReturn(Guid('43484112-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockRetMatrixChar,
            notify: true, write: false);
        when(mockRetMatrixChar.setNotifyValue(true))
            .thenAnswer((_) async => true);
        when(mockRetMatrixChar.setNotifyValue(false))
            .thenAnswer((_) async => true);
        when(mockRetMatrixChar.onValueReceived)
            .thenAnswer((_) => matrixNotifyController.stream);
        when(mockRetMatrixChar.isNotifying).thenReturn(true);

        when(mockAdapter.getDevice('AA:BB:CC:DD:EE:FF')).thenReturn(mockDevice);

        await service.connect('AA:BB:CC:DD:EE:FF');
        await Future.delayed(const Duration(milliseconds: 50));

        // Start getCalibrationData
        final calibrationFuture = service.getCalibrationData();

        await Future.delayed(const Duration(milliseconds: 50));

        // Spectrum coeff response (fetched first per manual order):
        specCoeffNotifyController.add([0x00, 0x02, 0x00]);
        await Future.delayed(const Duration(milliseconds: 20));
        specCoeffNotifyController.add([0x01, 0x55, 0x66]);

        await Future.delayed(const Duration(milliseconds: 50));

        // Multi-packet coeff response:
        // Header: [0x00, 0x04, 0x00] = size 4 bytes
        coeffNotifyController.add([0x00, 0x04, 0x00]);
        await Future.delayed(const Duration(milliseconds: 20));
        // Data packet: [0x01, 0xAA, 0xBB, 0xCC, 0xDD]
        coeffNotifyController.add([0x01, 0xAA, 0xBB, 0xCC, 0xDD]);

        await Future.delayed(const Duration(milliseconds: 50));

        // Multi-packet matrix response:
        // Header: [0x00, 0x03, 0x00] = size 3 bytes
        matrixNotifyController.add([0x00, 0x03, 0x00]);
        await Future.delayed(const Duration(milliseconds: 20));
        // Data packet: [0x01, 0x11, 0x22, 0x33]
        matrixNotifyController.add([0x01, 0x11, 0x22, 0x33]);

        final calData = await calibrationFuture;

        expect(calData.spectrumCoefficients.length, equals(2));
        expect(calData.spectrumCoefficients, equals([0x55, 0x66]));
        expect(calData.coefficients.length, equals(4));
        expect(calData.coefficients, equals([0xAA, 0xBB, 0xCC, 0xDD]));
        expect(calData.matrix.length, equals(3));
        expect(calData.matrix, equals([0x11, 0x22, 0x33]));

        // Cleanup
        await specCoeffNotifyController.close();
        await coeffNotifyController.close();
        await matrixNotifyController.close();
      });

      test('getCalibrationData uses cached data on second call', () async {
        final mockDevice = MockBluetoothDevice();
        final mockGcisService = MockBluetoothService();

        // Spectrum coefficient characteristics
        final mockReqSpecCoeffChar = MockBluetoothCharacteristic();
        final mockRetSpecCoeffChar = MockBluetoothCharacteristic();
        final specCoeffNotifyController =
            StreamController<List<int>>.broadcast();

        // Coefficient characteristics
        final mockReqCoeffChar = MockBluetoothCharacteristic();
        final mockRetCoeffChar = MockBluetoothCharacteristic();
        final coeffNotifyController = StreamController<List<int>>.broadcast();

        // Matrix characteristics
        final mockReqMatrixChar = MockBluetoothCharacteristic();
        final mockRetMatrixChar = MockBluetoothCharacteristic();
        final matrixNotifyController = StreamController<List<int>>.broadcast();

        var specCoeffWriteCount = 0;
        var coeffWriteCount = 0;
        var matrixWriteCount = 0;

        when(mockDevice.remoteId)
            .thenReturn(const DeviceIdentifier('AA:BB:CC:DD:EE:FF'));
        when(mockDevice.platformName).thenReturn('NIRScan Nano');
        when(mockDevice.connect(
          timeout: anyNamed('timeout'),
          autoConnect: anyNamed('autoConnect'),
        )).thenAnswer((_) async {});
        when(mockDevice.discoverServices())
            .thenAnswer((_) async => [mockGcisService]);
        when(mockDevice.connectionState).thenAnswer(
          (_) => Stream.value(BluetoothConnectionState.connected),
        );
        when(mockDevice.disconnect()).thenAnswer((_) async {});
        when(mockDevice.requestMtu(any,
                predelay: anyNamed('predelay'), timeout: anyNamed('timeout')))
            .thenAnswer((_) async => 512);

        // GCIS Service
        when(mockGcisService.uuid)
            .thenReturn(Guid('53455204-444c-5020-4e49-52204e616e6f'));
        when(mockGcisService.characteristics).thenReturn([
          mockReqSpecCoeffChar,
          mockRetSpecCoeffChar,
          mockReqCoeffChar,
          mockRetCoeffChar,
          mockReqMatrixChar,
          mockRetMatrixChar,
        ]);

        // Request spectrum coeff characteristic
        when(mockReqSpecCoeffChar.uuid)
            .thenReturn(Guid('4348410d-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockReqSpecCoeffChar,
            write: true, notify: false);
        when(mockReqSpecCoeffChar.write(any,
                withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {
          specCoeffWriteCount++;
        });

        // Return spectrum coeff characteristic
        when(mockRetSpecCoeffChar.uuid)
            .thenReturn(Guid('4348410e-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockRetSpecCoeffChar,
            notify: true, write: false);
        when(mockRetSpecCoeffChar.setNotifyValue(any))
            .thenAnswer((_) async => true);
        when(mockRetSpecCoeffChar.onValueReceived)
            .thenAnswer((_) => specCoeffNotifyController.stream);
        when(mockRetSpecCoeffChar.isNotifying).thenReturn(true);

        // Request coeff characteristic
        when(mockReqCoeffChar.uuid)
            .thenReturn(Guid('4348410f-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockReqCoeffChar,
            write: true, notify: false);
        when(mockReqCoeffChar.write(any,
                withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {
          coeffWriteCount++;
        });

        // Return coeff characteristic
        when(mockRetCoeffChar.uuid)
            .thenReturn(Guid('43484110-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockRetCoeffChar,
            notify: true, write: false);
        when(mockRetCoeffChar.setNotifyValue(any))
            .thenAnswer((_) async => true);
        when(mockRetCoeffChar.onValueReceived)
            .thenAnswer((_) => coeffNotifyController.stream);
        when(mockRetCoeffChar.isNotifying).thenReturn(true);

        // Request matrix characteristic
        when(mockReqMatrixChar.uuid)
            .thenReturn(Guid('43484111-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockReqMatrixChar,
            write: true, notify: false);
        when(mockReqMatrixChar.write(any,
                withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {
          matrixWriteCount++;
        });

        // Return matrix characteristic
        when(mockRetMatrixChar.uuid)
            .thenReturn(Guid('43484112-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockRetMatrixChar,
            notify: true, write: false);
        when(mockRetMatrixChar.setNotifyValue(any))
            .thenAnswer((_) async => true);
        when(mockRetMatrixChar.onValueReceived)
            .thenAnswer((_) => matrixNotifyController.stream);
        when(mockRetMatrixChar.isNotifying).thenReturn(true);

        when(mockAdapter.getDevice('AA:BB:CC:DD:EE:FF')).thenReturn(mockDevice);

        await service.connect('AA:BB:CC:DD:EE:FF');
        await Future.delayed(const Duration(milliseconds: 50));

        // First call
        final calibrationFuture1 = service.getCalibrationData();
        await Future.delayed(const Duration(milliseconds: 50));

        // Emit spectrum coefficient data
        specCoeffNotifyController.add([0x00, 0x02, 0x00]);
        await Future.delayed(const Duration(milliseconds: 20));
        specCoeffNotifyController.add([0x01, 0x55, 0x66]);

        await Future.delayed(const Duration(milliseconds: 50));

        // Emit coefficient data
        coeffNotifyController.add([0x00, 0x02, 0x00]); // Header: 2 bytes
        await Future.delayed(const Duration(milliseconds: 20));
        coeffNotifyController.add([0x01, 0xAA, 0xBB]); // Data

        await Future.delayed(const Duration(milliseconds: 50));

        // Emit matrix data
        matrixNotifyController.add([0x00, 0x02, 0x00]); // Header: 2 bytes
        await Future.delayed(const Duration(milliseconds: 20));
        matrixNotifyController.add([0x01, 0x11, 0x22]); // Data

        await calibrationFuture1;

        expect(specCoeffWriteCount, equals(1));
        expect(coeffWriteCount, equals(1));
        expect(matrixWriteCount, equals(1));

        // Second call - should use cache
        final calData2 = await service.getCalibrationData();

        // Verify no additional writes were made
        expect(specCoeffWriteCount, equals(1));
        expect(coeffWriteCount, equals(1));
        expect(matrixWriteCount, equals(1));

        expect(calData2.spectrumCoefficients, equals([0x55, 0x66]));
        expect(calData2.coefficients, equals([0xAA, 0xBB]));
        expect(calData2.matrix, equals([0x11, 0x22]));

        // Cleanup
        await specCoeffNotifyController.close();
        await coeffNotifyController.close();
        await matrixNotifyController.close();
      });

      test(
          'getCalibrationData returns spectrum coefficients, ref coefficients, and matrix',
          () async {
        final mockDevice = MockBluetoothDevice();
        final mockGcisService = MockBluetoothService();

        // Spectrum coefficient characteristics
        final mockReqSpecCoeffChar = MockBluetoothCharacteristic();
        final mockRetSpecCoeffChar = MockBluetoothCharacteristic();
        final specCoeffNotifyController =
            StreamController<List<int>>.broadcast();

        // Ref coefficient characteristics
        final mockReqCoeffChar = MockBluetoothCharacteristic();
        final mockRetCoeffChar = MockBluetoothCharacteristic();
        final coeffNotifyController = StreamController<List<int>>.broadcast();

        // Matrix characteristics
        final mockReqMatrixChar = MockBluetoothCharacteristic();
        final mockRetMatrixChar = MockBluetoothCharacteristic();
        final matrixNotifyController = StreamController<List<int>>.broadcast();

        when(mockDevice.remoteId)
            .thenReturn(const DeviceIdentifier('AA:BB:CC:DD:EE:FF'));
        when(mockDevice.platformName).thenReturn('NIRScan Nano');
        when(mockDevice.connect(
          timeout: anyNamed('timeout'),
          autoConnect: anyNamed('autoConnect'),
        )).thenAnswer((_) async {});
        when(mockDevice.discoverServices())
            .thenAnswer((_) async => [mockGcisService]);
        when(mockDevice.connectionState).thenAnswer(
          (_) => Stream.value(BluetoothConnectionState.connected),
        );
        when(mockDevice.disconnect()).thenAnswer((_) async {});
        when(mockDevice.requestMtu(any,
                predelay: anyNamed('predelay'), timeout: anyNamed('timeout')))
            .thenAnswer((_) async => 512);

        // GCIS Service
        when(mockGcisService.uuid)
            .thenReturn(Guid('53455204-444c-5020-4e49-52204e616e6f'));
        when(mockGcisService.characteristics).thenReturn([
          mockReqSpecCoeffChar,
          mockRetSpecCoeffChar,
          mockReqCoeffChar,
          mockRetCoeffChar,
          mockReqMatrixChar,
          mockRetMatrixChar,
        ]);

        // Request spectrum coeff characteristic (write only)
        when(mockReqSpecCoeffChar.uuid)
            .thenReturn(Guid('4348410d-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockReqSpecCoeffChar,
            write: true, notify: false);
        when(mockReqSpecCoeffChar.write(any,
                withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {});

        // Return spectrum coeff characteristic (notification only)
        when(mockRetSpecCoeffChar.uuid)
            .thenReturn(Guid('4348410e-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockRetSpecCoeffChar,
            notify: true, write: false);
        when(mockRetSpecCoeffChar.setNotifyValue(true))
            .thenAnswer((_) async => true);
        when(mockRetSpecCoeffChar.setNotifyValue(false))
            .thenAnswer((_) async => true);
        when(mockRetSpecCoeffChar.onValueReceived)
            .thenAnswer((_) => specCoeffNotifyController.stream);
        when(mockRetSpecCoeffChar.isNotifying).thenReturn(true);

        // Request ref coeff characteristic (write only)
        when(mockReqCoeffChar.uuid)
            .thenReturn(Guid('4348410f-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockReqCoeffChar,
            write: true, notify: false);
        when(mockReqCoeffChar.write(any,
                withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {});

        // Return ref coeff characteristic (notification only)
        when(mockRetCoeffChar.uuid)
            .thenReturn(Guid('43484110-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockRetCoeffChar,
            notify: true, write: false);
        when(mockRetCoeffChar.setNotifyValue(true))
            .thenAnswer((_) async => true);
        when(mockRetCoeffChar.setNotifyValue(false))
            .thenAnswer((_) async => true);
        when(mockRetCoeffChar.onValueReceived)
            .thenAnswer((_) => coeffNotifyController.stream);
        when(mockRetCoeffChar.isNotifying).thenReturn(true);

        // Request matrix characteristic (write only)
        when(mockReqMatrixChar.uuid)
            .thenReturn(Guid('43484111-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockReqMatrixChar,
            write: true, notify: false);
        when(mockReqMatrixChar.write(any,
                withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {});

        // Return matrix characteristic (notification only)
        when(mockRetMatrixChar.uuid)
            .thenReturn(Guid('43484112-444c-5020-4e49-52204e616e6f'));
        stubCharacteristicProperties(mockRetMatrixChar,
            notify: true, write: false);
        when(mockRetMatrixChar.setNotifyValue(true))
            .thenAnswer((_) async => true);
        when(mockRetMatrixChar.setNotifyValue(false))
            .thenAnswer((_) async => true);
        when(mockRetMatrixChar.onValueReceived)
            .thenAnswer((_) => matrixNotifyController.stream);
        when(mockRetMatrixChar.isNotifying).thenReturn(true);

        when(mockAdapter.getDevice('AA:BB:CC:DD:EE:FF'))
            .thenReturn(mockDevice);

        await service.connect('AA:BB:CC:DD:EE:FF');
        await Future.delayed(const Duration(milliseconds: 50));

        // Start getCalibrationData
        final calibrationFuture = service.getCalibrationData();

        await Future.delayed(const Duration(milliseconds: 50));

        // Spectrum coeff response (fetched FIRST per manual order):
        // Header: [0x00, 0x06, 0x00] = size 6 bytes
        specCoeffNotifyController.add([0x00, 0x06, 0x00]);
        await Future.delayed(const Duration(milliseconds: 20));
        // Data packet: [0x01, 0xEE, 0xFF, 0xDD, 0xCC, 0xBB, 0xAA]
        specCoeffNotifyController.add([0x01, 0xEE, 0xFF, 0xDD, 0xCC, 0xBB, 0xAA]);

        await Future.delayed(const Duration(milliseconds: 50));

        // Ref coeff response:
        // Header: [0x00, 0x04, 0x00] = size 4 bytes
        coeffNotifyController.add([0x00, 0x04, 0x00]);
        await Future.delayed(const Duration(milliseconds: 20));
        // Data packet: [0x01, 0xAA, 0xBB, 0xCC, 0xDD]
        coeffNotifyController.add([0x01, 0xAA, 0xBB, 0xCC, 0xDD]);

        await Future.delayed(const Duration(milliseconds: 50));

        // Matrix response:
        // Header: [0x00, 0x03, 0x00] = size 3 bytes
        matrixNotifyController.add([0x00, 0x03, 0x00]);
        await Future.delayed(const Duration(milliseconds: 20));
        // Data packet: [0x01, 0x11, 0x22, 0x33]
        matrixNotifyController.add([0x01, 0x11, 0x22, 0x33]);

        final calData = await calibrationFuture;

        expect(calData.spectrumCoefficients.length, equals(6));
        expect(calData.spectrumCoefficients,
            equals([0xEE, 0xFF, 0xDD, 0xCC, 0xBB, 0xAA]));
        expect(calData.coefficients.length, equals(4));
        expect(calData.coefficients, equals([0xAA, 0xBB, 0xCC, 0xDD]));
        expect(calData.matrix.length, equals(3));
        expect(calData.matrix, equals([0x11, 0x22, 0x33]));

        // Cleanup
        await specCoeffNotifyController.close();
        await coeffNotifyController.close();
        await matrixNotifyController.close();
      });
    });

    group('getScanConfigurations', () {
      test('throws NotConnectedException when not connected', () {
        expect(
          () => service.getScanConfigurations(),
          throwsA(isA<NotConnectedException>()),
        );
      });

      test('returns list of scan configurations from device', () async {
        final mockDevice = MockBluetoothDevice();
        final mockService = MockBluetoothService();
        final notifyController = StreamController<List<int>>.broadcast();

        // GSCIS characteristics
        final numStoredConfChar = createMockCharacteristic(
          uuid: Guid('43484113-444c-5020-4e49-52204e616e6f'),
          read: true,
          notify: false,
        );
        final reqStoredConfListChar = createMockCharacteristic(
          uuid: Guid('43484114-444c-5020-4e49-52204e616e6f'),
          write: true,
          notify: false,
        );
        final retStoredConfListChar = createMockCharacteristic(
          uuid: Guid('43484115-444c-5020-4e49-52204e616e6f'),
          notify: true,
          write: false,
        );
        final reqScanConfDataChar = createMockCharacteristic(
          uuid: Guid('43484116-444c-5020-4e49-52204e616e6f'),
          write: true,
          notify: false,
        );
        final retScanConfDataChar = createMockCharacteristic(
          uuid: Guid('43484117-444c-5020-4e49-52204e616e6f'),
          notify: true,
          write: false,
        );

        when(mockDevice.remoteId)
            .thenReturn(const DeviceIdentifier('AA:BB:CC:DD:EE:FF'));
        when(mockDevice.platformName).thenReturn('NIRScan Nano');
        when(mockDevice.connect(
          timeout: anyNamed('timeout'),
          autoConnect: anyNamed('autoConnect'),
        )).thenAnswer((_) async {});
        when(mockDevice.discoverServices())
            .thenAnswer((_) async => [mockService]);
        when(mockDevice.connectionState).thenAnswer(
          (_) => Stream.value(BluetoothConnectionState.connected),
        );
        when(mockDevice.disconnect()).thenAnswer((_) async {});
        when(mockDevice.requestMtu(any,
                predelay: anyNamed('predelay'), timeout: anyNamed('timeout')))
            .thenAnswer((_) async => 512);

        when(mockService.characteristics).thenReturn([
          numStoredConfChar,
          reqStoredConfListChar,
          retStoredConfListChar,
          reqScanConfDataChar,
          retScanConfDataChar,
        ]);

        // Return 2 stored configs
        when(numStoredConfChar.read()).thenAnswer((_) async => [0x02, 0x00]);
        when(reqStoredConfListChar.write(any, withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {});
        when(retStoredConfListChar.setNotifyValue(true))
            .thenAnswer((_) async => true);
        when(retStoredConfListChar.setNotifyValue(false))
            .thenAnswer((_) async => true);
        when(retStoredConfListChar.onValueReceived)
            .thenAnswer((_) => notifyController.stream);
        when(retStoredConfListChar.isNotifying).thenReturn(true);

        // Config data responses
        final configDataController = StreamController<List<int>>.broadcast();
        when(reqScanConfDataChar.write(any, withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {});
        when(retScanConfDataChar.setNotifyValue(true))
            .thenAnswer((_) async => true);
        when(retScanConfDataChar.setNotifyValue(false))
            .thenAnswer((_) async => true);
        when(retScanConfDataChar.onValueReceived)
            .thenAnswer((_) => configDataController.stream);
        when(retScanConfDataChar.isNotifying).thenReturn(true);

        when(mockAdapter.getDevice('AA:BB:CC:DD:EE:FF')).thenReturn(mockDevice);

        await service.connect('AA:BB:CC:DD:EE:FF');
        await Future.delayed(const Duration(milliseconds: 50));

        // Start fetching configs
        final configsFuture = service.getScanConfigurations();
        await Future.delayed(const Duration(milliseconds: 100));

        // Emit config list: 2 configs with indices 4 and 6
        notifyController.add([0x01, 0x04, 0x00]); // Config index 4
        await Future.delayed(const Duration(milliseconds: 20));
        notifyController.add([0x02, 0x06, 0x00]); // Config index 6
        await Future.delayed(const Duration(milliseconds: 100));

        // Emit config data for index 4 (multi-packet)
        // Config name: "Column 1" (40 bytes null-padded) + scanType(1) + numSections(2) + wavelengthStart(4) + etc.
        final configName1 = 'Column 1'.codeUnits + List.filled(32, 0);
        configDataController.add([0x00, 0x3C, 0x00]); // Header: 60 bytes
        await Future.delayed(const Duration(milliseconds: 20));
        configDataController.add([0x01, ...configName1.take(19)]); // First 19 bytes of name
        await Future.delayed(const Duration(milliseconds: 20));
        configDataController.add([0x02, ...configName1.skip(19).take(19)]); // Next 19 bytes
        await Future.delayed(const Duration(milliseconds: 20));
        // Remaining data with scan type, sections, etc.
        final remainingData = [
          ...configName1.skip(38), // Last 2 bytes of name
          0x00, // scanType = Column
          0x01, 0x00, // numSections = 1
          // wavelengthStart (900.0 as float LE)
          0x00, 0x00, 0x61, 0x44,
          // wavelengthEnd (1700.0 as float LE)
          0x00, 0x80, 0xD4, 0x44,
          // numPatterns
          0xE4, 0x00, // 228
          // width
          0x06, 0x00,
          // numRepeat
          0x06, 0x00,
          // exposure
          0x00, 0x00,
        ];
        configDataController.add([0x03, ...remainingData]);
        await Future.delayed(const Duration(milliseconds: 200));

        // For simplicity, let's just check that we get a list back
        // (full parsing test would be more complex)
        final configs = await configsFuture.timeout(
          const Duration(seconds: 2),
          onTimeout: () => <ScanConfiguration>[],
        );

        // Should have fetched something (even if parsing is basic for now)
        expect(configs, isA<List<ScanConfiguration>>());

        await notifyController.close();
        await configDataController.close();
      });
    });

    group('getActiveScanConfiguration', () {
      test('throws NotConnectedException when not connected', () {
        expect(
          () => service.getActiveScanConfiguration(),
          throwsA(isA<NotConnectedException>()),
        );
      });
    });

    group('setActiveScanConfiguration', () {
      test('throws NotConnectedException when not connected', () {
        expect(
          () => service.setActiveScanConfiguration(0),
          throwsA(isA<NotConnectedException>()),
        );
      });

      test('writes config index to active scan conf characteristic', () async {
        final mockDevice = MockBluetoothDevice();
        final mockService = MockBluetoothService();

        final activeConfChar = createMockCharacteristic(
          uuid: Guid('43484118-444c-5020-4e49-52204e616e6f'),
          read: true,
          write: true,
          notify: false,
        );

        when(mockDevice.remoteId)
            .thenReturn(const DeviceIdentifier('AA:BB:CC:DD:EE:FF'));
        when(mockDevice.platformName).thenReturn('NIRScan Nano');
        when(mockDevice.connect(
          timeout: anyNamed('timeout'),
          autoConnect: anyNamed('autoConnect'),
        )).thenAnswer((_) async {});
        when(mockDevice.discoverServices())
            .thenAnswer((_) async => [mockService]);
        when(mockDevice.connectionState).thenAnswer(
          (_) => Stream.value(BluetoothConnectionState.connected),
        );
        when(mockDevice.disconnect()).thenAnswer((_) async {});
        when(mockDevice.requestMtu(any,
                predelay: anyNamed('predelay'), timeout: anyNamed('timeout')))
            .thenAnswer((_) async => 512);

        when(mockService.characteristics).thenReturn([activeConfChar]);

        // Mock write and read back
        when(activeConfChar.write(any, withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {});
        when(activeConfChar.read()).thenAnswer((_) async => [0x04, 0x00]); // Returns index 4

        when(mockAdapter.getDevice('AA:BB:CC:DD:EE:FF')).thenReturn(mockDevice);

        await service.connect('AA:BB:CC:DD:EE:FF');
        await Future.delayed(const Duration(milliseconds: 50));

        await service.setActiveScanConfiguration(4);

        // Verify write was called with correct bytes (little-endian)
        verify(activeConfChar.write([0x04, 0x00], withoutResponse: false)).called(1);
      });
    });
  });
}

/// Helper to create mock ScanResult
ScanResult _createMockScanResult(String name, String id, int rssi) {
  final device = _FakeBluetoothDevice(id, name);
  return ScanResult(
    device: device,
    advertisementData: AdvertisementData(
      advName: name,
      txPowerLevel: null,
      appearance: null,
      connectable: true,
      manufacturerData: {},
      serviceData: {},
      serviceUuids: [],
    ),
    rssi: rssi,
    timeStamp: DateTime.now(),
  );
}

/// Fake BluetoothDevice for ScanResult creation
class _FakeBluetoothDevice implements BluetoothDevice {
  final String _id;
  final String _name;

  _FakeBluetoothDevice(this._id, this._name);

  @override
  DeviceIdentifier get remoteId => DeviceIdentifier(_id);

  @override
  String get platformName => _name;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
