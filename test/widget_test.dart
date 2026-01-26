import 'package:flutter_test/flutter_test.dart';

import 'package:spectriem_app/main.dart';

void main() {
  testWidgets('App launches with Bluetooth Connection screen', (tester) async {
    await tester.pumpWidget(const SpecTriemApp());
    await tester.pump();

    // Verify the Bluetooth Connection screen is shown
    expect(find.text('Bluetooth Connection'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('Disconnected'), findsOneWidget);
  });
}
