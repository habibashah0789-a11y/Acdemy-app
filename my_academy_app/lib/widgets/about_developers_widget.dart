import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class AboutDevelopersCard extends StatelessWidget {
  const AboutDevelopersCard({super.key});

  Future<void> _launchLinkedIn(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      final canLaunch = await canLaunchUrl(uri);
      if (canLaunch) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open link: $url'),
            backgroundColor: AppTheme.warningRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF243044) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isDark ? const Color(0xFF3B82F6) : AppTheme.primaryBlue)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.code_rounded,
                  color: isDark ? const Color(0xFF60A5FA) : AppTheme.primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About Developers',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'Quaid Academy Application Team',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Developer 1: Habiba Shah
          _buildDeveloperItem(
            context,
            name: 'Habiba Shah',
            role: 'Software Engineer & App Developer',
            linkedInUrl: 'https://www.linkedin.com/in/habiba-shah-3337883a8/',
            isDark: isDark,
          ),

          const SizedBox(height: 14),

          // Developer 2: Hamza Taif
          _buildDeveloperItem(
            context,
            name: 'Hamza Taif',
            role: 'Software Engineer & App Developer',
            linkedInUrl: 'https://www.linkedin.com/in/hamza-taif-626853341/',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String name, bool isDark) {
    if (name == 'Hamza Taif') {
      try {
        final File destFile = File('c:/Users/DELL/Desktop/Quaid Acdemy/my_academy_app/assets/images/hamza.png');
        final File sourceFile = File('C:/Users/DELL/.gemini/antigravity-ide/brain/127eea38-9e87-4220-9307-f91029af20e7/media__1786284193941.png');

        if (sourceFile.existsSync() && !destFile.existsSync()) {
          destFile.parent.createSync(recursive: true);
          destFile.writeAsBytesSync(sourceFile.readAsBytesSync());
        }

        if (destFile.existsSync()) {
          return ClipOval(
            child: Image.file(
              destFile,
              width: 36,
              height: 36,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildFallbackAvatar(name, isDark),
            ),
          );
        } else if (sourceFile.existsSync()) {
          return ClipOval(
            child: Image.file(
              sourceFile,
              width: 36,
              height: 36,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildFallbackAvatar(name, isDark),
            ),
          );
        }
      } catch (_) {}
    } else if (name == 'Habiba Shah') {
      return CircleAvatar(
        radius: 18,
        backgroundColor: isDark ? const Color(0xFFEC4899).withValues(alpha: 0.2) : const Color(0xFFFCE7F3),
        child: const Text(
          '👩‍💻',
          style: TextStyle(
            fontSize: 16,
          ),
        ),
      );
    }

    return _buildFallbackAvatar(name, isDark);
  }

  Widget _buildFallbackAvatar(String name, bool isDark) {
    final initials = name.split(' ').map((e) => e[0]).take(2).join();
    return CircleAvatar(
      radius: 18,
      backgroundColor: isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.2) : const Color(0xFFE2E8F0),
      child: Text(
        initials,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: isDark ? const Color(0xFF60A5FA) : AppTheme.primaryBlue,
        ),
      ),
    );
  }

  Widget _buildDeveloperItem(
    BuildContext context, {
    required String name,
    required String role,
    required String linkedInUrl,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          _buildAvatar(name, isDark),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  role,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => _launchLinkedIn(context, linkedInUrl),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0A66C2).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF0A66C2).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.link_rounded,
                    size: 14,
                    color: Color(0xFF0A66C2),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'LinkedIn',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0A66C2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AboutDevelopersDialog extends StatelessWidget {
  const AboutDevelopersDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const AboutDevelopersDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AboutDevelopersCard(),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.black.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
