import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device_info.dart';
import '../models/device_status.dart';
import '../models/scan_configuration.dart';
import '../models/scan_data.dart';
import '../providers/sensor_communication_notifier.dart';
import '../services/ble/nir_scan_service.dart';
import '../widgets/hex_dump_widget.dart';
import '../widgets/log_viewer_widget.dart';

class SensorCommunicationScreen extends ConsumerWidget {
  const SensorCommunicationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sensorCommunicationProvider);
    final notifier = ref.read(sensorCommunicationProvider.notifier);
    final commandState = ref.watch(commandExecutionProvider);
    final commandNotifier = ref.read(commandExecutionProvider.notifier);
    final isConnected = state.isConnected;
    final isLoading = commandState.isLoading;
    final response = commandState.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensor Communication'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.terminal,
              color: state.logPanelExpanded ? Colors.blue : null,
            ),
            onPressed: notifier.toggleLogPanel,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildMainContent(
              isConnected: isConnected,
              isLoading: isLoading,
              response: response,
              commandState: commandState,
              state: state,
              notifier: notifier,
              commandNotifier: commandNotifier,
            ),
          ),
          if (state.logPanelExpanded) _buildLogPanel(),
        ],
      ),
    );
  }

  Widget _buildMainContent({
    required bool isConnected,
    required bool isLoading,
    required Object? response,
    required AsyncValue<Object?> commandState,
    required SensorCommunicationState state,
    required SensorCommunication notifier,
    required CommandExecution commandNotifier,
  }) {
    if (!isConnected) {
      return _buildDisconnectedState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCommandSection(
            isConnected: isConnected,
            isLoading: isLoading,
            commandNotifier: commandNotifier,
          ),
          const SizedBox(height: 16),
          _buildConfigDropdown(state, notifier),
          const SizedBox(height: 16),
          _buildCommandResult(commandState, response),
        ],
      ),
    );
  }

  Widget _buildConfigDropdown(
    SensorCommunicationState state,
    SensorCommunication notifier,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Scan Configuration',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButton<int>(
              value: state.selectedConfigIndex,
              isExpanded: true,
              hint: const Text('Loading configurations...'),
              items: state.configurations?.map((config) {
                return DropdownMenuItem<int>(
                  value: config.index,
                  child: Text(config.name),
                );
              }).toList(),
              onChanged: notifier.selectConfig,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisconnectedState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bluetooth_disabled, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Not connected',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Connect to a sensor first',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildCommandSection({
    required bool isConnected,
    required bool isLoading,
    required CommandExecution commandNotifier,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Commands',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildCommandButton(
                  'Calibrate',
                  Icons.tune,
                  isConnected,
                  isLoading,
                  () => commandNotifier.executeCommand('getCalibrationData'),
                ),
                _buildCommandButton(
                  'Scan',
                  Icons.radar,
                  isConnected,
                  isLoading,
                  () => commandNotifier.executeCommand('performScan'),
                ),
                _buildCommandButton(
                  'Info',
                  Icons.info_outline,
                  isConnected,
                  isLoading,
                  () => commandNotifier.executeCommand('getDeviceInfo'),
                ),
                _buildCommandButton(
                  'Status',
                  Icons.monitor_heart_outlined,
                  isConnected,
                  isLoading,
                  () => commandNotifier.executeCommand('getDeviceStatus'),
                ),
                _buildCommandButton(
                  'Sync Time',
                  Icons.schedule,
                  isConnected,
                  isLoading,
                  () => commandNotifier.executeCommand('syncTime'),
                ),
                _buildCommandButton(
                  'Config',
                  Icons.settings,
                  isConnected,
                  isLoading,
                  () => commandNotifier.executeCommand('getScanConfigurations'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommandButton(
    String label,
    IconData icon,
    bool isConnected,
    bool isLoading,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: isConnected && !isLoading ? onPressed : null,
      icon: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 18),
      label: Text(label),
    );
  }

  Widget _buildCommandResult(
    AsyncValue<Object?> commandState,
    Object? response,
  ) {
    if (commandState.isLoading) {
      return const SizedBox.shrink();
    }

    if (commandState.hasError) {
      return _buildErrorCard(commandState.error);
    }

    if (response == null) {
      return const SizedBox.shrink();
    }

    return _buildResponseCard(response);
  }

  Widget _buildErrorCard(Object? error) {
    final message =
        error is NirScanException ? error.message : error.toString();

    return Card(
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponseCard(Object response) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Response',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildResponseContent(response),
          ],
        ),
      ),
    );
  }

  Widget _buildResponseContent(Object response) {
    if (response is DeviceInfo) {
      return _buildDeviceInfoResponse(response);
    } else if (response is DeviceStatus) {
      return _buildDeviceStatusResponse(response);
    } else if (response is ScanData) {
      return _buildScanDataResponse(response);
    } else if (response is List<ScanConfiguration>) {
      return _buildConfigListResponse(response);
    } else {
      return Text(response.toString());
    }
  }

  Widget _buildDeviceInfoResponse(DeviceInfo info) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Manufacturer', info.manufacturerName),
        _buildInfoRow('Model', info.modelNumber),
        _buildInfoRow('Serial', info.serialNumber),
        _buildInfoRow('Hardware', info.hardwareRevision),
        _buildInfoRow('Firmware', info.tivaFirmwareRevision),
      ],
    );
  }

  Widget _buildDeviceStatusResponse(DeviceStatus status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Battery', '${status.batteryLevel}%'),
        _buildInfoRow(
            'Temperature', '${status.temperature.toStringAsFixed(1)}°C'),
        _buildInfoRow('Humidity', '${status.humidity.toStringAsFixed(1)}%'),
        if (status.hasErrors)
          _buildInfoRow('Errors', status.errorMessages.join(', ')),
      ],
    );
  }

  Widget _buildScanDataResponse(ScanData scan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Name', scan.name),
        _buildInfoRow('Type', scan.type),
        _buildInfoRow('Date', scan.dateTime?.toString() ?? scan.date),
        _buildInfoRow('Data Size', '${scan.rawData.length} bytes'),
        const SizedBox(height: 12),
        const Text(
          'Raw Data',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        HexDumpWidget(data: scan.rawData),
      ],
    );
  }

  Widget _buildConfigListResponse(List<ScanConfiguration> configs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final config in configs)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '${config.index}: ${config.name} (${config.startWavelength}-${config.endWavelength}nm)',
            ),
          ),
      ],
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
