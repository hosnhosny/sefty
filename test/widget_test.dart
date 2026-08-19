// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_app/main.dart';

void main() {
  testWidgets('App builds without crashing', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // Wrapped with ProviderScope because the app uses Riverpod.
    await tester.pumpWidget(
      const ProviderScope(child: SafiApp()),
    );

    // At this point you can add real expectations for your app,
    // e.g. verifying that the login screen appears.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
