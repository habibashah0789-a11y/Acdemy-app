import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../utils/whatsapp_helper.dart';
import '../widgets/about_developers_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 1. ABOUT APP SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        title: Text(
          'About Quaid Academy',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // App Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(40),
                      child: Image.asset(
                        'assets/images/Quaid Academy logo.png',
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 72,
                          height: 72,
                          color: AppTheme.primaryBlue,
                          child: const Icon(Icons.school_rounded, color: Colors.white, size: 36),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Quaid Academy Management System',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Version 1.0.0 (Build 2026)',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Empowering educational excellence with seamless student registration, level-differentiated roll numbers, fee management, analytics, and instant student push notifications.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.85),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Key Features Grid Header
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Key Application Features',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
            const SizedBox(height: 12),

            _buildFeatureTile(
              context,
              icon: Icons.badge_rounded,
              color: const Color(0xFF3B82F6),
              title: 'Unique Level Roll Numbers',
              description:
                  'Automated class-differentiated sequence codes (e.g. QA-9-2026-001, QA-10-2026-001, QA-11-2026-001, QA-12-2026-001) for precise student tracking.',
              isDark: isDark,
            ),
            const SizedBox(height: 10),
            _buildFeatureTile(
              context,
              icon: Icons.payments_rounded,
              color: const Color(0xFF10B981),
              title: 'Fee Installment Engine',
              description:
                  'Tracks 1st, 2nd, and 3rd installments, generates digital PDF fee receipts, and provides real-time financial metrics.',
              isDark: isDark,
            ),
            const SizedBox(height: 10),
            _buildFeatureTile(
              context,
              icon: Icons.notifications_active_rounded,
              color: const Color(0xFFF59E0B),
              title: 'Instant Push Alerts',
              description:
                  'Sends fee reminders and academy announcements directly to student devices via Firebase Cloud Messaging.',
              isDark: isDark,
            ),
            const SizedBox(height: 10),
            _buildFeatureTile(
              context,
              icon: Icons.restore_from_trash_rounded,
              color: const Color(0xFF8B5CF6),
              title: 'Recycle Bin Data Safety',
              description:
                  'Protects student records from accidental loss with full restore capabilities and offline Hive caching.',
              isDark: isDark,
            ),

            const SizedBox(height: 24),

            // Developers Card Integration
            const AboutDevelopersCard(),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF243044) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. TERMS & CONDITIONS SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        title: Text(
          'Terms & Conditions',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: (isDark ? const Color(0xFF3B82F6) : AppTheme.primaryBlue).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: (isDark ? const Color(0xFF3B82F6) : AppTheme.primaryBlue).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.gavel_rounded, color: AppTheme.primaryBlue, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quaid Academy Regulations & Privacy',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Last updated: Academic Year 2026',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            _buildTermSection(
              context,
              number: '1',
              title: 'Acceptance & Portal Usage',
              content:
                  'By accessing the Quaid Academy Management System (both Admin Portal and Student Portal), users agree to comply with academy rules. Admin credentials are strictly reserved for authorized staff, while students must secure their level roll numbers and credentials.',
              isDark: isDark,
            ),

            _buildTermSection(
              context,
              number: '2',
              title: 'Student Data Confidentiality',
              content:
                  'All student information—including guardian contact numbers, father names, academic grades, and payment receipts—is securely stored locally and encrypted on cloud databases. Data is used solely for educational administration and fee management.',
              isDark: isDark,
            ),

            _buildTermSection(
              context,
              number: '3',
              title: 'Fee Policy & Installment Guidelines',
              content:
                  'Fee payments are categorized into monthly and installment plans (1st, 2nd, and 3rd installments). Fee reminders are dispatched electronically. Receipts generated via the application serve as official proof of payment.',
              isDark: isDark,
            ),

            _buildTermSection(
              context,
              number: '4',
              title: 'Roll Number Identity Policy',
              content:
                  'Every student is assigned a unique level-differentiated Roll Number (e.g. QA-9-2026-001, QA-10-2026-001, QA-11-2026-001, QA-12-2026-001). Modifying class levels preserves historical payment integrity while updating identification sequences.',
              isDark: isDark,
            ),

            _buildTermSection(
              context,
              number: '5',
              title: 'System Rights & Modifications',
              content:
                  'Quaid Academy reserves the right to update schedules, system features, and fee structures. Users will be notified of major policy changes via portal announcements.',
              isDark: isDark,
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildTermSection(
    BuildContext context, {
    required String number,
    required String title,
    required String content,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF243044) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    number,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: isDark ? Colors.grey.shade300 : const Color(0xFF475569),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. HELP & USER MANUAL SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        title: Text(
          'Help & User Manual',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.65),
          indicatorColor: Colors.amberAccent,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'FAQs', icon: Icon(Icons.quiz_rounded, size: 18)),
            Tab(text: 'User Manual', icon: Icon(Icons.menu_book_rounded, size: 18)),
            Tab(text: 'Support', icon: Icon(Icons.support_agent_rounded, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFaqTab(isDark),
          _buildUserManualTab(isDark),
          _buildSupportTab(isDark),
        ],
      ),
    );
  }

  // FAQ Tab
  Widget _buildFaqTab(bool isDark) {
    final faqs = [
      {
        'q': 'How do student Roll Numbers work?',
        'a':
            'Roll numbers are automatically formatted according to the student\'s class level:\n• 9th Class: QA-9-2026-001\n• 10th Class: QA-10-2026-001\n• FSc 1st Year: QA-11-2026-001\n• FSc 2nd Year: QA-12-2026-001\nThis ensures every student has a unique, identifiable code.'
      },
      {
        'q': 'How to register multiple students at once?',
        'a':
            'In the Admin Portal, go to Student Management -> Add Student -> Keyboard Bulk Registration. Enter student details line by line or paste tab-separated rows for instant batch enrollment.'
      },
      {
        'q': 'How do Push Fee Reminders work?',
        'a':
            'Navigate to Fee Reminders screen. Tap "Send Push Fee Alerts" to dispatch instant notification alerts directly to all active student devices.'
      },
      {
        'q': 'How can students check their fee payment history?',
        'a':
            'Students can log into the Student Portal using their Roll Number (e.g. QA-11-2026-001) and registered credentials to view complete fee receipts and installment logs.'
      },
      {
        'q': 'What happens if student data is accidentally deleted?',
        'a':
            'Deleted student records are moved to the Recycle Bin in Settings. Admins can restore records back to the active database at any time.'
      },
      {
        'q': 'How do I download or print fee receipts?',
        'a':
            'Open student details or fee records and tap "PDF Receipt" to preview, download, or print official academy receipts.'
      },
    ];

    final filteredFaqs = faqs.where((item) {
      final query = _searchQuery.toLowerCase();
      return item['q']!.toLowerCase().contains(query) ||
          item['a']!.toLowerCase().contains(query);
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Search Bar
        TextField(
          controller: _searchController,
          onChanged: (val) => setState(() => _searchQuery = val),
          decoration: InputDecoration(
            hintText: 'Search FAQs & Questions...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
          ),
        ),
        const SizedBox(height: 16),

        if (filteredFaqs.isEmpty)
          Container(
            padding: const EdgeInsets.all(30),
            alignment: Alignment.center,
            child: Text(
              'No matching questions found.',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          )
        else
          ...filteredFaqs.map((faq) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF243044) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.help_outline_rounded, color: AppTheme.primaryBlue, size: 18),
                  ),
                  title: Text(
                    faq['q']!,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Text(
                        faq['a']!,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: isDark ? Colors.grey.shade300 : const Color(0xFF475569),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
      ],
    );
  }

  // User Manual Tab
  Widget _buildUserManualTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildManualSection(
          isDark,
          title: '👨‍💼 Administrator Manual',
          color: const Color(0xFF1E3A8A),
          steps: [
            'Dashboard Analytics: View total active enrollment, total revenue collected, pending fee balances, and level strength breakdown.',
            'Student Management: Add new students individually or use Keyboard Bulk Registration for quick data entry.',
            'Fee Management: Record fee payments, track installments (1st, 2nd, 3rd), and issue PDF receipts.',
            'Fee Reminders: Dispatch push notification alerts to students with pending balances.',
            'Recycle Bin & Settings: Safely restore deleted students or clear data categories with security confirmation.',
          ],
        ),
        const SizedBox(height: 20),
        _buildManualSection(
          isDark,
          title: '🎓 Student Portal Manual',
          color: const Color(0xFF10B981),
          steps: [
            'Portal Login: Enter your assigned Roll Number (e.g. QA-9-2026-001 or QA-11-2026-001) and password.',
            'My Profile: View personal contact details, class format, grade level, and enrollment status.',
            'Fee History: Monitor installment payment receipts and outstanding dues in real-time.',
            'Push Notifications: Receive instant updates regarding fee deadlines, academy announcements, and notices.',
          ],
        ),
      ],
    );
  }

  Widget _buildManualSection(
    bool isDark, {
    required String title,
    required Color color,
    required List<String> steps,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF243044) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          ...steps.asMap().entries.map((entry) {
            final idx = entry.key + 1;
            final text = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$idx',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // Support Contact Tab
  Widget _buildSupportTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF243044) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.headset_mic_rounded, color: AppTheme.primaryBlue, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quaid Academy Support Desk',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'We are here to assist staff and students',
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

              _buildContactItem(
                isDark,
                icon: Icons.location_on_rounded,
                title: 'Academy Campus',
                subtitle: 'Quaid Academy Administration Building, Main Campus',
              ),
              const SizedBox(height: 12),
              _buildContactItem(
                isDark,
                icon: Icons.email_rounded,
                title: 'Official Email Support',
                subtitle: 'quaidacademy241992@gmail.com',
                onTap: () async {
                  final Uri emailLaunchUri = Uri.parse(
                    'mailto:quaidacademy241992@gmail.com?subject=Support%20Request%20-%20Quaid%20Academy%20Student%20Portal',
                  );
                  try {
                    await launchUrl(emailLaunchUri);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not open email client: $e')),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 12),
              _buildContactItem(
                isDark,
                icon: Icons.phone_rounded,
                title: 'Helpdesk Phone & WhatsApp',
                subtitle: '+92 313 9509505 / Campus Helpline',
                onTap: () {
                  WhatsAppHelper.openWhatsApp(context, '+92 313 9509505');
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        const AboutDevelopersCard(),
      ],
    );
  }

  Widget _buildContactItem(
    bool isDark, {
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: onTap != null
                  ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                  : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade100),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: AppTheme.primaryBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: onTap != null
                        ? AppTheme.primaryBlue
                        : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    fontWeight: onTap != null ? FontWeight.w500 : FontWeight.normal,
                    decoration: onTap != null ? TextDecoration.underline : null,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.open_in_new_rounded,
              size: 14,
              color: AppTheme.primaryBlue.withValues(alpha: 0.7),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        hoverColor: AppTheme.primaryBlue.withValues(alpha: 0.05),
        splashColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
        highlightColor: AppTheme.primaryBlue.withValues(alpha: 0.05),
        child: content,
      ),
    );
  }
}
