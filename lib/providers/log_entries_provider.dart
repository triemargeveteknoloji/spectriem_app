import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:spectriem_app/providers/log_provider.dart';
import 'package:spectriem_app/services/logging/log_service.dart';

part 'log_entries_provider.g.dart';

@riverpod
class LogEntries extends _$LogEntries {
  StreamSubscription<LogEntry>? _subscription;

  @override
  List<LogEntry> build() {
    final logService = ref.watch(logServiceProvider);

    // Load history
    final entries = List<LogEntry>.from(logService.history);

    // Subscribe to stream
    _subscription = logService.logStream.listen(
      (entry) {
        // Use scheduleMicrotask to avoid state modification during build
        scheduleMicrotask(() {
          if (state is List<LogEntry>) {
            state = [...state, entry];
          }
        });
      },
      onError: (error) {
        // Handle errors silently
      },
    );

    // Cleanup on dispose
    ref.onDispose(() {
      _subscription?.cancel();
    });

    return entries;
  }

  void clear() {
    state = [];
  }
}
