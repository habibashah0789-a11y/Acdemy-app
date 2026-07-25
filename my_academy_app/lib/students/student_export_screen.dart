import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/student_model.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../utils/whatsapp_helper.dart';

class StudentExportScreen extends StatefulWidget {
  const StudentExportScreen({super.key});

  @override
  State<StudentExportScreen> createState() => _StudentExportScreenState();
}

class _StudentExportScreenState extends State<StudentExportScreen> {
  final TextEditingController _messageController = TextEditingController();
  final Box _settingsBox = Hive.box('settings');
  List<StudentModel> _recipients = [];
  final Set<String> _sentIds = {};
  String _currentFilter = 'All Students';

  @override
  void initState() {
    super.initState();
    _messageController.text = _settingsBox.get('last_whatsapp_message',
        defaultValue:
            'Dear {studentName},\n\nAssalam-o-Alaikum. I hope you are doing well.\n\nThis is a gentle reminder from Quaid Academy regarding your fee payment.\nYour remaining fee is Rs. {remainingFee}.\n\nWe kindly request you to please clear the pending fee at your earliest convenience. Your cooperation helps us continue providing quality education.\n\nIf you have already paid, please ignore this message.\n\nJazakAllah Khair\nQuaid Academy Administration.');
    _recipients = _getStudents();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _saveMessage(String message) async {
    await _settingsBox.put('last_whatsapp_message', message);
  }

  String _formatMessage(String template, StudentModel student) {
    final academy = DatabaseService.getAcademyProfile();
    return template
        .replaceAll('{studentName}', student.name)
        .replaceAll('{fatherName}', student.fatherName)
        .replaceAll('{class}', student.classLevel)
        .replaceAll('{remainingFee}', student.feeRemaining.toStringAsFixed(0))
        .replaceAll('{academyName}', academy['name'] ?? 'Quaid Academy');
  }

  List<StudentModel> _getStudents({String? classType, bool? isPaid}) {
    var students = DatabaseService.getAllStudentsLocal();
    if (classType != null) {
      students = students.where((s) => s.classType == classType).toList();
    }
    if (isPaid != null) {
      students =
          students.where((s) => (s.feeRemaining <= 0) == isPaid).toList();
    }
    return students;
  }

  void _applyFilter(String title, List<StudentModel> students) {
    setState(() {
      _currentFilter = title;
      _recipients = students;
      _sentIds.clear();
    });
  }

  Widget _buildAvatarImage(String url, String initials) {
    if (url.isEmpty) {
      return Center(
        child: Text(
          initials.isNotEmpty ? initials : 'S',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryBlue,
          ),
        ),
      );
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, __) => const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (_, __, ___) => const Icon(Icons.person, color: AppTheme.primaryBlue),
      );
    }
    if (url.startsWith('data:image') || (!url.contains('/') && !url.contains('\\') && url.length > 100)) {
      try {
        final base64Str = url.contains(',') ? url.split(',').last : url;
        final bytes = base64Decode(base64Str.trim());
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
        );
      } catch (e) {
        // fallback
      }
    }
    if (url.startsWith('blob:')) {
      return Image.network(url, fit: BoxFit.cover);
    }
    if (!kIsWeb) {
      try {
        return Image.file(
          io.File(url),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.person, color: AppTheme.primaryBlue);
          },
        );
      } catch (e) {
        // fallback
      }
    }
    return const Icon(Icons.person, color: AppTheme.primaryBlue);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bulk WhatsApp')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Template card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Message Template',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _messageController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText:
                            'Enter message with placeholders: {studentName}, {fatherName}, {class}, {remainingFee}, {academyName}',
                        contentPadding: EdgeInsets.all(12),
                      ),
                      onChanged: _saveMessage,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Header for recipients list
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentFilter,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Total Recipients: ${_recipients.length}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                if (_recipients.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Sent: ${_sentIds.length} / ${_recipients.length}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Recipients list
            Expanded(
              child: _recipients.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          const Text(
                            'No recipients found matching the filter.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _recipients.length,
                      itemBuilder: (context, index) {
                        final student = _recipients[index];
                        final isSent = _sentIds.contains(student.id);
                        final hasValidPhone = student.phone.isNotEmpty && student.phone.trim().length >= 7;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: _buildAvatarImage(student.profilePicUrl, student.initials),
                              ),
                            ),
                            title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              'Class: ${student.classType} • Due: Rs ${student.feeRemaining.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: isSent
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : IconButton(
                                    icon: const Icon(Icons.send_rounded, color: Color(0xFF25D366)),
                                    onPressed: !hasValidPhone
                                        ? null
                                        : () async {
                                            final msg = _formatMessage(_messageController.text, student);
                                            await WhatsAppHelper.openWhatsApp(context, student.phone, msg);
                                            setState(() {
                                              _sentIds.add(student.id);
                                            });
                                          },
                                    tooltip: 'Send WhatsApp message',
                                  ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: SpeedDial(
        animatedIcon: AnimatedIcons.menu_close,
        backgroundColor: AppTheme.secondaryGreen,
        children: [
          SpeedDialChild(
            child: const Icon(Icons.group),
            label: 'Message All',
            onTap: () => _applyFilter('All Students', _getStudents()),
          ),
          SpeedDialChild(
            child: const Icon(Icons.school),
            label: 'Message 9th',
            onTap: () =>
                _applyFilter('Matric 9th Recipients', _getStudents(classType: 'Matric 9th')),
          ),
          SpeedDialChild(
            child: const Icon(Icons.school),
            label: 'Message 10th',
            onTap: () =>
                _applyFilter('Matric 10th Recipients', _getStudents(classType: 'Matric 10th')),
          ),
          SpeedDialChild(
            child: const Icon(Icons.money_off),
            label: 'Pending Fee',
            onTap: () => _applyFilter('Pending Fee Recipients', _getStudents(isPaid: false)),
          ),
          SpeedDialChild(
            child: const Icon(Icons.payments),
            label: 'Fully Paid',
            onTap: () => _applyFilter('Fully Paid Recipients', _getStudents(isPaid: true)),
          ),
        ],
      ),
    );
  }
}