import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectriem_app/screens/bluetooth_connection_screen.dart';
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
    return MaterialApp(
      home: BluetoothConnectionScreen(
        bleService: customBleService ?? bleService,
        logService: logService,
      ),
    );
  }

  group('BluetoothConnectionScreen', () {
    group('idle state', () {
      testWidgets('shows scan button when disconnected', (tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text('Scan'), findsOneWidget);
        expect(find.byIcon(Icons.search), findsOneWidget);
      });

      testWidgets('shows disconnected status', (tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text('Disconnected'), findsOneWidget);
      });

      testWidgets('shows no devices found message initially', (tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.textContaining('No devices found'), findsOneWidget);
      });
    });

    group('log panel', () {
      testWidgets('log panel toggle button exists', (tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.byIcon(Icons.terminal), findsOneWidget);
      });

      testWidgets('log panel expands on toggle', (tester) async {
        await tester.pumpWidget(createTestWidget());

        await tester.tap(find.byIcon(Icons.terminal));
        await tester.pump();

        expect(find.text('No logs'), findsOneWidget);
      });

      testWidgets('log panel collapses on second toggle', (tester) async {
        await tester.pumpWidget(createTestWidget());

        // Expand
        await tester.tap(find.byIcon(Icons.terminal));
        await tester.pump();
        expect(find.text('No logs'), findsOneWidget);

        // Collapse
        await tester.tap(find.byIcon(Icons.terminal));
        await tester.pump();
        expect(find.text('No logs'), findsNothing);
      });
    });

    group('UI elements', () {
      testWidgets('has app bar with title', (tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text('Bluetooth Connection'), findsOneWidget);
      });

      testWidgets('scan button has correct icon', (tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.byIcon(Icons.search), findsOneWidget);
      });

      testWidgets('disconnected state has bluetooth disabled icon', (tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.byIcon(Icons.bluetooth_disabled), findsOneWidget);
      });
    });
  });
}
