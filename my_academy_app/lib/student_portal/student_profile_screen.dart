import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../models/student_model.dart';
import '../screens/app_info_screens.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/image_utils.dart';
import '../widgets/about_developers_widget.dart';
import '../widgets/crop_image_dialog.dart';
import '../widgets/custom_card.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/shimmer_loading_widget.dart';
import '../widgets/student_avatar.dart';
import 'student_auth_service.dart';
import 'student_login_screen.dart';

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  StudentModel? _student;
  bool _isLoading = true;
  bool _isUploadingPhoto = false;
  String? _errorMessage;
  StreamSubscription<DocumentSnapshot>? _studentSubscription;

  @override
  void initState() {
    super.initState();
    _initProfileDataAndListener();
  }

  @override
  void dispose() {
    _studentSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initProfileDataAndListener() async {
    setState(() {
      _isLoading = _student == null;
      _errorMessage = null;
    });

    try {
      final session = await StudentAuthService.getLocalSession();
      if (session == null) {
        if (mounted) setState(() => _errorMessage = 'Session expired. Please log in again.');
        return;
      }

      final studentId = session['studentId'] as String? ?? '';
      final studentCode = session['studentCode'] as String?;

      if (studentId.isEmpty) {
        if (mounted) setState(() => _errorMessage = 'Invalid student session ID.');
        return;
      }

      // 1. Initial fast local/server fetch
      final initialStudent = await StudentAuthService.fetchCurrentStudent(
        studentId: studentId,
        studentCode: studentCode,
        forceRefresh: false,
      );

      if (mounted && initialStudent != null) {
        setState(() {
          _student = initialStudent;
          _isLoading = false;
        });
      }

      // 2. Real-time Firestore stream listener (instantly updates when admin/student uploads photo)
      _studentSubscription?.cancel();
      _studentSubscription = FirebaseFirestore.instance
          .collection('students')
          .doc(studentId)
          .snapshots()
          .listen((doc) {
        if (doc.exists && mounted) {
          final updatedStudent = StudentModel.fromFirestore(doc);
          StudentAvatar.invalidateCache(updatedStudent.id);
          DatabaseService.studentBox.put(updatedStudent.id, updatedStudent);
          setState(() {
            _student = updatedStudent;
            _isLoading = false;
            _errorMessage = null;
          });
        }
      }, onError: (e) {
        debugPrint('[StudentProfileScreen] Realtime sync error: $e');
      });
    } catch (e) {
      if (mounted && _student == null) {
        setState(() => _errorMessage = 'Failed to load profile. Please try again.');
      }
    } finally {
      if (mounted && _student != null) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refreshProfileData() async {
    try {
      final session = await StudentAuthService.getLocalSession();
      if (session == null) return;
      final studentId = session['studentId'] as String? ?? '';
      final studentCode = session['studentCode'] as String?;

      final freshStudent = await StudentAuthService.fetchCurrentStudent(
        studentId: studentId,
        studentCode: studentCode,
        forceRefresh: true,
      );

      if (mounted && freshStudent != null) {
        StudentAvatar.invalidateCache(freshStudent.id);
        setState(() {
          _student = freshStudent;
        });
      }
    } catch (e) {
      debugPrint('[StudentProfileScreen] Refresh error: $e');
    }
  }

  Future<void> _showImagePickerSheet(StudentModel student) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Upload Profile Picture',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  child: const Icon(Icons.camera_alt_rounded, color: AppTheme.primaryBlue),
                ),
                title: Text('Take Photo', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.withValues(alpha: 0.1),
                  child: const Icon(Icons.photo_library_rounded, color: Colors.green),
                ),
                title: Text('Choose from Gallery', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;
    await _pickAndUploadPhoto(student, source);
  }

  Future<void> _pickAndUploadPhoto(StudentModel student, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 75);
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      final cropped = await showDialog<Uint8List>(
        context: context,
        barrierDismissible: false,
        builder: (_) => CropImageDialog(imageBytes: bytes),
      );

      final finalBytes = cropped ?? bytes;
      setState(() => _isUploadingPhoto = true);

      final compressed = await ImageUtils.compressAndResizeImage(
        finalBytes,
        targetWidth: 360,
        targetHeight: 360,
        quality: 75,
      );

      final base64Uri = 'data:image/png;base64,${base64Encode(compressed)}';

      // 1. Save locally for instant offline display
      if (!kIsWeb) {
        try {
          await ImageUtils.saveImageLocally(student.id, compressed);
        } catch (_) {}
      }

      // 2. Instant UI update with base64
      final instantStudent = student.copyWith(profilePicUrl: base64Uri);
      StudentAvatar.invalidateCache(student.id);
      await DatabaseService.studentBox.put(student.id, instantStudent);
      if (mounted) {
        setState(() {
          _student = instantStudent;
        });
      }

      // 3. Immediately save base64 to Firestore
      await FirebaseFirestore.instance.collection('students').doc(student.id).set({
        'profilePicUrl': base64Uri,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 4. Background upload to Firebase Storage
      unawaited(() async {
        try {
          final fileName = 'students/profile_${student.id}_${DateTime.now().millisecondsSinceEpoch}.png';
          final storageRef = FirebaseStorage.instance.ref().child(fileName);
          await storageRef
              .putData(compressed, SettableMetadata(contentType: 'image/png'))
              .timeout(const Duration(seconds: 10));
          final remoteUrl = await storageRef.getDownloadURL().timeout(const Duration(seconds: 5));

          final current = DatabaseService.studentBox.get(student.id) ?? instantStudent;
          final finalStudent = current.copyWith(profilePicUrl: remoteUrl);
          StudentAvatar.invalidateCache(student.id);
          await DatabaseService.studentBox.put(student.id, finalStudent);

          await FirebaseFirestore.instance.collection('students').doc(student.id).set({
            'profilePicUrl': remoteUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          if (mounted) {
            setState(() {
              _student = finalStudent;
            });
          }
        } catch (e) {
          debugPrint('[StudentProfileScreen] Background storage upload error: $e');
        }
      }());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully!'),
            backgroundColor: AppTheme.secondaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update picture: $e'),
            backgroundColor: AppTheme.warningRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.warningRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, color: AppTheme.warningRed, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              'Sign Out',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to sign out of your student portal session?',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final session = await StudentAuthService.getLocalSession();
      if (session != null) {
        final studentId = session['studentId'] as String? ?? '';
        if (studentId.isNotEmpty) {
          await NotificationService.unregisterFcmToken(userId: studentId);
          NotificationService.cancelStudentSubscription();
        }
      }
      await StudentAuthService.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const StudentLoginScreen()),
          (_) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: const [
            SizedBox(height: 40),
            Center(child: ShimmerLoadingWidget(width: 100, height: 100, borderRadius: 50)),
            SizedBox(height: 24),
            ShimmerLoadingWidget(width: double.infinity, height: 140, borderRadius: 18),
            SizedBox(height: 20),
            ShimmerLoadingWidget(width: double.infinity, height: 140, borderRadius: 18),
          ],
        ),
      );
    }

    if (_errorMessage != null || _student == null) {
      return Scaffold(
        body: EmptyStateWidget(
          title: 'Profile Unavailable',
          description: _errorMessage ?? 'Could not retrieve profile information.',
          icon: Icons.person_off_rounded,
          actionLabel: 'Retry',
          onAction: _initProfileDataAndListener,
        ),
      );
    }

    final student = _student!;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'My Student Profile',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshProfileData,
        color: AppTheme.primaryBlue,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Avatar & Name Card
            CustomCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.primaryBlue, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryBlue.withValues(alpha: 0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: GestureDetector(
                          onTap: () => StudentAvatar.showFullScreen(context, student),
                          child: Hero(
                            tag: 'student_avatar_zoom_profile_${student.id}',
                            child: StudentAvatar(
                              student: student,
                              size: 100,
                              isLarge: true,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -2,
                        right: -2,
                        child: Material(
                          color: AppTheme.primaryBlue,
                          shape: const CircleBorder(),
                          elevation: 4,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _isUploadingPhoto ? null : () => _showImagePickerSheet(student),
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: _isUploadingPhoto
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.camera_alt_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ).animate().scale(duration: 400.ms),
                  const SizedBox(height: 16),
                  Text(
                    student.name,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      student.studentCode,
                      style: const TextStyle(
                        color: AppTheme.primaryBlue,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(),

            const SizedBox(height: 20),

            // Academic Information
            _buildSectionHeader('Academic Details', Icons.school_rounded),
            const SizedBox(height: 10),
            CustomCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _buildInfoRow(Icons.category_rounded, 'Class Format', student.classType),
                  const Divider(height: 20),
                  _buildInfoRow(Icons.grade_rounded, 'Grade / Level', student.grade),
                  const Divider(height: 20),
                  _buildInfoRow(
                    Icons.verified_user_rounded,
                    'Enrollment Status',
                    student.enrollmentStatusText,
                    valueColor: student.enrollmentStatusColor,
                  ),
                ],
              ),
            ).animate().fadeIn(),

            const SizedBox(height: 20),

            // Personal Information
            _buildSectionHeader('Personal Contact Info', Icons.contact_phone_rounded),
            const SizedBox(height: 10),
            CustomCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _buildInfoRow(Icons.person_outline_rounded, 'Father\'s Name', student.fatherName),
                  const Divider(height: 20),
                  _buildInfoRow(Icons.phone_android_rounded, 'Guardian Phone', student.phone),
                  const Divider(height: 20),
                  _buildInfoRow(
                    Icons.email_outlined,
                    'Email Address',
                    student.email.isEmpty ? 'N/A' : student.email,
                  ),
                ],
              ),
            ).animate().fadeIn(),

            const SizedBox(height: 20),

            // App Information & Support
            _buildSectionHeader('App Information & Support', Icons.info_outline_rounded),
            const SizedBox(height: 10),
            CustomCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded, color: AppTheme.primaryBlue),
                    title: Text('About Quaid Academy', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text('Version 1.0.0 (Build 2026)', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutAppScreen())),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.gavel_rounded, color: AppTheme.primaryBlue),
                    title: Text('Terms & Conditions', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text('Academy Rules & Data Privacy', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsConditionsScreen())),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.help_outline_rounded, color: AppTheme.primaryBlue),
                    title: Text('Help & User Manual', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text('FAQs, Student Guide & Support Desk', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen())),
                  ),
                ],
              ),
            ).animate().fadeIn(),

            const SizedBox(height: 20),

            // About Developers Card
            const AboutDevelopersCard().animate().fadeIn(),

            const SizedBox(height: 28),

            // Sign Out Button
            ElevatedButton.icon(
              onPressed: _handleLogout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign Out of Portal'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warningRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ).animate().fadeIn(),

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryBlue),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryBlue),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
