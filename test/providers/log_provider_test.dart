import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spectriem_app/providers/log_provider.dart';
import 'package:spectriem_app/services/logging/log_service.dart';

void main() {
  group('logServiceProvider', () {
    test('provides a LogService instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final logService = container.read(logServiceProvider);

      expect(logService, isA<LogService>());
    });

    test('returns the same instance on multiple reads', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final logService1 = container.read(logServiceProvider);
      final logService2 = container.read(logServiceProvider);

      expect(identical(logService1, logService2), isTrue);
    });

    test('disposes LogService when container is disposed', () {
      final container = ProviderContainer();
      final logService = container.read(logServiceProvider);

      container.dispose();

      // Verify stream is closed by checking if adding to stream throws
      expect(
        () => logService.debug('test'),
        throwsA(isA<StateError>()),
      );
    });

    test('logService has working logStream', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final logService = container.read(logServiceProvider);
      final entries = <String>[];

      final subscription = logService.logStream.listen((entry) {
        entries.add(entry.message);
      });
      addTearDown(subscription.cancel);

      logService.info('Test message 1');
      logService.debug('Test message 2');

      await Future.delayed(Duration(milliseconds: 10));

      expect(entries, ['Test message 1', 'Test message 2']);
    });

    test('logService maintains history buffer', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final logService = container.read(logServiceProvider);

      logService.info('Message 1');
      logService.debug('Message 2');
      logService.warning('Message 3');

      expect(logService.history, hasLength(3));
      expect(logService.history[0].message, 'Message 1');
      expect(logService.history[1].message, 'Message 2');
      expect(logService.history[2].message, 'Message 3');
    });

    test('can override with custom LogService in tests', () {
      final mockLogService = LogService();
      final container = ProviderContainer(
        overrides: [
          logServiceProvider.overrideWithValue(mockLogService),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(mockLogService.dispose);

      final logService = container.read(logServiceProvider);

      expect(identical(logService, mockLogService), isTrue);
    });
  });
}
