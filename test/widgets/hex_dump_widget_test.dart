import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectriem_app/widgets/hex_dump_widget.dart';

void main() {
  Widget createTestWidget(Uint8List data) {
    return MaterialApp(
      home: Scaffold(
        body: HexDumpWidget(data: data),
      ),
    );
  }

  group('HexDumpWidget', () {
    testWidgets('renders hex dump content for small data', (tester) async {
      final data = Uint8List.fromList([0x48, 0x65, 0x6C, 0x6C, 0x6F]); // "Hello"

      await tester.pumpWidget(createTestWidget(data));

      // Should show hex representation
      expect(find.textContaining('48 65 6C 6C 6F'), findsOneWidget);
      // Should show ASCII representation
      expect(find.textContaining('Hello'), findsOneWidget);
    });

    testWidgets('renders empty state for empty data', (tester) async {
      final data = Uint8List(0);

      await tester.pumpWidget(createTestWidget(data));

      expect(find.text('No data'), findsOneWidget);
    });

    testWidgets('shows "Show all" button when data > 64 bytes', (tester) async {
      final data = Uint8List(100); // 100 bytes, more than 64

      await tester.pumpWidget(createTestWidget(data));

      expect(find.text('Show all (100 bytes)'), findsOneWidget);
    });

    testWidgets('does not show "Show all" button when data <= 64 bytes',
        (tester) async {
      final data = Uint8List(64); // Exactly 64 bytes

      await tester.pumpWidget(createTestWidget(data));

      expect(find.textContaining('Show all'), findsNothing);
    });

    testWidgets('expands to full content on button tap', (tester) async {
      // Create 80 bytes of data with distinct pattern
      final data = Uint8List.fromList(List.generate(80, (i) => i));

      await tester.pumpWidget(createTestWidget(data));

      // Initially should show truncated content (64 bytes = 4 rows)
      // Row at offset 0x0040 (64) should NOT be visible initially
      expect(find.textContaining('0040:'), findsNothing);

      // Tap the "Show all" button
      await tester.tap(find.text('Show all (80 bytes)'));
      await tester.pump();

      // After expansion, should show all content including offset 0x0040
      expect(find.textContaining('0040:'), findsOneWidget);

      // Button should change to "Show less"
      expect(find.text('Show less'), findsOneWidget);
    });

    testWidgets('collapses back on "Show less" tap', (tester) async {
      final data = Uint8List.fromList(List.generate(80, (i) => i));

      await tester.pumpWidget(createTestWidget(data));

      // Expand
      await tester.tap(find.text('Show all (80 bytes)'));
      await tester.pump();

      // Collapse
      await tester.tap(find.text('Show less'));
      await tester.pump();

      // Should be back to truncated state
      expect(find.textContaining('0040:'), findsNothing);
      expect(find.text('Show all (80 bytes)'), findsOneWidget);
    });

    testWidgets('uses monospace font', (tester) async {
      final data = Uint8List.fromList([0x41, 0x42, 0x43]); // "ABC"

      await tester.pumpWidget(createTestWidget(data));

      // Find the text widget containing hex content
      final textFinder = find.textContaining('41 42 43');
      expect(textFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(textFinder);
      expect(textWidget.style?.fontFamily, equals('monospace'));
    });

    testWidgets('renders in a container with proper styling', (tester) async {
      final data = Uint8List.fromList([0x00, 0xFF]);

      await tester.pumpWidget(createTestWidget(data));

      // Should be wrapped in a Container
      expect(find.byType(Container), findsWidgets);
    });
  });
}
