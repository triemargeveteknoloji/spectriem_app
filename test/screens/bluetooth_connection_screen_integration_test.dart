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

  Widget createTestWidget({MockNirScanService? customService}) {
    return MaterialApp(
      home: BluetoothConnectionScreen(
        bleService: customService ?? bleService,
        logService: logService,
      ),
    );
  }

  Future<void> pumpN(WidgetTester tester, {int count = 20}) async {
    // Run multiple async cycles to process all microtasks
    for (var j = 0; j < 5; j++) {
      await tester.runAsync(() async {
        await Future.delayed(Duration.zero);
      });
      await tester.pump(Duration.zero);
    }
    // Then pump more to process remaining UI updates
    for (var i = 0; i < count; i++) {
      await tester.pump(Duration.zero);
    }
  }

  group('BluetoothConnectionScreen Integration', () {
    group('scanning flow', () {
      testWidgets('scan discovers devices after tapping scan button',
          (tester) async {
        await tester.pumpWidget(createTestWidget());

        // Initial state: no devices
        expect(find.text('No devices found.\nTap Scan to search.'), findsOneWidget);

        // Tap scan button and pump multiple times for async chain
        await tester.tap(find.text('Scan'));
        await pumpN(tester);

        // Scan completes, state returns to idle with devices found
        expect(find.text('Disconnected'), findsOneWidget);

        // All 3 devices should be visible
        expect(find.text('NIRScan Nano B'), findsOneWidget);
        expect(find.text('NIRScan Nano C'), findsOneWidget);
        expect(find.text('NIRScan Nano D'), findsOneWidget);

        // Verify device list has 3 devices
        expect(find.byType(ListTile), findsNWidgets(3));
      });

      testWidgets('discovered devices persist after scan completes', (tester) async {
        await tester.pumpWidget(createTestWidget());

        // Start scan - devices appear and scan completes immediately
        await tester.tap(find.text('Scan'));
        await pumpN(tester);

        // Should be in idle state with devices found
        expect(find.text('Disconnected'), findsOneWidget);
        expect(find.text('Scan'), findsOneWidget);
        expect(find.byType(ListTile), findsNWidgets(3));
      });
    });

    group('connection flow', () {
      testWidgets('tap device initiates connection and shows connected state',
          (tester) async {
        await tester.pumpWidget(createTestWidget());

        // Start scan - devices appear immediately
        await tester.tap(find.text('Scan'));
        await pumpN(tester);

        // Tap on first device
        await tester.tap(find.text('NIRScan Nano B'));
        await pumpN(tester);

        // Should show connected state
        expect(find.text('Connected'), findsOneWidget);

        // Should show device info card
        expect(find.text('Device Information'), findsOneWidget);
        expect(find.text('Texas Instruments'), findsOneWidget);
        expect(find.text('NIRScan Nano EVM'), findsOneWidget);

        // Should show device status card
        expect(find.text('Device Status'), findsOneWidget);
        expect(find.text('Battery'), findsOneWidget);
        expect(find.text('Temperature'), findsOneWidget);
      });

      testWidgets('disconnect button disconnects device', (tester) async {
        await tester.pumpWidget(createTestWidget());

        // Scan and connect to device
        await tester.tap(find.text('Scan'));
        await pumpN(tester);
        await tester.tap(find.text('NIRScan Nano B'));
        await pumpN(tester);

        // Verify connected
        expect(find.text('Connected'), findsOneWidget);
        expect(find.text('Disconnect'), findsOneWidget);

        // Tap disconnect
        await tester.tap(find.text('Disconnect'));
        await pumpN(tester);

        // Should be back to idle state
        expect(find.text('Disconnected'), findsOneWidget);
        expect(find.text('Scan'), findsOneWidget);

        // Device info should be gone
        expect(find.text('Device Information'), findsNothing);
      });
    });

    group('error handling', () {
      testWidgets('connection error shows error state with retry option',
          (tester) async {
        // Create service that simulates errors
        final errorService = MockNirScanService(
          operationDelay: Duration.zero,
          scanDelay: Duration.zero,
          deviceEmitInterval: Duration.zero,
          simulateErrors: true,
          errorProbability: 1.0, // Always fail
        );

        await tester.pumpWidget(createTestWidget(customService: errorService));

        // Scan and try to connect
        await tester.tap(find.text('Scan'));
        await pumpN(tester);
        await tester.tap(find.text('NIRScan Nano B'));
        await pumpN(tester);

        // Should show error state
        expect(find.text('Error'), findsOneWidget);
        expect(find.text('Connection Error'), findsOneWidget);
        expect(find.text('Try Again'), findsOneWidget);

        // Cleanup
        await errorService.stopDeviceScan();
        errorService.dispose();
      });

      testWidgets('retry button starts new scan after error', (tester) async {
        final errorService = MockNirScanService(
          operationDelay: Duration.zero,
          scanDelay: Duration.zero,
          deviceEmitInterval: Duration.zero,
          simulateErrors: true,
          errorProbability: 1.0,
        );

        await tester.pumpWidget(createTestWidget(customService: errorService));

        // Trigger error state
        await tester.tap(find.text('Scan'));
        await pumpN(tester);
        await tester.tap(find.text('NIRScan Nano B'));
        await pumpN(tester);

        expect(find.text('Error'), findsOneWidget);

        // Tap try again
        await tester.tap(find.text('Try Again'));
        await pumpN(tester);

        // Should show devices again (scanning completed)
        expect(find.text('NIRScan Nano B'), findsOneWidget);

        // Cleanup
        await errorService.stopDeviceScan();
        errorService.dispose();
      });
    });

    group('log integration', () {
      testWidgets('scan actions are logged', (tester) async {
        await tester.pumpWidget(createTestWidget());

        // Open log panel
        await tester.tap(find.byIcon(Icons.terminal));
        await tester.pump();

        // Start scan
        await tester.tap(find.text('Scan'));
        await pumpN(tester);

        // Check log contains scan message
        expect(find.textContaining('Starting device scan'), findsOneWidget);

        // Devices are emitted - at least one should be found
        expect(find.textContaining('Found device'), findsWidgets);

        // Check scan completed is logged
        expect(find.textContaining('Scan completed'), findsOneWidget);
      });

      testWidgets('connection actions are logged', (tester) async {
        await tester.pumpWidget(createTestWidget());

        // Open log panel
        await tester.tap(find.byIcon(Icons.terminal));
        await tester.pump();

        // Scan and connect
        await tester.tap(find.text('Scan'));
        await pumpN(tester);
        await tester.tap(find.text('NIRScan Nano B'));
        await pumpN(tester);

        // Check log contains connection messages
        expect(find.textContaining('Connecting to'), findsOneWidget);
        // Texas Instruments appears in both log and device info
        expect(find.textContaining('Texas Instruments'), findsWidgets);
      });
    });
  });
}
