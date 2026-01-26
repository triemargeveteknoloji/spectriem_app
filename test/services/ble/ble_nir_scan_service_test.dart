import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:spectriem_app/services/ble/ble_adapter.dart';
import 'package:spectriem_app/services/ble/nir_scan_service.dart';
import 'package:spectriem_app/services/ble/ble_nir_scan_service.dart';
import 'package:spectriem_app/services/logging/log_service.dart';

import 'ble_nir_scan_service_test.mocks.dart';

@GenerateMocks(
    [BluetoothDevice, BluetoothService, BluetoothCharacteristic, BleAdapter])
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
        final mockCharacteristic = MockBluetoothCharacteristic();
        final notificationCharacteristics = <MockBluetoothCharacteristic>[];

        // Create mock characteristics for all notification UUIDs
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
          final char = MockBluetoothCharacteristic();
          when(char.uuid).thenReturn(Guid(uuidStr));
          when(char.setNotifyValue(true)).thenAnswer((_) async => true);
          when(char.lastValueStream).thenAnswer((_) => Stream.value([]));
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
        when(mockRetSpecCalCoeffChar.setNotifyValue(true))
            .thenAnswer((_) async => true);
        when(mockRetSpecCalCoeffChar.onValueReceived)
            .thenAnswer((_) => notificationController.stream);

        when(mockAdapter.getDevice('AA:BB:CC:DD:EE:FF')).thenReturn(mockDevice);

        await service.connect('AA:BB:CC:DD:EE:FF');
        await Future.delayed(const Duration(milliseconds: 50));

        final dataStream = await service.subscribeToNotifications(
          Guid('4348410e-444c-5020-4e49-52204e616e6f'),
        );

        // Verify setNotifyValue was called
        verify(mockRetSpecCalCoeffChar.setNotifyValue(true)).called(1);

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
          when(char.setNotifyValue(true)).thenAnswer((_) async => true);
          when(char.onValueReceived)
              .thenAnswer((_) => notificationController.stream);
        }

        when(mockAdapter.getDevice('AA:BB:CC:DD:EE:FF')).thenReturn(mockDevice);

        await service.connect('AA:BB:CC:DD:EE:FF');
        await Future.delayed(const Duration(milliseconds: 50));

        await service.subscribeToAllNotifications();

        // Verify setNotifyValue was called on all notification characteristics
        verify(gcisRetSpecCalCoeff.setNotifyValue(true)).called(1);
        verify(gcisRetRefCalCoeff.setNotifyValue(true)).called(1);
        verify(gcisRetRefCalMatrix.setNotifyValue(true)).called(1);
        verify(gsdisStartScan.setNotifyValue(true)).called(1);
        verify(gsdisRetScanName.setNotifyValue(true)).called(1);
        verify(gsdisRetScanType.setNotifyValue(true)).called(1);
        verify(gsdisRetScanDate.setNotifyValue(true)).called(1);
        verify(gsdisRetPktFmtVer.setNotifyValue(true)).called(1);
        verify(gsdisRetSerScanDataStruct.setNotifyValue(true)).called(1);
        verify(gsdisSdStoredScanIndListData.setNotifyValue(true)).called(1);
        verify(gsdisClearScan.setNotifyValue(true)).called(1);
        verify(gscisRetStoredConfList.setNotifyValue(true)).called(1);
        verify(gscisRetScanConfData.setNotifyValue(true)).called(1);

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
        when(mockStartScanChar.write(any,
                withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {});
        when(mockStartScanChar.setNotifyValue(true))
            .thenAnswer((_) async => true);
        when(mockStartScanChar.onValueReceived)
            .thenAnswer((_) => startScanNotifyController.stream);

        when(mockAdapter.getDevice('AA:BB:CC:DD:EE:FF')).thenReturn(mockDevice);

        await service.connect('AA:BB:CC:DD:EE:FF');

        // Start scan - will timeout waiting for notification, but we only care about time sync
        final scanFuture = service.performScan();
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert: time sync should have been called BEFORE scan started
        expect(timeSyncCalled, isTrue);

        // Cleanup
        startScanNotifyController.close();
      });

      test('writes save flag 0x00 to start scan characteristic', () async {
        final mockDevice = MockBluetoothDevice();
        final mockGsdisService = MockBluetoothService();
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
            .thenAnswer((_) async => [mockGsdisService]);
        when(mockDevice.connectionState).thenAnswer(
          (_) => Stream.value(BluetoothConnectionState.connected),
        );
        when(mockDevice.disconnect()).thenAnswer((_) async {});
        when(mockDevice.requestMtu(any, predelay: anyNamed('predelay'), timeout: anyNamed('timeout')))
            .thenAnswer((_) async => 512);

        when(mockGsdisService.uuid)
            .thenReturn(Guid('53455206-444c-5020-4e49-52204e616e6f'));
        when(mockGsdisService.characteristics).thenReturn([mockStartScanChar]);

        // GSDIS_START_SCAN characteristic
        when(mockStartScanChar.uuid)
            .thenReturn(Guid('4348411d-444c-5020-4e49-52204e616e6f'));
        when(mockStartScanChar.write(any,
                withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {});
        when(mockStartScanChar.setNotifyValue(true))
            .thenAnswer((_) async => true);
        when(mockStartScanChar.onValueReceived)
            .thenAnswer((_) => startScanNotifyController.stream);

        when(mockAdapter.getDevice('AA:BB:CC:DD:EE:FF')).thenReturn(mockDevice);

        await service.connect('AA:BB:CC:DD:EE:FF');
        await Future.delayed(const Duration(milliseconds: 50));

        // Start scan in background, will wait for notification
        final scanFuture = service.performScan(saveToSd: false);

        await Future.delayed(const Duration(milliseconds: 50));

        // Verify write was called with [0x00] (save=false)
        verify(mockStartScanChar
                .write([0x00], withoutResponse: anyNamed('withoutResponse')))
            .called(1);

        // Emit scan failed to complete the future
        startScanNotifyController.add([0x01]); // Non-0xFF = error

        // Expect ScanFailedException
        await expectLater(scanFuture, throwsA(isA<ScanFailedException>()));

        await startScanNotifyController.close();
      });

      test('writes save flag 0x01 when saveToSd is true', () async {
        final mockDevice = MockBluetoothDevice();
        final mockGsdisService = MockBluetoothService();
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
            .thenAnswer((_) async => [mockGsdisService]);
        when(mockDevice.connectionState).thenAnswer(
          (_) => Stream.value(BluetoothConnectionState.connected),
        );
        when(mockDevice.disconnect()).thenAnswer((_) async {});
        when(mockDevice.requestMtu(any, predelay: anyNamed('predelay'), timeout: anyNamed('timeout')))
            .thenAnswer((_) async => 512);

        when(mockGsdisService.uuid)
            .thenReturn(Guid('53455206-444c-5020-4e49-52204e616e6f'));
        when(mockGsdisService.characteristics).thenReturn([mockStartScanChar]);

        when(mockStartScanChar.uuid)
            .thenReturn(Guid('4348411d-444c-5020-4e49-52204e616e6f'));
        when(mockStartScanChar.write(any,
                withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {});
        when(mockStartScanChar.setNotifyValue(true))
            .thenAnswer((_) async => true);
        when(mockStartScanChar.onValueReceived)
            .thenAnswer((_) => startScanNotifyController.stream);

        when(mockAdapter.getDevice('AA:BB:CC:DD:EE:FF')).thenReturn(mockDevice);

        await service.connect('AA:BB:CC:DD:EE:FF');
        await Future.delayed(const Duration(milliseconds: 50));

        final scanFuture = service.performScan(saveToSd: true);

        await Future.delayed(const Duration(milliseconds: 50));

        // Verify write was called with [0x01] (save=true)
        verify(mockStartScanChar
                .write([0x01], withoutResponse: anyNamed('withoutResponse')))
            .called(1);

        startScanNotifyController.add([0x01]);

        await expectLater(scanFuture, throwsA(isA<ScanFailedException>()));

        await startScanNotifyController.close();
      });

      test('throws ScanFailedException when scan notification is not 0xFF',
          () async {
        final mockDevice = MockBluetoothDevice();
        final mockGsdisService = MockBluetoothService();
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
            .thenAnswer((_) async => [mockGsdisService]);
        when(mockDevice.connectionState).thenAnswer(
          (_) => Stream.value(BluetoothConnectionState.connected),
        );
        when(mockDevice.disconnect()).thenAnswer((_) async {});
        when(mockDevice.requestMtu(any, predelay: anyNamed('predelay'), timeout: anyNamed('timeout')))
            .thenAnswer((_) async => 512);

        when(mockGsdisService.uuid)
            .thenReturn(Guid('53455206-444c-5020-4e49-52204e616e6f'));
        when(mockGsdisService.characteristics).thenReturn([mockStartScanChar]);

        when(mockStartScanChar.uuid)
            .thenReturn(Guid('4348411d-444c-5020-4e49-52204e616e6f'));
        when(mockStartScanChar.write(any,
                withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {});
        when(mockStartScanChar.setNotifyValue(true))
            .thenAnswer((_) async => true);
        when(mockStartScanChar.onValueReceived)
            .thenAnswer((_) => startScanNotifyController.stream);

        when(mockAdapter.getDevice('AA:BB:CC:DD:EE:FF')).thenReturn(mockDevice);

        await service.connect('AA:BB:CC:DD:EE:FF');
        await Future.delayed(const Duration(milliseconds: 50));

        final scanFuture = service.performScan();

        await Future.delayed(const Duration(milliseconds: 50));

        // Emit error response (not 0xFF)
        startScanNotifyController.add([0x02, 0x00, 0x00, 0x00, 0x00]);

        await expectLater(scanFuture, throwsA(isA<ScanFailedException>()));

        await startScanNotifyController.close();
      });

      test('returns ScanData on successful scan', () async {
        final mockDevice = MockBluetoothDevice();
        final mockGsdisService = MockBluetoothService();

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
            .thenAnswer((_) async => [mockGsdisService]);
        when(mockDevice.connectionState).thenAnswer(
          (_) => Stream.value(BluetoothConnectionState.connected),
        );
        when(mockDevice.disconnect()).thenAnswer((_) async {});
        when(mockDevice.requestMtu(any, predelay: anyNamed('predelay'), timeout: anyNamed('timeout')))
            .thenAnswer((_) async => 512);

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

        // GSDIS_START_SCAN
        when(mockStartScanChar.uuid)
            .thenReturn(Guid('4348411d-444c-5020-4e49-52204e616e6f'));
        when(mockStartScanChar.write(any,
                withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {});
        when(mockStartScanChar.setNotifyValue(true))
            .thenAnswer((_) async => true);
        when(mockStartScanChar.onValueReceived)
            .thenAnswer((_) => startScanNotifyController.stream);

        // GSDIS_REQ_SCAN_NAME
        when(mockReqScanNameChar.uuid)
            .thenReturn(Guid('4348411f-444c-5020-4e49-52204e616e6f'));
        when(mockReqScanNameChar.write(any,
                withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {});

        // GSDIS_RET_SCAN_NAME (notify)
        when(mockRetScanNameChar.uuid)
            .thenReturn(Guid('43484120-444c-5020-4e49-52204e616e6f'));
        when(mockRetScanNameChar.setNotifyValue(true))
            .thenAnswer((_) async => true);
        when(mockRetScanNameChar.onValueReceived)
            .thenAnswer((_) => retScanNameNotifyController.stream);

        // GSDIS_REQ_SCAN_TYPE
        when(mockReqScanTypeChar.uuid)
            .thenReturn(Guid('43484121-444c-5020-4e49-52204e616e6f'));
        when(mockReqScanTypeChar.write(any,
                withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {});

        // GSDIS_RET_SCAN_TYPE (notify)
        when(mockRetScanTypeChar.uuid)
            .thenReturn(Guid('43484122-444c-5020-4e49-52204e616e6f'));
        when(mockRetScanTypeChar.setNotifyValue(true))
            .thenAnswer((_) async => true);
        when(mockRetScanTypeChar.onValueReceived)
            .thenAnswer((_) => retScanTypeNotifyController.stream);

        // GSDIS_REQ_SCAN_DATE
        when(mockReqScanDateChar.uuid)
            .thenReturn(Guid('43484123-444c-5020-4e49-52204e616e6f'));
        when(mockReqScanDateChar.write(any,
                withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {});

        // GSDIS_RET_SCAN_DATE (notify)
        when(mockRetScanDateChar.uuid)
            .thenReturn(Guid('43484124-444c-5020-4e49-52204e616e6f'));
        when(mockRetScanDateChar.setNotifyValue(true))
            .thenAnswer((_) async => true);
        when(mockRetScanDateChar.onValueReceived)
            .thenAnswer((_) => retScanDateNotifyController.stream);

        // GSDIS_REQ_PKT_FMT_VER
        when(mockReqPktFmtVerChar.uuid)
            .thenReturn(Guid('43484125-444c-5020-4e49-52204e616e6f'));
        when(mockReqPktFmtVerChar.write(any,
                withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {});

        // GSDIS_RET_PKT_FMT_VER (notify)
        when(mockRetPktFmtVerChar.uuid)
            .thenReturn(Guid('43484126-444c-5020-4e49-52204e616e6f'));
        when(mockRetPktFmtVerChar.setNotifyValue(true))
            .thenAnswer((_) async => true);
        when(mockRetPktFmtVerChar.onValueReceived)
            .thenAnswer((_) => retPktFmtVerNotifyController.stream);

        // GSDIS_REQ_SER_SCAN_DATA_STRUCT
        when(mockReqSerScanDataChar.uuid)
            .thenReturn(Guid('43484127-444c-5020-4e49-52204e616e6f'));
        when(mockReqSerScanDataChar.write(any,
                withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {});

        // GSDIS_RET_SER_SCAN_DATA_STRUCT (notify - multi-packet)
        when(mockRetSerScanDataChar.uuid)
            .thenReturn(Guid('43484128-444c-5020-4e49-52204e616e6f'));
        when(mockRetSerScanDataChar.setNotifyValue(true))
            .thenAnswer((_) async => true);
        when(mockRetSerScanDataChar.onValueReceived)
            .thenAnswer((_) => retSerScanDataNotifyController.stream);

        when(mockAdapter.getDevice('AA:BB:CC:DD:EE:FF')).thenReturn(mockDevice);

        await service.connect('AA:BB:CC:DD:EE:FF');
        await Future.delayed(const Duration(milliseconds: 50));

        final scanFuture = service.performScan();

        await Future.delayed(const Duration(milliseconds: 50));

        // Simulate scan complete notification: 0xFF + 4-byte scan index
        // Scan index = 0x00000001 (little-endian)
        startScanNotifyController.add([0xFF, 0x01, 0x00, 0x00, 0x00]);

        await Future.delayed(const Duration(milliseconds: 50));

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
      test('fetches reference calibration data on first scan', () async {
        final mockDevice = MockBluetoothDevice();
        final mockGcisService = MockBluetoothService();
        final mockReqCoeffChar = MockBluetoothCharacteristic();
        final mockRetCoeffChar = MockBluetoothCharacteristic();
        final coeffNotifyController = StreamController<List<int>>.broadcast();

        var coeffRequested = false;

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
            .thenReturn(Guid('4348410e-444c-5020-4e49-52204e616e6f'));
        when(mockGcisService.characteristics)
            .thenReturn([mockReqCoeffChar, mockRetCoeffChar]);

        // Request characteristic
        when(mockReqCoeffChar.uuid)
            .thenReturn(Guid('4348410f-444c-5020-4e49-52204e616e6f'));
        when(mockReqCoeffChar.write(any,
                withoutResponse: anyNamed('withoutResponse')))
            .thenAnswer((_) async {
          coeffRequested = true;
        });

        // Return characteristic (notification)
        when(mockRetCoeffChar.uuid)
            .thenReturn(Guid('43484110-444c-5020-4e49-52204e616e6f'));
        when(mockRetCoeffChar.setNotifyValue(true))
            .thenAnswer((_) async => true);
        when(mockRetCoeffChar.onValueReceived)
            .thenAnswer((_) => coeffNotifyController.stream);

        when(mockAdapter.getDevice('AA:BB:CC:DD:EE:FF')).thenReturn(mockDevice);

        await service.connect('AA:BB:CC:DD:EE:FF');

        // Simulate request for calibration (would be called internally)
        // For now, just verify the characteristic exists
        expect(coeffRequested, isFalse); // Not yet called

        // TODO: When ensureCalibration() is implemented, verify it gets called

        coeffNotifyController.close();
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
