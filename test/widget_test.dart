import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spectriem_app/providers/ble_providers.dart';
import 'package:spectriem_app/providers/log_provider.dart';
import 'package:spectriem_app/services/ble/mock_nir_scan_service.dart';
import 'package:spectriem_app/services/logging/log_service.dart';

void main() {
  testWidgets('App launches with Bluetooth Connection screen', (tester) async {
    final bleService = MockNirScanService(
      operationDelay: Duration.zero,
      scanDelay: Duration.zero,
      deviceEmitInterval: Duration.zero,
    );
    final logService = LogService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nirScanServiceProvider.overrideWithValue(bleService),
          logServiceProvider.overrideWithValue(logService),
        ],
        child: MaterialApp(
          title: 'SpecTriem',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
            useMaterial3: true,
          ),
          home: const Scaffold(
            body: Text('Bluetooth Connection'),
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify the Bluetooth Connection screen is shown
    expect(find.text('Bluetooth Connection'), findsOneWidget);

    // Cleanup
    await bleService.stopDeviceScan();
    bleService.dispose();
    logService.dispose();
  });
}
