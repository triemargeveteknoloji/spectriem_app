import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import 'screens/bluetooth_connection_screen.dart';
import 'screens/sensor_communication_screen.dart';
import 'services/ble/mock_nir_scan_service.dart';
import 'services/ble/nir_scan_service.dart';
import 'services/ble/ble_nir_scan_service.dart';
import 'services/logging/log_service.dart';

NirScanService createNirScanService() {
  if (Platform.isAndroid || Platform.isIOS) {
    return BleNirScanService();
  }
  return MockNirScanService();
}

void main() {
  runApp(const SpecTriemApp());
}

class SpecTriemApp extends StatefulWidget {
  const SpecTriemApp({super.key});

  @override
  State<SpecTriemApp> createState() => _SpecTriemAppState();
}

class _SpecTriemAppState extends State<SpecTriemApp> {
  late final NirScanService _bleService;
  late final LogService _logService;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _bleService = createNirScanService();
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
      home: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            BluetoothConnectionScreen(
              bleService: _bleService,
              logService: _logService,
            ),
            SensorCommunicationScreen(
              bleService: _bleService,
              logService: _logService,
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.bluetooth),
              selectedIcon: Icon(Icons.bluetooth_connected),
              label: 'Connection',
            ),
            NavigationDestination(
              icon: Icon(Icons.sensors_outlined),
              selectedIcon: Icon(Icons.sensors),
              label: 'Communicate',
            ),
          ],
        ),
      ),
    );
  }
}
