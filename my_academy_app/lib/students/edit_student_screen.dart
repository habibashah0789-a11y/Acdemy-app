import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/student_model.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../widgets/crop_image_dialog.dart';
import '../theme/app_theme.dart';

class EditStudentScreen extends StatefulWidget {
  final StudentModel student;
  const EditStudentScreen({super.key, required this.student});

  @override
  State<EditStudentScreen> createState() => _EditStudentScreenState();
}

class _EditStudentScreenState extends State<EditStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameC, _fatherC, _phoneC, _emailC, _feeSubC, _feeRemC, _bioC, _phyC, _chemC, _engC, _mathC;
  Uint8List? _imageBytes;
  late String _existingUrl;
  bool _isSaving = false;

  // Dropdown values
  late String _selectedClassType;
  late String _selectedGrade;
  late String _selectedSubject;
  late String _selectedSchedule;

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
    _existingUrl = s.profilePicUrl;

    _selectedClassType = _classTypes.contains(s.classType) ? s.classType : 'FSc';
    _selectedGrade = (_gradeOptions[_selectedClassType] ?? []).contains(s.grade)
        ? s.grade
        : (_gradeOptions[_selectedClassType]!.first);
    _selectedSubject = _subjects.contains(s.subject) ? s.subject : 'Biology';
    _selectedSchedule = _scheduleSlots.contains(s.schedule) ? s.schedule : '7:00 AM';
  }

  @override
  void dispose() {
    _nameC.dispose(); _fatherC.dispose(); _phoneC.dispose(); _emailC.dispose();
    _feeSubC.dispose(); _feeRemC.dispose();
    _bioC.dispose(); _phyC.dispose(); _chemC.dispose(); _engC.dispose(); _mathC.dispose();
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
      
      // Upload new image to Firebase Storage if provided
      if (_imageBytes != null) {
        try {
          // Delete old image if exists
          if (_existingUrl.isNotEmpty) await DatabaseService.deleteImage(_existingUrl);
          
          final fileName = 'students/profile_${widget.student.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final storageRef = FirebaseStorage.instance.ref().child(fileName);
          
          // Upload with timeout to prevent hanging
          await storageRef
              .putData(_imageBytes!, SettableMetadata(contentType: 'image/jpeg'))
              .timeout(const Duration(seconds: 30));
          
          // Get download URL
          picUrl = await storageRef.getDownloadURL().timeout(const Duration(seconds: 10));
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
          // Don't proceed with update if image upload fails
          setState(() => _isSaving = false);
          return;
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

      final updated = StudentModel(
        id: widget.student.id,
        firstName: _nameC.text.trim(),
        fatherName: _fatherC.text.trim(),
        lastName: widget.student.lastName,
        phone: _phoneC.text.trim(),
        email: _emailC.text.trim(),
        schedule: _selectedSchedule,
        classType: _selectedClassType,
        grade: _selectedGrade,
        subject: _selectedSubject,
        feeSubmitted: newPaid,
        feeRemaining: double.tryParse(_feeRemC.text.trim()) ?? 0,
        biologyFee: double.tryParse(_bioC.text.trim()) ?? 0,
        physicsFee: double.tryParse(_phyC.text.trim()) ?? 0,
        chemistryFee: double.tryParse(_chemC.text.trim()) ?? 0,
        englishFee: double.tryParse(_engC.text.trim()) ?? 0,
        mathFee: double.tryParse(_mathC.text.trim()) ?? 0,
        profilePicUrl: picUrl,
        createdAt: widget.student.createdAt,
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
                const SizedBox(height: 16),

                // Subject dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedSubject,
                  decoration: const InputDecoration(
                    labelText: 'Subject *',
                    prefixIcon: Icon(Icons.book_rounded),
                  ),
                  items: _subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedSubject = v);
                  },
                ),
                const SizedBox(height: 16),

                // Schedule dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedSchedule,
                  decoration: const InputDecoration(
                    labelText: 'Class Schedule *',
                    prefixIcon: Icon(Icons.access_time_rounded),
                  ),
                  items: _scheduleSlots.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedSchedule = v);
                  },
                ),

                _sectionTitle('Fee Structure (Rs)'),
                Row(
                  children: [
                    Expanded(child: _feeField('Biology Fee', _bioC, Colors.green)),
                    const SizedBox(width: 12),
                    Expanded(child: _feeField('Physics Fee', _phyC, Colors.blue)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _feeField('Chemistry Fee', _chemC, Colors.orange)),
                    const SizedBox(width: 12),
                    Expanded(child: _feeField('English Fee', _engC, Colors.purple)),
                  ],
                ),
                const SizedBox(height: 12),
                _feeField('Math Fee', _mathC, const Color(0xFF00897B)),
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
