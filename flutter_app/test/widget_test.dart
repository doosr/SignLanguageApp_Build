import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sign_language_app/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the home screen with SignLanguage title appears
    expect(find.text('SignLanguage'), findsOneWidget);
  });
}
