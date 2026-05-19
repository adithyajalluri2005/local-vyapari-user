import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Simple app widget smoke test', (WidgetTester tester) async {
    // Build a simple placeholder widget to verify test runner configuration
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Local Vyapari'),
          ),
        ),
      ),
    );

    expect(find.text('Local Vyapari'), findsOneWidget);
  });
}
