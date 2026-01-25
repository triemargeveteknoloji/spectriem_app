import 'package:flutter_test/flutter_test.dart';
import 'package:spectriem_app/services/ble/mock_nir_scan_service.dart';
import 'package:spectriem_app/services/ble/nir_scan_service.dart';

void main() {
  late MockNirScanService service;

  setUp(() {
    service = MockNirScanService(
      operationDelay: const Duration(milliseconds: 10),
      scanDelay: const Duration(milliseconds: 50),
    );
  });

  tearDown(() {
    service.dispose();
  });

  group('MockNirScanService', () {
    group('connection', () {
      test('starts in disconnected state', () {
        expect(service.connectedDevice, isNull);
      });

      test('can connect to mock device', () async {
        final states = <NirConnectionState>[];
        final subscription = service.connectionState.listen(states.add);

        await service.connect('mock-device-1');
        // Give stream time to emit
        await Future.delayed(const Duration(milliseconds: 50));

        expect(service.connectedDevice, isNotNull);
        expect(service.connectedDevice!.id, equals('mock-device-1'));
        expect(states, contains(NirConnectionState.connecting));
        expect(states, contains(NirConnectionState.connected));

        await subscription.cancel();
      });

      test('can disconnect', () async {
        await service.connect('mock-device-1');
        await service.disconnect();

        expect(service.connectedDevice, isNull);
      });
    });

    group('device info', () {
      test('throws NotConnectedException when not connected', () async {
        expect(
          () => service.getDeviceInfo(),
          throwsA(isA<NotConnectedException>()),
        );
      });

      test('returns device info when connected', () async {
        await service.connect('mock-device-1');

        final info = await service.getDeviceInfo();

        expect(info.manufacturerName, equals('Texas Instruments'));
        expect(info.modelNumber, contains('NIRScan'));
      });
    });

    group('device status', () {
      test('returns status when connected', () async {
        await service.connect('mock-device-1');

        final status = await service.getDeviceStatus();

        expect(status.batteryLevel, inInclusiveRange(0, 100));
        expect(status.temperature, inInclusiveRange(0, 100));
        expect(status.humidity, inInclusiveRange(0, 100));
      });
    });

    group('scan', () {
      test('performs scan and returns data', () async {
        await service.connect('mock-device-1');

        final scanData = await service.performScan();

        expect(scanData.name, isNotEmpty);
        expect(scanData.rawData, isNotEmpty);
        expect(scanData.date.length, equals(12));
      });

      test('scan with saveToSd returns scan index', () async {
        await service.connect('mock-device-1');

        final scanData = await service.performScan(saveToSd: true);

        expect(scanData.scanIndex, isNotNull);
        expect(scanData.scanIndex!.length, equals(4));
      });
    });

    group('configurations', () {
      test('returns scan configurations', () async {
        await service.connect('mock-device-1');

        final configs = await service.getScanConfigurations();

        expect(configs, isNotEmpty);
        expect(configs.first.name, isNotEmpty);
      });

      test('returns active configuration', () async {
        await service.connect('mock-device-1');

        final config = await service.getActiveScanConfiguration();

        expect(config.name, isNotEmpty);
      });
    });

    group('device discovery', () {
      test('emits discovered devices during scan', () async {
        final devices = <NirScanDevice>[];
        service.discoveredDevices.listen(devices.add);

        await service.startDeviceScan(timeout: const Duration(seconds: 2));
        await Future.delayed(const Duration(seconds: 2));

        expect(devices, isNotEmpty);
        expect(devices.first.name, contains('NIRScan'));
      });
    });
  });
}
