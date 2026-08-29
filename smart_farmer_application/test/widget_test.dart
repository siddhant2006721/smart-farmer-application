import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_farmer_application/welcome_page.dart';

void main() {
  testWidgets('Welcome page renders properly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WelcomePage(),
      ),
    );

    expect(find.text('SMART FARMER'), findsOneWidget);
    expect(find.text('GET STARTED'), findsOneWidget);
  });
}
