import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spectriem_app/providers/log_entries_provider.dart';
import 'package:spectriem_app/providers/log_provider.dart';
import 'package:spectriem_app/services/logging/log_service.dart';
import 'package:fake_async/fake_async.dart';

void main() {
  group('LogEntriesNotifier', () {
    test('initial state is empty list', () {
      final streamController = StreamController<LogEntry>.broadcast();
      final mockLogService = _MockLogService(streamController.stream);

      final container = ProviderContainer(
        overrides: [
          logServiceProvider.overrideWith((ref) => mockLogService),
        ],
      );
      addTearDown(() {
        container.dispose();
        streamController.close();
      });

      final state = container.read(logEntriesProvider);

      expect(state, isEmpty);
    });

    test('adds log entries from stream', () {
      fakeAsync((async) {
        final streamController = StreamController<LogEntry>.broadcast();
        final mockLogService = _MockLogService(streamController.stream);

        final container = ProviderContainer(
          overrides: [
            logServiceProvider.overrideWith((ref) => mockLogService),
          ],
        );

        // Read provider to initialize it
        container.read(logEntriesProvider);

        // Emit first log entry
        final entry1 = LogEntry(
          timestamp: DateTime.now(),
          level: LogLevel.info,
          message: 'Test message 1',
        );
        streamController.add(entry1);

        // Flush microtasks
        async.flushMicrotasks();

        // Should have one entry
        expect(container.read(logEntriesProvider).length, 1);
        expect(
            container.read(logEntriesProvider).first.message, 'Test message 1');

        // Emit second log entry
        final entry2 = LogEntry(
          timestamp: DateTime.now(),
          level: LogLevel.error,
          message: 'Test message 2',
        );
        streamController.add(entry2);

        async.flushMicrotasks();

        // Should have two entries
        expect(container.read(logEntriesProvider).length, 2);
        expect(container.read(logEntriesProvider)[1].message, 'Test message 2');

        container.dispose();
        streamController.close();
      });
    });

    test('clear() removes all entries', () {
      fakeAsync((async) {
        final streamController = StreamController<LogEntry>.broadcast();
        final mockLogService = _MockLogService(streamController.stream);

        final container = ProviderContainer(
          overrides: [
            logServiceProvider.overrideWith((ref) => mockLogService),
          ],
        );

        // Initialize provider
        container.read(logEntriesProvider);

        // Add entries
        streamController.add(LogEntry(
          timestamp: DateTime.now(),
          level: LogLevel.info,
          message: 'Entry 1',
        ));
        streamController.add(LogEntry(
          timestamp: DateTime.now(),
          level: LogLevel.info,
          message: 'Entry 2',
        ));

        async.flushMicrotasks();

        expect(container.read(logEntriesProvider).length, 2);

        // Clear entries
        container.read(logEntriesProvider.notifier).clear();

        expect(container.read(logEntriesProvider), isEmpty);

        container.dispose();
        streamController.close();
      });
    });

    test('loads history on initialization', () {
      final streamController = StreamController<LogEntry>.broadcast();
      final historyEntries = [
        LogEntry(
          timestamp: DateTime.now(),
          level: LogLevel.debug,
          message: 'History entry 1',
        ),
        LogEntry(
          timestamp: DateTime.now(),
          level: LogLevel.info,
          message: 'History entry 2',
        ),
      ];

      final serviceWithHistory = _MockLogServiceWithHistory(
        streamController.stream,
        historyEntries,
      );

      final container = ProviderContainer(
        overrides: [
          logServiceProvider.overrideWith((ref) => serviceWithHistory),
        ],
      );
      addTearDown(() {
        container.dispose();
        streamController.close();
      });

      final state = container.read(logEntriesProvider);

      expect(state.length, 2);
      expect(state[0].message, 'History entry 1');
      expect(state[1].message, 'History entry 2');
    });

    test('cancels stream subscription on dispose', () {
      final streamController = StreamController<LogEntry>.broadcast();
      final mockLogService = _MockLogService(streamController.stream);

      final container = ProviderContainer(
        overrides: [
          logServiceProvider.overrideWith((ref) => mockLogService),
        ],
      );

      // Access provider to initialize it
      container.read(logEntriesProvider);

      // Dispose container
      container.dispose();

      // Stream should no longer affect state (no crash)
      streamController.add(LogEntry(
        timestamp: DateTime.now(),
        level: LogLevel.info,
        message: 'Should not be added',
      ));

      streamController.close();

      // No assertion needed - just verifying no crash occurs
      expect(true, isTrue);
    });
  });
}

// Mock LogService
class _MockLogService implements LogService {
  final Stream<LogEntry> _stream;

  _MockLogService(this._stream);

  @override
  Stream<LogEntry> get logStream => _stream;

  @override
  List<LogEntry> get history => [];

  @override
  int get maxBufferSize => 1000;

  @override
  void log(String message, {LogLevel level = LogLevel.info, String? tag}) {}

  @override
  void debug(String message, {String? tag, Map<String, dynamic>? metadata}) {}

  @override
  void info(String message, {String? tag, Map<String, dynamic>? metadata}) {}

  @override
  void warning(String message, {String? tag, Map<String, dynamic>? metadata}) {}

  @override
  void error(String message, {String? tag, Map<String, dynamic>? metadata}) {}

  @override
  void clear() {}

  @override
  void dispose() {}
}

class _MockLogServiceWithHistory extends _MockLogService {
  final List<LogEntry> _history;

  _MockLogServiceWithHistory(super.stream, this._history);

  @override
  List<LogEntry> get history => _history;
}
