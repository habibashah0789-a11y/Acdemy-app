import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/teacher_model.dart';
import '../../services/teacher_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/image_utils.dart';
import '../../widgets/crop_image_dialog.dart';
import '../../widgets/teacher_avatar.dart';

class AddEditTeacherScreen extends StatefulWidget {
  final TeacherModel? teacher;
  const AddEditTeacherScreen({super.key, this.teacher});

  bool get isEditing => teacher != null;

  @override
  State<AddEditTeacherScreen> createState() => _AddEditTeacherScreenState();
}

class _AddEditTeacherScreenState extends State<AddEditTeacherScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  Uint8List? _imageBytes;
  bool _removeExistingPhoto = false;

  String _selectedSection = 'FSc';
  String _selectedSubject = 'Biology';
  final List<String> _selectedClasses = [];
  bool _isActive = true;
  bool _isLoading = false;

  static const List<String> _sections = ['FSc', 'Matric'];
  static const List<String> _subjects = [
    'Biology',
    'Physics',
    'Chemistry',
    'Mathematics',
    'English',
    'Computer Science',
    'Urdu',
    'Islamiyat',
    'Pakistan Studies',
    'Arabic',
  ];

  static const Map<String, List<String>> _classesBySection = {
    'FSc': ['First Year', 'Second Year'],
    'Matric': [
      '9th Grade',
      '10th Grade',
    ],
  };

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      final t = widget.teacher!;
      _nameCtrl.text = t.name;
      _emailCtrl.text = t.email;
      _selectedSection = t.section;
      _selectedSubject = t.subject;
      _selectedClasses.addAll(t.assignedClasses);
      _isActive = t.isActive;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

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
                'Select Teacher Profile Picture',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.bold,
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
              if (_imageBytes != null || (widget.isEditing && widget.teacher!.profilePicUrl.isNotEmpty && !_removeExistingPhoto))
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red.shade50,
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  ),
                  title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _imageBytes = null;
                      if (widget.isEditing) {
                        _removeExistingPhoto = true;
                      }
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource src) async {
    try {
      final f = await ImagePicker().pickImage(source: src, imageQuality: 75);
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
              targetWidth: 360,
              targetHeight: 360,
              quality: 75,
            );
            if (mounted) {
              setState(() {
                _imageBytes = compressed;
              });
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to pick image: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  List<String> get _availableClasses =>
      _classesBySection[_selectedSection] ?? [];

  Future<void> _handleSave() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClasses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one class.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final generatedTeacherId = widget.isEditing 
          ? widget.teacher!.teacherId 
          : await TeacherService.generateTeacherId(
              section: _selectedSection,
              subject: _selectedSubject,
            );

      String finalPicUrl = '';

      if (widget.isEditing) {
        final teacherUid = widget.teacher!.id;
        if (_imageBytes != null) {
          final uploadedUrl = await TeacherService.uploadTeacherProfileImage(
            _imageBytes!,
            teacherUid,
          );

          if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
            finalPicUrl = uploadedUrl;
          } else {
            finalPicUrl = 'data:image/png;base64,${base64Encode(_imageBytes!)}';
          }
        } else if (!_removeExistingPhoto) {
          finalPicUrl = widget.teacher?.profilePicUrl ?? '';
        }

        final teacher = TeacherModel(
          id: teacherUid,
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          teacherId: generatedTeacherId,
          subject: _selectedSubject,
          section: _selectedSection,
          assignedClasses: List.from(_selectedClasses),
          profilePicUrl: finalPicUrl,
          isActive: _isActive,
          createdAt: widget.teacher!.createdAt,
        );

        await TeacherService.updateTeacher(teacher);

        if (mounted) {
          setState(() => _isLoading = false);
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${_nameCtrl.text.trim()}\'s teacher profile updated successfully.',
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        // ── Register New Teacher with Auth + Firestore (Password set by Admin) ──
        if (_imageBytes != null) {
          finalPicUrl = 'data:image/png;base64,${base64Encode(_imageBytes!)}';
        }

        final teacher = TeacherModel(
          id: '', // Generated during Auth registration
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          teacherId: generatedTeacherId,
          subject: _selectedSubject,
          section: _selectedSection,
          assignedClasses: List.from(_selectedClasses),
          profilePicUrl: finalPicUrl,
          isActive: _isActive,
          createdAt: DateTime.now(),
        );

        final newTeacherUid = await TeacherService.registerTeacherWithAuth(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text.trim(),
          teacher: teacher,
        );

        // Upload profile photo to storage if provided
        if (_imageBytes != null) {
          unawaited(() async {
            try {
              final uploadedUrl = await TeacherService.uploadTeacherProfileImage(
                _imageBytes!,
                newTeacherUid,
              );
              if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
                await TeacherService.updateTeacher(teacher.copyWith(id: newTeacherUid, profilePicUrl: uploadedUrl));
              }
            } catch (_) {}
          }());
        }

        if (mounted) {
          setState(() => _isLoading = false);
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${_nameCtrl.text.trim()} has been registered! They can log in to Teacher Portal using email: ${_emailCtrl.text.trim()} and the password you set.',
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (fe) {
      setState(() => _isLoading = false);
      String msg = 'Registration failed: ${fe.message}';
      if (fe.code == 'email-already-in-use') {
        msg = 'This email is already registered in the system.';
      } else if (fe.code == 'weak-password') {
        msg = 'The password is too weak. Please use at least 6 characters.';
      } else if (fe.code == 'invalid-email') {
        msg = 'The email address is invalid.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${e.toString().replaceFirst("Exception: ", "")}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Edit Teacher' : 'Add Teacher',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Profile Photo Picker Widget ──
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: _showImageSheet,
                          child: Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primaryBlue.withOpacity(0.1),
                              border: Border.all(
                                color: AppTheme.primaryBlue,
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryBlue.withOpacity(0.15),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: _imageBytes != null
                                  ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                                  : (widget.isEditing && widget.teacher!.profilePicUrl.isNotEmpty && !_removeExistingPhoto
                                      ? TeacherAvatar(
                                          teacher: widget.teacher!,
                                          size: 104,
                                        )
                                      : Center(
                                          child: Icon(
                                            Icons.person_rounded,
                                            size: 50,
                                            color: AppTheme.primaryBlue
                                                .withOpacity(0.7),
                                          ),
                                        )),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _showImageSheet,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBlue,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _showImageSheet,
                      icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                      label: Text(
                        _imageBytes != null ||
                                (widget.isEditing && widget.teacher!.profilePicUrl.isNotEmpty && !_removeExistingPhoto)
                            ? 'Change Profile Picture'
                            : 'Upload Profile Picture',
                        style: GoogleFonts.poppins(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Section: Basic Info ──
              _sectionHeader('Basic Information', Icons.person_rounded),
              const SizedBox(height: 12),

              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  prefixIcon: Icon(Icons.person_outline_rounded,
                      color: AppTheme.primaryBlue),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 14),


              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                enabled: !widget.isEditing,
                decoration: InputDecoration(
                  labelText: 'Email Address *',
                  prefixIcon: const Icon(Icons.email_outlined,
                      color: AppTheme.primaryBlue),
                  helperText:
                      widget.isEditing ? 'Email cannot be changed' : null,
                ),
                validator: (v) => (v == null || !v.contains('@'))
                    ? 'Enter a valid email'
                    : null,
              ),
              const SizedBox(height: 14),

              if (!widget.isEditing) ...[
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Teacher Login Password *',
                    hintText: 'Minimum 6 characters (e.g. Pass123)',
                    prefixIcon: const Icon(Icons.lock_outline_rounded,
                        color: AppTheme.primaryBlue),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: Colors.grey,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    helperText: 'Teacher will log into the Teacher Portal with this password',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Password is required for teacher portal login';
                    }
                    if (v.trim().length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
              ],


              const SizedBox(height: 8),

              // ── Section: Academic Assignment ──
              _sectionHeader('Academic Assignment', Icons.school_rounded),
              const SizedBox(height: 12),

              // Section
              DropdownButtonFormField<String>(
                value: _selectedSection,
                decoration: const InputDecoration(
                  labelText: 'Section *',
                  prefixIcon: Icon(Icons.account_balance_rounded,
                      color: AppTheme.primaryBlue),
                ),
                items: _sections
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _selectedSection = v;
                      _selectedClasses.clear();
                    });
                  }
                },
              ),
              const SizedBox(height: 14),

              // Subject
              DropdownButtonFormField<String>(
                value: _selectedSubject,
                decoration: const InputDecoration(
                  labelText: 'Subject *',
                  prefixIcon:
                      Icon(Icons.auto_stories_rounded, color: AppTheme.primaryBlue),
                ),
                items: _subjects
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedSubject = v);
                },
              ),
              const SizedBox(height: 16),

              // Assigned Classes
              Text(
                'Assigned Classes *',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableClasses.map((cls) {
                  final selected = _selectedClasses.contains(cls);
                  return FilterChip(
                    label: Text(cls),
                    selected: selected,
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _selectedClasses.add(cls);
                        } else {
                          _selectedClasses.remove(cls);
                        }
                      });
                    },
                    selectedColor: AppTheme.primaryBlue.withOpacity(0.15),
                    checkmarkColor: AppTheme.primaryBlue,
                    labelStyle: TextStyle(
                      color: selected
                          ? AppTheme.primaryBlue
                          : AppTheme.lightTextSecondary,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),


              // Status toggle (edit mode only)
              if (widget.isEditing) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Account Active',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _isActive
                        ? 'Teacher can login to the portal'
                        : 'Teacher login is disabled',
                    style:
                        const TextStyle(fontSize: 12, color: AppTheme.lightTextSecondary),
                  ),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  activeColor: Colors.green,
                ),
                const SizedBox(height: 8),
              ],



              // ── Save Button ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppTheme.primaryBlue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          widget.isEditing
                              ? 'SAVE CHANGES'
                              : 'CREATE TEACHER RECORD',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryBlue),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
