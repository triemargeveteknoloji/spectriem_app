/// Handles multi-packet BLE notifications for NIRScan Nano.
///
/// Due to 20-byte MTU limit, large data transfers are split into packets:
/// - Header packet: [0x00, size_lsb, size_msb] - indicates total data size
/// - Data packets: [index, data...] - contain actual data bytes
///
/// Usage:
/// ```dart
/// final receiver = MultiPacketReceiver();
/// characteristic.onValueChanged.listen((data) {
///   receiver.onPacketReceived(data);
///   if (receiver.isComplete) {
///     final result = receiver.data;
///     receiver.reset();
///   }
/// });
/// ```
class MultiPacketReceiver {
  int _expectedSize = 0;
  final List<int> _buffer = [];
  bool _headerReceived = false;

  /// Process an incoming BLE notification packet.
  void onPacketReceived(List<int> packet) {
    if (packet.isEmpty) return;

    final packetIndex = packet[0];

    if (packetIndex == 0x00) {
      // Header packet: [0x00, size_lsb, size_msb]
      _expectedSize = packet.length >= 3
          ? (packet[2] << 8) | (packet[1] & 0xFF)
          : 0;
      _buffer.clear();
      _headerReceived = true;
    } else if (_headerReceived) {
      // Data packet: [index, data...]
      for (int i = 1; i < packet.length && _buffer.length < _expectedSize; i++) {
        _buffer.add(packet[i]);
      }
    }
  }

  /// Whether the header packet has been received.
  bool get headerReceived => _headerReceived;

  /// Expected total data size from header.
  int get expectedSize => _expectedSize;

  /// Number of data bytes received so far.
  int get receivedSize => _buffer.length;

  /// Whether all expected data has been received.
  bool get isComplete => _headerReceived && _buffer.length >= _expectedSize;

  /// Accumulated data bytes.
  List<int> get data => List.unmodifiable(_buffer);

  /// Reception progress (0.0 to 1.0).
  double get progress {
    if (!_headerReceived) return 0.0;
    if (_expectedSize == 0) return 1.0;
    return _buffer.length / _expectedSize;
  }

  /// Reset receiver state for new transmission.
  void reset() {
    _expectedSize = 0;
    _buffer.clear();
    _headerReceived = false;
  }
}
