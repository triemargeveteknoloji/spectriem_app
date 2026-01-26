import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectriem_app/providers/ble_providers.dart';
import 'package:spectriem_app/providers/log_provider.dart';
import 'package:spectriem_app/screens/sensor_communication_screen.dart';
import 'package:spectriem_app/services/ble/mock_nir_scan_service.dart';
import 'package:spectriem_app/services/logging/log_service.dart';

void main() {
  late MockNirScanService bleService;
  late LogService logService;

  setUp(() {
    bleService = MockNirScanService(
      operationDelay: Duration.zero,
      scanDelay: Duration.zero,
      deviceEmitInterval: Duration.zero,
    );
    logService = LogService();
  });

  tearDown(() async {
    await bleService.stopDeviceScan();
    bleService.dispose();
    logService.dispose();
  });

  Widget createTestWidget({MockNirScanService? customBleService}) {
    return ProviderScope(
      overrides: [
        nirScanServiceProvider
            .overrideWithValue(customBleService ?? bleService),
        logServiceProvider.overrideWithValue(logService),
      ],
      child: const MaterialApp(
        home: SensorCommunicationScreen(),
      ),
    );
  }

  Future<void> connectDevice(WidgetTester tester) async {
    await bleService.connect('mock-device-1');
    await tester.pumpAndSettle();
  }

  group('SensorCommunicationScreen', () {
    group('UI structure', () {
      testWidgets('has app bar with title', (tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text('Sensor Communication'), findsOneWidget);
      });

      testWidgets('has log toggle button in app bar', (tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.byIcon(Icons.terminal), findsOneWidget);
      });

      testWidgets('shows all command buttons', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await connectDevice(tester);

        expect(find.text('Scan'), findsOneWidget);
        expect(find.text('Info'), findsOneWidget);
        expect(find.text('Status'), findsOneWidget);
        expect(find.text('Sync Time'), findsOneWidget);
        expect(find.text('Config'), findsOneWidget);
      });
    });

    group('log panel', () {
      testWidgets('log panel is hidden by default', (tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text('No logs'), findsNothing);
      });

      testWidgets('log panel expands on toggle', (tester) async {
        await tester.pumpWidget(createTestWidget());

        await tester.tap(find.byIcon(Icons.terminal));
        await tester.pump();

        expect(find.text('No logs'), findsOneWidget);
      });

      testWidgets('log panel collapses on second toggle', (tester) async {
        await tester.pumpWidget(createTestWidget());

        await tester.tap(find.byIcon(Icons.terminal));
        await tester.pump();
        expect(find.text('No logs'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.terminal));
        await tester.pump();
        expect(find.text('No logs'), findsNothing);
      });
    });

    group('command execution', () {
      testWidgets('Info button calls getDeviceInfo', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await connectDevice(tester);

        await tester.tap(find.text('Info'));
        await tester.pump();

        final logs = logService.history;
        expect(logs.any((e) => e.message.contains('getDeviceInfo')), isTrue);
      });

      testWidgets('Status button calls getDeviceStatus', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await connectDevice(tester);

        await tester.tap(find.text('Status'));
        await tester.pump();

        final logs = logService.history;
        expect(logs.any((e) => e.message.contains('getDeviceStatus')), isTrue);
      });

      testWidgets('Sync Time button calls syncTime', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await connectDevice(tester);

        await tester.tap(find.text('Sync Time'));
        await tester.pumpAndSettle();

        final logs = logService.history;
        expect(logs.any((e) => e.message.contains('syncTime')), isTrue);
      });

      testWidgets('Scan button calls performScan', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await connectDevice(tester);

        await tester.tap(find.text('Scan'));
        await tester.pumpAndSettle();

        final logs = logService.history;
        expect(logs.any((e) => e.message.contains('performScan')), isTrue);
      });

      testWidgets('logs command sent with arrow prefix', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await connectDevice(tester);

        await tester.tap(find.text('Info'));
        await tester.pump();

        final logs = logService.history;
        expect(logs.any((e) => e.message.startsWith('↑')), isTrue);
      });

      testWidgets('logs response received with arrow prefix', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await connectDevice(tester);

        await tester.tap(find.text('Info'));
        await tester.pumpAndSettle();

        final logs = logService.history;
        expect(logs.any((e) => e.message.startsWith('↓')), isTrue);
      });
    });

    group('disconnected state', () {
      testWidgets('shows disconnected message when not connected',
          (tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.textContaining('Not connected'), findsOneWidget);
      });

      testWidgets('command buttons are not shown when disconnected',
          (tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text('Info'), findsNothing);
        expect(find.text('Status'), findsNothing);
        expect(find.text('Scan'), findsNothing);
      });
    });

    group('config dropdown', () {
      testWidgets('shows config dropdown when connected', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await connectDevice(tester);
        await tester.pumpAndSettle();

        expect(find.byType(DropdownButton<int>), findsOneWidget);
      });

      testWidgets('dropdown shows scan configurations', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await connectDevice(tester);
        await tester.pumpAndSettle();

        await tester.tap(find.byType(DropdownButton<int>));
        await tester.pumpAndSettle();

        expect(find.text('Column 1'), findsWidgets);
        expect(find.text('Hadamard'), findsOneWidget);
        expect(find.text('Quick Scan'), findsOneWidget);
      });

      testWidgets('selecting config calls setActiveScanConfiguration',
          (tester) async {
        await tester.pumpWidget(createTestWidget());
        await connectDevice(tester);
        await tester.pumpAndSettle();

        await tester.tap(find.byType(DropdownButton<int>));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Hadamard').last);
        await tester.pumpAndSettle();

        final logs = logService.history;
        expect(
            logs.any((e) => e.message.contains('setActiveScanConfiguration')),
            isTrue);
      });
    });
  });
}
