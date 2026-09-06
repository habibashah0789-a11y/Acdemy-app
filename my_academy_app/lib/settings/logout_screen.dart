import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

class LogoutScreen extends StatefulWidget {
  const LogoutScreen({super.key});

  @override
  State<LogoutScreen> createState() => _LogoutScreenState();
}

class _LogoutScreenState extends State<LogoutScreen> {
  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      // AuthWrapper will automatically redirect to login
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, color: Colors.red),
            ),
            const SizedBox(width: 12),
            Text('Sign Out', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to sign out of the Admin Portal? You will need to enter your credentials to access it again.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop(); // Close dialog
              _signOut(); // Perform sign out
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Yes, Sign Out', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ),
        ],
      ).animate().scale(duration: 200.ms, curve: Curves.easeOutBack),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Logout',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon Container
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withOpacity(0.1),
                  border: Border.all(color: Colors.red.withOpacity(0.3), width: 2),
                ),
                child: const Icon(
                  Icons.exit_to_app_rounded,
                  size: 60,
                  color: Colors.red,
                ),
              ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.8, 0.8)),
              
              const SizedBox(height: 32),
              
              Text(
                'Ready to leave?',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.primaryDarkBlue,
                ),
              ).animate().fadeIn().slideY(begin: 0.2),
              
              const SizedBox(height: 12),
              
              Text(
                'You are currently signed in as an Administrator.\nMake sure you have saved all your work.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  height: 1.5,
                ),
              ).animate().fadeIn().slideY(begin: 0.3),
              
              const SizedBox(height: 48),
              
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _showLogoutConfirmation,
                  icon: const Icon(Icons.logout_rounded, size: 22),
                  label: Text(
                    'SIGN OUT',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: Colors.red.withOpacity(0.4),
                  ),
                ),
              ).animate().fadeIn().slideY(begin: 0.4),
              
              const SizedBox(height: 16),
              
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel & Go Back',
                  style: GoogleFonts.poppins(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ).animate().fadeIn().slideY(begin: 0.5),
            ],
          ),
        ),
      ),
    );
  }
}
