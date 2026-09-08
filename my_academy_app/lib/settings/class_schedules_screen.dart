import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import '../models/student_model.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../utils/whatsapp_helper.dart';
import '../students/student_detail_screen.dart';
import '../widgets/shimmer_loading_widget.dart';

class ClassSchedulesScreen extends StatefulWidget {
  const ClassSchedulesScreen({super.key});

  @override
  State<ClassSchedulesScreen> createState() => _ClassSchedulesScreenState();
}

class _ClassSchedulesScreenState extends State<ClassSchedulesScreen> {
  bool _isLoading = false;
  List<StudentModel> _allStudents = [];
  
  // Selected filter states
  String _selectedGrade = 'Ninth'; // 'Ninth', 'Tenth', 'First Year', 'Second Year'
  String _selectedSubject = 'Biology'; // 'Botany', 'Zoology', 'Biology', 'Maths', 'Physics', 'Chemistry'

  // Predefined schedule slots for chronological sorting
  static const List<String> _scheduleSlots = [
    '7:00 AM', '8:00 AM', '9:00 AM', '10:00 AM', '11:00 AM',
    '12:00 PM', '1:00 PM', '2:00 PM', '3:00 PM', '4:00 PM',
    '5:00 PM', '6:00 PM', '7:00 PM', '8:00 PM', '9:00 PM', '10:00 PM',
  ];

  final List<Map<String, String>> _classOptions = [
    {'value': 'Ninth', 'label': 'Class 9', 'sub': '9th Grade'},
    {'value': 'Tenth', 'label': 'Class 10', 'sub': '10th Grade'},
    {'value': 'First Year', 'label': 'Class 11', 'sub': '1st Year'},
    {'value': 'Second Year', 'label': 'Class 12', 'sub': '2nd Year'},
    {'value': 'MDCAT Session', 'label': 'MDCAT', 'sub': 'MDCAT Batch'},
  ];

  final List<Map<String, dynamic>> _subjectOptions = [
    {'name': 'Biology', 'icon': Icons.biotech_rounded, 'color': Color(0xFF4CAF50)},
    {'name': 'Botany', 'icon': Icons.park_rounded, 'color': Color(0xFF2E7D32)},
    {'name': 'Zoology', 'icon': Icons.pets_rounded, 'color': Color(0xFF00796B)},
    {'name': 'Maths', 'icon': Icons.calculate_rounded, 'color': Color(0xFF00897B)},
    {'name': 'Physics', 'icon': Icons.science_rounded, 'color': Color(0xFF2196F3)},
    {'name': 'Chemistry', 'icon': Icons.colorize_rounded, 'color': Color(0xFFFF9800)},
    {'name': 'English', 'icon': Icons.menu_book_rounded, 'color': Color(0xFF9C27B0)},
  ];

  List<Map<String, dynamic>> get _availableSubjects {
    // All classes have the same 5 core subjects: Biology, Physics, Chemistry, English, Maths
    return _subjectOptions.where((opt) => 
      opt['name'] != 'Botany' && opt['name'] != 'Zoology'
    ).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      // Fetch fresh data from Firestore and sync locally
      _allStudents = await DatabaseService.getAllStudentsFromFirestore();
      await DatabaseService.syncFromFirestore();
    } catch (e) {
      // Offline fallback
      _allStudents = DatabaseService.getAllStudentsLocal();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Filter students based on current selections
  List<StudentModel> get _filteredStudents {
    return _allStudents.where((s) {
      bool matchesGrade = false;
      if (_selectedGrade == 'MDCAT Session') {
        matchesGrade = s.classType.toLowerCase().contains('mdcat') || s.grade.toLowerCase().contains('mdcat');
      } else {
        matchesGrade = s.grade.toLowerCase() == _selectedGrade.toLowerCase();
      }
      
      final subjectsList = s.subject.trim().toLowerCase().split(',').map((x) => x.trim()).toList();
      final tSub = _selectedSubject.trim().toLowerCase();
      
      bool matchesSubject = false;
      if (tSub == 'maths' || tSub == 'math') {
        matchesSubject = subjectsList.any((x) => x == 'math' || x == 'maths');
      } else {
        matchesSubject = subjectsList.contains(tSub);
      }
      
      return matchesGrade && matchesSubject;
    }).toList();
  }

  // Group filtered students by their schedule strings
  Map<String, List<StudentModel>> get _groupedByTime {
    final Map<String, List<StudentModel>> grouped = {};
    for (final student in _filteredStudents) {
      final subjectSchedule = student.getScheduleForSubject(_selectedSubject);
      final time = subjectSchedule.trim().isNotEmpty ? subjectSchedule.trim() : 'Unscheduled';
      grouped.putIfAbsent(time, () => []).add(student);
    }
    return grouped;
  }

  // Sort time slots chronologically using the slot indices
  List<String> get _sortedTimes {
    final times = _groupedByTime.keys.toList();
    times.sort((a, b) {
      final idxA = _scheduleSlots.indexWhere((slot) => a.contains(slot));
      final idxB = _scheduleSlots.indexWhere((slot) => b.contains(slot));
      if (idxA != -1 && idxB != -1) {
        return idxA.compareTo(idxB);
      }
      return a.compareTo(b);
    });
    return times;
  }

  // Build the student avatar image widget helper
  Widget _buildAvatarImage(String url, String initials) {
    if (url.isEmpty) {
      return Center(
        child: Text(
          initials.isNotEmpty ? initials : 'S',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: AppTheme.primaryBlue,
          ),
        ),
      );
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, __) => const ShimmerLoadingWidget(
          width: double.infinity,
          height: double.infinity,
        ),
        errorWidget: (_, __, ___) => const Center(
          child: Icon(Icons.person_rounded, color: AppTheme.primaryBlue, size: 24),
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
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.person_rounded, color: AppTheme.primaryBlue, size: 24),
          ),
        );
      } catch (_) {}
    }
    if (url.startsWith('blob:')) {
      return Image.network(url, fit: BoxFit.cover);
    }
    if (!kIsWeb) {
      try {
        return Image.file(
          io.File(url),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.person_rounded, color: AppTheme.primaryBlue, size: 24),
          ),
        );
      } catch (_) {}
    }
    return const Center(
      child: Icon(Icons.person_rounded, color: AppTheme.primaryBlue, size: 24),
    );
  }

  // Opens a bottom sheet showing the student names and action options
  void _showStudentsSheet(String timeSlot, List<StudentModel> students) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Top notch drag indicator
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Header section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.schedule_rounded, color: AppTheme.primaryBlue),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              timeSlot,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '$_selectedGrade • $_selectedSubject (${students.length} Student${students.length > 1 ? 's' : ''})',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(),
                
                // Student list
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final student = students[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          onTap: () {
                            Navigator.pop(context); // Close sheet
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StudentDetailScreen(student: student),
                              ),
                            );
                          },
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: _buildAvatarImage(student.profilePicUrl, student.initials),
                            ),
                          ),
                          title: Text(
                            student.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('Father: ${student.fatherName}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Call Button
                              IconButton(
                                icon: const Icon(Icons.phone_rounded, color: Colors.blue),
                                onPressed: () async {
                                  final uri = Uri.parse('tel:${student.phone}');
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri);
                                  }
                                },
                              ),
                              // WhatsApp Button
                              IconButton(
                                icon: const Icon(Icons.message_rounded, color: Color(0xFF25D366)),
                                onPressed: () => WhatsAppHelper.openWhatsApp(context, student.phone),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groupedData = _groupedByTime;
    final sortedTimeKeys = _sortedTimes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Class Schedules'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadStudents,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Class/Grade Selector ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: const Text(
              'Select Class',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _classOptions.length,
              itemBuilder: (context, index) {
                final option = _classOptions[index];
                final isSelected = _selectedGrade == option['value'];
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedGrade = option['value']!;
                          final validSubjects = _availableSubjects;
                          final isCurrentSubjectValid = validSubjects.any((s) => s['name'] == _selectedSubject);
                          if (!isCurrentSubjectValid && validSubjects.isNotEmpty) {
                            _selectedSubject = validSubjects.first['name']!;
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 110,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? AppTheme.primaryBlue 
                              : (isDark ? Colors.grey.shade900 : Colors.white),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected 
                                ? AppTheme.primaryBlue 
                                : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                            width: 1.5,
                          ),
                          boxShadow: isSelected ? [
                            BoxShadow(
                              color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ] : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              option['label']!,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              option['sub']!,
                              style: TextStyle(
                                fontSize: 10,
                                color: isSelected 
                                    ? Colors.white.withValues(alpha: 0.8) 
                                    : (isDark ? Colors.white38 : Colors.black45),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // ── Subject Selector ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: const Text(
              'Select Subject',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _availableSubjects.length,
              itemBuilder: (context, index) {
                final option = _availableSubjects[index];
                final String name = option['name']!;
                final IconData icon = option['icon']!;
                final Color themeColor = option['color']!;
                final isSelected = _selectedSubject == name;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    avatar: Icon(
                      icon, 
                      color: isSelected ? Colors.white : themeColor,
                      size: 18,
                    ),
                    label: Text(name),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      setState(() {
                        _selectedSubject = name;
                      });
                    },
                    selectedColor: themeColor,
                    checkmarkColor: Colors.white,
                    backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
                    side: BorderSide(
                      color: isSelected 
                          ? themeColor 
                          : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                    ),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          
          // ── Schedule slots displaying section ──
          Expanded(
            child: _isLoading
                ? ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: 5,
                    itemBuilder: (context, _) => ShimmerLoadingWidget.listTilePlaceholder(context),
                  )
                : sortedTimeKeys.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: sortedTimeKeys.length,
                        itemBuilder: (context, index) {
                          final timeKey = sortedTimeKeys[index];
                          final studentsInSlot = groupedData[timeKey] ?? [];
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              onTap: () => _showStudentsSheet(timeKey, studentsInSlot),
                              leading: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.access_time_filled_rounded,
                                  color: AppTheme.primaryBlue,
                                  size: 24,
                                ),
                              ),
                              title: Text(
                                timeKey,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: AppTheme.primaryBlue,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${studentsInSlot.length} Student${studentsInSlot.length > 1 ? 's' : ''}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              trailing: Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 16,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ).animate().fadeIn().slideY(begin: 0.1, end: 0);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 64,
            color: Colors.grey.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Schedules Found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'There are no students enrolled in Class $_selectedGrade for $_selectedSubject with a registered time schedule.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }
}
