import 'package:flutter/material.dart';

import 'screens/bluetooth_connection_screen.dart';
import 'services/ble/mock_nir_scan_service.dart';
import 'services/logging/log_service.dart';

void main() {
  runApp(const SpecTriemApp());
}

class SpecTriemApp extends StatefulWidget {
  const SpecTriemApp({super.key});

  @override
  State<SpecTriemApp> createState() => _SpecTriemAppState();
}

class _SpecTriemAppState extends State<SpecTriemApp> {
  late final MockNirScanService _bleService;
  late final LogService _logService;

  @override
  void initState() {
    super.initState();
    _bleService = MockNirScanService();
    _logService = LogService();
  }

  @override
  void dispose() {
    _bleService.dispose();
    _logService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpecTriem',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: BluetoothConnectionScreen(
        bleService: _bleService,
        logService: _logService,
      ),
    );
  }
}
