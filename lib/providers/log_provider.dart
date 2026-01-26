import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spectriem_app/services/logging/log_service.dart';

final logServiceProvider = Provider<LogService>((ref) {
  final logService = LogService();
  ref.onDispose(() {
    logService.dispose();
  });
  return logService;
});
