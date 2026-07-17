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

    final String phoneDigits = cleanPhone.replaceFirst('+', '');
    final String query = message != null ? "?text=${Uri.encodeComponent(message)}" : "";
    final Uri whatsappUrl = Uri.parse("https://wa.me/$phoneDigits$query");
    final Uri whatsappAppUrl = Uri.parse("whatsapp://send?phone=$phoneDigits${message != null ? "&text=${Uri.encodeComponent(message)}" : ""}");

    try {
      // 1. Try launching WhatsApp app scheme directly
      bool launched = await launchUrl(whatsappAppUrl);
      if (!launched) {
        // 2. Try launching wa.me universal link in external application
        launched = await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      }
      if (!launched) {
        // 3. Try launching wa.me in platform default (web browser)
        launched = await launchUrl(whatsappUrl, mode: LaunchMode.platformDefault);
      }
      
      if (!launched) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open WhatsApp or web fallback.')),
          );
        }
      }
    } catch (e) {
      // Catch exceptions and try one final fallback to browser
      try {
        bool launched = await launchUrl(whatsappUrl, mode: LaunchMode.platformDefault);
        if (!launched && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch WhatsApp: $e')),
          );
        }
      } catch (err) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch WhatsApp: $err')),
          );
        }
      }
    }
  }
}
