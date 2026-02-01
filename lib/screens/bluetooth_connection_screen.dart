import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device_info.dart';
import '../models/device_status.dart';
import '../providers/bluetooth_connection_notifier.dart';
import '../widgets/log_viewer_widget.dart';

class BluetoothConnectionScreen extends ConsumerWidget {
  const BluetoothConnectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bluetoothConnectionProvider);
    final notifier = ref.read(bluetoothConnectionProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Connection'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.terminal,
              color: state.logPanelExpanded ? Colors.blue : null,
            ),
            onPressed: () => notifier.toggleLogPanel(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildMainContent(state, notifier),
          ),
          if (state.logPanelExpanded) _buildLogPanel(),
        ],
      ),
    );
  }

  Widget _buildMainContent(
    BluetoothConnectionState state,
    BluetoothConnection notifier,
  ) {
    return Column(
      children: [
        _buildStatusHeader(state, notifier),
        const Divider(height: 1),
        Expanded(
          child: _buildDeviceSection(state, notifier),
        ),
      ],
    );
  }

  Widget _buildStatusHeader(
    BluetoothConnectionState state,
    BluetoothConnection notifier,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildConnectionStatus(state),
          const Spacer(),
          _buildScanButton(state, notifier),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus(BluetoothConnectionState state) {
    final (text, color, icon) = switch (state.screenState) {
      ScreenState.idle => (
          'Disconnected',
          Colors.grey,
          Icons.bluetooth_disabled
        ),
      ScreenState.scanning => (
          'Scanning...',
          Colors.blue,
          Icons.bluetooth_searching
        ),
      ScreenState.connecting => (
          'Connecting...',
          Colors.orange,
          Icons.bluetooth_connected
        ),
      ScreenState.connected => (
          'Connected',
          Colors.green,
          Icons.bluetooth_connected
        ),
      ScreenState.error => ('Error', Colors.red, Icons.error_outline),
    };

    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildScanButton(
    BluetoothConnectionState state,
    BluetoothConnection notifier,
  ) {
    if (state.screenState == ScreenState.scanning) {
      return Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => notifier.stopScanning(),
            icon: const Icon(Icons.stop),
            label: const Text('Stop'),
          ),
        ],
      );
    }

    if (state.screenState == ScreenState.connected) {
      return TextButton.icon(
        onPressed: () => notifier.disconnect(),
        icon: const Icon(Icons.link_off),
        label: const Text('Disconnect'),
        style: TextButton.styleFrom(foregroundColor: Colors.red),
      );
    }

    return TextButton.icon(
      onPressed: state.screenState == ScreenState.connecting
          ? null
          : () => notifier.startScanning(),
      icon: const Icon(Icons.search),
      label: const Text('Scan'),
    );
  }

  Widget _buildDeviceSection(
    BluetoothConnectionState state,
    BluetoothConnection notifier,
  ) {
    if (state.screenState == ScreenState.connected &&
        state.deviceInfo != null) {
      return _buildConnectedDeviceInfo(state.deviceInfo!, state.deviceStatus);
    }

    if (state.screenState == ScreenState.error) {
      return _buildErrorState(state, notifier);
    }

    return _buildDeviceList(state, notifier);
  }

  Widget _buildDeviceList(
    BluetoothConnectionState state,
    BluetoothConnection notifier,
  ) {
    if (state.discoveredDevices.isEmpty) {
      return const Center(
        child: Text(
          'No devices found.\nTap Scan to search.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: state.discoveredDevices.length,
      itemBuilder: (context, index) {
        final device = state.discoveredDevices[index];
        return ListTile(
          leading: const Icon(Icons.bluetooth),
          title: Text(device.name),
          subtitle: Text(device.id),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => notifier.connectToDevice(device),
        );
      },
    );
  }

  Widget _buildConnectedDeviceInfo(
      DeviceInfo deviceInfo, DeviceStatus? deviceStatus) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            'Device Information',
            [
              _buildInfoRow('Manufacturer', deviceInfo.manufacturerName),
              _buildInfoRow('Model', deviceInfo.modelNumber),
              _buildInfoRow('Serial', deviceInfo.serialNumber),
              _buildInfoRow('Firmware', deviceInfo.tivaFirmwareRevision),
            ],
          ),
          const SizedBox(height: 16),
          if (deviceStatus != null)
            _buildInfoCard(
              'Device Status',
              [
                _buildStatusRow(
                  Icons.battery_full,
                  'Battery',
                  '${deviceStatus.batteryLevel}%',
                ),
                _buildStatusRow(
                  Icons.thermostat,
                  'Temperature',
                  '${deviceStatus.temperature.toStringAsFixed(1)}°C',
                ),
                _buildStatusRow(
                  Icons.water_drop,
                  'Humidity',
                  '${deviceStatus.humidity.toStringAsFixed(1)}%',
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildStatusRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.grey)),
          const Spacer(),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildErrorState(
    BluetoothConnectionState state,
    BluetoothConnection notifier,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          const Text('Connection Error'),
          if (state.errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          TextButton(
            onPressed: () => notifier.startScanning(),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildLogPanel() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: const LogViewerWidget(),
    );
  }
}
