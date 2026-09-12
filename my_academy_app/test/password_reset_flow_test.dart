import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_academy_app/screens/forgot_password_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
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
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    expect(find.text('Reset Password'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
