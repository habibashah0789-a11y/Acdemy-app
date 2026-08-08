import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/student_model.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../widgets/crop_image_dialog.dart';
import '../theme/app_theme.dart';
import '../utils/image_utils.dart';
import '../student_portal/student_auth_service.dart';
import 'bulk_registration_widget.dart';
import '../widgets/celebration_overlay.dart';
import '../services/sound_service.dart';

class AddStudentScreen extends StatefulWidget {
  final String? presetClassType;
  final String? presetSubject;
  final String? presetGrade;
  final String? presetSchedule;

  const AddStudentScreen({
    super.key,
    this.presetClassType,
    this.presetSubject,
    this.presetGrade,
    this.presetSchedule,
  });

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  int _currentModeIndex = 0; // 0 = Single Admission, 1 = Bulk Registration

  final _formKey = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _fatherC = TextEditingController();
  final _phoneC = TextEditingController();
  final _emailC = TextEditingController();
  final _feeSubC = TextEditingController();
  final _feeRemC = TextEditingController();
  final _bioC = TextEditingController();
  final _phyC = TextEditingController();
  final _chemC = TextEditingController();
  final _engC = TextEditingController();
  final _mathC = TextEditingController();

  final _bioPaidC = TextEditingController();
  final _phyPaidC = TextEditingController();
  final _chemPaidC = TextEditingController();
  final _engPaidC = TextEditingController();
  final _mathPaidC = TextEditingController();

  // FocusNodes for fast keyboard navigation
  final _nameFocusNode = FocusNode();
  final _fatherFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _classTypeFocusNode = FocusNode();
  final _gradeFocusNode = FocusNode();
  final _feeSubFocusNode = FocusNode();
  final _feeRemFocusNode = FocusNode();

  final _bioFocusNode = FocusNode();
  final _bioPaidFocusNode = FocusNode();
  final _phyFocusNode = FocusNode();
  final _phyPaidFocusNode = FocusNode();
  final _chemFocusNode = FocusNode();
  final _chemPaidFocusNode = FocusNode();
  final _engFocusNode = FocusNode();
  final _engPaidFocusNode = FocusNode();
  final _mathFocusNode = FocusNode();
  final _mathPaidFocusNode = FocusNode();

  Uint8List? _imageBytes;
  bool _isSaving = false;

  // Dropdown values
  late String _selectedClassType;
  late String _selectedGrade;
  
  // Track selected subjects and their schedules
  Map<String, String> _selectedSubjectSchedules = {};

  static const List<String> _classTypes = ['FSc', 'Matric'];
  static const Map<String, List<String>> _gradeOptions = {
    'FSc': ['First Year', 'Second Year'],
    'Matric': ['Ninth', 'Tenth'],
  };
  static const List<String> _subjects = ['Biology', 'Physics', 'Chemistry', 'English', 'Math'];
  static const List<String> _scheduleSlots = [
    '7:00 AM', '8:00 AM', '9:00 AM', '10:00 AM', '11:00 AM',
    '12:00 PM', '1:00 PM', '2:00 PM', '3:00 PM', '4:00 PM',
    '5:00 PM', '6:00 PM', '7:00 PM', '8:00 PM', '9:00 PM', '10:00 PM',
  ];

  @override
  void initState() {
    super.initState();
    _selectedClassType = widget.presetClassType ?? 'FSc';
    _selectedGrade = widget.presetGrade ?? _gradeOptions[_selectedClassType]!.first;
    
    // Set initial default subject and schedule
    final defaultSubj = widget.presetSubject ?? 'Biology';
    final defaultSched = widget.presetSchedule ?? '7:00 AM';
    _selectedSubjectSchedules = {defaultSubj: defaultSched};
    
    _bioC.text = '';
    _phyC.text = '';
    _chemC.text = '';
    _engC.text = '';
    _mathC.text = '';

    _bioPaidC.text = '';
    _phyPaidC.text = '';
    _chemPaidC.text = '';
    _engPaidC.text = '';
    _mathPaidC.text = '';

    _feeSubC.text = '';
    _feeRemC.text = '';

    // Add listeners to auto-calculate remaining fee
    _bioC.addListener(_updateCalculatedFees);
    _phyC.addListener(_updateCalculatedFees);
    _chemC.addListener(_updateCalculatedFees);
    _engC.addListener(_updateCalculatedFees);
    _mathC.addListener(_updateCalculatedFees);

    _bioPaidC.addListener(_updateCalculatedFees);
    _phyPaidC.addListener(_updateCalculatedFees);
    _chemPaidC.addListener(_updateCalculatedFees);
    _engPaidC.addListener(_updateCalculatedFees);
    _mathPaidC.addListener(_updateCalculatedFees);
    
  }

  TextEditingController _getFeeControllerForSubject(String sub) {
    switch (sub) {
      case 'Biology': return _bioC;
      case 'Physics': return _phyC;
      case 'Chemistry': return _chemC;
      case 'English': return _engC;
      case 'Math': return _mathC;
      default: return TextEditingController();
    }
  }

  TextEditingController _getPaidControllerForSubject(String sub) {
    switch (sub) {
      case 'Biology': return _bioPaidC;
      case 'Physics': return _phyPaidC;
      case 'Chemistry': return _chemPaidC;
      case 'English': return _engPaidC;
      case 'Math': return _mathPaidC;
      default: return TextEditingController();
    }
  }

  FocusNode _getFeeFocusForSubject(String sub) {
    switch (sub) {
      case 'Biology': return _bioFocusNode;
      case 'Physics': return _phyFocusNode;
      case 'Chemistry': return _chemFocusNode;
      case 'English': return _engFocusNode;
      case 'Math': return _mathFocusNode;
      default: return _feeSubFocusNode;
    }
  }

  FocusNode _getPaidFocusForSubject(String sub) {
    switch (sub) {
      case 'Biology': return _bioPaidFocusNode;
      case 'Physics': return _phyPaidFocusNode;
      case 'Chemistry': return _chemPaidFocusNode;
      case 'English': return _engPaidFocusNode;
      case 'Math': return _mathPaidFocusNode;
      default: return _feeSubFocusNode;
    }
  }

  void _updateCalculatedFees() {
    double total = 0;
    double submitted = 0;
    for (final sub in _subjects) {
      if (_selectedSubjectSchedules.containsKey(sub)) {
        total += double.tryParse(_getFeeControllerForSubject(sub).text.trim()) ?? 0;
        submitted += double.tryParse(_getPaidControllerForSubject(sub).text.trim()) ?? 0;
      }
    }
    
    final newSubText = submitted > 0 ? submitted.toStringAsFixed(0) : '';
    if (_feeSubC.text != newSubText) {
      _feeSubC.text = newSubText;
    }
    
    double remaining = total - submitted;
    if (remaining < 0) remaining = 0;
    final newRemText = (total > 0 && remaining > 0) ? remaining.toStringAsFixed(0) : '';
    if (_feeRemC.text != newRemText) {
      _feeRemC.text = newRemText;
    }
  }

  Color _getSubjectColor(String sub) {
    switch (sub) {
      case 'Biology': return Colors.green;
      case 'Physics': return Colors.blue;
      case 'Chemistry': return Colors.orange;
      case 'English': return Colors.purple;
      case 'Math': return const Color(0xFF00897B);
      default: return AppTheme.primaryBlue;
    }
  }

  void _resetFormForNextStudent() {
    setState(() {
      _nameC.clear();
      _fatherC.clear();
      _phoneC.clear();
      _emailC.clear();
      _imageBytes = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocusNode.requestFocus();
    });
  }

  Widget _buildSubjectSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Subjects and Schedules *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryBlue,
          ),
        ),
        const SizedBox(height: 12),
        ..._subjects.map((sub) {
          final isChecked = _selectedSubjectSchedules.containsKey(sub);
          final currentSchedule = _selectedSubjectSchedules[sub] ?? '7:00 AM';
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            color: isChecked ? AppTheme.primaryBlue.withValues(alpha: 0.05) : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isChecked ? AppTheme.primaryBlue.withValues(alpha: 0.3) : Colors.grey.shade300,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Checkbox(
                    value: isChecked,
                    activeColor: AppTheme.primaryBlue,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedSubjectSchedules[sub] = '7:00 AM';
                        } else {
                          _selectedSubjectSchedules.remove(sub);
                          _getFeeControllerForSubject(sub).text = '0';
                          _getPaidControllerForSubject(sub).text = '0';
                        }
                        _updateCalculatedFees();
                      });
                    },
                  ),
                  Expanded(
                    child: Text(
                      sub,
                      style: TextStyle(
                        fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                        color: isChecked ? AppTheme.primaryBlue : null,
                      ),
                    ),
                  ),
                  if (isChecked) ...[
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: currentSchedule,
                      underline: const SizedBox(),
                      items: _scheduleSlots.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (sVal) {
                        if (sVal != null) {
                          setState(() {
                            _selectedSubjectSchedules[sub] = sVal;
                          });
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  List<Widget> _buildDynamicFeeFields() {
    final List<Widget> fields = [];
    final activeSubs = _subjects.where((s) => _selectedSubjectSchedules.containsKey(s)).toList();
    
    for (int i = 0; i < activeSubs.length; i++) {
      final sub = activeSubs[i];
      final nextSub = (i < activeSubs.length - 1) ? activeSubs[i + 1] : null;

      fields.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$sub Fee Distribution',
                style: TextStyle(fontWeight: FontWeight.bold, color: _getSubjectColor(sub), fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _feeField(
                      'Total Fee',
                      _getFeeControllerForSubject(sub),
                      _getFeeFocusForSubject(sub),
                      _getPaidFocusForSubject(sub),
                      _getSubjectColor(sub),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _feeField(
                      'Paid amount',
                      _getPaidControllerForSubject(sub),
                      _getPaidFocusForSubject(sub),
                      nextSub != null ? _getFeeFocusForSubject(nextSub) : _feeSubFocusNode,
                      Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return fields;
  }

  @override
  void dispose() {
    _nameC.dispose();
    _fatherC.dispose();
    _phoneC.dispose();
    _emailC.dispose();
    _feeSubC.dispose();
    _feeRemC.dispose();
    _bioC.dispose();
    _phyC.dispose();
    _chemC.dispose();
    _engC.dispose();
    _mathC.dispose();
    _bioPaidC.dispose();
    _phyPaidC.dispose();
    _chemPaidC.dispose();
    _engPaidC.dispose();
    _mathPaidC.dispose();

    _nameFocusNode.dispose();
    _fatherFocusNode.dispose();
    _phoneFocusNode.dispose();
    _emailFocusNode.dispose();
    _classTypeFocusNode.dispose();
    _gradeFocusNode.dispose();
    _feeSubFocusNode.dispose();
    _feeRemFocusNode.dispose();

    _bioFocusNode.dispose();
    _bioPaidFocusNode.dispose();
    _phyFocusNode.dispose();
    _phyPaidFocusNode.dispose();
    _chemFocusNode.dispose();
    _chemPaidFocusNode.dispose();
    _engFocusNode.dispose();
    _engPaidFocusNode.dispose();
    _mathFocusNode.dispose();
    _mathPaidFocusNode.dispose();

    super.dispose();
  }

  void _showImageSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
          child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Select Profile Picture',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.primaryBlue,
              )),
          const SizedBox(height: 16),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade50,
              child: const Icon(Icons.camera_alt, color: AppTheme.primaryBlue),
            ),
            title: const Text('Camera'),
            onTap: () {
              Navigator.pop(ctx);
              _pick(ImageSource.camera);
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
              _pick(ImageSource.gallery);
            },
          ),
        ]),
      )),
    );
  }

  Future<void> _pick(ImageSource src) async {
    try {
      final f = await ImagePicker().pickImage(source: src, imageQuality: 70);
      if (f != null) {
        final bytes = await f.readAsBytes();
        if (mounted) {
          final cropped = await showDialog<Uint8List>(
            context: context,
            barrierDismissible: false,
            builder: (_) => CropImageDialog(imageBytes: bytes),
          );
          if (cropped != null) {
            final compressed = await ImageUtils.compressAndResizeImage(
              cropped,
              targetWidth: 512,
              targetHeight: 512,
            );
            setState(() => _imageBytes = compressed);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<String> _generateStudentCode() async {
    final year = DateTime.now().year;
    final baseCount = DatabaseService.getAllStudentsLocal()
        .where((s) => s.studentCode.startsWith('QA-$year-'))
        .length;
    final nextNum = baseCount + 1;
    return 'QA-$year-${nextNum.toString().padLeft(3, '0')}';
  }

  Future<void> _save({bool addAnother = false}) async {
    // Validate form & focus first invalid field if validation fails
    if (!_formKey.currentState!.validate()) {
      if (_nameC.text.trim().isEmpty) {
        _nameFocusNode.requestFocus();
      } else if (_fatherC.text.trim().isEmpty) {
        _fatherFocusNode.requestFocus();
      } else if (_phoneC.text.trim().isEmpty) {
        _phoneFocusNode.requestFocus();
      }
      return;
    }

    if (_selectedSubjectSchedules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one subject and schedule.'), backgroundColor: Colors.orange)
      );
      return;
    }

    final nameToSave = _nameC.text.trim();
    setState(() => _isSaving = true);

    try {
      final studentId = DateTime.now().millisecondsSinceEpoch.toString();
      final studentCode = await _generateStudentCode();
      String picUrl = '';
      
      if (_imageBytes != null) {
        picUrl = 'data:image/jpeg;base64,${base64Encode(_imageBytes!)}';
        if (!kIsWeb) {
          try {
            await ImageUtils.saveImageLocally(studentId, _imageBytes!);
          } catch (e) {
            debugPrint('Local image save error: $e');
          }
        }
        
        unawaited(() async {
          try {
            final fileName = 'students/profile_${studentId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
            final storageRef = FirebaseStorage.instance.ref().child(fileName);
            await storageRef
                .putData(_imageBytes!, SettableMetadata(contentType: 'image/jpeg'))
                .timeout(const Duration(seconds: 10));
            final url = await storageRef.getDownloadURL().timeout(const Duration(seconds: 5));
            final currentStudent = DatabaseService.studentBox.get(studentId);
            if (currentStudent != null) {
              final updated = currentStudent.copyWith(profilePicUrl: url);
              await DatabaseService.updateStudent(updated);
            }
          } catch (e) {
            debugPrint('Background storage upload error: $e');
          }
        }());
      }
      final initialFee = double.tryParse(_feeSubC.text.trim()) ?? 0;
      
      Map<String, double> subjectPayments = {};
      for (final sub in _selectedSubjectSchedules.keys) {
        subjectPayments[sub] = double.tryParse(_getPaidControllerForSubject(sub).text.trim()) ?? 0;
      }

      final student = StudentModel(
        id: studentId,
        studentCode: studentCode,
        firstName: nameToSave,
        fatherName: _fatherC.text.trim(),
        lastName: '',
        phone: _phoneC.text.trim(),
        email: _emailC.text.trim(),
        schedule: _selectedSubjectSchedules.entries.map((e) => '${e.key}: ${e.value}').join(', '),
        classType: _selectedClassType,
        grade: _selectedGrade,
        subject: _selectedSubjectSchedules.keys.join(', '),
        feeSubmitted: initialFee,
        feeRemaining: double.tryParse(_feeRemC.text.trim()) ?? 0,
        biologyFee: _selectedSubjectSchedules.containsKey('Biology') ? (double.tryParse(_bioC.text.trim()) ?? 0) : 0,
        physicsFee: _selectedSubjectSchedules.containsKey('Physics') ? (double.tryParse(_phyC.text.trim()) ?? 0) : 0,
        chemistryFee: _selectedSubjectSchedules.containsKey('Chemistry') ? (double.tryParse(_chemC.text.trim()) ?? 0) : 0,
        englishFee: _selectedSubjectSchedules.containsKey('English') ? (double.tryParse(_engC.text.trim()) ?? 0) : 0,
        mathFee: _selectedSubjectSchedules.containsKey('Math') ? (double.tryParse(_mathC.text.trim()) ?? 0) : 0,
        profilePicUrl: picUrl,
        subjectPaymentsJson: jsonEncode(subjectPayments),
        subjectSchedulesJson: jsonEncode(_selectedSubjectSchedules),
        paymentHistoryJson: initialFee > 0
            ? jsonEncode([{
                'date': DateTime.now().toIso8601String(),
                'amount': initialFee,
                'note': 'Registration Payment (Distributed)',
              }])
            : null,
      );
      await DatabaseService.addStudent(student);
      SoundService.playSuccess();
      
      await NotificationService.createStudentRegistrationNotification(student: student);

      String? qrToken;
      try {
        final authResult = await StudentAuthService.createStudentAuthRecord(
          studentId: studentId,
          studentCode: studentCode,
          studentName: nameToSave,
        );
        qrToken = authResult['qrToken'];
      } catch (authError) {
        debugPrint('Student auth setup failed (non-fatal): $authError');
      }

      if (mounted) {
        if (qrToken != null) {
          await _showStudentQrDialog(
            studentName: nameToSave,
            studentCode: studentCode,
            qrToken: qrToken,
          );
        }

        if (addAnother) {
          _resetFormForNextStudent();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Student "$nameToSave" saved! Focused on Name field for next student.'),
              backgroundColor: AppTheme.secondaryGreen,
            ),
          );
        } else {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to create student: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showStudentQrDialog({
    required String studentName,
    required String studentCode,
    required String qrToken,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CelebrationOverlay(
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            maxWidth: 480,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF0F4FF), Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryGreen.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_rounded, color: AppTheme.secondaryGreen, size: 36),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Student Registered!',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryDarkBlue),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      studentName,
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: QrImageView(
                        data: jsonEncode({
                          'type': 'student_access',
                          'version': 1,
                          'studentCode': studentCode,
                          'token': qrToken,
                        }),
                        version: QrVersions.auto,
                        size: 180,
                        gapless: true,
                        errorCorrectionLevel: QrErrorCorrectLevel.M,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: AppTheme.primaryDarkBlue,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Student Login Code',
                            style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            studentCode,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.accentOrange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.accentOrange.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline_rounded, color: AppTheme.accentOrange, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Give this to the student:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.accentOrange),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text('① Student scans this QR code', style: TextStyle(fontSize: 12)),
                          const Text('② Then types their Login Code above', style: TextStyle(fontSize: 12)),
                          const Text('③ Portal access is granted!', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          'Done',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryBlue,
        ),
      ),
    );
  }

  Widget _buildSingleStudentForm() {
    final activeSubs = _subjects.where((s) => _selectedSubjectSchedules.containsKey(s)).toList();
    final firstFeeFocus = activeSubs.isNotEmpty ? _getFeeFocusForSubject(activeSubs.first) : _feeSubFocusNode;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
          if (!_isSaving) _save(addAnother: true);
        },
        const SingleActivator(LogicalKeyboardKey.numpadEnter, control: true): () {
          if (!_isSaving) _save(addAnother: true);
        },
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          if (!_isSaving) _save(addAnother: false);
        },
      },
      child: Focus(
        autofocus: true,
        child: Stack(children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _showImageSheet,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          child: _imageBytes != null
                              ? ClipOval(
                                  child: Image.memory(_imageBytes!,
                                      width: 120, height: 120, fit: BoxFit.cover))
                              : const Icon(Icons.person_rounded, size: 60, color: AppTheme.primaryBlue),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: AppTheme.primaryBlue,
                            child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                _sectionTitle('Personal Information'),
                TextFormField(
                  controller: _nameC,
                  focusNode: _nameFocusNode,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  onFieldSubmitted: (_) => _fatherFocusNode.requestFocus(),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _fatherC,
                  focusNode: _fatherFocusNode,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Father Name *',
                    prefixIcon: Icon(Icons.family_restroom_rounded),
                  ),
                  onFieldSubmitted: (_) => _phoneFocusNode.requestFocus(),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _phoneC,
                        focusNode: _phoneFocusNode,
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone *',
                          prefixIcon: Icon(Icons.phone_android_rounded),
                        ),
                        onFieldSubmitted: (_) => _emailFocusNode.requestFocus(),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _emailC,
                        focusNode: _emailFocusNode,
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email (optional)',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        onFieldSubmitted: (_) => _classTypeFocusNode.requestFocus(),
                        validator: (v) {
                          if (v != null && v.isNotEmpty && !v.contains('@')) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),

                _sectionTitle('Class Information'),
                Focus(
                  focusNode: _classTypeFocusNode,
                  child: DropdownButtonFormField<String>(
                    value: _selectedClassType,
                    decoration: const InputDecoration(
                      labelText: 'Class Type *',
                      prefixIcon: Icon(Icons.category_rounded),
                    ),
                    items: _classTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _selectedClassType = v;
                          _selectedGrade = _gradeOptions[v]!.first;
                        });
                        _gradeFocusNode.requestFocus();
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),

                Focus(
                  focusNode: _gradeFocusNode,
                  child: DropdownButtonFormField<String>(
                    value: _selectedGrade,
                    decoration: const InputDecoration(
                      labelText: 'Grade / Year *',
                      prefixIcon: Icon(Icons.school_rounded),
                    ),
                    items: _gradeOptions[_selectedClassType]!
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedGrade = v);
                        firstFeeFocus.requestFocus();
                      }
                    },
                  ),
                ),
                const SizedBox(height: 24),

                _buildSubjectSelection(),
                const SizedBox(height: 16),

                _sectionTitle('Fee Structure (Rs)'),
                ..._buildDynamicFeeFields(),
                const SizedBox(height: 12),
                _feeField('Total Fee Submitted', _feeSubC, _feeSubFocusNode, _feeRemFocusNode, AppTheme.primaryBlue),
                const SizedBox(height: 12),
                _feeField('Total Fee Remaining', _feeRemC, _feeRemFocusNode, null, Colors.red, isFinalField: true),

                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSaving ? null : () => _save(addAnother: true),
                        icon: const Icon(Icons.library_add_rounded),
                        label: const Text('SAVE & ADD ANOTHER (Ctrl+Enter)'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : () => _save(addAnother: false),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isSaving
                            ? const SpinKitThreeBounce(color: Colors.white, size: 20)
                            : const Text('REGISTER STUDENT (Ctrl+S)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
        if (_isSaving)
          Container(
            color: Colors.black.withValues(alpha: 0.1),
            child: const Center(
              child: SpinKitPulse(color: AppTheme.primaryBlue, size: 60),
            ),
          ),
      ]),
    ),
    );
  }

  Widget _feeField(
    String label,
    TextEditingController c,
    FocusNode focusNode,
    FocusNode? nextFocusNode,
    Color color, {
    bool isFinalField = false,
  }) {
    return TextFormField(
      controller: c,
      focusNode: focusNode,
      textInputAction: isFinalField ? TextInputAction.done : TextInputAction.next,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
        _StripLeadingZeroFormatter(),
      ],
      decoration: InputDecoration(
        labelText: label,
        prefixText: 'Rs ',
        prefixStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
        prefixIcon: Icon(Icons.payments_rounded, color: color, size: 18),
        hintText: '0',
      ),
      onFieldSubmitted: (_) {
        if (isFinalField) {
          _save(addAnother: false);
        } else if (nextFocusNode != null) {
          nextFocusNode.requestFocus();
        }
      },
    );
  }

  Widget _buildModeSwitcherHeader() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildModeTabItem(
                  index: 0,
                  icon: Icons.person_add_rounded,
                  label: 'Single Admission',
                ),
              ),
              Expanded(
                child: _buildModeTabItem(
                  index: 1,
                  icon: Icons.grid_on_rounded,
                  label: 'Bulk Excel Mode',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeTabItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _currentModeIndex == index;
    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          setState(() => _currentModeIndex = index);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Admission'),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildModeSwitcherHeader(),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _currentModeIndex == 0
                  ? _buildSingleStudentForm()
                  : BulkStudentRegistrationWidget(
                      presetClassType: widget.presetClassType,
                      presetSubject: widget.presetSubject,
                      presetGrade: widget.presetGrade,
                      presetSchedule: widget.presetSchedule,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StripLeadingZeroFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text;
    if (text.length > 1 && text.startsWith('0') && !text.startsWith('0.')) {
      text = text.replaceFirst(RegExp(r'^0+'), '');
      if (text.isEmpty) text = '0';
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    return newValue;
  }
}
