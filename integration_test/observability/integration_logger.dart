import 'dart:io';

import 'log_formatter.dart';

enum LogCategory {
  step,
  ble,
  state,
  cal,
  scan,
  pass,
  fail,
  data,
}

class IntegrationLogger {
  final bool enabled;

  IntegrationLogger({this.enabled = true});

  String _formatTimestamp(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    final ms = time.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  String _categoryColor(LogCategory category) {
    return switch (category) {
      LogCategory.step => AnsiColors.cyan,
      LogCategory.ble => AnsiColors.blue,
      LogCategory.state => AnsiColors.magenta,
      LogCategory.cal => AnsiColors.yellow,
      LogCategory.scan => AnsiColors.yellow,
      LogCategory.pass => '${AnsiColors.bold}${AnsiColors.green}',
      LogCategory.fail => '${AnsiColors.bold}${AnsiColors.red}',
      LogCategory.data => AnsiColors.white,
    };
  }

  String _categoryLabel(LogCategory category) {
    return category.name.toUpperCase().padRight(5);
  }

  void log(LogCategory category, String message) {
    if (!enabled) return;

    final timestamp = _formatTimestamp(DateTime.now());
    final color = _categoryColor(category);
    final label = _categoryLabel(category);

    stdout.writeln(
      '$timestamp $color[$label]${AnsiColors.reset} $message',
    );
  }

  void step(String message) {
    log(LogCategory.step, '=== $message ===');
  }

  void ble(String message) {
    log(LogCategory.ble, message);
  }

  void state(String oldState, String newState) {
    log(LogCategory.state, '$oldState -> $newState');
  }

  void pass(String message) {
    log(LogCategory.pass, '\u2713 $message');
  }

  void fail(String message) {
    log(LogCategory.fail, '\u2717 $message');
  }

  void data(String label, dynamic value) {
    log(LogCategory.data, '$label: $value');
  }

  void separator() {
    if (!enabled) return;
    stdout.writeln('─' * 60);
  }
}
