import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/student_model.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../widgets/crop_image_dialog.dart';
import '../theme/app_theme.dart';
import '../utils/image_utils.dart';

class EditStudentScreen extends StatefulWidget {
  final StudentModel student;
  const EditStudentScreen({super.key, required this.student});

  @override
  State<EditStudentScreen> createState() => _EditStudentScreenState();
}

class _EditStudentScreenState extends State<EditStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameC, _fatherC, _phoneC, _emailC, _feeSubC, _feeRemC, _bioC, _phyC, _chemC, _engC, _mathC;
  late final TextEditingController _bioPaidC, _phyPaidC, _chemPaidC, _engPaidC, _mathPaidC;
  Uint8List? _imageBytes;
  late String _existingUrl;
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
    final s = widget.student;
    _nameC = TextEditingController(text: s.name);
    _fatherC = TextEditingController(text: s.fatherName);
    _phoneC = TextEditingController(text: s.phone);
    _emailC = TextEditingController(text: s.email);
    _feeSubC = TextEditingController(text: s.feeSubmitted.toStringAsFixed(0));
    _feeRemC = TextEditingController(text: s.feeRemaining.toStringAsFixed(0));
    _bioC = TextEditingController(text: s.biologyFee.toStringAsFixed(0));
    _phyC = TextEditingController(text: s.physicsFee.toStringAsFixed(0));
    _chemC = TextEditingController(text: s.chemistryFee.toStringAsFixed(0));
    _engC = TextEditingController(text: s.englishFee.toStringAsFixed(0));
    _mathC = TextEditingController(text: s.mathFee.toStringAsFixed(0));

    final payments = s.subjectPayments;
    _bioPaidC = TextEditingController(text: (payments['Biology'] ?? 0).toStringAsFixed(0));
    _phyPaidC = TextEditingController(text: (payments['Physics'] ?? 0).toStringAsFixed(0));
    _chemPaidC = TextEditingController(text: (payments['Chemistry'] ?? 0).toStringAsFixed(0));
    _engPaidC = TextEditingController(text: (payments['English'] ?? 0).toStringAsFixed(0));
    _mathPaidC = TextEditingController(text: (payments['Math'] ?? 0).toStringAsFixed(0));

    _existingUrl = s.profilePicUrl;

    _selectedClassType = _classTypes.contains(s.classType) ? s.classType : 'FSc';
    _selectedGrade = (_gradeOptions[_selectedClassType] ?? []).contains(s.grade)
        ? s.grade
        : (_gradeOptions[_selectedClassType]!.first);
    
    // Load student's subject schedules
    _selectedSubjectSchedules = Map<String, String>.from(s.subjectSchedules);

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
    
    for (final sub in activeSubs) {
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
                  Expanded(child: _feeField('Total Fee', _getFeeControllerForSubject(sub), _getSubjectColor(sub))),
                  const SizedBox(width: 12),
                  Expanded(child: _feeField('Paid amount', _getPaidControllerForSubject(sub), Colors.green)),
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
    _nameC.dispose(); _fatherC.dispose(); _phoneC.dispose(); _emailC.dispose();
    _feeSubC.dispose(); _feeRemC.dispose();
    _bioC.dispose(); _phyC.dispose(); _chemC.dispose(); _engC.dispose(); _mathC.dispose();
    _bioPaidC.dispose(); _phyPaidC.dispose(); _chemPaidC.dispose(); _engPaidC.dispose(); _mathPaidC.dispose();
    super.dispose();
  }

  void _showImageSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Change Profile Picture', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.primaryBlue)),
          const SizedBox(height: 16),
          ListTile(
            leading: CircleAvatar(backgroundColor: Colors.blue.shade50, child: const Icon(Icons.camera_alt, color: AppTheme.primaryBlue)),
            title: const Text('Camera'),
            onTap: () { Navigator.pop(ctx); _pick(ImageSource.camera); },
          ),
          ListTile(
            leading: CircleAvatar(backgroundColor: Colors.green.shade50, child: const Icon(Icons.photo_library, color: Colors.green)),
            title: const Text('Gallery'),
            onTap: () { Navigator.pop(ctx); _pick(ImageSource.gallery); },
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _update() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      String picUrl = _existingUrl;
      
      // Upload new image to Firebase Storage and save locally if provided
      if (_imageBytes != null) {
        if (!kIsWeb) {
          try {
            await ImageUtils.saveImageLocally(widget.student.id, _imageBytes!);
          } catch (e) {
            debugPrint('Local image save error: $e');
          }
        }
        
        try {
          if (_existingUrl.isNotEmpty && _existingUrl.startsWith('http')) {
            await DatabaseService.deleteImage(_existingUrl);
          }
          
          final fileName = 'students/profile_${widget.student.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final storageRef = FirebaseStorage.instance.ref().child(fileName);
          
          await storageRef
              .putData(_imageBytes!, SettableMetadata(contentType: 'image/jpeg'))
              .timeout(const Duration(seconds: 15));
          
          picUrl = await storageRef.getDownloadURL().timeout(const Duration(seconds: 8));
          debugPrint('Image uploaded to Firebase Storage: $picUrl');
        } catch (uploadError) {
          debugPrint('Firebase Storage upload failed: $uploadError. Falling back to base64 encoding.');
          final base64String = base64Encode(_imageBytes!);
          picUrl = 'data:image/jpeg;base64,$base64String';
        }
      }
      double oldPaid = widget.student.feeSubmitted;
      double newPaid = double.tryParse(_feeSubC.text.trim()) ?? 0;
      String? historyJson = widget.student.paymentHistoryJson;
      List<dynamic> history = [];
      if (historyJson != null && historyJson.isNotEmpty) {
        try {
          history = jsonDecode(historyJson);
        } catch (e) {
          debugPrint('Error decoding payment history: $e');
        }
      }

      if (history.isEmpty && oldPaid > 0) {
        history.add({
          'date': widget.student.createdAt.toIso8601String(),
          'amount': oldPaid,
          'note': 'Registration Payment',
        });
      }

      if (newPaid != oldPaid) {
        double diff = newPaid - oldPaid;
        history.add({
          'date': DateTime.now().toIso8601String(),
          'amount': diff,
          'note': diff > 0 ? 'Additional Payment' : 'Adjustment',
        });
      }

      if (_selectedSubjectSchedules.isEmpty) {
        throw 'Please select at least one subject and schedule.';
      }

      Map<String, double> subjectPayments = {};
      for (final sub in _selectedSubjectSchedules.keys) {
        subjectPayments[sub] = double.tryParse(_getPaidControllerForSubject(sub).text.trim()) ?? 0;
      }

      final updated = StudentModel(
        id: widget.student.id,
        firstName: _nameC.text.trim(),
        fatherName: _fatherC.text.trim(),
        lastName: widget.student.lastName,
        phone: _phoneC.text.trim(),
        email: _emailC.text.trim(),
        schedule: _selectedSubjectSchedules.entries.map((e) => '${e.key}: ${e.value}').join(', '),
        classType: _selectedClassType,
        grade: _selectedGrade,
        subject: _selectedSubjectSchedules.keys.join(', '),
        feeSubmitted: newPaid,
        feeRemaining: double.tryParse(_feeRemC.text.trim()) ?? 0,
        biologyFee: _selectedSubjectSchedules.containsKey('Biology') ? (double.tryParse(_bioC.text.trim()) ?? 0) : 0,
        physicsFee: _selectedSubjectSchedules.containsKey('Physics') ? (double.tryParse(_phyC.text.trim()) ?? 0) : 0,
        chemistryFee: _selectedSubjectSchedules.containsKey('Chemistry') ? (double.tryParse(_chemC.text.trim()) ?? 0) : 0,
        englishFee: _selectedSubjectSchedules.containsKey('English') ? (double.tryParse(_engC.text.trim()) ?? 0) : 0,
        mathFee: _selectedSubjectSchedules.containsKey('Math') ? (double.tryParse(_mathC.text.trim()) ?? 0) : 0,
        profilePicUrl: picUrl,
        createdAt: widget.student.createdAt,
        subjectPaymentsJson: jsonEncode(subjectPayments),
        subjectSchedulesJson: jsonEncode(_selectedSubjectSchedules),
        paymentHistoryJson: history.isNotEmpty ? jsonEncode(history) : null,
      );
      await DatabaseService.updateStudent(updated);
      
      // Trigger Notification if payment was made
      if (newPaid > oldPaid) {
        final isSecond = history.length == 2;
        await NotificationService.createFeePaymentNotification(
          student: updated,
          amount: newPaid - oldPaid,
          isSecondInstallment: isSecond,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
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
      appBar: AppBar(title: const Text('Edit Student')),
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
                              ? ClipOval(child: Image.memory(_imageBytes!, width: 120, height: 120, fit: BoxFit.cover))
                              : _existingUrl.isNotEmpty
                                  ? ClipOval(child: CachedNetworkImage(imageUrl: _existingUrl, width: 120, height: 120, fit: BoxFit.cover, placeholder: (_, __) => const Icon(Icons.person, size: 60)))
                                  : const Icon(Icons.person_rounded, size: 60, color: AppTheme.primaryBlue),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: AppTheme.primaryBlue,
                            child: const Icon(Icons.edit_rounded, size: 18, color: Colors.white),
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
                    decoration: const InputDecoration(labelText: 'Full Name *', prefixIcon: Icon(Icons.person_outline_rounded)),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                const SizedBox(height: 16),
                TextFormField(
                    controller: _fatherC,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Father Name *', prefixIcon: Icon(Icons.family_restroom_rounded)),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                const SizedBox(height: 16),
                TextFormField(
                    controller: _phoneC,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone *', prefixIcon: Icon(Icons.phone_android_rounded)),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                const SizedBox(height: 16),
                TextFormField(
                    controller: _emailC,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email (optional)', prefixIcon: Icon(Icons.email_outlined)),
                    validator: (v) { if (v != null && v.isNotEmpty && !v.contains('@')) return 'Invalid Email'; return null; }),

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
                SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: _isSaving ? null : _update,
                  child: _isSaving ? const SpinKitThreeBounce(color: Colors.white, size: 20) : const Text('UPDATE STUDENT'),
                )),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
        if (_isSaving) Container(color: Colors.black.withValues(alpha: 0.1), child: const Center(child: SpinKitPulse(color: AppTheme.primaryBlue, size: 60))),
      ]),
    );
  }

  Widget _feeField(String label, TextEditingController c, Color color) {
    return TextFormField(
      controller: c,
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
