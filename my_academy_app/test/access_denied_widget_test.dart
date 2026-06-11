import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_academy_app/screens/access_denied.dart';

void main() {
  testWidgets('Access denied shows message', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: AccessDeniedScreen()));
    expect(find.text('Access denied. You must be an admin to use this app.'), findsOneWidget);
  });
}
