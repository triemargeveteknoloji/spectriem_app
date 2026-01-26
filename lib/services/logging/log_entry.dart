enum LogLevel {
  debug,
  info,
  warning,
  error,
}

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? tag;
  final Map<String, dynamic>? metadata;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.tag,
    this.metadata,
  });

  @override
  String toString() {
    final time = _formatTime(timestamp);
    final levelStr = level.name.toUpperCase();
    final tagPart = tag != null ? '[$tag] ' : '';
    return '$time $levelStr $tagPart$message';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LogEntry &&
          runtimeType == other.runtimeType &&
          timestamp == other.timestamp &&
          level == other.level &&
          message == other.message &&
          tag == other.tag &&
          _mapEquals(metadata, other.metadata);

  bool _mapEquals(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      timestamp.hashCode ^
      level.hashCode ^
      message.hashCode ^
      tag.hashCode ^
      metadata.hashCode;
}
