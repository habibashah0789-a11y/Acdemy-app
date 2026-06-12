import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'fsc_teacher_screen.dart';
import 'matric_teacher_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────
const List<String> kSubjects = ['Biology', 'Physics', 'Chemistry', 'English', 'Math'];

const Map<String, List<String>> kGrades = {
  'FSc': ['First Year', 'Second Year'],
  'Matric': ['Ninth', 'Tenth'],
};

const Map<String, IconData> kSubjectIcons = {
  'Biology': Icons.biotech_rounded,
  'Physics': Icons.science_rounded,
  'Chemistry': Icons.colorize_rounded,
  'English': Icons.menu_book_rounded,
  'Math': Icons.calculate_rounded,
};

const Map<String, Color> kSubjectColors = {
  'Biology': Color(0xFF4CAF50),
  'Physics': Color(0xFF2196F3),
  'Chemistry': Color(0xFFFF9800),
  'English': Color(0xFF9C27B0),
  'Math': Color(0xFF00897B),
};

const List<String> kScheduleSlots = [
  '7:00 AM', '8:00 AM', '9:00 AM', '10:00 AM', '11:00 AM',
  '12:00 PM', '1:00 PM', '2:00 PM', '3:00 PM', '4:00 PM',
  '5:00 PM', '6:00 PM', '7:00 PM', '8:00 PM', '9:00 PM', '10:00 PM',
];

// ─────────────────────────────────────────────────────────────────────────────
// LEVEL 0 — Two main folders: FSc Teachers & Matric Teachers
// ─────────────────────────────────────────────────────────────────────────────
class TeacherFolderScreen extends StatelessWidget {
  const TeacherFolderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Teachers')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Category',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Browse teachers by class type',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 28),
            FolderCard(
              title: 'FSc Teachers',
              subtitle: 'First Year & Second Year',
              icon: Icons.school_rounded,
              gradient: const [Color(0xFF1565C0), Color(0xFF42A5F5)],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FscSubjectListScreen(),
                ),
              ),
            ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.15),
            const SizedBox(height: 16),
            FolderCard(
              title: 'Matric Teachers',
              subtitle: 'Ninth & Tenth Class',
              icon: Icons.auto_stories_rounded,
              gradient: const [Color(0xFF2E7D32), Color(0xFF66BB6A)],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MatricSubjectListScreen(),
                ),
              ),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.15),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Folder Card Widget
// ─────────────────────────────────────────────────────────────────────────────
class FolderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  const FolderCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: gradient.first.withOpacity(0.25),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withOpacity(0.7),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
