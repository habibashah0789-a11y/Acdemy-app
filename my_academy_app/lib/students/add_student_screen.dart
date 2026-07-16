import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../models/student_model.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

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
  final _scheduleC = TextEditingController();
  Uint8List? _imageBytes;
  bool _isSaving = false;

  // Dropdown values
  late String _selectedClassType;
  late String _selectedGrade;
  late String _selectedSubject;
  int? _startSlotIdx;
  int? _endSlotIdx;

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
    _selectedSubject = widget.presetSubject ?? 'Biology';
    _scheduleC.text = widget.presetSchedule ?? '7:00 AM';
    _parseSchedule(_scheduleC.text);
  }

  void _parseSchedule(String text) {
    if (text.contains('-') || text.contains('—')) {
      final parts = text.split(RegExp(r'[-—]'));
      if (parts.length == 2) {
        final start = parts[0].trim();
        final end = parts[1].trim();
        final startIdx = _scheduleSlots.indexOf(start);
        final endIdx = _scheduleSlots.indexOf(end);
        if (startIdx != -1 && endIdx != -1) {
          _startSlotIdx = startIdx;
          _endSlotIdx = endIdx;
          return;
        }
      }
    }
    final idx = _scheduleSlots.indexOf(text.trim());
    if (idx != -1) {
      _startSlotIdx = idx;
      _endSlotIdx = null;
    }
  }

  void _onSlotTapped(int index) {
    setState(() {
      if (_startSlotIdx == null || (_startSlotIdx != null && _endSlotIdx != null)) {
        _startSlotIdx = index;
        _endSlotIdx = null;
        _scheduleC.text = _scheduleSlots[index];
      } else {
        if (index >= _startSlotIdx!) {
          _endSlotIdx = index;
          _scheduleC.text = '${_scheduleSlots[_startSlotIdx!]} - ${_scheduleSlots[_endSlotIdx!]}';
        } else {
          _startSlotIdx = index;
          _endSlotIdx = null;
          _scheduleC.text = _scheduleSlots[index];
        }
      }
    });
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
    _scheduleC.dispose();
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
        if (mounted) setState(() => _imageBytes = bytes);
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
    setState(() => _isSaving = true);
    try {
      String picUrl = '';
      if (_imageBytes != null) {
        String? u = await DatabaseService.uploadImage(_imageBytes!, 'students');
        if (u != null) picUrl = u;
      }
      final student = StudentModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        firstName: _nameC.text.trim(),
        fatherName: _fatherC.text.trim(),
        lastName: '',
        phone: _phoneC.text.trim(),
        email: _emailC.text.trim(),
        schedule: _scheduleC.text.trim(),
        classType: _selectedClassType,
        grade: _selectedGrade,
        subject: _selectedSubject,
        feeSubmitted: double.tryParse(_feeSubC.text.trim()) ?? 0,
        feeRemaining: double.tryParse(_feeRemC.text.trim()) ?? 0,
        biologyFee: double.tryParse(_bioC.text.trim()) ?? 0,
        physicsFee: double.tryParse(_phyC.text.trim()) ?? 0,
        chemistryFee: double.tryParse(_chemC.text.trim()) ?? 0,
        englishFee: double.tryParse(_engC.text.trim()) ?? 0,
        mathFee: double.tryParse(_mathC.text.trim()) ?? 0,
        profilePicUrl: picUrl,
      );
      await DatabaseService.addStudent(student);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed: $e'), backgroundColor: Colors.red));
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

                // Schedule input and scrollable slot row
                TextFormField(
                  controller: _scheduleC,
                  decoration: const InputDecoration(
                    labelText: 'Class Schedule *',
                    prefixIcon: Icon(Icons.access_time_rounded),
                    hintText: 'e.g., 7:00 AM - 10:00 AM',
                  ),
                  onChanged: (v) {
                    setState(() {
                      _parseSchedule(v);
                    });
                  },
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _scheduleSlots.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final isSelected = (_endSlotIdx != null)
                          ? (index >= _startSlotIdx! && index <= _endSlotIdx!)
                          : (index == _startSlotIdx);
                      final color = AppTheme.primaryBlue;

                      return GestureDetector(
                        onTap: () => _onSlotTapped(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? color : color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isSelected ? color : color.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            _scheduleSlots[index],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : color,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

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
