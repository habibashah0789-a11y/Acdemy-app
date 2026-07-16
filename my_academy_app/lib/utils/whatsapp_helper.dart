import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class WhatsAppHelper {
  static Future<void> openWhatsApp(BuildContext context, String phone, [String? message]) async {
    // Clean phone number (remove spaces, dashes, etc.)
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Auto-format local Pakistani numbers starting with 0 if necessary
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '+92${cleanPhone.substring(1)}';
    } else if (!cleanPhone.startsWith('+')) {
      cleanPhone = '+92$cleanPhone';
    }

    final String query = message != null ? "?text=${Uri.encodeComponent(message)}" : "";
    final Uri whatsappUrl = Uri.parse("https://wa.me/${cleanPhone.replaceFirst('+', '')}$query");

    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('WhatsApp is not installed and web fallback failed.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch WhatsApp: $e')),
        );
      }
    }
  }
}
