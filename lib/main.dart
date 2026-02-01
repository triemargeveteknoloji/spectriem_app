import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/bluetooth_connection_screen.dart';
import 'screens/sensor_communication_screen.dart';
import 'providers/navigation_provider.dart';

void main() {
  runApp(
    const ProviderScope(
      child: SpecTriemApp(),
    ),
  );
}

class SpecTriemApp extends ConsumerWidget {
  const SpecTriemApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(navigationIndexProvider);
    final navigation = ref.read(navigationIndexProvider.notifier);

    return MaterialApp(
      title: 'SpecTriem',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: IndexedStack(
          index: currentIndex,
          children: const [
            BluetoothConnectionScreen(),
            SensorCommunicationScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (index) {
            navigation.state = index;
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
