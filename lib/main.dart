import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/bluetooth_connection_screen.dart';
import 'screens/sensor_communication_screen.dart';
import 'services/ble/nir_scan_service.dart';
import 'services/logging/log_service.dart';

void main() {
  runApp(
    const ProviderScope(
      child: SpecTriemApp(),
    ),
  );
}

class SpecTriemApp extends StatefulWidget {
  const SpecTriemApp({super.key});

  @override
  State<SpecTriemApp> createState() => _SpecTriemAppState();
}

class _SpecTriemAppState extends State<SpecTriemApp> {
  int _currentIndex = 0;

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
          children: const [
            BluetoothConnectionScreen(),
            SensorCommunicationScreen(),
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
