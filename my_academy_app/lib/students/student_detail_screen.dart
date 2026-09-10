import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/student_model.dart';
import '../services/database_service.dart';
import '../services/print_service.dart';
import '../theme/app_theme.dart';
import 'edit_student_screen.dart';
import '../utils/whatsapp_helper.dart';
import '../widgets/student_qr_widget.dart';
import '../widgets/crop_image_dialog.dart';
import '../widgets/student_avatar.dart';
import '../utils/image_utils.dart';
import '../student_portal/student_auth_service.dart';
import '../widgets/shimmer_loading_widget.dart';

class StudentDetailScreen extends StatefulWidget {
  final StudentModel student;

  const StudentDetailScreen({super.key, required this.student});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  late StudentModel student;
  bool _isPrinting = false;
  bool _isUploadingPhoto = false;
  Uint8List? _pendingImageBytes;

  Map<String, dynamic>? _authInfo;
  bool _isLoadingAuth = true;

  // Real-time device binding state — updated live from Firestore stream.
  // This ensures the Device Bound / Not Bound badge reflects the actual
  // Firestore value at all times, not just at screen-open time.
  StreamSubscription? _authStreamSub;
  String _deviceId = ''; // live-updated linkedDeviceId from Firestore

  @override
  void initState() {
    super.initState();
    student = widget.student;
    _loadAuthInfo();
    _subscribeToDeviceStatus();
  }

  /// Subscribes to real-time Firestore updates for this student's auth doc.
  /// Updates _deviceId live so the Device Bound / Not Bound badge always
  /// reflects the true Firestore state without requiring a screen reload.
  void _subscribeToDeviceStatus() {
    _authStreamSub?.cancel();
    final cleanCode = student.studentCode.trim().toUpperCase();

    if (cleanCode.isNotEmpty) {
      _authStreamSub = FirebaseFirestore.instance
          .collection('student_auth')
          .where('studentCode', isEqualTo: cleanCode)
          .snapshots()
          .listen((query) {
        if (!mounted) return;
        String foundId = '';
        for (final doc in query.docs) {
          final id = doc.data()['linkedDeviceId'] as String? ?? '';
          if (id.isNotEmpty) {
            foundId = id;
            break;
          }
        }
        debugPrint(
            '[ADMIN BINDING] Detail query snapshot received | student = $cleanCode (ID: ${student.id}) | linkedDeviceId = $foundId | calculated bound count = ${foundId.isNotEmpty ? 1 : 0}');
        if (foundId.isNotEmpty) {
          setState(() => _deviceId = foundId);
        } else {
          FirebaseFirestore.instance
              .collection('student_auth')
              .doc(student.id)
              .get()
              .then((doc) {
            if (mounted && doc.exists && doc.data() != null) {
              final id = doc.data()?['linkedDeviceId'] as String? ?? '';
              debugPrint(
                  '[ADMIN BINDING] Detail fallback doc fetched | studentId = ${student.id} | linkedDeviceId = $id | calculated bound count = ${id.isNotEmpty ? 1 : 0}');
              setState(() => _deviceId = id);
            }
          });
        }
      }, onError: (_) {});
    } else {
      _authStreamSub = FirebaseFirestore.instance
          .collection('student_auth')
          .doc(student.id)
          .snapshots()
          .listen((doc) {
        if (!mounted) return;
        if (doc.exists && doc.data() != null) {
          final id = doc.data()?['linkedDeviceId'] as String? ?? '';
          debugPrint(
              '[ADMIN BINDING] Detail doc snapshot received | studentId = ${student.id} | linkedDeviceId = $id | calculated bound count = ${id.isNotEmpty ? 1 : 0}');
          setState(() => _deviceId = id);
        }
      }, onError: (_) {});
    }
  }

  Future<void> _loadAuthInfo() async {
    setState(() => _isLoadingAuth = true);
    try {
      final info = await StudentAuthService.getOrGenerateStudentAuthInfo(
        studentId: student.id,
        studentCode: student.studentCode,
        studentName: student.name,
      );
      if (mounted) {
        final initialDeviceId = info['linkedDeviceId'] as String? ?? '';
        setState(() {
          _authInfo = info;
          if (initialDeviceId.isNotEmpty) _deviceId = initialDeviceId;
          _isLoadingAuth = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingAuth = false);
      }
    }
  }

  @override
  void dispose() {
    _authStreamSub?.cancel();
    super.dispose();
  }

  Future<void> _resetDevice() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Student Device?'),
        content: const Text(
            'This will clear the student\'s linked device. The student will be logged out and must re-authenticate to bind a new device.'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context, false),
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Cancel'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            icon: const Icon(Icons.restart_alt_rounded, size: 16),
            label: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoadingAuth = true);
    try {
      // 1. Write the reset to Firestore. The student portal's real-time
      //    Firestore listener will detect this change and force-logout
      //    the student on their device automatically.
      await StudentAuthService.resetDeviceBinding(
        student.id,
        studentCode: student.studentCode,
      );

      // 2. Update local _authInfo so the badge flips to 'Not Bound'.
      //    _deviceId is also updated immediately via the Firestore stream.
      if (mounted) {
        setState(() {
          _authInfo = _authInfo != null
              ? {..._authInfo!, 'linkedDeviceId': '', 'deviceLinkedAt': null}
              : {'linkedDeviceId': '', 'deviceLinkedAt': null};
          _deviceId = '';
          _isLoadingAuth = false;
        });
      }

      // 3. Show the success animation dialog.
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_outline_rounded,
                      color: Colors.green,
                      size: 60,
                    ),
                  )
                      .animate()
                      .scale(duration: 500.ms, curve: Curves.elasticOut)
                      .fadeIn(duration: 300.ms),
                  const SizedBox(height: 16),
                  Text(
                    'Device Reset Successfully',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  )
                      .animate()
                      .slideY(begin: 0.3, end: 0, duration: 400.ms, curve: Curves.easeOutBack)
                      .fadeIn(duration: 300.ms),
                  const SizedBox(height: 8),
                  Text(
                    'Device binding cleared.\nStatus is now "Not Bound".',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  )
                      .animate()
                      .slideY(begin: 0.3, end: 0, duration: 450.ms, curve: Curves.easeOutBack)
                      .fadeIn(duration: 300.ms),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('OK'),
                  )
                      .animate()
                      .fadeIn(duration: 300.ms),
                ],
              ),
            ),
          ),
        );
      }

      // 4. Refresh auth info in the background to sync any server-side changes.
      _loadAuthInfo();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reset device: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoadingAuth = false);
      }
    }
  }

  Future<void> _regenerateQrCode() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regenerate Student QR Code?'),
        content: const Text(
            'This will generate a fresh, unique QR code and reset any existing device binding.\n\nThe student\'s previous QR code will immediately stop working, and the student will be able to re-access their portal by scanning the new code.'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context, false),
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Cancel'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            icon: const Icon(Icons.qr_code_rounded, size: 16),
            label: const Text('Regenerate'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoadingAuth = true);
      try {
        final newPlainToken = await StudentAuthService.generateAndStoreQrToken(
          student.id,
          studentCode: student.studentCode,
          studentName: student.name,
        );
        await _loadAuthInfo();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('QR Code regenerated and device binding cleared. Student can now scan to log in.'),
              backgroundColor: Colors.green,
            ),
          );
          // Show the new QR pass in a custom dialog
          showStudentQrDialog(context, student, customQrData: newPlainToken);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to regenerate QR code: $e'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoadingAuth = false);
        }
      }
    }
  }



  Widget _buildLargeAvatarImage(String url) {
    if (url.isEmpty) {
      return Container(
        color: Colors.black12,
        child: const Icon(Icons.person, size: 100, color: Colors.grey),
      );
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.contain,
        placeholder: (_, __) => const ShimmerLoadingWidget(
          width: double.infinity,
          height: double.infinity,
          borderRadius: 0,
        ),
        errorWidget: (_, __, ___) => Container(
          color: Colors.black12,
          child: const Icon(Icons.person, size: 100, color: Colors.grey),
        ),
      );
    }
    if (url.startsWith('data:image') || (!url.contains('/') && !url.contains('\\') && url.length > 50)) {
      try {
        String clean = url.contains(',') ? url.split(',').last : url;
        clean = clean.replaceAll('\n', '').replaceAll('\r', '').replaceAll(' ', '').trim();
        while (clean.length % 4 != 0) {
          clean += '=';
        }
        final bytes = base64Decode(clean);
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.black12,
            child: const Icon(Icons.person, size: 100, color: Colors.grey),
          ),
        );
      } catch (e) {
        // fallback
      }
    }
    if (url.startsWith('blob:')) {
      return Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.black12,
          child: const Icon(Icons.person, size: 100, color: Colors.grey),
        ),
      );
    }
    if (!kIsWeb) {
      try {
        return Image.file(
          io.File(url),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.black12,
              child: const Icon(Icons.person, size: 100, color: Colors.grey),
            );
          },
        );
      } catch (e) {
        // fallback
      }
    }
    return Container(
      color: Colors.black12,
      child: const Icon(Icons.person, size: 100, color: Colors.grey),
    );
  }

  void _showLargeProfilePicture(BuildContext context) {
    if (student.profilePicUrl.isEmpty && _pendingImageBytes == null) return;
    
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  constraints: const BoxConstraints(
                    maxWidth: 350,
                    maxHeight: 350,
                  ),
                  color: Colors.black,
                  child: _pendingImageBytes != null
                      ? Image.memory(
                          _pendingImageBytes!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.black12,
                            child: const Icon(Icons.person, size: 100, color: Colors.grey),
                          ),
                        )
                      : _buildLargeAvatarImage(student.profilePicUrl),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Photo upload ────────────────────────────────────────────────────────

  void _showImageSheet() {
    showModalBottomSheet(
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
                'Change Profile Picture',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade50,
                  child: const Icon(Icons.camera_alt, color: AppTheme.primaryBlue),
                ),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.shade50,
                  child: const Icon(Icons.photo_library, color: Colors.green),
                ),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 75,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        if (mounted) {
          final cropped = await showDialog<Uint8List>(
            context: context,
            barrierDismissible: false,
            builder: (_) => CropImageDialog(imageBytes: bytes),
          );
          if (cropped != null) {
            await _uploadPhoto(cropped);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _uploadPhoto(Uint8List bytes) async {
    setState(() => _isUploadingPhoto = true);
    try {
      // Fast compression to lightweight PNG for instant (< 0.1s) local update & sub-second storage upload
      final compressedBytes = await ImageUtils.compressAndResizeImage(
        bytes,
        targetWidth: 360,
        targetHeight: 360,
        quality: 75,
      );

      final instantBase64Url = 'data:image/png;base64,${base64Encode(compressedBytes)}';

      // 1. Save locally on device for immediate local access
      if (!kIsWeb) {
        try {
          await ImageUtils.saveImageLocally(student.id, compressedBytes);
        } catch (e) {
          debugPrint('Local image save error: $e');
        }
      }

      // 2. Immediately update the student record with instant photo URL (0ms UI latency)
      final updatedStudent = student.copyWith(profilePicUrl: instantBase64Url);
      StudentAvatar.invalidateCache(student.id);
      await DatabaseService.updateStudent(updatedStudent);
      await FirebaseFirestore.instance.collection('students').doc(student.id).set({
        'profilePicUrl': instantBase64Url,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          student = updatedStudent;
          _pendingImageBytes = null;
          _isUploadingPhoto = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // 3. Background async upload to Firebase Storage (~150ms completion)
      final oldUrlToDelete = student.profilePicUrl;
      final studentIdToUpdate = student.id;

      unawaited(() async {
        try {
          if (oldUrlToDelete.isNotEmpty && oldUrlToDelete.startsWith('http')) {
            await DatabaseService.deleteImage(oldUrlToDelete);
          }

          final fileName =
              'students/profile_${studentIdToUpdate}_${DateTime.now().millisecondsSinceEpoch}.png';
          final storageRef = FirebaseStorage.instance.ref().child(fileName);
          await storageRef
              .putData(compressedBytes, SettableMetadata(contentType: 'image/png'))
              .timeout(const Duration(seconds: 8));
          final remoteUrl = await storageRef.getDownloadURL().timeout(const Duration(seconds: 5));

          final currentStudent = DatabaseService.studentBox.get(studentIdToUpdate);
          if (currentStudent != null) {
            final finalStudent = currentStudent.copyWith(profilePicUrl: remoteUrl);
            StudentAvatar.invalidateCache(studentIdToUpdate);
            await DatabaseService.updateStudent(finalStudent);
            if (mounted) {
              setState(() {
                student = finalStudent;
              });
            }
          }

          // Direct Firestore sync for real-time propagation to student portal
          await FirebaseFirestore.instance.collection('students').doc(studentIdToUpdate).set({
            'profilePicUrl': remoteUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          StudentAvatar.invalidateCache(studentIdToUpdate);
        } catch (e) {
          debugPrint('Background storage upload error: $e');
        }
      }());
    } catch (e) {
      if (mounted) {
        setState(() {
          _pendingImageBytes = null;
          _isUploadingPhoto = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _editStudent() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditStudentScreen(student: student)),
    );
    if (result == true) {
      // Refresh student data from Firestore (cloud) first
      final updatedFromCloud = await DatabaseService.getStudentById(student.id);
      if (updatedFromCloud != null) {
        setState(() => student = updatedFromCloud);
      } else {
        // Fallback to local Hive
        final all = DatabaseService.getAllStudentsLocal();
        final updated = all.firstWhere((s) => s.id == student.id, orElse: () => student);
        setState(() => student = updated);
      }
    }
  }

  void _deleteStudent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move to Recycle Bin'),
        content: Text('Are you sure you want to move ${student.name} to the Recycle Bin?'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(ctx, false),
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Cancel'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            icon: const Icon(Icons.delete_sweep_rounded, size: 16),
            label: const Text('Move'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await DatabaseService.recycleStudent(student);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${student.name} moved to Recycle Bin'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    double totalFee = student.biologyFee +
        student.physicsFee +
        student.chemistryFee +
        student.englishFee +
        student.mathFee;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, isDark),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsRow(totalFee),
                  const SizedBox(height: 24),
                  _buildSectionTitle(context, 'Student QR Pass'),
                  const SizedBox(height: 12),
                  _buildQrCodeCard(context, isDark),
                  const SizedBox(height: 24),
                  _buildSectionTitle(context, 'Class Information'),
                  const SizedBox(height: 16),
                  _buildClassInfoCard(isDark),
                  const SizedBox(height: 32),
                  _buildSectionTitle(context, 'Academic Courses'),
                  const SizedBox(height: 16),
                  _buildSubjectGrid(),
                  const SizedBox(height: 32),
                  _buildSectionTitle(context, 'Personal Information'),
                  const SizedBox(height: 16),
                  _buildPersonalInfoCard(isDark),
                  const SizedBox(height: 40),
                  _buildActionButtons(context),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      backgroundColor: AppTheme.primaryBlue,
      actions: [
        _isPrinting
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Preparing PDF...',
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              )
            : IconButton(
                icon: const Icon(Icons.print_rounded, color: Colors.white),
                tooltip: 'Print Record',
                onPressed: () async {
                  setState(() => _isPrinting = true);
                  try {
                    // 30-second guard so the spinner always releases.
                    await PrintService.printStudentReport(student)
                        .timeout(const Duration(seconds: 30));
                  } catch (e) {
                    if (context.mounted) {
                      final msg = e.toString().contains('TimeoutException')
                          ? 'Print timed out. Please try again.'
                          : 'Print failed: $e';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(msg), backgroundColor: Colors.red),
                      );
                    }
                  } finally {
                    if (mounted) {
                      setState(() => _isPrinting = false);
                    }
                  }
                },
              ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.primaryBlue,
                    AppTheme.primaryBlue.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                GestureDetector(
                  onTap: () => _showLargeProfilePicture(context),
                  child: Hero(
                    tag: 'student_${student.id}',
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(50),
                            child: _isUploadingPhoto
                                ? Container(
                                    color: Colors.black54,
                                    child: const Center(
                                      child: SizedBox(
                                        width: 32,
                                        height: 32,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      ),
                                    ),
                                  )
                                : _pendingImageBytes != null
                                    ? Image.memory(_pendingImageBytes!, fit: BoxFit.cover)
                                    : StudentAvatar(
                                    student: student,
                                    size: 100,
                                  ),
                          ),
                        ),
                        // Camera overlay button
                        GestureDetector(
                          onTap: _isUploadingPhoto ? null : _showImageSheet,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: _isUploadingPhoto ? Colors.grey : AppTheme.primaryBlue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  student.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    'ID: ${student.studentCode}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${student.classType} · ${student.grade} · ${student.subject}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildStatsRow(double totalFee) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 420) {
          return Row(
            children: [
              Expanded(child: _buildStatCard('Total Fee', 'Rs ${totalFee.toStringAsFixed(0)}', AppTheme.primaryBlue)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard('Paid', 'Rs ${student.feeSubmitted.toStringAsFixed(0)}', Colors.green)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard('Due', 'Rs ${student.feeRemaining.toStringAsFixed(0)}', Colors.red)),
            ],
          );
        }

        return Column(
          children: [
            _buildStatCard('Total Fee', 'Rs ${totalFee.toStringAsFixed(0)}', AppTheme.primaryBlue),
            const SizedBox(height: 8),
            _buildStatCard('Paid', 'Rs ${student.feeSubmitted.toStringAsFixed(0)}', Colors.green),
            const SizedBox(height: 8),
            _buildStatCard('Due', 'Rs ${student.feeRemaining.toStringAsFixed(0)}', Colors.red),
          ],
        );
      },
    ).animate().fadeIn();
  }

  Widget _buildQrCodeCard(BuildContext context, bool isDark) {
    final qrToken = _authInfo?['qrToken'] as String?;
    // Use _deviceId (live Firestore stream) instead of _authInfo for the
    // device binding status. This ensures instant badge update on reset.
    final deviceId = _deviceId;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          InkWell(
            onTap: () => showStudentQrDialog(context, student, customQrData: qrToken),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  StudentQrWidget(
                    student: student,
                    size: 65,
                    showLabel: false,
                    customQrData: qrToken,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unique Student Pass',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Student ID: ${student.studentCode}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          qrToken == null
                              ? 'Predictive/Not Generated. Tap to setup.'
                              : 'Secure token active. Tap to enlarge.',
                          style: TextStyle(
                            fontSize: 11,
                            color: qrToken == null ? Colors.orange : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.primaryBlue),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Device Binding:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: deviceId.isEmpty ? Colors.grey.shade100 : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: deviceId.isEmpty ? Colors.grey.shade300 : Colors.amber.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            deviceId.isEmpty ? Icons.lightbulb_outline_rounded : Icons.lightbulb_rounded,
                            size: 16,
                            color: deviceId.isEmpty ? Colors.grey.shade600 : Colors.amber.shade800,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            deviceId.isEmpty ? 'Not Bound' : 'Bound',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: deviceId.isEmpty ? Colors.grey.shade600 : Colors.amber.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (deviceId.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'ID: ${deviceId.substring(0, math.min(16, deviceId.length))}...',
                      style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'monospace'),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isLoadingAuth ? null : _regenerateQrCode,
                        icon: const Icon(Icons.qr_code_2_rounded, size: 16),
                        label: const Text('Regen QR'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          foregroundColor: Colors.orange,
                          side: const BorderSide(color: Colors.orange),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isLoadingAuth || _deviceId.isEmpty ? null : _resetDevice,
                        icon: const Icon(Icons.phonelink_erase_rounded, size: 16),
                        label: const Text('Reset Device'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassInfoCard(bool isDark) {
    final schedules = student.subjectSchedules;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoRow(Icons.category_rounded, 'Class Type', student.classType),
            const Divider(),
            _buildInfoRow(Icons.school_rounded, 'Grade / Year', student.grade),
            const Divider(),
            if (schedules.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.book_rounded, size: 20, color: AppTheme.primaryBlue),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Registered Subjects & Schedules', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          const SizedBox(height: 8),
                          ...schedules.entries.map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(e.key, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    e.value,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              _buildInfoRow(Icons.book_rounded, 'Subject', student.subject),
              const Divider(),
              _buildInfoRow(Icons.access_time_rounded, 'Schedule', student.schedule),
            ],
          ],
        ),
      ),
    ).animate().fadeIn();
  }

  Widget _buildSubjectGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildSubjectItem('Biology', student.biologyFee, Icons.biotech_rounded, Colors.green),
        _buildSubjectItem('Physics', student.physicsFee, Icons.science_rounded, Colors.blue),
        _buildSubjectItem('Chemistry', student.chemistryFee, Icons.colorize_rounded, Colors.orange),
        _buildSubjectItem('English', student.englishFee, Icons.menu_book_rounded, Colors.purple),
        _buildSubjectItem('Math', student.mathFee, Icons.calculate_rounded, const Color(0xFF00897B)),
      ],
    );
  }

  Widget _buildSubjectItem(String subject, double totalFee, IconData icon, Color color) {
    if (totalFee <= 0 && !student.subject.contains(subject)) return const SizedBox.shrink();
    
    final paid = student.getSubjectPaid(subject);
    final remaining = student.getSubjectRemaining(subject);
    final isPaid = remaining <= 0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    subject,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Total: Rs ${totalFee.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Paid: Rs ${paid.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w600),
                ),
                Text(
                  isPaid ? 'PAID' : 'Rem: ${remaining.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: isPaid ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildPersonalInfoCard(bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoRow(Icons.person_outline_rounded, 'Father Name', student.fatherName),
            const Divider(),
            InkWell(
              onTap: () => WhatsAppHelper.openWhatsApp(context, student.phone),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  Expanded(
                    child: _buildInfoRow(Icons.phone_android_rounded, 'Phone (Tap to Chat)', student.phone),
                  ),
                  const Icon(Icons.send_rounded, color: Color(0xFF25D366), size: 22),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            const Divider(),
            _buildInfoRow(Icons.email_outlined, 'Email', student.email.isEmpty ? 'N/A' : student.email),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryBlue),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButtons(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 380) {
          return Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _editStudent,
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('EDIT PROFILE'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _deleteStudent,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('REMOVE'),
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _editStudent,
              icon: const Icon(Icons.edit_rounded),
              label: const Text('EDIT PROFILE'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _deleteStudent,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('REMOVE'),
            ),
          ],
        );
      },
    );
  }
}