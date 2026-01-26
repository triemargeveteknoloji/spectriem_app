import 'package:flutter_test/flutter_test.dart';
import 'package:spectriem_app/services/logging/log_entry.dart';
import 'package:spectriem_app/services/logging/log_service.dart';

void main() {
  group('LogLevel', () {
    test('has correct ordering', () {
      expect(LogLevel.debug.index, lessThan(LogLevel.info.index));
      expect(LogLevel.info.index, lessThan(LogLevel.warning.index));
      expect(LogLevel.warning.index, lessThan(LogLevel.error.index));
    });

    test('values list contains all levels', () {
      expect(LogLevel.values, hasLength(4));
      expect(LogLevel.values, contains(LogLevel.debug));
      expect(LogLevel.values, contains(LogLevel.info));
      expect(LogLevel.values, contains(LogLevel.warning));
      expect(LogLevel.values, contains(LogLevel.error));
    });
  });

  group('LogEntry', () {
    test('constructor sets all fields', () {
      final timestamp = DateTime(2026, 1, 26, 10, 30, 0);
      final entry = LogEntry(
        timestamp: timestamp,
        level: LogLevel.info,
        message: 'Test message',
        tag: 'BLE',
        metadata: {'key': 'value'},
      );

      expect(entry.timestamp, equals(timestamp));
      expect(entry.level, equals(LogLevel.info));
      expect(entry.message, equals('Test message'));
      expect(entry.tag, equals('BLE'));
      expect(entry.metadata, equals({'key': 'value'}));
    });

    test('tag and metadata are optional', () {
      final entry = LogEntry(
        timestamp: DateTime.now(),
        level: LogLevel.debug,
        message: 'Simple message',
      );

      expect(entry.tag, isNull);
      expect(entry.metadata, isNull);
    });

    test('toString includes level, tag, and message', () {
      final entry = LogEntry(
        timestamp: DateTime(2026, 1, 26, 10, 30, 45),
        level: LogLevel.warning,
        message: 'Warning occurred',
        tag: 'GATT',
      );

      final str = entry.toString();

      expect(str, contains('WARNING'));
      expect(str, contains('GATT'));
      expect(str, contains('Warning occurred'));
      expect(str, contains('10:30:45'));
    });

    test('toString without tag omits bracket section', () {
      final entry = LogEntry(
        timestamp: DateTime(2026, 1, 26, 10, 30, 0),
        level: LogLevel.info,
        message: 'No tag message',
      );

      final str = entry.toString();

      expect(str, contains('INFO'));
      expect(str, contains('No tag message'));
      expect(str, isNot(contains('[]')));
    });

    test('equality compares all fields', () {
      final timestamp = DateTime(2026, 1, 26, 10, 0, 0);
      final entry1 = LogEntry(
        timestamp: timestamp,
        level: LogLevel.info,
        message: 'Same',
        tag: 'TAG',
      );
      final entry2 = LogEntry(
        timestamp: timestamp,
        level: LogLevel.info,
        message: 'Same',
        tag: 'TAG',
      );
      final entry3 = LogEntry(
        timestamp: timestamp,
        level: LogLevel.error,
        message: 'Same',
        tag: 'TAG',
      );

      expect(entry1, equals(entry2));
      expect(entry1, isNot(equals(entry3)));
    });
  });

  group('LogService', () {
    late LogService logService;

    setUp(() {
      logService = LogService();
    });

    tearDown(() {
      logService.dispose();
    });

    group('logging methods', () {
      test('debug() emits entry with debug level', () async {
        final entries = <LogEntry>[];
        logService.logStream.listen(entries.add);

        logService.debug('Debug message');
        await Future.delayed(Duration.zero);

        expect(entries, hasLength(1));
        expect(entries.first.level, equals(LogLevel.debug));
        expect(entries.first.message, equals('Debug message'));
      });

      test('info() emits entry with info level', () async {
        final entries = <LogEntry>[];
        logService.logStream.listen(entries.add);

        logService.info('Info message', tag: 'TEST');
        await Future.delayed(Duration.zero);

        expect(entries, hasLength(1));
        expect(entries.first.level, equals(LogLevel.info));
        expect(entries.first.tag, equals('TEST'));
      });

      test('warning() emits entry with warning level', () async {
        final entries = <LogEntry>[];
        logService.logStream.listen(entries.add);

        logService.warning('Warning message');
        await Future.delayed(Duration.zero);

        expect(entries.first.level, equals(LogLevel.warning));
      });

      test('error() emits entry with error level', () async {
        final entries = <LogEntry>[];
        logService.logStream.listen(entries.add);

        logService.error('Error message', metadata: {'code': 500});
        await Future.delayed(Duration.zero);

        expect(entries.first.level, equals(LogLevel.error));
        expect(entries.first.metadata, equals({'code': 500}));
      });

      test('log entries have auto-generated timestamps', () async {
        final before = DateTime.now();
        logService.info('Timed message');
        final after = DateTime.now();

        await Future.delayed(Duration.zero);

        final entry = logService.history.first;
        expect(entry.timestamp.isAfter(before.subtract(Duration(seconds: 1))), isTrue);
        expect(entry.timestamp.isBefore(after.add(Duration(seconds: 1))), isTrue);
      });
    });

    group('history', () {
      test('returns buffered entries', () {
        logService.debug('First');
        logService.info('Second');
        logService.warning('Third');

        expect(logService.history, hasLength(3));
        expect(logService.history[0].message, equals('First'));
        expect(logService.history[1].message, equals('Second'));
        expect(logService.history[2].message, equals('Third'));
      });

      test('history is read-only copy', () {
        logService.info('Entry');

        final history1 = logService.history;
        final history2 = logService.history;

        expect(identical(history1, history2), isFalse);
      });
    });

    group('clear', () {
      test('empties the buffer', () {
        logService.info('Entry 1');
        logService.info('Entry 2');
        expect(logService.history, hasLength(2));

        logService.clear();

        expect(logService.history, isEmpty);
      });
    });

    group('dispose', () {
      test('closes the stream', () async {
        var streamClosed = false;
        logService.logStream.listen(
          (_) {},
          onDone: () => streamClosed = true,
        );

        logService.dispose();
        await Future.delayed(Duration.zero);

        expect(streamClosed, isTrue);
      });
    });

    group('buffer limit', () {
      test('evicts oldest entries when limit exceeded', () {
        final smallBufferService = LogService(maxBufferSize: 3);

        smallBufferService.info('Entry 1');
        smallBufferService.info('Entry 2');
        smallBufferService.info('Entry 3');
        smallBufferService.info('Entry 4');

        expect(smallBufferService.history, hasLength(3));
        expect(smallBufferService.history[0].message, equals('Entry 2'));
        expect(smallBufferService.history[2].message, equals('Entry 4'));

        smallBufferService.dispose();
      });
    });
  });
}
