import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_academy_app/widgets/portal_loading_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('PortalLoadingScreen.admin instantiates and displays admin title', (tester) async {
    bool completed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: PortalLoadingScreen.admin(
          adminName: 'SuperAdmin',
          duration: const Duration(milliseconds: 100),
          onComplete: () {
            completed = true;
          },
        ),
      ),
    );

    expect(find.text('ADMINISTRATOR PORTAL'), findsOneWidget);
    expect(find.text('Welcome, SuperAdmin!'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 150));
    expect(completed, isTrue);
  });

  testWidgets('PortalLoadingScreen.teacher instantiates and displays teacher title', (tester) async {
    bool completed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: PortalLoadingScreen.teacher(
          teacherName: 'Sir Bilal',
          subject: 'Physics',
          duration: const Duration(milliseconds: 100),
          onComplete: () {
            completed = true;
          },
        ),
      ),
    );

    expect(find.text('TEACHER PORTAL'), findsOneWidget);
    expect(find.text('Welcome, Sir Bilal!'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 150));
    expect(completed, isTrue);
  });

  testWidgets('PortalLoadingScreen.student instantiates and displays student title', (tester) async {
    bool completed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: PortalLoadingScreen.student(
          studentName: 'Ali Khan',
          studentCode: 'QA-2024-001',
          duration: const Duration(milliseconds: 100),
          onComplete: () {
            completed = true;
          },
        ),
      ),
    );

    expect(find.text('STUDENT PORTAL'), findsOneWidget);
    expect(find.text('Welcome, Ali Khan!'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 150));
    expect(completed, isTrue);
  });

  testWidgets('BeautifulLoadingWidget renders cleanly with message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BeautifulLoadingWidget(
            message: 'Loading records...',
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Loading records...'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
