import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device_info.dart';
import '../models/device_status.dart';
import '../models/scan_configuration.dart';
import '../models/scan_data.dart';
import '../providers/ble_providers.dart';
import '../providers/log_provider.dart';
import '../services/ble/nir_scan_service.dart';
import '../widgets/log_viewer_widget.dart';

class SensorCommunicationScreen extends ConsumerStatefulWidget {
  const SensorCommunicationScreen({super.key});

  @override
  ConsumerState<SensorCommunicationScreen> createState() =>
      _SensorCommunicationScreenState();
}

class _SensorCommunicationScreenState
    extends ConsumerState<SensorCommunicationScreen> {
  bool _logPanelExpanded = false;
  bool _isConnected = false;
  String? _loadingCommand;
  Object? _lastResponse;
  String? _lastError;
  List<ScanConfiguration>? _configurations;
  int? _selectedConfigIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bleService = ref.read(nirScanServiceProvider);
      _isConnected = bleService.connectedDevice != null;
      if (_isConnected) {
        _loadConfigurations();
      }
    });
  }

  void _onConnectionStateChanged(NirConnectionState state) {
    final wasConnected = _isConnected;
    setState(() {
      _isConnected = state == NirConnectionState.connected;
    });
    if (_isConnected && !wasConnected) {
      _loadConfigurations();
    } else if (!_isConnected) {
      setState(() {
        _configurations = null;
        _selectedConfigIndex = null;
      });
    }
  }

  Future<void> _loadConfigurations() async {
    try {
      final bleService = ref.read(nirScanServiceProvider);
      final configs = await bleService.getScanConfigurations();
      if (mounted) {
        setState(() {
          _configurations = configs;
          _selectedConfigIndex =
              configs.isNotEmpty ? configs.first.index : null;
        });
      }
    } catch (e) {
      final logService = ref.read(logServiceProvider);
      logService.error('Failed to load configurations: $e', tag: 'UI');
    }
  }

  Future<void> _onConfigurationChanged(int? index) async {
    if (index == null || index == _selectedConfigIndex) return;

    final bleService = ref.read(nirScanServiceProvider);
    final logService = ref.read(logServiceProvider);

    logService.info('↑ CMD: setActiveScanConfiguration($index)', tag: 'UI');
    try {
      await bleService.setActiveScanConfiguration(index);
      logService.info('↓ RSP: OK', tag: 'UI');
      if (mounted) {
        setState(() {
          _selectedConfigIndex = index;
        });
      }
    } on NirScanException catch (e) {
      logService.error('↓ ERR: $e', tag: 'UI');
    }
  }

  void _toggleLogPanel() {
    setState(() {
      _logPanelExpanded = !_logPanelExpanded;
    });
  }

  Future<void> _executeCommand(
    String commandName,
    Future<Object?> Function() command,
  ) async {
    if (!_isConnected) return;

    final logService = ref.read(logServiceProvider);

    setState(() {
      _loadingCommand = commandName;
      _lastError = null;
    });

    logService.info('↑ CMD: $commandName', tag: 'UI');

    try {
      final result = await command();
      logService.info('↓ RSP: $result', tag: 'UI');
      if (mounted) {
        setState(() {
          _lastResponse = result;
          _loadingCommand = null;
        });
      }
    } on NirScanException catch (e) {
      logService.error('↓ ERR: $e', tag: 'UI');
      if (mounted) {
        setState(() {
          _lastError = e.message;
          _loadingCommand = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<NirConnectionState>>(
      connectionStateProvider,
      (previous, next) {
        next.whenData((state) {
          _onConnectionStateChanged(state);
        });
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensor Communication'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.terminal,
              color: _logPanelExpanded ? Colors.blue : null,
            ),
            onPressed: _toggleLogPanel,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildMainContent(),
          ),
          if (_logPanelExpanded) _buildLogPanel(),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (!_isConnected) {
      return _buildDisconnectedState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCommandSection(),
          const SizedBox(height: 16),
          _buildConfigDropdown(),
          const SizedBox(height: 16),
          if (_lastError != null) _buildErrorCard(),
          if (_lastResponse != null && _lastError == null) _buildResponseCard(),
        ],
      ),
    );
  }

  Widget _buildConfigDropdown() {
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
              value: _selectedConfigIndex,
              isExpanded: true,
              hint: const Text('Loading configurations...'),
              items: _configurations?.map((config) {
                return DropdownMenuItem<int>(
                  value: config.index,
                  child: Text(config.name),
                );
              }).toList(),
              onChanged: _onConfigurationChanged,
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

  Widget _buildCommandSection() {
    final bleService = ref.read(nirScanServiceProvider);

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
                  'Scan',
                  Icons.radar,
                  () => _executeCommand(
                    'performScan',
                    () => bleService.performScan(),
                  ),
                ),
                _buildCommandButton(
                  'Info',
                  Icons.info_outline,
                  () => _executeCommand(
                    'getDeviceInfo',
                    () => bleService.getDeviceInfo(),
                  ),
                ),
                _buildCommandButton(
                  'Status',
                  Icons.monitor_heart_outlined,
                  () => _executeCommand(
                    'getDeviceStatus',
                    () => bleService.getDeviceStatus(),
                  ),
                ),
                _buildCommandButton(
                  'Sync Time',
                  Icons.schedule,
                  () => _executeCommand(
                    'syncTime',
                    () async {
                      await bleService.syncTime();
                      return 'OK';
                    },
                  ),
                ),
                _buildCommandButton(
                  'Config',
                  Icons.settings,
                  () => _executeCommand(
                    'getScanConfigurations',
                    () => bleService.getScanConfigurations(),
                  ),
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
    VoidCallback onPressed,
  ) {
    final isLoading = _loadingCommand != null;
    final isThisLoading = _loadingCommand == label;

    return ElevatedButton.icon(
      onPressed: _isConnected && !isLoading ? onPressed : null,
      icon: isThisLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 18),
      label: Text(label),
    );
  }

  Widget _buildErrorCard() {
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
                _lastError!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponseCard() {
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
            _buildResponseContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildResponseContent() {
    final response = _lastResponse;

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
