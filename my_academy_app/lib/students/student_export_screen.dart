import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:hive_flutter/hive_flutter.dart';
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
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _messageController.text = _settingsBox.get('last_whatsapp_message',
        defaultValue:
            'Dear {studentName},\n\nAssalam-o-Alaikum.Ihope you are doing well.\n\nThis is a gentle reminder from Quaid Academy regarding your fee payement.\nYour remaining fee is Rs. {remainingFee}.\n\n We kindly  request you to please the pendingfee at your earliest convenience.Your cooperation helps us continue providing quality education.\n\nIf you have already paid, please ignore this message.\n\nJazakllah Khair\nQuaid Academy Administration.');
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

  Future<void> _processBulkMessages(List<StudentModel> students) async {
    if (students.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Sending'),
        content: Text('Send message to ${students.length} students?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Send')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    int success = 0;
    int skipped = 0;
    int failed = 0;

    for (final student in students) {
      if (student.phone.isEmpty || student.phone.length < 7) {
        skipped++;
        continue;
      }
      try {
        final message = _formatMessage(_messageController.text, student);
        // Note: url_launcher only supports opening the chat, not sending directly
        // due to platform restrictions. We inform the user to send.
        await WhatsAppHelper.openWhatsApp(context, student.phone, message);
        if (!mounted) return;
        await Future.delayed(
            const Duration(seconds: 2)); // Wait for WhatsApp to open
        success++;
      } catch (e) {
        failed++;
      }
    }

    setState(() => _isProcessing = false);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Summary'),
        content: Text(
            'Total: ${students.length}\nSuccess: $success\nSkipped: $skipped\nFailed: $failed'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'))
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //
      appBar: AppBar(title: const Text('Bulk WhatsApp')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                maxLines: null,
                //expands: true,
                decoration: const InputDecoration(
                  labelText: 'Message Template',
                  border: OutlineInputBorder(),
                  hintText:
                      'Enter message with placeholders: {studentName}, {fatherName}, {class}, {remainingFee}, {academyName}',
                ),
                onChanged: _saveMessage,
              ),
            ),
            const SizedBox(height: 80),
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
            onTap: () => _processBulkMessages(_getStudents()),
          ),
          SpeedDialChild(
            child: const Icon(Icons.school),
            label: 'Message 9th',
            onTap: () =>
                _processBulkMessages(_getStudents(classType: 'Matric 9th')),
          ),
          SpeedDialChild(
            child: const Icon(Icons.school),
            label: 'Message 10th',
            onTap: () =>
                _processBulkMessages(_getStudents(classType: 'Matric 10th')),
          ),
          SpeedDialChild(
            child: const Icon(Icons.money_off),
            label: 'Pending Fee',
            onTap: () => _processBulkMessages(_getStudents(isPaid: false)),
          ),
          SpeedDialChild(
            child: const Icon(Icons.payments),
            label: 'Fully Paid',
            onTap: () => _processBulkMessages(_getStudents(isPaid: true)),
          ),
        ],
      ),
    );
  }
}
class WhatsAppHelper {
  static Future<void> openWhatsApp(BuildContext context, String phone, String message) async {
    String formattedPhone = phone.trim();
    if (formattedPhone.startsWith('0')) {
      formattedPhone = '92${formattedPhone.substring(1)}';
    }
    if (formattedPhone.startsWith('+')) {
      formattedPhone = formattedPhone.substring(1);
    }
    
    final url = "https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}";
    
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp not installed or invalid number')),
      );
    }
  }
}