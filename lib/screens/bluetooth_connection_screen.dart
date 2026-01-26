import 'dart:async';

import 'package:flutter/material.dart';

import '../models/device_info.dart';
import '../models/device_status.dart';
import '../services/ble/nir_scan_service.dart';
import '../services/logging/log_service.dart';
import '../widgets/log_viewer_widget.dart';

enum _ScreenState {
  idle,
  scanning,
  connecting,
  connected,
  error,
}

class BluetoothConnectionScreen extends StatefulWidget {
  final NirScanService bleService;
  final LogService logService;

  const BluetoothConnectionScreen({
    super.key,
    required this.bleService,
    required this.logService,
  });

  @override
  State<BluetoothConnectionScreen> createState() =>
      _BluetoothConnectionScreenState();
}

class _BluetoothConnectionScreenState extends State<BluetoothConnectionScreen> {
  _ScreenState _state = _ScreenState.idle;
  List<NirScanDevice> _discoveredDevices = [];
  DeviceInfo? _deviceInfo;
  DeviceStatus? _deviceStatus;
  String? _errorMessage;
  bool _logPanelExpanded = false;

  StreamSubscription<NirScanDevice>? _deviceSubscription;
  StreamSubscription<NirConnectionState>? _connectionSubscription;

  @override
  void initState() {
    super.initState();
    _connectionSubscription =
        widget.bleService.connectionState.listen(_onConnectionStateChanged);
  }

  @override
  void dispose() {
    _deviceSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  void _onConnectionStateChanged(NirConnectionState state) {
    setState(() {
      switch (state) {
        case NirConnectionState.disconnected:
          _state = _ScreenState.idle;
          _deviceInfo = null;
          _deviceStatus = null;
        case NirConnectionState.connecting:
          _state = _ScreenState.connecting;
        case NirConnectionState.connected:
          _state = _ScreenState.connected;
          _loadDeviceInfo();
        case NirConnectionState.disconnecting:
          break;
      }
    });
  }

  Future<void> _startScan() async {
    widget.logService.info('Starting device scan...', tag: 'BLE');
    setState(() {
      _state = _ScreenState.scanning;
      _discoveredDevices = [];
    });

    _deviceSubscription = widget.bleService.discoveredDevices.listen((device) {
      widget.logService.debug('Found device: ${device.name}', tag: 'BLE');
      setState(() {
        if (!_discoveredDevices.any((d) => d.id == device.id)) {
          _discoveredDevices = [..._discoveredDevices, device];
        }
      });
    });

    try {
      await widget.bleService.startDeviceScan(
        timeout: const Duration(seconds: 10),
      );
    } catch (e) {
      widget.logService.error('Scan failed: $e', tag: 'BLE');
    }

    await _deviceSubscription?.cancel();
    if (mounted && _state == _ScreenState.scanning) {
      widget.logService.info('Scan completed', tag: 'BLE');
      setState(() {
        _state = _ScreenState.idle;
      });
    }
  }

  Future<void> _stopScan() async {
    widget.logService.info('Stopping scan', tag: 'BLE');
    await widget.bleService.stopDeviceScan();
    await _deviceSubscription?.cancel();
    setState(() {
      _state = _ScreenState.idle;
    });
  }

  Future<void> _connectToDevice(NirScanDevice device) async {
    widget.logService.info('Connecting to ${device.name}...', tag: 'BLE');
    setState(() {
      _state = _ScreenState.connecting;
    });

    try {
      await widget.bleService.connect(device.id);
    } catch (e) {
      widget.logService.error('Connection failed: $e', tag: 'BLE');
      setState(() {
        _state = _ScreenState.error;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _disconnect() async {
    widget.logService.info('Disconnecting...', tag: 'BLE');
    try {
      await widget.bleService.disconnect();
    } catch (e) {
      widget.logService.error('Disconnect failed: $e', tag: 'BLE');
    }
  }

  Future<void> _loadDeviceInfo() async {
    try {
      widget.logService.debug('Loading device info...', tag: 'BLE');
      final info = await widget.bleService.getDeviceInfo();
      final status = await widget.bleService.getDeviceStatus();
      widget.logService.info(
        'Device: ${info.manufacturerName} ${info.modelNumber}',
        tag: 'BLE',
      );
      if (mounted) {
        setState(() {
          _deviceInfo = info;
          _deviceStatus = status;
        });
      }
    } catch (e) {
      widget.logService.error('Failed to load device info: $e', tag: 'BLE');
    }
  }

  void _toggleLogPanel() {
    setState(() {
      _logPanelExpanded = !_logPanelExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Connection'),
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
    return Column(
      children: [
        _buildStatusHeader(),
        const Divider(height: 1),
        Expanded(
          child: _buildDeviceSection(),
        ),
      ],
    );
  }

  Widget _buildStatusHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildConnectionStatus(),
          const Spacer(),
          _buildScanButton(),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    final (text, color, icon) = switch (_state) {
      _ScreenState.idle => ('Disconnected', Colors.grey, Icons.bluetooth_disabled),
      _ScreenState.scanning => ('Scanning...', Colors.blue, Icons.bluetooth_searching),
      _ScreenState.connecting => ('Connecting...', Colors.orange, Icons.bluetooth_connected),
      _ScreenState.connected => ('Connected', Colors.green, Icons.bluetooth_connected),
      _ScreenState.error => ('Error', Colors.red, Icons.error_outline),
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

  Widget _buildScanButton() {
    if (_state == _ScreenState.scanning) {
      return Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _stopScan,
            icon: const Icon(Icons.stop),
            label: const Text('Stop'),
          ),
        ],
      );
    }

    if (_state == _ScreenState.connected) {
      return TextButton.icon(
        onPressed: _disconnect,
        icon: const Icon(Icons.link_off),
        label: const Text('Disconnect'),
        style: TextButton.styleFrom(foregroundColor: Colors.red),
      );
    }

    return TextButton.icon(
      onPressed: _state == _ScreenState.connecting ? null : _startScan,
      icon: const Icon(Icons.search),
      label: const Text('Scan'),
    );
  }

  Widget _buildDeviceSection() {
    if (_state == _ScreenState.connected && _deviceInfo != null) {
      return _buildConnectedDeviceInfo();
    }

    if (_state == _ScreenState.error) {
      return _buildErrorState();
    }

    return _buildDeviceList();
  }

  Widget _buildDeviceList() {
    if (_discoveredDevices.isEmpty) {
      return const Center(
        child: Text(
          'No devices found.\nTap Scan to search.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: _discoveredDevices.length,
      itemBuilder: (context, index) {
        final device = _discoveredDevices[index];
        return ListTile(
          leading: const Icon(Icons.bluetooth),
          title: Text(device.name),
          subtitle: Text(device.id),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _connectToDevice(device),
        );
      },
    );
  }

  Widget _buildConnectedDeviceInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            'Device Information',
            [
              _buildInfoRow('Manufacturer', _deviceInfo!.manufacturerName),
              _buildInfoRow('Model', _deviceInfo!.modelNumber),
              _buildInfoRow('Serial', _deviceInfo!.serialNumber),
              _buildInfoRow('Firmware', _deviceInfo!.tivaFirmwareRevision),
            ],
          ),
          const SizedBox(height: 16),
          if (_deviceStatus != null)
            _buildInfoCard(
              'Device Status',
              [
                _buildStatusRow(
                  Icons.battery_full,
                  'Battery',
                  '${_deviceStatus!.batteryLevel}%',
                ),
                _buildStatusRow(
                  Icons.thermostat,
                  'Temperature',
                  '${_deviceStatus!.temperature.toStringAsFixed(1)}°C',
                ),
                _buildStatusRow(
                  Icons.water_drop,
                  'Humidity',
                  '${_deviceStatus!.humidity.toStringAsFixed(1)}%',
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

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          const Text('Connection Error'),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          TextButton(
            onPressed: _startScan,
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
      child: LogViewerWidget(
        logService: widget.logService,
      ),
    );
  }
}
