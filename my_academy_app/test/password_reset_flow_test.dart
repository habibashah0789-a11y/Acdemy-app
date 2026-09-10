import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_academy_app/screens/reset_password_screen.dart';
import 'package:my_academy_app/screens/forgot_password_screen.dart';

void main() {
  testWidgets('ResetPasswordScreen instantiates properly with oobCode', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ResetPasswordScreen(
          oobCode: 'test-oob-code-123456',
          roleHint: 'admin',
        ),
      ),
    );

    expect(find.byType(ResetPasswordScreen), findsOneWidget);
    expect(find.text('Set New Password'), findsOneWidget);
  });

  testWidgets('ForgotPasswordScreen instantiates properly for admin and teacher', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ForgotPasswordScreen(
          initialRole: 'admin',
          initialEmail: 'admin@quaid.edu',
        ),
      ),
    );

    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    expect(find.text('Password Recovery'), findsOneWidget);
  });
}
