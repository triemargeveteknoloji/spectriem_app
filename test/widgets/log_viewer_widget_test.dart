import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectriem_app/services/logging/log_service.dart';
import 'package:spectriem_app/widgets/log_viewer_widget.dart';

void main() {
  late LogService logService;

  setUp(() {
    logService = LogService();
  });

  tearDown(() {
    logService.dispose();
  });

  Widget createTestWidget({
    LogLevel? filterLevel,
    bool expanded = true,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: LogViewerWidget(
          logService: logService,
          filterLevel: filterLevel,
          expanded: expanded,
        ),
      ),
    );
  }

  group('LogViewerWidget', () {
    testWidgets('renders empty state when no logs', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('No logs'), findsOneWidget);
    });

    testWidgets('renders log entries from stream', (tester) async {
      await tester.pumpWidget(createTestWidget());

      logService.info('Test log message');
      await tester.pump();

      expect(find.text('Test log message'), findsOneWidget);
    });

    testWidgets('renders multiple log entries', (tester) async {
      await tester.pumpWidget(createTestWidget());

      logService.debug('Debug message');
      logService.info('Info message');
      logService.warning('Warning message');
      await tester.pump();

      expect(find.text('Debug message'), findsOneWidget);
      expect(find.text('Info message'), findsOneWidget);
      expect(find.text('Warning message'), findsOneWidget);
    });

    testWidgets('displays log level indicator', (tester) async {
      await tester.pumpWidget(createTestWidget());

      logService.error('Error occurred');
      await tester.pump();

      expect(find.text('ERROR'), findsOneWidget);
    });

    testWidgets('displays tag when present', (tester) async {
      await tester.pumpWidget(createTestWidget());

      logService.info('Tagged message', tag: 'BLE');
      await tester.pump();

      expect(find.text('BLE'), findsOneWidget);
    });

    testWidgets('filters by log level', (tester) async {
      await tester.pumpWidget(createTestWidget(filterLevel: LogLevel.warning));

      logService.debug('Debug - should not show');
      logService.info('Info - should not show');
      logService.warning('Warning - should show');
      logService.error('Error - should show');
      await tester.pump();

      expect(find.text('Debug - should not show'), findsNothing);
      expect(find.text('Info - should not show'), findsNothing);
      expect(find.text('Warning - should show'), findsOneWidget);
      expect(find.text('Error - should show'), findsOneWidget);
    });

    testWidgets('shows existing history on build', (tester) async {
      logService.info('Pre-existing log');

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.text('Pre-existing log'), findsOneWidget);
    });

    testWidgets('auto-scrolls to bottom on new entry', (tester) async {
      await tester.pumpWidget(createTestWidget());

      for (int i = 0; i < 50; i++) {
        logService.info('Log entry $i');
      }
      await tester.pumpAndSettle();

      // Verify early entries are NOT visible (scrolled past)
      expect(find.text('Log entry 0'), findsNothing);
      // Verify recent entries ARE visible
      expect(find.text('Log entry 49'), findsOneWidget);
    });

    testWidgets('collapsed state shows minimal UI', (tester) async {
      await tester.pumpWidget(createTestWidget(expanded: false));

      logService.info('Should not be visible');
      await tester.pump();

      expect(find.text('Should not be visible'), findsNothing);
      expect(find.byType(LogViewerWidget), findsOneWidget);
    });

    testWidgets('uses different colors for log levels', (tester) async {
      await tester.pumpWidget(createTestWidget());

      logService.debug('Debug');
      logService.info('Info');
      logService.warning('Warning');
      logService.error('Error');
      await tester.pump();

      final errorText = tester.widget<Text>(
        find.text('ERROR'),
      );
      expect(errorText.style?.color, equals(Colors.red));
    });
  });
}
