import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class WhatsAppHelper {
  static Future<void> openWhatsApp(BuildContext context, String phone) async {
    // Clean phone number (remove spaces, dashes, etc.)
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Auto-format local Pakistani numbers starting with 0 if necessary
    // Since academy is likely in PK (Rs. currency), this is a safe assumption, 
    // otherwise it falls back to the exact number.
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '+92${cleanPhone.substring(1)}';
    } else if (!cleanPhone.startsWith('+')) {
      // If it doesn't have a country code, we can assume PK.
      cleanPhone = '+92$cleanPhone';
    }

    final Uri whatsappMobile = Uri.parse("whatsapp://send?phone=$cleanPhone");
    final Uri whatsappWeb = Uri.parse("https://wa.me/$cleanPhone");

    try {
      if (await canLaunchUrl(whatsappMobile)) {
        await launchUrl(whatsappMobile, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(whatsappWeb)) {
        await launchUrl(whatsappWeb, mode: LaunchMode.externalApplication);
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
