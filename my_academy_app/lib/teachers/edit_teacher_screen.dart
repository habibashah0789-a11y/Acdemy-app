import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../models/teacher_model.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class EditTeacherScreen extends StatefulWidget {
  final TeacherModel teacher;
  const EditTeacherScreen({super.key, required this.teacher});

  @override
  State<EditTeacherScreen> createState() => _EditTeacherScreenState();
}

class _EditTeacherScreenState extends State<EditTeacherScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameC, _phoneC, _emailC, _salaryC;
  late String _selectedSubject;
  Uint8List? _imageBytes;
  late String _existingUrl;
  bool _isSaving = false;

  final List<Map<String, dynamic>> _subjects = [
    {'name': 'Biology', 'color': Colors.green},
    {'name': 'Physics', 'color': Colors.blue},
    {'name': 'Chemistry', 'color': Colors.orange},
    {'name': 'English', 'color': Colors.purple},
  ];

  Color get _subjColor => (_subjects.firstWhere((s) => s['name'] == _selectedSubject))['color'] as Color;

  @override
  void initState() {
    super.initState();
    final t = widget.teacher;
    _nameC = TextEditingController(text: t.name);
    _phoneC = TextEditingController(text: t.phone);
    _emailC = TextEditingController(text: t.email);
    _salaryC = TextEditingController(text: t.salary.toStringAsFixed(0));
    _selectedSubject = t.subject;
    _existingUrl = t.profilePicUrl;
  }

  @override
  void dispose() {
    _nameC.dispose(); _phoneC.dispose(); _emailC.dispose(); _salaryC.dispose();
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
        if (mounted) setState(() => _imageBytes = bytes);
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
      if (_imageBytes != null) {
        if (_existingUrl.isNotEmpty) await DatabaseService.deleteImage(_existingUrl);
        String? u = await DatabaseService.uploadImage(_imageBytes!, 'teachers');
        if (u != null) picUrl = u;
      }
      final updated = TeacherModel(
        id: widget.teacher.id, name: _nameC.text.trim(),
        phone: _phoneC.text.trim(), email: _emailC.text.trim(),
        subject: _selectedSubject,
        salary: double.tryParse(_salaryC.text.trim()) ?? 0,
        profilePicUrl: picUrl,
      );
      await DatabaseService.updateTeacher(updated);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Faculty')),
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
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(shape: BoxShape.circle, color: _subjColor.withOpacity(0.5)),
                          child: CircleAvatar(
                            radius: 60, backgroundColor: Colors.white,
                            child: _imageBytes != null
                              ? ClipOval(child: Image.memory(_imageBytes!, width: 120, height: 120, fit: BoxFit.cover))
                              : _existingUrl.isNotEmpty
                                  ? ClipOval(child: CachedNetworkImage(imageUrl: _existingUrl, width: 120, height: 120, fit: BoxFit.cover, placeholder: (_, __) => Icon(Icons.person, size: 60, color: _subjColor)))
                                  : Icon(Icons.person_rounded, size: 60, color: _subjColor),
                          ),
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
                
                Text('Faculty Information', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                const SizedBox(height: 20),
                
                TextFormField(controller: _nameC, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline_rounded)), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                const SizedBox(height: 16),
                TextFormField(controller: _phoneC, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_android_rounded)), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                const SizedBox(height: 16),
                TextFormField(controller: _emailC, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)), validator: (v) { if (v != null && v.isNotEmpty && !v.contains('@')) return 'Invalid Email'; return null; }),
                const SizedBox(height: 16),
                
                DropdownButtonFormField<String>(
                  value: _selectedSubject,
                  decoration: const InputDecoration(labelText: 'Primary Subject', prefixIcon: Icon(Icons.book_outlined)),
                  items: _subjects.map((s) {
                    return DropdownMenuItem(value: s['name'] as String, child: Row(children: [
                      Container(width: 12, height: 12, decoration: BoxDecoration(color: s['color'] as Color, shape: BoxShape.circle)),
                      const SizedBox(width: 12),
                      Text(s['name'] as String),
                    ]));
                  }).toList(),
                  onChanged: (v) { if (v != null) setState(() => _selectedSubject = v); },
                ),
                const SizedBox(height: 16),
                TextFormField(controller: _salaryC, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Monthly Salary (Rs)', prefixIcon: Icon(Icons.payments_outlined)), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),

                const SizedBox(height: 40),
                SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: _isSaving ? null : _update,
                  child: _isSaving ? const SpinKitThreeBounce(color: Colors.white, size: 20) : const Text('UPDATE FACULTY'),
                )),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
        if (_isSaving) Container(color: Colors.black.withOpacity(0.1), child: const Center(child: SpinKitPulse(color: AppTheme.primaryBlue, size: 60))),
      ]),
    );
  }
}
