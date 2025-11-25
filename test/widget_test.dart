// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greengo_mobile/main.dart';

void main() {
  testWidgets('App smoke test - verifies that the home page renders', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const GreenGoApp());

    // Allow time for async operations like the backend health check to complete.
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Verify that the AppBar title is displayed.
    expect(find.text('GreenGo Mobile'), findsOneWidget);

    // Verify that the main action button is present.
    expect(find.text('Start Demo'), findsOneWidget);

    // Verify that key metric cards are on the screen.
    expect(find.text('Next Change'), findsOneWidget);
    expect(find.text('Speed'), findsOneWidget);
    expect(find.text('Distance'), findsOneWidget);

    // Verify that the bottom stats section is visible.
    expect(find.text('Lights Passed'), findsOneWidget);
  });
}
