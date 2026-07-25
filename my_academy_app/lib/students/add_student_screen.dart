import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import '../models/student_model.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../widgets/crop_image_dialog.dart';
import '../theme/app_theme.dart';
import '../utils/image_utils.dart';

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
    
    _bioC.text = '0';
    _phyC.text = '0';
    _chemC.text = '0';
    _engC.text = '0';
    _mathC.text = '0';
    _feeSubC.text = '0';
    _feeRemC.text = '0';

    // Add listeners to auto-calculate remaining fee
    _bioC.addListener(_updateCalculatedFees);
    _phyC.addListener(_updateCalculatedFees);
    _chemC.addListener(_updateCalculatedFees);
    _engC.addListener(_updateCalculatedFees);
    _mathC.addListener(_updateCalculatedFees);
    _feeSubC.addListener(_updateCalculatedFees);
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

  void _updateCalculatedFees() {
    double total = 0;
    for (final sub in _subjects) {
      if (_selectedSubjectSchedules.containsKey(sub)) {
        total += double.tryParse(_getFeeControllerForSubject(sub).text.trim()) ?? 0;
      }
    }
    double submitted = double.tryParse(_feeSubC.text.trim()) ?? 0;
    double remaining = total - submitted;
    if (remaining < 0) remaining = 0;
    _feeRemC.text = remaining.toStringAsFixed(0);
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
    
    for (int i = 0; i < activeSubs.length; i += 2) {
      if (i + 1 < activeSubs.length) {
        final sub1 = activeSubs[i];
        final sub2 = activeSubs[i + 1];
        fields.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              children: [
                Expanded(child: _feeField('$sub1 Fee', _getFeeControllerForSubject(sub1), _getSubjectColor(sub1))),
                const SizedBox(width: 12),
                Expanded(child: _feeField('$sub2 Fee', _getFeeControllerForSubject(sub2), _getSubjectColor(sub2))),
              ],
            ),
          ),
        );
      } else {
        final sub = activeSubs[i];
        fields.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: _feeField('$sub Fee', _getFeeControllerForSubject(sub), _getSubjectColor(sub)),
          ),
        );
      }
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
            setState(() => _imageBytes = cropped);
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSubjectSchedules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one subject and schedule.'), backgroundColor: Colors.orange)
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final studentId = DateTime.now().millisecondsSinceEpoch.toString();
      String picUrl = '';
      
      // Upload image to Firebase Storage and save locally if provided
      if (_imageBytes != null) {
        try {
          // 1. Save image locally on device (for faster local access)
          if (!kIsWeb) {
            await ImageUtils.saveImageLocally(studentId, _imageBytes!);
          }
          
          // 2. Upload to Firebase Storage (for cross-device access)
          final fileName = 'students/profile_${studentId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final storageRef = FirebaseStorage.instance.ref().child(fileName);
          
          // Upload with timeout to prevent hanging
          await storageRef
              .putData(_imageBytes!, SettableMetadata(contentType: 'image/jpeg'))
              .timeout(const Duration(seconds: 30));
          
          // Get download URL
          picUrl = await storageRef.getDownloadURL().timeout(const Duration(seconds: 10));
          debugPrint('Image uploaded to Firebase Storage: $picUrl');
        } catch (uploadError) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Image upload failed. Please check your internet connection and try again.'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 4),
              ),
            );
          }
          // Don't proceed with student creation if image upload fails
          setState(() => _isSaving = false);
          return;
        }
      }
      final initialFee = double.tryParse(_feeSubC.text.trim()) ?? 0;
      final student = StudentModel(
        id: studentId,
        firstName: _nameC.text.trim(),
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
        subjectSchedulesJson: jsonEncode(_selectedSubjectSchedules),
        paymentHistoryJson: initialFee > 0
            ? jsonEncode([{
                'date': DateTime.now().toIso8601String(),
                'amount': initialFee,
                'note': 'Registration Payment',
              }])
            : null,
      );
      await DatabaseService.addStudent(student);
      
      // Trigger Notification
      await NotificationService.createStudentRegistrationNotification(student: student);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to create student: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Admission')),
      body: Stack(children: [
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
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                        labelText: 'Full Name *',
                        prefixIcon: Icon(Icons.person_outline_rounded)),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                const SizedBox(height: 16),
                TextFormField(
                    controller: _fatherC,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                        labelText: 'Father Name *',
                        prefixIcon: Icon(Icons.family_restroom_rounded)),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _phoneC,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                            labelText: 'Phone *',
                            prefixIcon: Icon(Icons.phone_android_rounded)),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _emailC,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                            labelText: 'Email (optional)',
                            prefixIcon: Icon(Icons.email_outlined)),
                        validator: (v) {
                          if (v != null && v.isNotEmpty && !v.contains('@')) return 'Invalid';
                          return null;
                        }),
                    ),
                  ],
                ),

                _sectionTitle('Class Information'),
                // Class Type dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedClassType,
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
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Grade dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedGrade,
                  decoration: const InputDecoration(
                    labelText: 'Grade / Year *',
                    prefixIcon: Icon(Icons.school_rounded),
                  ),
                  items: _gradeOptions[_selectedClassType]!
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedGrade = v);
                  },
                ),
                const SizedBox(height: 24),

                // Multi-subject selection
                _buildSubjectSelection(),
                const SizedBox(height: 16),

                _sectionTitle('Fee Structure (Rs)'),
                ..._buildDynamicFeeFields(),
                const SizedBox(height: 12),
                _feeField('Total Fee Submitted', _feeSubC, AppTheme.primaryBlue),
                const SizedBox(height: 12),
                _feeField('Total Fee Remaining', _feeRemC, Colors.red),

                const SizedBox(height: 40),
                SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SpinKitThreeBounce(color: Colors.white, size: 20)
                          : const Text('REGISTER STUDENT'),
                    )),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
        if (_isSaving)
          Container(
              color: Colors.black.withValues(alpha: 0.1),
              child: const Center(
                  child: SpinKitPulse(color: AppTheme.primaryBlue, size: 60))),
      ]),
    );
  }

  Widget _feeField(String label, TextEditingController c, Color color) {
    return TextFormField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
          labelText: label,
          prefixText: 'Rs ',
          prefixStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
          prefixIcon: Icon(Icons.payments_rounded, color: color, size: 18),
          hintText: '0'),
    );
  }
}
