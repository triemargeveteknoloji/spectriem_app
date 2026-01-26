import 'dart:async';

import 'log_entry.dart';

export 'log_entry.dart';

class LogService {
  static const int _defaultMaxBufferSize = 1000;

  final int maxBufferSize;
  final List<LogEntry> _buffer = [];
  final StreamController<LogEntry> _logController =
      StreamController<LogEntry>.broadcast();

  LogService({this.maxBufferSize = _defaultMaxBufferSize});

  Stream<LogEntry> get logStream => _logController.stream;

  List<LogEntry> get history => List.unmodifiable(_buffer);

  void debug(String message, {String? tag, Map<String, dynamic>? metadata}) {
    _log(LogLevel.debug, message, tag: tag, metadata: metadata);
  }

  void info(String message, {String? tag, Map<String, dynamic>? metadata}) {
    _log(LogLevel.info, message, tag: tag, metadata: metadata);
  }

  void warning(String message, {String? tag, Map<String, dynamic>? metadata}) {
    _log(LogLevel.warning, message, tag: tag, metadata: metadata);
  }

  void error(String message, {String? tag, Map<String, dynamic>? metadata}) {
    _log(LogLevel.error, message, tag: tag, metadata: metadata);
  }

  void _log(
    LogLevel level,
    String message, {
    String? tag,
    Map<String, dynamic>? metadata,
  }) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      tag: tag,
      metadata: metadata,
    );

    _buffer.add(entry);

    if (_buffer.length > maxBufferSize) {
      _buffer.removeAt(0);
    }

    _logController.add(entry);
  }

  void clear() {
    _buffer.clear();
  }

  void dispose() {
    _logController.close();
  }
}
