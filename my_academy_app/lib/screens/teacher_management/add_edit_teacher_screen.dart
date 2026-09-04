import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/teacher_model.dart';
import '../../services/teacher_service.dart';
import '../../theme/app_theme.dart';

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
  final _uidCtrl = TextEditingController();
  final _teacherIdCtrl = TextEditingController();

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
      _uidCtrl.text = t.id;
      _teacherIdCtrl.text = t.teacherId;
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
    _uidCtrl.dispose();
    _teacherIdCtrl.dispose();
    super.dispose();
  }

  List<String> get _availableClasses =>
      _classesBySection[_selectedSection] ?? [];

  Future<void> _generateTeacherId() async {
    setState(() => _isLoading = true);
    final id = await TeacherService.generateTeacherId(
      section: _selectedSection,
      subject: _selectedSubject,
    );
    if (mounted) {
      setState(() {
        _teacherIdCtrl.text = id;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClasses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one class.'),
          backgroundColor: AppTheme.warningRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final teacher = TeacherModel(
        id: widget.isEditing ? widget.teacher!.id : _uidCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        teacherId: _teacherIdCtrl.text.trim(),
        subject: _selectedSubject,
        section: _selectedSection,
        assignedClasses: List.from(_selectedClasses),
        profilePicUrl:
            widget.isEditing ? (widget.teacher?.profilePicUrl ?? '') : '',
        isActive: _isActive,
        createdAt: widget.isEditing
            ? widget.teacher!.createdAt
            : DateTime.now(),
      );

      if (widget.isEditing) {
        await TeacherService.updateTeacher(teacher);
      } else {
        await TeacherService.createTeacherRecord(
          uid: _uidCtrl.text.trim(),
          teacher: teacher,
        );
      }

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEditing
                  ? '${_nameCtrl.text.trim()} updated successfully.'
                  : '${_nameCtrl.text.trim()} has been added as a teacher. They can now log in with their email and password.',
            ),
            backgroundColor: AppTheme.secondaryGreen,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppTheme.warningRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              // ── Section: Basic Info ──
              _sectionHeader('Basic Information', Icons.person_rounded),
              const SizedBox(height: 12),

              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _uidCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Firebase Auth UID *',
                          prefixIcon: Icon(Icons.fingerprint_rounded,
                              color: AppTheme.primaryBlue),
                          helperText:
                              'Paste from Firebase Auth or tap button to auto-generate',
                          helperMaxLines: 2,
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'UID is required' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Auto-generate UID',
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _uidCtrl.text = FirebaseFirestore.instance
                                .collection('teachers')
                                .doc()
                                .id;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 18),
                        ),
                        child: const Icon(Icons.auto_fix_high_rounded, size: 18),
                      ),
                    ),
                  ],
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
                    selectedColor: AppTheme.primaryBlue.withValues(alpha: 0.15),
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

              // Teacher ID
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _teacherIdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Teacher ID *',
                        prefixIcon:
                            Icon(Icons.tag_rounded, color: AppTheme.primaryBlue),
                        helperText: 'Auto-generated or custom ID',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'ID is required' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _generateTeacherId,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 18),
                    ),
                    child: const Icon(Icons.auto_fix_high_rounded, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 16),

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
                  activeColor: AppTheme.secondaryGreen,
                ),
                const SizedBox(height: 8),
              ],

              // Info box for new teacher
              if (!widget.isEditing) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.accentOrange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.accentOrange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: AppTheme.accentOrange, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'You must create the teacher\'s Firebase Auth account FIRST '
                          'in the Firebase Console (Authentication → Add User), then '
                          'paste the UID here. The UID links this profile to their login.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.accentOrange,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
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
